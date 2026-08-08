*! version 2.0.0  06aug2026
* stqa_scanlog: Read a suite log and report what it actually says
* Description: Scans a Stata log for line-initial PASS:/FAIL:/SKIP: verdict
*              tokens and for the completion sentinel, collects the failed test
*              ids, and returns everything in r(). The file is read in Mata so
*              that log content can never be taken for syntax. Verdicts are read
*              from the log, never from a batch exit code.
* Options: using(filename)   the log to scan (may also be given positionally)
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
        return scalar pass = 0
        return scalar fail = 0
        return scalar done = 0
        return scalar skip = 0
        return local  ids  ""
        exit 0
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
    string scalar    path, s, ids, id, tail, head
    real scalar      i, n, p, q, np, nf, done, skip, declared, d_fail, d_inc

    path = st_local("logfile")

    np = 0 ; nf = 0 ; done = 0 ; skip = 0 ; ids = "" ; declared = 0

    // Post the empty result first, so that every early return below still
    // leaves the caller with a complete set of locals.
    st_local("s_pass",  "0")
    st_local("s_fail",  "0")
    st_local("s_done",  "0")
    st_local("s_skip",  "0")
    st_local("s_ids",   "")
    st_local("s_found", "0")

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
        if (substr(s, 1, 6) == "PASS: ") np = np + 1

        if (substr(s, 1, 6) == "FAIL: ") {
            nf = nf + 1

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
        if (substr(s, 1, 17) == "ALL CHECKS PASSED")      done = 1

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
        if (substr(s, 1, 6) == "SKIP: ") skip = skip + 1
    }

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
}

end
