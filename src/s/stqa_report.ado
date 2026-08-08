*! version 2.0.0  06aug2026
* stqa_report: Summarize a stataqa run
* Description: Prints a summary table for a JUnit XML report or for a run log. A
*              .xml source is counted element by element; any other source is handed
*              to stqa_scanlog so that the verdict still comes from the log. With no
*              source at all the counters left behind by the last run are printed.
* Options: none (an optional filename argument)
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_report, rclass
    version 14.0
    * The filename is peeled off with gettoken rather than -syntax anything()-,
    * which mangles a quoted path carrying a drive letter or spaces (defect #11).
    gettoken src rest : 0
    local rest = trim(`"`macval(rest)'"')
    if `"`rest'"' != "" {
        di as error "stqa_report accepts a single filename argument"
        exit 198
    }

    di as txt "{hline 60}"
    di as txt "stataqa report"
    di as txt "{hline 60}"

    * ---- no source: report the counters left by the last run ------------
    if `"`src'"' == "" {
        local gp "$stqa_n_pass"
        capture confirm integer number `gp'
        if _rc local gp "."
        local gf "$stqa_n_fail"
        capture confirm integer number `gf'
        if _rc local gf "."
        local gs "$stqa_n_skip"
        capture confirm integer number `gs'
        if _rc local gs "."
        local gt "$stqa_n_total"
        capture confirm integer number `gt'
        if _rc local gt "."

        di as txt "source     : last run (global counters)"
        di as txt "checks     : `gt'"
        di as result "passed     : `gp'"
        if "`gf'" == "0" {
            di as txt "failed     : `gf'"
        }
        else {
            di as error "failed     : `gf'"
        }
        di as txt "skipped    : `gs'"
        if `"$stqa_failed_ids"' != "" {
            di as error "failed ids : $stqa_failed_ids"
        }
        if `"$stqa_skip_notes"' != "" {
            di as txt "skip notes : $stqa_skip_notes"
        }
        di as txt "{hline 60}"
        if "`gt'" == "." {
            di as txt "No run has been recorded in this session. Run: stataqa run"
        }

        return local kind "globals"
        return local failed_ids `"$stqa_failed_ids"'
        if "`gt'" != "." return scalar total = `gt'
        if "`gs'" != "." return scalar skip  = `gs'
        if "`gf'" != "." return scalar fail  = `gf'
        if "`gp'" != "." return scalar pass  = `gp'
        exit 0
    }

    capture confirm file `"`src'"'
    if _rc {
        di as error "Report source not found: `src'"
        exit 601
    }

    local ext = lower(substr(`"`src'"', -4, 4))

    * ---- JUnit XML -------------------------------------------------------
    if "`ext'" == ".xml" {
        local ncase 0
        local nfail 0
        local nskip 0

        tempname fh
        capture file open `fh' using `"`src'"', read text
        if _rc {
            di as error "Could not read JUnit report: `src'"
            exit 603
        }
        file read `fh' line
        local eof = r(eof)
        while `eof' == 0 {
            capture noisily {
                if strpos(`"`macval(line)'"', "<testcase") > 0 local ncase = `ncase' + 1
                if strpos(`"`macval(line)'"', "<failure") > 0 local nfail = `nfail' + 1
                if strpos(`"`macval(line)'"', "<skipped") > 0 local nskip = `nskip' + 1
            }
            file read `fh' line
            local eof = r(eof)
        }
        file close `fh'

        local npass = `ncase' - `nfail' - `nskip'
        if `npass' < 0 local npass = 0

        di as txt "source     : `src' (JUnit XML)"
        di as txt "testcases  : `ncase'"

        * The log branch of this same command already refuses to call a log
        * green without a completion sentinel; the JUnit branch had no
        * equivalent, so an empty or truncated report -- a run killed
        * mid-write -- returned total 0, fail 0 and printed "failed: 0" in
        * ordinary text. Zero testcases is not zero failures.
        if `ncase' == 0 {
            di as error "NO testcases found -- this report is empty or truncated, not a green run"
            di as txt "{hline 60}"
            return local kind "junit"
            return local source `"`src'"'
            return scalar total = 0
            return scalar skip  = 0
            return scalar fail  = 1
            return scalar pass  = 0
            exit 9
        }
        di as result "passed     : `npass'"
        if `nfail' == 0 {
            di as txt "failed     : `nfail'"
        }
        else {
            di as error "failed     : `nfail'"
        }
        di as txt "skipped    : `nskip'"
        di as txt "{hline 60}"

        return local kind "junit"
        return local source `"`src'"'
        return scalar total = `ncase'
        return scalar skip  = `nskip'
        return scalar fail  = `nfail'
        return scalar pass  = `npass'
        exit 0
    }

    * ---- run log: the verdict still comes from the log scanner ----------
    * -using- form: a positional path with a space in it is re-tokenized by
    * the scanner's own -syntax anything()- and arrives truncated
    capture noisily stqa_scanlog using `"`src'"'
    local scanrc = _rc
    if `scanrc' {
        di as error "stqa_scanlog failed on `src' (rc = `scanrc')"
        di as txt "{hline 60}"
        exit `scanrc'
    }

    local lpass = cond(missing(r(pass)), 0, r(pass))
    local lfail = cond(missing(r(fail)), 0, r(fail))
    local lskip = cond(missing(r(skip)), 0, r(skip))
    local ldone = cond(missing(r(done)), 0, r(done))
    local lids  `"`r(ids)'"'
    local ltot  = `lpass' + `lfail' + `lskip'

    di as txt "source     : `src' (run log)"
    di as txt "checks     : `ltot'"
    di as result "passed     : `lpass'"
    if `lfail' == 0 {
        di as txt "failed     : `lfail'"
    }
    else {
        di as error "failed     : `lfail'"
    }
    di as txt "skipped    : `lskip'"
    if `"`lids'"' != "" {
        di as error "failed ids : `lids'"
    }
    if `ldone' == 0 {
        di as error "completion : NO completion sentinel - this log is not a green run"
    }
    else if `lfail' == 0 {
        di as result "completion : sentinel present, no failures"
    }
    else {
        di as error "completion : sentinel present, `lfail' failure(s)"
    }
    di as txt "{hline 60}"

    return local kind "log"
    return local source `"`src'"'
    return local failed_ids `"`lids'"'
    return scalar done  = `ldone'
    return scalar total = `ltot'
    return scalar skip  = `lskip'
    return scalar fail  = `lfail'
    return scalar pass  = `lpass'
end
