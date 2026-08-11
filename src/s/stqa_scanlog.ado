*! version 2.1.0  10aug2026
* stqa_scanlog: Read a suite log and report what it actually says
* Description: Scans a Stata log for line-initial PASS:/FAIL:/SKIP: verdict
*              tokens and for the completion sentinel, collects the failed test
*              ids, and returns everything in r(). The file is read in Mata so
*              that log content can never be taken for syntax. Verdicts are read
*              from the log, never from a batch exit code.
* Syntax:  stqa_scanlog [using] logfile   -- the keyword is optional; the
*          runners use -using- because that is the convention the other
*          seven file-taking commands require.
* Returns: r(pass) r(fail) r(skip) r(done) r(ids) r(counted) r(declared)
*          r(stataqa)      1 if the log carries any stataqa marker
*          r(logversion)   the version the log says wrote it, if any
*          r(logsupported) 1 if r(logversion) is empty or names a version this
*                          scanner reads, else 0. Empty counts as supported:
*                          every log written before 2.5.0 carries no format
*                          header.
*          Every exit path posts all of them; DET-24 holds that true.
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT

program define stqa_scanlog, rclass
    version 14.0
    syntax [anything(name=logfile)] [using/]

    *-----------------------------------------------------------------------
    * Resolve the path. -using- wins if both forms are supplied.
    *-----------------------------------------------------------------------
    if (`"`using'"' != "") local logfile `"`using'"'

    * A positional path arrives with its quotes still attached; strip one
    * matched pair. char(34) is used rather than a literal quote so that this
    * line cannot itself become the quoting accident described below.
    if (substr(`"`logfile'"', 1, 1) == char(34)) {
        local _len = length(`"`logfile'"')
        local logfile = substr(`"`logfile'"', 2, `_len' - 2)
    }

    if (`"`logfile'"' == "") {
        di as error "stqa_scanlog: no log file specified"
        di as text  "Syntax:  stqa_scanlog using {it:logfile}"
        exit 198
    }

    *-----------------------------------------------------------------------
    * Defaults. They stand if the scan cannot run, so every exit path from
    * this program returns a complete, honest r() set.
    *-----------------------------------------------------------------------
    local s_pass     0
    local s_fail     0
    local s_done     0
    local s_skip     0
    local s_found    0
    local s_counted  0
    local s_declared 0
    local s_ids      ""
    local s_mark     0
    local s_logver   ""

    *-----------------------------------------------------------------------
    * The window of log formats this scanner claims to read.
    *
    * The verdict grammar is a contract, and it has changed once already: until
    * 2.1.0 the completion sentinel was matched ANYWHERE in a line rather than
    * line-initially, so a log written under the old rule can be read as
    * complete by a scanner applying the new one. That is the failure this
    * window exists to make visible rather than silent.
    *
    * Both bounds are literals in this file, on purpose. Reading them from
    * elsewhere would make the answer depend on which copy of the package is
    * installed, when the question being asked is precisely "does THIS reader
    * understand THAT log".
    *
    * Raise MAX when the grammar gains a marker. Raise MIN only when an old
    * format genuinely stops being readable -- doing so declares every archived
    * log below it unverified, which is a claim to make deliberately.
    *-----------------------------------------------------------------------
    local LOGFMT_MIN "2.5.0"
    local LOGFMT_MAX "2.5.0"

    local s_supported 1
    local s_fmtnote   ""

    * The path is handed to Mata through st_local(), not interpolated into a
    * Mata string literal, so a path containing a quote cannot break the call.
    capture mata: stqa_scanlog_impl()
    local mrc = _rc

    if (`mrc' != 0) {
        if (`mrc' == 3499) {
            di as error "stqa_scanlog: the Mata scanner is not loaded"
            di as text  "  Mata's memory was cleared without dropping the ado programs,"
            di as text  "  so this command survived but its scanner did not."
            di as text  "  Run -discard- and try again."
        }
        else {
            di as error "stqa_scanlog: could not read the log (Mata rc `mrc')"
            di as text  "  file: `logfile'"
        }
        * The FULL set, and posted from the defaults rather than from literal
        * zeros. Two reasons, and the second is why it is written this way.
        *
        * The comment above says every exit path returns a complete r() set.
        * Until 2.5.0 this path returned five of seven and the sentence was
        * already false; adding three results made it five of nine. A caller
        * reading r(logsupported) after a Mata failure got a missing value and
        * no way to tell it from a log that had not been checked.
        *
        * Posting the locals means the defaults block above is the single
        * source. A literal zero here is a second copy of a default, and two
        * copies of a default are two things that drift apart. DET-24 pins the
        * two paths to the same result names so this cannot rot again.
        return scalar pass     = `s_pass'
        return scalar fail     = `s_fail'
        return scalar done     = `s_done'
        return scalar skip     = `s_skip'
        return local  ids      `"`s_ids'"'
        return scalar counted  = `s_counted'
        return scalar declared = `s_declared'
        return scalar stataqa  = `s_mark'
        return local  logversion   `"`s_logver'"'
        return scalar logsupported = `s_supported'
        exit 0
    }

    *-----------------------------------------------------------------------
    * Is the declared format one this scanner claims to read?
    *
    * Three outcomes, and each is reported rather than raised. A scanner that
    * aborted on an unfamiliar log would destroy the evidence the caller needs
    * to record WHY nothing could be read -- the same reason a missing log is
    * reported rather than raised, twenty lines below.
    *
    *   no format header  supported. Logs written before 2.5.0 carry none, and
    *                     are recognised by their verdict tokens instead. To
    *                     call them unsupported would orphan every archived log
    *                     in every consumer repository on the day of upgrade.
    *   unparseable       NOT supported, and said so. A format header that
    *                     is not a version is a corrupted or forged line,
    *                     and guessing past it is how a bad log gets read
    *                     as a good one.
    *   outside the window  NOT supported, naming the direction.
    *-----------------------------------------------------------------------
    if (`"`s_logver'"' != "") {
        * Each r(value) is copied into a local immediately. The next call to an
        * r-class program replaces r(), which is the hazard DATA-02 in this
        * package's own suite exists to pin -- and a version comparison reading
        * a stale r() would answer confidently and wrongly.
        stqa_semver `"`s_logver'"'
        local _lv = r(value)
        stqa_semver "`LOGFMT_MIN'"
        local _min = r(value)
        stqa_semver "`LOGFMT_MAX'"
        local _max = r(value)

        if (missing(`_lv')) {
            local s_supported 0
            * The offending string is NOT interpolated into this note. It is
            * already printed on the "written by" line above, and putting
            * untrusted text inside a quoted macro is how the report meant to
            * flag a bad format header ends up dying on one.
            local s_fmtnote   "the declared version is not a version number"
        }
        else if (`_lv' < `_min') {
            local s_supported 0
            local s_fmtnote   "older than `LOGFMT_MIN', the oldest format this scanner reads"
        }
        else if (`_lv' > `_max') {
            local s_supported 0
            local s_fmtnote   "newer than `LOGFMT_MAX', the newest format this scanner knows"
        }
    }

    *-----------------------------------------------------------------------
    * Report.
    *
    * The labels below are deliberately lower case. A log of THIS command's
    * output must not itself be mistaken for a suite log: a line reading
    * "passed  : 12" cannot be confused with a line-initial verdict token.
    *-----------------------------------------------------------------------
    if (`s_found' == 0) {
        * A MISSING log is not an error to abort on. It is precisely the
        * hung-, killed- or never-started-run case that the completion
        * sentinel exists to catch, and the caller needs the r() set in order
        * to record it. Aborting with r(601) here would destroy the evidence.
        di as error "stqa_scanlog: log file not found"
        di as text  "  file: `logfile'"
        di as text  "  Reported as r(done)=0 (run INCOMPLETE), not raised as an error:"
        di as text  "  a missing log is the hung-run case the sentinel exists to catch."
    }
    else {
        di as text  "stqa_scanlog: `logfile'"
        di as text  "  passed   : `s_pass'"
        di as text  "  failed   : `s_fail'"
        di as text  "  skipped  : `s_skip'"
        if (`s_done' == 1) {
            di as text  "  sentinel : found (the suite ran to completion)"
        }
        else {
            di as error "  sentinel : MISSING -- the suite did not run to completion"
        }
        if (`"`s_ids'"' != "") {
            di as text  "  failed ids:`s_ids'"
        }

        * Provenance, when the log states it. A log written by a different
        * version was read under THIS version's grammar, and the reader is
        * entitled to know that before trusting the counts above. Said, not
        * acted on: the precedent is stqa_replay, which reports a Stata-version
        * mismatch and declines to compare rather than guessing through it.
        if (`"`s_logver'"' != "") {
            di as text  `"  written by: stataqa `s_logver'"'
            if (`s_supported' == 0) {
                di as error `"  format   : `s_fmtnote'"'
                di as text  "  The counts above were read with this version's rules."
                di as text  "  Re-read the log with stataqa `s_logver', or treat the"
                di as text  "  figures as unverified."
            }
        }

        * The compatibility observation. Phrased for what was actually
        * established -- no markers were found -- and never as "this is not a
        * stataqa log", which is a claim this command cannot support: an empty
        * log carries no markers, and so does a genuine run that died before
        * its first test. Both are reported honestly by the sentinel line
        * above; this line only stops a wrong filename from being read as a
        * red suite.
        if (`s_mark' == 0) {
            di as text  "  markers  : none -- this may not be a stataqa run log"
        }
    }

    * This command reports; it does not judge. It exits 0 even when the log is
    * full of failures, because the gate decision belongs to the caller
    * (stqa_run), which also owns the counters and the closing banner.
    return scalar pass = `s_pass'
    return scalar fail = `s_fail'
    return scalar done = `s_done'
    return scalar skip = `s_skip'
    return local  ids  `"`s_ids'"'

    * The two components of r(fail), so a caller can tell a failure that was
    * emitted as a token from one that only the closing sentinel declared --
    * the latter means the assertion was suppressed by -capture-.
    return scalar counted  = `s_counted'
    return scalar declared = `s_declared'

    * Provenance. r(stataqa) is 1 when the log carries any marker only this
    * package writes, 0 when it carries none -- which distinguishes "the run
    * did not finish" from "this file was never produced by stataqa", two
    * diagnoses that were previously identical in every returned figure.
    * r(logversion) is the version the log says wrote it, empty for a log
    * written before the format header existed.
    return scalar stataqa    = `s_mark'
    return local  logversion `"`s_logver'"'

    * 1 when this scanner claims to understand the format the log declares.
    * A log with no format header is supported: it predates the header and
    * is read by its verdict tokens. 0 means the counts above were produced
    * by rules the log was not written under, and should not be trusted
    * without re-reading under the version named in r(logversion).
    return scalar logsupported = `s_supported'
end

*---------------------------------------------------------------------------
* Compare two dotted versions as one number, so that 2.10.0 sorts after 2.9.0
* rather than before it. Missing when the string is not MAJOR.MINOR.PATCH,
* which the caller treats as "unreadable", never as "old" or "new" -- a
* corrupted format header is not evidence about a direction.
*
* Written as a program rather than inline because it is used three times and
* an off-by-one in a version comparison is the kind of defect that reports the
* wrong answer confidently.
*---------------------------------------------------------------------------
program define stqa_semver, rclass
    version 14.0
    args v
    local a = .
    if regexm(`"`v'"', "^([0-9]+)\.([0-9]+)\.([0-9]+)$") {
        local a = real(regexs(1)) * 1000000 + real(regexs(2)) * 1000 + real(regexs(3))
    }
    return scalar value = `a'
end

*===========================================================================
* THE SCANNER
*===========================================================================
* It is written in MATA on purpose, and that is not a style preference.
*
* A Stata log echoes the suite's own source code, and that source is full of
* backticks and compound double quotes. The ordinary Stata idiom for reading a
* file line by line ends up wrapping the line just read in compound quotes and
* passing it to a string function such as trim(). The moment a line carrying an
* opening backtick or an odd number of double quotes reaches that
* macro-expanded string expression, the quote closes early and the caller dies
* with "too few quotes", r(132) -- on a log that is perfectly well formed.
*
* Mata reads the file as DATA, with cat(). Nothing in the content is ever
* offered to the parser, so no log can break the scanner that reads it. This
* was learned the expensive way on a suite whose only crime was containing its
* own test code, and it is the reason the whole file exists.
*
* For the same reason, no literal backtick, dollar sign or double quote appears
* in the Mata source below: lines inside a mata block in an ado file are still
* macro-expanded before Mata compiles them. char() is used instead.
*---------------------------------------------------------------------------
version 14.0

* Drop any previous copy before compiling, so a re-install or a second adopath
* entry cannot leave a stale scanner in memory. A non-zero rc here means only
* "there was nothing to drop", which is the ordinary first-load path (and the
* path after -clear all-, which drops Mata functions and ado programs alike, so
* the next call reloads this file and recompiles). Anything else means Mata
* itself is in a state we should not compile on top of.
capture mata: mata drop stqa_scanlog_impl()
local _drop_rc = _rc
if (`_drop_rc' != 0 & `_drop_rc' != 111 & `_drop_rc' != 3000 & `_drop_rc' != 3499) {
    di as error "stqa_scanlog: Mata is in an unexpected state (rc `_drop_rc');"
    di as error "              the log scanner could not be installed."
    error `_drop_rc'
}

mata:

void stqa_scanlog_impl()
{
    string colvector lines
    string scalar    path, s, ids, id, tail, head, logver
    real scalar      i, n, p, q, np, nf, done, skip, declared, d_fail, d_inc
    real scalar      mark

    path = st_local("logfile")

    np = 0 ; nf = 0 ; done = 0 ; skip = 0 ; ids = "" ; declared = 0
    mark = 0 ; logver = ""

    // Post the empty result first, so that every early return below still
    // leaves the caller with a complete set of locals.
    st_local("s_pass",  "0")
    st_local("s_fail",  "0")
    st_local("s_done",  "0")
    st_local("s_skip",  "0")
    st_local("s_ids",   "")
    st_local("s_found", "0")
    st_local("s_mark",  "0")
    st_local("s_logver", "")

    if (path == "")         return
    if (!fileexists(path))  return

    st_local("s_found", "1")

    lines = cat(path)
    n     = rows(lines)

    for (i = 1; i <= n; i++) {

        s = strtrim(lines[i])

        // Strip leading SMCL directives. A log opened without the -text-
        // option writes verdicts as {res}PASS: ... , and a scanner that
        // silently reported zero passes on such a log would be worse than
        // one that failed loudly. Stripping them also preserves the
        // line-initial rule: an echoed source line reads {com}. display ...
        // which still begins with a period once the directive is gone.
        while (substr(s, 1, 1) == "{") {
            p = strpos(s, "}")
            if (p == 0) break
            s = strtrim(substr(s, p + 1, .))
        }

        // A verdict counts only when the line STARTS with the token. The
        // suite's own -display- statements are echoed into the log as well,
        // and those echoes begin with a period or with a line number, so they
        // do not count. This is the whole reason the contract insists that
        // verdict tokens be emitted at the start of a line.
        if (substr(s, 1, 6) == "PASS: ") {
            np   = np + 1
            mark = 1
        }

        if (substr(s, 1, 6) == "FAIL: ") {
            nf = nf + 1
            mark = 1

            // The id is the first token after the marker.
            id = strtrim(substr(s, 7, 32))
            p  = strpos(id, " ")
            if (p > 0) id = substr(id, 1, p - 1)

            // The id is about to travel back through a Stata local and then
            // through -return local-, so strip the four characters that could
            // reopen the quoting wound this function exists to avoid:
            // backtick, single quote, dollar sign, double quote.
            id = subinstr(id, char(96), "")
            id = subinstr(id, char(39), "")
            id = subinstr(id, char(36), "")
            id = subinstr(id, char(34), "")

            if (id != "") ids = ids + " " + id
        }

        // The completion sentinel. Its ABSENCE is the signal that matters: a
        // suite that was killed, hung or crashed leaves a log full of PASS
        // lines and no sentinel, and must never be recorded green.
        //
        // The sentinel is matched LINE-INITIALLY, under exactly the same rule
        // as the verdict tokens, and for the same reason. Matching it anywhere
        // in the line -- as this function did until version 2.1.0 -- means a
        // suite can be recorded complete because it happened to ECHO the words.
        // That is not hypothetical: a run log of the yaml package's own
        // suite (measured, 2026) carries the echoed source line
        //     . di as result "  ALL TESTS PASSED"
        // inside a run that failed, and a substring match reports that run as
        // having run to completion. The distinction the rule enforces is
        // between "the log mentions the sentinel" and "the suite emitted it".
        if (substr(s, 1, 17) == "ALL CHECKS PASSED") {
            done = 1
            mark = 1
        }

        // The red sentinel carries its own count: "STATAQA SUITE COMPLETE
        // (7 checks, 2 failed)". That declared figure must be honoured, and
        // not merely used to set done, because of a seam that otherwise
        // produces a silent false pass. The documented way to write a test is
        //     capture stqa_assert <cond>
        // and -capture- suppresses the -display- through which the assertion
        // emits its FAIL: token. The failure is booked in the counters, so the
        // runner knows about it and states it here, but NO line-initial token
        // ever reaches the log -- and a scanner that counts only tokens
        // reports zero failures for a suite that failed. Reading the declared
        // count closes that gap for every consumer of the log at once: this
        // program, stqa_report, and anything scraping the logs from CI.
        if (substr(s, 1, 22) == "STATAQA SUITE COMPLETE") {
            done = 1
            mark = 1
            p = strpos(s, ",")
            if (p > 0) {
                tail = strtrim(substr(s, p + 1, .))
                tail = subinstr(tail, ")", "")
                // "3 failed, 1 incomplete" -- both count against the run. A
                // suite that is red ONLY because a file never finished
                // declares 0 failed, and reading that alone would report a
                // green run for a suite the runner gated red. Sentinels
                // written before the incomplete clause existed simply have
                // no match here, which scores 0, which is what they meant.
                d_fail = 0
                d_inc  = 0
                p = strpos(tail, " failed")
                if (p > 0) {
                    head = strtrim(substr(tail, 1, p - 1))
                    if (head != "" & strtoreal(head) != .) d_fail = strtoreal(head)
                }
                p = strpos(tail, " incomplete")
                if (p > 0) {
                    head = strtrim(substr(tail, 1, p - 1))
                    q    = strrpos(head, ",")
                    if (q > 0) head = strtrim(substr(head, q + 1, .))
                    if (head != "" & strtoreal(head) != .) d_inc = strtoreal(head)
                }
                declared = max((declared, d_fail + d_inc))
            }
        }

        // Legacy spellings, kept so that logs written by the earlier runners
        // still read correctly. A ledger is only worth keeping if its old
        // entries remain legible. These are matched line-initially too, so a
        // suite that tags its sentinel with a prefix (datalib's suite emits
        // "DET: ALL CHECKS PASSED (n checks)") must move the tag or adopt
        // stqa_run, which stamps the sentinel itself. That is deliberate: a
        // prefix-tolerant rule is a substring rule wearing a hat.
        if (substr(s, 1, 22) == "ALL SMOKE TESTS PASSED") done = 1
        if (substr(s, 1, 16) == "ALL TESTS PASSED")       done = 1
        if (substr(s, 1, 17) == "ACCEPTANCE PASSED")      done = 1

        // A missing PREREQUISITE is not a defect in the code under test, so it
        // is reported as skipped and never counted against the gate -- and
        // never counted as a pass either. It is still counted, because a suite
        // that quietly stops running is how one drifts out of the gate
        // altogether.
        //
        // Only the explicit marker counts. An earlier version also treated any
        // line containing "fixtures missing" as a skip, inherited verbatim from
        // datalib's own suite scanner, where it was a local convenience. In a
        // general package it is a false-skip waiting to happen: a log echoing a
        // test that merely mentions the phrase would be scored as skipped. A
        // missing prerequisite is declared with stqa_skip, which emits the
        // marker this rule reads.
        if (substr(s, 1, 6) == "SKIP: ") {
            skip = skip + 1
            mark = 1
        }

        // The format header stqa_run stamps into every case log it
        // opens: "STATAQA LOG 2.5.0". Read here rather than inferred, because
        // the grammar this function applies -- line-initial verdict tokens
        // plus a sentinel -- is a contract, and a scanner that cannot tell
        // WHICH version wrote a log has no way to know whether its own rules
        // are the rules that log was written under. Matched line-initially
        // like everything else.
        if (substr(s, 1, 12) == "STATAQA LOG ") {
            logver = strtrim(substr(s, 13, .))
            p = strpos(logver, " ")
            if (p > 0) logver = substr(logver, 1, p - 1)

            // Sanitised exactly as a failed-test id is, and for the same
            // reason: this string is about to travel through a Stata local,
            // through -return local-, and into a -display-. A format header
            // is untrusted input -- it can be corrupted, truncated by a killed
            // run, or simply not written by this package at all -- and a
            // version carrying a backtick or a quote would break the very
            // report that exists to say the version looks wrong.
            logver = subinstr(logver, char(96), "")
            logver = subinstr(logver, char(39), "")
            logver = subinstr(logver, char(36), "")
            logver = subinstr(logver, char(34), "")

            mark = 1
        }
    }

    // Is this a stataqa log at all? The union of everything only stataqa
    // writes. This exists because every counter above reads ZERO on a log
    // stataqa never produced -- which is byte-identical to a genuine stataqa
    // log whose run died before the sentinel was stamped. Those are different
    // defects with different remedies: investigate the run, versus you named
    // the wrong file. Without this the caller cannot tell them apart.
    //
    // It reports the ABSENCE OF EVIDENCE, never the absence of the thing. An
    // empty log carries no markers, and so does a genuine run that died before
    // its first test. That is why the flag is named for what was found and the
    // message says "carries no stataqa markers", never "is not a stataqa log".

    // The reported failure count is the greater of what was counted from
    // tokens and what the closing sentinel declared. They differ only when
    // failures were suppressed by -capture- (see above), and in that case the
    // declared figure is the truthful one. Taking the maximum rather than the
    // sum avoids double counting when both are present, and keeps the rule
    // conservative in the direction that matters: a suite is never reported
    // with fewer failures than some part of the log claims it had.
    st_local("s_pass",     strofreal(np))
    st_local("s_fail",     strofreal(max((nf, declared))))
    st_local("s_counted",  strofreal(nf))
    st_local("s_declared", strofreal(declared))
    st_local("s_done",     strofreal(done))
    st_local("s_skip",     strofreal(skip))
    st_local("s_ids",      ids)
    st_local("s_mark",     strofreal(mark))
    st_local("s_logver",   logver)
}

end
