*! version 2.3.0  07aug2026
* stqa_history: Append-only certification ledger for stataqa gate runs
* Description: Appends one structured stanza per gate run to a ledger file --
*              date, times, duration, git branch, package version, Stata
*              version and flavour, counts, failed ids, skip notes and the
*              verdict. Red and incomplete runs are recorded exactly like green
*              ones. In -check- mode it reads the last stanza back and returns
*              its fields in r().
* Options: using(filename), verdict(), notes(), starttime(), endtime(), check
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT

program define stqa_history, rclass
    version 14.0
    syntax [using/] [,                  ///
            VERDict(string)             ///
            NOTes(string)               ///
            STARTtime(string)           ///
            ENDtime(string)             ///
            CHECK ]

    local histfile `"`using'"'
    if (`"`histfile'"' == "") local histfile "qa/test_history.txt"

    *=======================================================================
    * CHECK MODE -- read the last stanza back
    *=======================================================================
    * This is what CI runs to validate the record without re-running any Stata
    * tests: the ledger is the artefact, so the ledger is what gets inspected.
    if ("`check'" != "") {

        local h_found     0
        local h_date      ""
        local h_start     ""
        local h_end       ""
        local h_duration  ""
        local h_branch    ""
        local h_commit    ""
        local h_dirty     ""
        local h_version   ""
        local h_stata     ""
        local h_run       ""
        local h_pass      ""
        local h_fail      ""
        local h_skip      ""
        local h_ids       ""
        local h_skipnotes ""
        local h_notes     ""
        local h_verdict   ""
        local h_build     ""
        local h_log       ""
        local h_checks    ""
        local h_tests_raw   ""
        local h_suites_raw  ""
        local h_suites_run     ""
        local h_suites_green   ""
        local h_suites_red     ""
        local h_suites_skipped ""

        * Read in Mata, for the same reason stqa_scanlog does: the ledger
        * carries free text (notes, skip reasons) that may contain backticks
        * and unbalanced quotes, and a macro-expanded read of such a line dies
        * with r(132) on a file that is perfectly well formed.
        capture mata: stqa_history_read()
        local mrc = _rc

        if (`mrc' != 0) {
            if (`mrc' == 3499) {
                di as error "stqa_history: the Mata ledger reader is not loaded"
                di as text  "  Run -discard- and try again."
            }
            else {
                di as error "stqa_history: could not read the ledger (Mata rc `mrc')"
                di as text  "  file: `histfile'"
            }
            return scalar found = 0
            exit 0
        }

        if (`h_found' == 0) {
            di as error "stqa_history: no run stanza found"
            di as text  "  file: `histfile'"
            di as text  "  Nothing has been certified yet, or the ledger is not a ledger."
            return scalar found = 0
            exit 0
        }

        local r_run  = real("`h_run'")
        local r_pass = real("`h_pass'")
        local r_fail = real("`h_fail'")
        local r_skip = real("`h_skip'")
        if (`r_run'  >= .) local r_run  = 0
        if (`r_pass' >= .) local r_pass = 0
        if (`r_fail' >= .) local r_fail = 0
        if (`r_skip' >= .) local r_skip = 0

        local r_green = 0
        if ("`h_verdict'" == "GATE GREEN") local r_green = 1

        * Lower-case labels again, so that a log of this output can never be
        * mistaken for a suite log by stqa_scanlog.
        di as text "stqa_history (check): `histfile'"
        di as text "  run      : `h_date'  `h_start' to `h_end'  (`h_duration')"
        di as text "  branch   : `h_branch'"
        if (`"`h_commit'"' != "") di as text "  commit   : `h_commit'"
        if (`"`h_dirty'"'  != "") di as text "  dirty    : `h_dirty'"
        di as text "  version  : `h_version'"
        di as text "  stata    : `h_stata'"
        di as text "  counts   : `r_run' run, `r_pass' passed, `r_fail' failed, `r_skip' skipped"
        if (`"`h_ids'"' != "")       di as text "  failed ids: `h_ids'"
        if (`"`h_skipnotes'"' != "") di as text "  skip notes: `h_skipnotes'"
        if (`"`h_notes'"' != "")     di as text "  notes    : `h_notes'"
        if (`r_green' == 1) {
            di as text  "  verdict  : `h_verdict'"
        }
        else {
            di as error "  verdict  : `h_verdict'"
        }

        return scalar found   = 1
        return scalar green   = `r_green'
        return scalar run     = `r_run'
        return scalar pass    = `r_pass'
        return scalar fail    = `r_fail'
        return scalar skip    = `r_skip'
        return local  verdict   `"`h_verdict'"'
        return local  notes     `"`h_notes'"'
        return local  skipnotes `"`h_skipnotes'"'
        return local  ids       `"`h_ids'"'
        return local  stata     `"`h_stata'"'
        return local  version   `"`h_version'"'
        return local  branch    `"`h_branch'"'
        return local  commit    `"`h_commit'"'
        return local  dirty     `"`h_dirty'"'
        return local  duration  `"`h_duration'"'
        return local  end       `"`h_end'"'
        return local  start     `"`h_start'"'
        return local  date      `"`h_date'"'
        return local  file      `"`histfile'"'

        * Fields the four production ledgers carry that this package's own
        * stanza does not. They are returned rather than ignored so that
        * -check- mode is useful against an existing ledger, not only against
        * one stataqa wrote.
        return local  build       `"`h_build'"'
        return local  log         `"`h_log'"'
        return local  tests_raw   `"`h_tests_raw'"'
        return local  suites_raw  `"`h_suites_raw'"'
        if (`"`h_checks'"' != "")         return scalar checks         = real(`"`h_checks'"')
        if (`"`h_suites_run'"' != "")     return scalar suites_run     = real(`"`h_suites_run'"')
        if (`"`h_suites_green'"' != "")   return scalar suites_green   = real(`"`h_suites_green'"')
        if (`"`h_suites_red'"' != "")     return scalar suites_red     = real(`"`h_suites_red'"')
        if (`"`h_suites_skipped'"' != "") return scalar suites_skipped = real(`"`h_suites_skipped'"')

        * The verdict wording differs by suite: this package and datalib write
        * GATE GREEN, the other three write ALL TESTS PASSED. r(green) above
        * recognises only the first, so a caller validating a foreign ledger
        * gets the second here rather than a silent zero.
        local r_pass_words = 0
        if (`"`h_verdict'"' == "ALL TESTS PASSED")  local r_pass_words = 1
        if (`"`h_verdict'"' == "ALL CHECKS PASSED") local r_pass_words = 1
        if (`"`h_verdict'"' == "PASSED")            local r_pass_words = 1
        return scalar passed_wording = `r_pass_words'
        exit 0
    }

    *=======================================================================
    * WRITE MODE
    *=======================================================================

    *-- a partial run is not a gate record ---------------------------------
    * Single-test mode runs one id. Recording that as though it were a gate
    * run would put a one-line "green" into the certification ledger, which is
    * the exact flattery the ledger exists to remove.
    if (`"$stqa_target"' != "") {
        di as text "stqa_history: single-test mode (target = $stqa_target)."
        di as text "  A partial run is not a gate record, so nothing was appended to"
        di as text "  `histfile'."
        return scalar written = 0
        return local  file `"`histfile'"'
        exit 0
    }

    *-- counters -----------------------------------------------------------
    * Read from the live globals, so the stanza can never drift from what
    * actually ran. Globals are used rather than locals because they survive
    * the -clear all- that test files issue.
    local n_pass  "$stqa_n_pass"
    local n_fail  "$stqa_n_fail"
    local n_skip  "$stqa_n_skip"
    local n_total "$stqa_n_total"

    capture confirm number `n_pass'
    if (_rc) local n_pass 0
    capture confirm number `n_fail'
    if (_rc) local n_fail 0
    capture confirm number `n_skip'
    if (_rc) local n_skip 0
    capture confirm number `n_total'
    if (_rc) local n_total 0

    local f_ids ""
    capture local f_ids `"$stqa_failed_ids"'
    if (_rc) local f_ids "(failed ids unreadable -- unbalanced quotes)"

    local sk_notes ""
    capture local sk_notes `"$stqa_skip_notes"'
    if (_rc) local sk_notes "(skip notes unreadable -- unbalanced quotes)"

    *-- times and duration -------------------------------------------------
    local t_end `"`endtime'"'
    if (`"`t_end'"' == "") local t_end = c(current_time)
    local t_start `"`starttime'"'
    if (`"`t_start'"' == "") local t_start `"`t_end'"'

    local duration "(unknown)"
    local dur_ok = 1
    local len_s = length(`"`t_start'"')
    local len_e = length(`"`t_end'"')
    if (`len_s' < 8 | `len_e' < 8) local dur_ok = 0

    if (`dur_ok' == 1) {
        local sh = real(substr(`"`t_start'"', 1, 2))
        local sm = real(substr(`"`t_start'"', 4, 2))
        local ss = real(substr(`"`t_start'"', 7, 2))
        local eh = real(substr(`"`t_end'"',   1, 2))
        local em = real(substr(`"`t_end'"',   4, 2))
        local es = real(substr(`"`t_end'"',   7, 2))
        if (`sh' >= . | `sm' >= . | `ss' >= .) local dur_ok = 0
        if (`eh' >= . | `em' >= . | `es' >= .) local dur_ok = 0
    }

    if (`dur_ok' == 1) {
        local secs = (`eh'*3600 + `em'*60 + `es') - (`sh'*3600 + `sm'*60 + `ss')
        * c(current_time) is a clock, not a stopwatch. A run that crosses
        * midnight yields a negative difference, and one day is the only
        * correction it is safe to assume: a suite still running 24 hours
        * later is not a suite anybody is waiting on.
        if (`secs' < 0) local secs = `secs' + 86400
        local duration = string(floor(`secs'/60)) + "m " + string(mod(`secs',60)) + "s"
    }

    *-- git provenance: branch, commit, dirty ------------------------------
    * One shared implementation, stqa_gitinfo: .git is read directly (no
    * shell for branch/commit; shell judged by artifact for dirty).  The
    * commit matters more than the branch -- branch names are mutable and
    * Version: is hand-maintained; only the SHA identifies a tree -- and
    * Dirty: qualifies it: a certification of a dirty tree certifies
    * something that exists nowhere but that machine.
    local branch "(unknown)"
    local commit "(unknown)"
    local dirtystate "(not determined)"
    capture stqa_gitinfo
    if (_rc == 0) {
        local branch     `"`r(branch)'"'
        local commit     `"`r(commit)'"'
        local dirtystate `"`r(dirtystate)'"'
        if (r(inrepo) == 0) {
            di as text "stqa_history: no git repository here; branch and commit recorded as absent"
        }
    }

    *-- package version ----------------------------------------------------
    * Parsed from the header of the INSTALLED stataqa.ado, not from a constant
    * in this file: the ledger must record the version that actually ran.
    local pkgver "unknown"
    local pkgfn  ""
    capture which stataqa
    if (_rc == 0) local pkgfn `"`r(fn)'"'
    if (`"`pkgfn'"' == "") {
        capture findfile stataqa.ado
        if (_rc == 0) local pkgfn `"`r(fn)'"'
    }

    if (`"`pkgfn'"' != "") {
        tempname vh
        capture file open `vh' using `"`pkgfn'"', read text
        if (_rc == 0) {
            local k = 0
            file read `vh' vline
            local eof = r(eof)
            while (`eof' == 0 & `k' < 20) {
                local k = `k' + 1
                * Broad on purpose. The old pattern demanded the literal
                * lower-case word "version", one or more literal SPACES (a
                * tab did not qualify), and a strict three-part semver. Any
                * deviation -- "*! v 2.2.0", "*! Version 2.2.0", a two-part
                * "*! version 3.0", a tab after the word -- left the stamp at
                * "unknown" while the stanza was still written. A ledger that
                * records an unknown version without saying so is asserting
                * less than it appears to.
                capture local hit = ustrregexm(`"`macval(vline)'"', "^\*!.*?[ \t!](?i:version|v)[ \t.]*([0-9][0-9.]*[0-9]|[0-9])")
                if (_rc) local hit = 0
                if (`hit' == 1) {
                    capture local pkgver = ustrregexs(1)
                    if (_rc) local pkgver "unknown"
                    continue, break
                }
                file read `vh' vline
                local eof = r(eof)
            }
            file close `vh'
        }
    }

    * Say so. The stanza is written either way -- an incomplete record is
    * still a record -- but a reader must be able to tell "version 2.2.0" from
    * "the version could not be read", and silence cannot carry that.
    if (`"`pkgver'"' == "unknown") {
        di as txt "stqa_history: package version could not be read from `pkgfn'; recorded as unknown"
    }

    *-- Stata version and flavour ------------------------------------------
    * c(flavor) alone is not the flavour: it reports "IC" (or "Small") on a
    * Stata/MP installation, so a ledger built from it would certify the wrong
    * binary. c(MP) and c(SE) are the fields that actually distinguish them.
    local sflavor "`c(flavor)'"
    capture local is_mp = c(MP)
    if (_rc) local is_mp = 0
    capture local is_se = c(SE)
    if (_rc) local is_se = 0
    if (`is_se' == 1) local sflavor "SE"
    if (`is_mp' == 1) local sflavor "MP"
    local statastr "`c(stata_version)' `sflavor' (`c(os)')"

    *-- verdict ------------------------------------------------------------
    * A caller that knows better (stqa_run, which also holds the sentinel
    * result from stqa_scanlog) passes verdict() and it is recorded verbatim.
    * Derived otherwise: a failure outranks everything, and a run in which
    * nothing was counted is INCOMPLETE rather than green, because a suite
    * that never ran is not a suite that passed.
    local vd `"`verdict'"'
    if (`"`vd'"' == "") {
        local vd "GATE GREEN"
        if (`n_total' <= 0) local vd "INCOMPLETE"
        if (`n_fail'  >  0) local vd "GATE RED"
    }

    *-- make sure the default location exists ------------------------------
    if (`"`using'"' == "") {
        capture mkdir "qa"
        local mkrc = _rc
        if (`mkrc' != 0 & `mkrc' != 693) {
            di as text "stqa_history: could not create qa/ (rc `mkrc'); the append may fail"
        }
    }

    *-- append -------------------------------------------------------------
    * APPEND ONLY. There is deliberately no -replace- option: this is the
    * Gould (2001) principle that tests are never thrown away, applied to the
    * record of the runs. A red or incomplete run is written in exactly the
    * same shape as a green one. A hand-maintained green snapshot once
    * asserted success about a run that had in fact hung; a ledger that can
    * only grow cannot tell that lie.
    local sep "=============================================================================="

    tempname fh
    capture file open `fh' using `"`histfile'"', write append text
    local orc = _rc
    if (`orc' != 0) {
        di as error "stqa_history: could not append the ledger (rc `orc')"
        di as text  "  file: `histfile'"
        di as text  "  The run itself is unaffected, but NO gate record was written."
        return scalar written = 0
        return local  verdict `"`vd'"'
        return local  file    `"`histfile'"'
        exit 0
    }

    file write `fh' _n "`sep'" _n
    file write `fh' "Test Run:   `c(current_date)'" _n
    file write `fh' "Started:    `t_start'" _n
    file write `fh' "Ended:      `t_end'" _n
    file write `fh' "Duration:   `duration'" _n
    file write `fh' `"Branch:     `macval(branch)'"' _n
    file write `fh' `"Commit:     `macval(commit)'"' _n
    file write `fh' `"Dirty:      `macval(dirtystate)'"' _n
    file write `fh' "Version:    `pkgver'" _n
    file write `fh' "Stata:      `statastr'" _n
    file write `fh' "Run:        `n_total'" _n
    file write `fh' "Passed:     `n_pass'" _n
    file write `fh' "Failed:     `n_fail'" _n
    file write `fh' "Skipped:    `n_skip'" _n
    file write `fh' `"Failed IDs: `macval(f_ids)'"' _n
    file write `fh' `"Skip notes: `macval(sk_notes)'"' _n
    file write `fh' `"Notes:      `macval(notes)'"' _n
    file write `fh' "Result:     `vd'" _n
    file write `fh' "`sep'" _n
    file close `fh'

    di as text "stqa_history: appended to `histfile'"
    di as text "  result   : `vd'"

    return scalar written = 1
    return scalar run     = `n_total'
    return scalar pass    = `n_pass'
    return scalar fail    = `n_fail'
    return scalar skip    = `n_skip'
    return local  duration `"`duration'"'
    return local  stata    `"`statastr'"'
    return local  version  `"`pkgver'"'
    return local  branch   `"`branch'"'
    return local  verdict  `"`vd'"'
    return local  file     `"`histfile'"'
end

*===========================================================================
* THE LEDGER READER
*===========================================================================
* In Mata for the same hard-won reason as stqa_scanlog: the ledger holds free
* text supplied by whoever ran the suite -- notes, skip reasons, failed ids --
* and the ordinary Stata idiom for reading a file wraps each line in compound
* quotes and hands it to a string function. A line carrying an opening backtick
* or an odd number of double quotes closes the quote early and the reader dies
* with "too few quotes", r(132). Mata reads the file as data with cat(), so the
* ledger can never break the command that reads it.
*
* No literal backtick, dollar sign or double quote appears in the Mata source
* below, because lines inside a mata block in an ado file are still
* macro-expanded before Mata compiles them. char() is used instead.
*---------------------------------------------------------------------------
version 14.0

capture mata: mata drop stqa_history_read()
capture mata: mata drop stqa_history_isnum()
capture mata: mata drop stqa_history_counts()
local _drop_rc = _rc
if (`_drop_rc' != 0 & `_drop_rc' != 111 & `_drop_rc' != 3000 & `_drop_rc' != 3499) {
    di as error "stqa_history: Mata is in an unexpected state (rc `_drop_rc');"
    di as error "              the ledger reader could not be installed."
    error `_drop_rc'
}

mata:

void stqa_history_read()
{
    string colvector lines
    string scalar    path, s, key, val
    real scalar      i, n, p, i0

    path = st_local("histfile")

    st_local("h_found", "0")

    if (path == "")         return
    if (!fileexists(path))  return

    lines = cat(path)
    n     = rows(lines)

    // The ledger is append-only, so the LAST stanza is always the latest run.
    // Find where it starts rather than assuming a fixed stanza length: older
    // entries written by earlier versions may carry fewer fields.
    i0 = 0
    for (i = 1; i <= n; i++) {
        if (substr(strtrim(lines[i]), 1, 9) == "Test Run:") i0 = i
    }
    if (i0 == 0) return

    st_local("h_found", "1")

    for (i = i0; i <= n; i++) {

        s = strtrim(lines[i])

        // The stanza ends at its closing rule.
        if (i > i0 & substr(s, 1, 3) == "===") break

        p = strpos(s, ":")
        if (p == 0) continue

        key = strlower(strtrim(substr(s, 1, p - 1)))
        val = strtrim(substr(s, p + 1, .))

        // Everything below travels back through a Stata local and then through
        // -return local-. Strip the characters that could reopen the quoting
        // wound this function exists to avoid: backtick, dollar sign, double
        // quote. The single quote is kept, because it is ordinary English and
        // is harmless inside compound quotes.
        val = subinstr(val, char(96), "")
        val = subinstr(val, char(36), "")
        val = subinstr(val, char(34), "")

        // Note that "failed ids" and "failed" are distinct keys: the split is
        // on the FIRST colon, so a value such as a clock time or a skip note
        // that itself contains a colon survives intact.
             if (key == "test run")   st_local("h_date",      val)
        else if (key == "started")    st_local("h_start",     val)
        else if (key == "ended")      st_local("h_end",       val)
        else if (key == "duration")   st_local("h_duration",  val)
        else if (key == "branch")     st_local("h_branch",    val)
        else if (key == "commit")     st_local("h_commit",    val)
        else if (key == "dirty")      st_local("h_dirty",     val)
        else if (key == "version")    st_local("h_version",   val)
        else if (key == "stata")      st_local("h_stata",     val)
        else if (key == "run")        st_local("h_run",       val)
        else if (key == "passed")     st_local("h_pass",      val)
        else if (key == "skipped")    st_local("h_skip",      val)
        else if (key == "failed ids") st_local("h_ids",       val)
        else if (key == "skip notes") st_local("h_skipnotes", val)
        else if (key == "notes")      st_local("h_notes",     val)
        else if (key == "result")     st_local("h_verdict",   val)
        else if (key == "build")      st_local("h_build",     val)
        else if (key == "log" | key == "logs") st_local("h_log", val)

        // ---------------------------------------------------------------
        // "Failed:" is written by two different conventions and the reader
        // must not confuse them.  This package writes a COUNT; all four of
        // the production suites this framework generalises write the failing
        // IDs there instead:
        //     Failed:   XPLAT-01, XPLAT-04        (unicefdata)
        //     Failed:   INT-02 INT-03             (yaml)
        // Reading those as a count would put "XPLAT-01, XPLAT-04" into a
        // numeric field.  A value made only of digits is a count; anything
        // else is a list of ids.
        // ---------------------------------------------------------------
        else if (key == "failed") {
            if (stqa_history_isnum(val)) st_local("h_fail", val)
            else                         st_local("h_ids",  val)
        }

        // ---------------------------------------------------------------
        // The compact counts line used by yaml, unicefdata and wbopendata:
        //     Tests:    63 run, 61 passed, 2 failed
        // Each comma-separated piece is "<number> <label>".
        // ---------------------------------------------------------------
        else if (key == "tests") {
            st_local("h_tests_raw", val)
            stqa_history_counts(val, "run",     "h_run")
            stqa_history_counts(val, "passed",  "h_pass")
            stqa_history_counts(val, "failed",  "h_fail")
            stqa_history_counts(val, "skipped", "h_skip")
        }

        // ---------------------------------------------------------------
        // datalib counts suites and checks separately:
        //     Suites:   8 run, 8 green, 0 red, 0 skipped, 0 separate
        //     Checks:   205
        // The per-suite breakdown lines beneath ("  - SMOKE passed 48
        // checks") carry no colon and are skipped by the guard above.
        // ---------------------------------------------------------------
        else if (key == "suites") {
            st_local("h_suites_raw", val)
            stqa_history_counts(val, "run",     "h_suites_run")
            stqa_history_counts(val, "green",   "h_suites_green")
            stqa_history_counts(val, "red",     "h_suites_red")
            stqa_history_counts(val, "skipped", "h_suites_skipped")
        }
        else if (key == "checks") {
            if (stqa_history_isnum(val)) st_local("h_checks", val)
        }
    }
}

// True when every character is a digit, i.e. the value is a bare count.
real scalar stqa_history_isnum(string scalar s)
{
    real scalar i, n
    n = strlen(s)
    if (n == 0) return(0)
    for (i = 1; i <= n; i++) {
        if (strpos("0123456789", substr(s, i, 1)) == 0) return(0)
    }
    return(1)
}

// Pull "<number> <label>" out of a comma-separated counts line and post it to
// the named local.  Absent labels leave the local untouched, so a dialect that
// omits one (wbopendata writes no "skipped") simply reports nothing for it
// rather than reporting a wrong zero.
void stqa_history_counts(string scalar line, string scalar label,
                         string scalar locname)
{
    string vector parts
    string scalar piece, num
    real   scalar i, j, k

    parts = tokens(line, ",")

    for (i = 1; i <= length(parts); i++) {
        piece = strtrim(parts[i])
        if (piece == ",") continue

        // the label is the last word of the piece, the number the first
        k = strpos(piece, " ")
        if (k == 0) continue
        num = strtrim(substr(piece, 1, k - 1))
        if (strtrim(substr(piece, k + 1, .)) != label) continue
        if (!stqa_history_isnum(num)) continue

        st_local(locname, num)
        return
    }
}

end
