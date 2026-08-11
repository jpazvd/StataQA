*! version 2.1.0  06aug2026
* stqa_run: Discover and execute a stataqa test suite
* Description: Runs every discovered test file inside its own named log, reads the
*              verdict back out of that log via stqa_scanlog (never from the batch
*              return code), keeps live counters that feed the closing banner, writes
*              an optional JUnit XML report, and emits the suite completion sentinel.
*              Stale per-test logs and a stale JUnit file are erased before the run so
*              that a stale artifact can never masquerade as the current one.
*              Test ids are grouped by family (DET-01 is family DET): family() filters
*              a run, list groups the catalog, and the closing banner breaks the
*              counts down per family.
* Options: pattern() junit() test() family() logdir() verbose list allowempty
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_run
    version 14.0

    * ---- positional arguments: [path] [testid] -------------------------
    * The positional part is tokenized by hand and only the option tail is
    * handed to -syntax-. This is defect #11: -syntax anything()- mangles a
    * quoted path that carries a drive letter, spaces or slashes, turning
    * "c:/work/x y/tests" into the token c: and then failing. gettoken
    * honours the quotes, so the path survives whole.
    local path ""
    local targ ""
    local optpart ""
    local npos 0
    local iter 0
    local done 0
    local scan `"`macval(0)'"'
    while `done' == 0 {
        local iter = `iter' + 1
        if `iter' > 100 {
            local done 1
        }
        else {
            gettoken tok scan : scan, parse(" ,")
            if `"`macval(tok)'"' == "" {
                local done 1
            }
            else if `"`macval(tok)'"' == "," {
                local optpart `", `macval(scan)'"'
                local done 1
            }
            else {
                local npos = `npos' + 1
                if `npos' == 1 {
                    local path `"`macval(tok)'"'
                }
                else if `npos' == 2 {
                    local targ `"`macval(tok)'"'
                }
                else {
                    di as error "stqa_run accepts at most two arguments: [path] [testid]"
                    exit 198
                }
            }
        }
    }

    local 0 `"`macval(optpart)'"'
    syntax [, PATtern(string) Junit(string) ///
        TESt(string) FAMily(string) LOGdir(string) VERBose LISt ALLOWEMPTY ///
        ROLE(string) ]

    local dq = char(34)

    * ------------------------------------------------------------------
    * The package version, read once per run from the dispatcher's own *!
    * header. Read rather than hardcoded so there is ONE source of truth: a
    * version string duplicated into a second file is a version string that
    * will disagree with itself, which is the drift this suite spends its
    * time catching elsewhere. Parsed with substr/strpos rather than a
    * regular expression, because Stata's regexm does not honour interval
    * quantifiers and fails by returning 0 rather than erroring.
    *
    * Empty is a tolerated outcome, not an error: a runner that refused to
    * run because it could not find its own header would trade a cosmetic
    * gap for a dead suite. The format header is simply omitted.
    * ------------------------------------------------------------------
    local stqa_pkgver ""
    capture quietly findfile stataqa.ado
    if _rc == 0 {
        local _pkgado `"`r(fn)'"'
        tempname _vh
        capture file open `_vh' using `"`_pkgado'"', read text
        if _rc == 0 {
            file read `_vh' _vline
            local _p = strpos(`"`macval(_vline)'"', "version ")
            if `_p' > 0 {
                local stqa_pkgver = trim(substr(`"`macval(_vline)'"', `_p' + 8, .))
                local _q = strpos(`"`stqa_pkgver'"', " ")
                if `_q' > 0 local stqa_pkgver = substr(`"`stqa_pkgver'"', 1, `_q' - 1)
            }
            file close `_vh'
        }
    }

    * ------------------------------------------------------------------
    * Role resolution.  The option is authoritative; $stqa_role is the
    * session default a CI job sets once; absent both, the role is REVIEW:
    * safe to point at a repository you do not own.  Review executes
    * everything and writes nothing durable that StataQA owns -- logs go to
    * a scratch directory unless the caller named one explicitly, and no
    * ledger stanza is appended.  Certify is the deliberate act: real logs,
    * and the run is recorded.  (Validate never reaches this program; it is
    * stqa_validate, and it executes nothing.)
    * ------------------------------------------------------------------
    if `"`role'"' == "" local role `"$stqa_role"'
    if `"`role'"' == "" local role "review"
    if !inlist("`role'", "review", "certify") {
        di as error `"stqa_run: role() must be review or certify (got `role')"'
        exit 198
    }

    * The active role is exported for the duration of the run so that
    * blessing ceremonies (stqa_manifest add, stqa_replay update) can refuse
    * under review.  A test file that issues -clear all- drops the global, so
    * this is a guardrail against accident, not access control -- the stated
    * design position.  Reset at entry so an aborted run cannot leave a stale
    * refusal behind for the next one.
    global stqa_role_run "`role'"

    * Certifying a dirty tree certifies something that exists nowhere but
    * this machine: the stanza's Commit: will name a commit that does not
    * contain what actually ran.  Warn up front, where it can still be
    * acted on; the stanza itself records Dirty: either way.
    if "`role'" == "certify" {
        capture stqa_gitinfo
        if (_rc == 0) {
            if (r(dirty) == 1) {
                di as txt "warning: the working tree is DIRTY -- this certification will not correspond to any commit."
                di as txt "         Commit first, or expect Dirty: yes in the stanza."
            }
        }
    }

    if `"`path'"' == "" local path "tests"
    if `"`pattern'"' == "" local pattern "test*.do"
    if `"`test'"' != "" local targ `"`test'"'

    * ---- family targeting ----------------------------------------------
    * family(DET ERR) runs only the blocks whose ids begin with one of those
    * family codes.  It is implemented through the SAME mechanism as
    * single-test targeting, because the runner cannot skip do-file lines: it
    * sets a global that stqa_test reads and uses to neutralise the blocks it
    * does not want.  It is kept separate from $stqa_target rather than
    * overloaded onto it, so that "one id" and "a set of families" never have
    * to be told apart by inspecting the value.  Codes are upper-cased here,
    * once, so that family(det) and family(DET) are the same request, and a
    * comma-separated list is accepted as well as a space-separated one
    * because writing family(DET, ERR) is the obvious mistake to make.
    local famtarg = upper(itrim(trim(subinstr(`"`family'"', ",", " ", .))))

    * drop a trailing directory separator so that "`path'/`f'" stays clean
    local plast = substr(`"`path'"', -1, 1)
    if "`plast'" == "/" | "`plast'" == "\" {
        local path = substr(`"`path'"', 1, length(`"`path'"') - 1)
    }

    if `"`logdir'"' == "" {
        if "`role'" == "review" {
            * Review's non-destructive promise is about StataQA's OWN
            * artifacts: case logs go to scratch so a review run leaves the
            * maintainer's qa/logs/ untouched.  The stale-log erasure below
            * still happens -- against the scratch copies -- because a stale
            * log read as fresh is a false green regardless of role.  An
            * explicitly named logdir() is honored: explicit wins.
            local logdir `"`c(tmpdir)'/stataqa_review"'
        }
        else {
            local logdir `"`path'/logs"'
        }
    }

    * ---- the test directory must exist ---------------------------------
    capture local probe : dir `"`path'"' files "*"
    if _rc {
        di as error "FAIL: _discovery test directory not found: `path'"
        di as error "STATAQA SUITE COMPLETE (1 checks, 1 failed)"
        exit 601
    }

    * ---- log directory, created defensively (defect #12) ---------------
    * mkdir's return code is not trusted: the directory is judged by whether it
    * can be listed afterwards.
    capture mkdir `"`logdir'"'
    capture local probe : dir `"`logdir'"' files "*"
    if _rc {
        di as error "FAIL: _discovery could not create or access log directory: `logdir'"
        di as error "STATAQA SUITE COMPLETE (1 checks, 1 failed)"
        exit 693
    }

    * ---- discovery ------------------------------------------------------
    local files : dir `"`path'"' files `"`pattern'"'
    local files : list sort files
    local nfiles : list sizeof files

    * ---- list mode: catalog only, run nothing --------------------------
    if "`list'" != "" {
        di as txt "Test catalog for `path'  (pattern: `pattern')"
        di as txt "{hline 64}"
        local nfam 0
        local famnames ""
        local nids 0
        tempname lh
        foreach f of local files {
            di as txt "`f'"
            capture file open `lh' using `"`path'/`f'"', read text
            if _rc {
                di as txt "      (file could not be read)"
                continue
            }
            file read `lh' line
            local eof = r(eof)
            while `eof' == 0 {
                * source lines are arbitrary text and may contain a sequence that
                * closes a compound quote, so the parse is captured quietly and
                * only a cleanly recovered id is displayed
                local foundid ""
                capture {
                    local lt = trim(`"`macval(line)'"')
                    if substr(`"`macval(lt)'"', 1, 1) != "*" {
                        * Line-initial only, exactly as the verdict tokens are
                        * matched. A substring match read the id out of any
                        * line MENTIONING stqa_test -- so
                        *     foreach c in stqa_test stqa_endtest stqa_skip {
                        * in qa/test_smoke.do contributed a phantom id named
                        * "stqa_endtest" to the roster, inflating the catalog
                        * and polluting the duplicate-id check that reads it.
                        local p = 0
                        if substr(`"`macval(lt)'"', 1, 10) == "stqa_test " local p = 1
                        if `p' > 0 {
                            local tail = trim(substr(`"`macval(lt)'"', `p' + 10, .))
                            if substr(`"`macval(tail)'"', 1, 1) == `"`dq'"' {
                                local tail = substr(`"`macval(tail)'"', 2, .)
                                local q = strpos(`"`macval(tail)'"', `"`dq'"')
                                if `q' > 1 local tail = substr(`"`macval(tail)'"', 1, `q' - 1)
                            }
                            else {
                                gettoken tail : tail
                            }
                            local foundid `"`macval(tail)'"'
                        }
                    }
                }
                if `"`macval(foundid)'"' != "" {
                    di as txt `"      id: `macval(foundid)'"'
                    * bucket the id by family for the grouped catalog below.
                    * The classification is captured for the same reason the
                    * parse above is: the token came out of arbitrary source
                    * text and may carry characters that break macro
                    * expansion.  A token that cannot be classified is simply
                    * not bucketed.
                    local famkey ""
                    capture {
                        local famkey "_other"
                        * a recovered token carrying a blank cannot be an id -
                        * an id is a single token - so it is the description of
                        * a single-argument stqa_test, whose id is generated
                        if strpos(`"`macval(foundid)'"', " ") > 0 {
                            local famkey "_auto"
                        }
                        else if regexm(`"`macval(foundid)'"', "^T[0-9][0-9][0-9][0-9]*$") {
                            local famkey "_auto"
                        }
                        else {
                            local dpos = strpos(`"`macval(foundid)'"', "-")
                            if `dpos' > 2 {
                                local fcand = substr(`"`macval(foundid)'"', 1, `dpos' - 1)
                                local ncand = substr(`"`macval(foundid)'"', `dpos' + 1, .)
                                if regexm("`fcand'", "^[A-Z0-9][A-Z0-9]+$") & length("`fcand'") <= 8 ///
                                    & regexm("`ncand'", "^[0-9][0-9]+$") {
                                    local famkey "`fcand'"
                                }
                            }
                        }
                    }
                    if `"`famkey'"' != "" {
                        local nids = `nids' + 1
                        * the flat roster, so that a caller can check for
                        * duplicate ids without re-parsing the tree
                        local all_ids `"`macval(all_ids)' `macval(foundid)'"'
                        local fix : list posof "`famkey'" in famnames
                        if `fix' == 0 {
                            local nfam = `nfam' + 1
                            local famnames `"`famnames' `famkey'"'
                            local fix = `nfam'
                            local L`fix' ""
                        }
                        capture local L`fix' `"`macval(L`fix')' `macval(foundid)'"'
                    }
                }
                file read `lh' line
                local eof = r(eof)
            }
            file close `lh'
        }

        * ---- the same ids, grouped by family ---------------------------
        * A family prefix is the part of an id that says what the test is
        * for, so the catalog is more useful read by family than by file.
        if `nfam' > 0 {
            di as txt "{hline 64}"
            di as txt "By family:"
            local fj 0
            foreach fm of local famnames {
                local fj = `fj' + 1
                local fmean ""
                if substr("`fm'", 1, 1) != "_" {
                    * the family table belongs to stqa_families; a missing or
                    * erroring stqa_families costs the meaning column, nothing else
                    capture {
                        quietly stqa_families `fm'
                        local fmean `"`r(meaning)'"'
                    }
                }
                else if "`fm'" == "_auto" {
                    local fmean "auto-generated ids (unstable; not for a ledger)"
                }
                else {
                    local fmean "ids outside the FAMILY-NN taxonomy"
                }
                if `"`fmean'"' == "" local fmean "(no declared meaning)"
                capture local fmean = substr(`"`fmean'"', 1, 64)
                capture noisily di as txt "  " %-8s "`fm'" "  " `"`fmean'"'
                if _rc di as txt "  " %-8s "`fm'"
                * -noisily- is required: a bare -capture- would swallow the
                * very line it is protecting.  The ids came out of arbitrary
                * source text, so the display can still fail; the family
                * heading above has already been printed either way.
                capture noisily di as txt `"      `macval(L`fj')'"'
            }
        }

        di as txt "{hline 64}"
        global stqa_all_ids `"`macval(all_ids)'"'

        * A duplicated id makes the ledger's Failed IDs field unresolvable and
        * makes test() ambiguous, so say so here rather than leaving it for a
        * reader of the ledger to notice months later.
        local uids : list uniq all_ids
        local nuq  : word count `uids'
        if `nids' != `nuq' {
            di as error "WARNING: `=`nids'-`nuq'' duplicate check id(s) in the suite"
            local seen ""
            foreach z of local all_ids {
                local hit : list posof "`z'" in seen
                if `hit' {
                    di as error "  duplicate id: `z'"
                }
                local seen `"`seen' `z'"'
            }
        }

        di as txt "`nfiles' test file(s), `nids' test id(s) in `nfam' famil(y/ies) catalogued. Nothing was run (list)."
        exit 0
    }

    * ---- an empty suite has failed, it has not passed -------------------
    if `nfiles' == 0 {
        if "`allowempty'" != "" {
            di as txt "SKIP: _discovery no test files in `path' matching `pattern' (allowempty)"
            global stqa_n_pass  0
            global stqa_n_fail  0
            global stqa_n_skip  1
            global stqa_n_total 0
            global stqa_failed_ids ""
            global stqa_skip_notes "_discovery: no test files matching `pattern'"
            * NOT the green sentinel.  allowempty means "an empty suite is not an
            * error here", not "an empty suite verified everything".  Emitting
            * ALL CHECKS PASSED would make a run that executed nothing
            * indistinguishable, to stqa_scanlog and to CI, from a run that
            * passed -- which is the exact confusion this package exists to stop.
            di as txt "STATAQA SUITE COMPLETE (0 checks, 0 failed, 0 incomplete)"
            exit 0
        }
        di as error "FAIL: _discovery no test files in `path' matching `pattern'"
        global stqa_n_pass  0
        global stqa_n_fail  1
        global stqa_n_skip  0
        global stqa_n_total 1
        global stqa_failed_ids "_discovery"
        di as error "STATAQA SUITE COMPLETE (1 checks, 1 failed, 0 incomplete)"
        exit 9
    }

    * ---- nesting depth, so a nested run does not close its parent's log --
    * A test file may itself call stqa_run -- qa/test_roster.do must, to check
    * that targeting a single id runs exactly one test. With a fixed log name
    * the nested run's -log close- shut the PARENT's case log, so every verdict
    * the parent emitted afterwards went to the screen and never reached the
    * file the scanner reads. The parent then recorded zero checks and the
    * suite stayed green while three checks silently vanished.
    local depth 0
    capture local depth = $stqa_depth
    if "`depth'" == "" | "`depth'" == "." local depth 0
    local depth = `depth' + 1
    global stqa_depth `depth'
    local casename "stqa_case`depth'"

    * ---- suite state reset ---------------------------------------------
    global stqa_n_pass  0
    global stqa_n_fail  0
    global stqa_n_skip  0
    global stqa_n_total 0
    global stqa_failed_ids ""
    global stqa_skip_notes ""
    global stqa_test_name ""
    global stqa_test_id ""
    global stqa_block_failed 0

    * The skip flag is cleared by stqa_test at the head of every block, so it
    * cannot go stale BETWEEN blocks.  It can go stale ACROSS a suite boundary:
    * a stqa_skip whose block never reached stqa_endtest -- because the file
    * died, or because the user called stqa_skip interactively -- leaves the
    * flag set, and every one of the assertion commands opens with
    *     if "$stqa_skip_block" == "1" { exit 0 }
    * so any assertion executed at FILE SCOPE before the first stqa_test of the
    * next run returns rc 0 having checked nothing.  Resetting here costs three
    * lines and closes the window.
    global stqa_skip_block ""
    global stqa_SKIP_FLAG  ""
    global stqa_SKIP_MSG   ""
    global stqa_target `"`targ'"'
    global stqa_target_family `"`famtarg'"'

    * taxonomy state is per run: the once-per-run notes must fire again in the
    * next run, and the stqa_families probe must be retaken in case the family
    * table was installed or changed since
    global stqa_used_autoids ""
    global stqa_families_seen ""
    global stqa_families_noted ""
    global stqa_families_ok ""
    global stqa_badid_noted ""

    if "`verbose'" != "" {
        global stqa_verbose "1"
    }
    else {
        global stqa_verbose ""
    }

    * ---- erase stale artifacts BEFORE anything runs ---------------------
    foreach f of local files {
        local stub "`f'"
        if lower(substr("`stub'", -3, 3)) == ".do" {
            local stub = substr("`stub'", 1, length("`stub'") - 3)
        }
        capture erase `"`logdir'/`stub'_stqa.log"'
    }
    if `"`junit'"' != "" {
        capture erase `"`junit'"'
        tempfile casebuf
        tempname cb
        capture file open `cb' using `"`casebuf'"', write text replace
        if _rc {
            di as error "FAIL: _junit could not open the JUnit work buffer"
            exit 603
        }
        file close `cb'
    }

    di as txt "stataqa run: `nfiles' file(s) in `path' matching `pattern'"
    if `"`targ'"' != "" di as txt "single-test mode: only test id `targ' will execute"
    if `"`famtarg'"' != "" di as txt "family mode: only families `famtarg' will execute"
    if "`verbose'" != "" di as txt "verbose: trace is on inside test bodies"

    * ---- live counters ---------------------------------------------------
    local n_files_pass 0
    local n_files_fail 0
    local n_files_skip 0
    local n_files_nc   0
    local c_pass 0
    local c_fail 0
    local c_skip 0
    local failed_ids ""
    local junit_failed 0

    * ---- per-family counters, indexed by position in `famnames' ----------
    local nfam 0
    local famnames ""
    local sawauto 0

    local suite_t0 = clock(c(current_time), "hms")
    local tstart = c(current_time)

    tempname stamp
    tempname cbw
    tempname fh

    foreach f of local files {

        local stub "`f'"
        if lower(substr("`stub'", -3, 3)) == ".do" {
            local stub = substr("`stub'", 1, length("`stub'") - 3)
        }
        local tlog `"`logdir'/`stub'_stqa.log"'

        di as txt "{hline 64}"
        di as txt "Running: `path'/`f'"

        local verdict ""
        local reason  ""
        local s_pass 0
        local s_fail 0
        local s_skip 0
        local s_ids  ""
        local rc     0
        local secs   "0.000"

        * per-file block state must not leak in from the previous file
        global stqa_test_name ""
        global stqa_test_id ""
        global stqa_block_failed 0

        * snapshot the contract counters so the per-file delta is known
        local g0_pass = $stqa_n_pass
        local g0_fail = $stqa_n_fail
        local g0_skip = $stqa_n_skip

        capture log close `casename'
        capture log using `"`tlog'"', name(`casename') replace text
        local logrc = _rc

        * The format header, stamped as the log's first line.
        *
        * The verdict grammar this package defines -- line-initial PASS:/FAIL:/
        * SKIP: plus a completion sentinel -- is a contract between whatever
        * wrote a log and whatever later reads it. Without a version in the log
        * itself, a future scanner reading an old log has no way to know which
        * version of that contract applied, and would silently apply its own.
        * That is a false-green generator of exactly the shape this package
        * exists to prevent, so the log says who wrote it.
        *
        * It goes ONLY in logs stataqa itself writes. Golden masters under
        * qa/replay are excluded deliberately: those capture the output of the
        * code under test, not of the harness, and they are pinned by bytes in
        * the manifest. Stamping a tool version into them would make every
        * blessed pair fail on every release -- a tool that changes its own
        * baselines when it upgrades is not offering baselines.
        if (`logrc' == 0 & `"`stqa_pkgver'"' != "") {
            di as text "STATAQA LOG `stqa_pkgver'"
        }

        if `logrc' {
            local verdict "NOTCOMPLETED"
            local reason  "could not open case log `tlog' (rc = `logrc')"
        }
        else {
            if "$stqa_verbose" == "1" {
                set tracedepth 4
                set trace on
            }

            local t0 = clock(c(current_time), "hms")
            capture noisily do `"`path'/`f'"'
            local rc = _rc
            local t1 = clock(c(current_time), "hms")

            capture set trace off
            capture log close `casename'

            local esec = (`t1' - `t0') / 1000
            if missing(`esec') local esec = 0
            if `esec' < 0 local esec = `esec' + 86400
            local secs = trim(string(`esec', "%12.3f"))

            * a test file may have dropped or clobbered the globals
            capture confirm integer number $stqa_n_pass
            if _rc  global stqa_n_pass `g0_pass'
            capture confirm integer number $stqa_n_fail
            if _rc  global stqa_n_fail `g0_fail'
            capture confirm integer number $stqa_n_skip
            if _rc  global stqa_n_skip `g0_skip'

            local d_pass = $stqa_n_pass - `g0_pass'
            local d_fail = $stqa_n_fail - `g0_fail'
            local d_skip = $stqa_n_skip - `g0_skip'
            if `d_pass' < 0 local d_pass = 0
            if `d_fail' < 0 local d_fail = 0
            if `d_skip' < 0 local d_skip = 0
            local d_tot = `d_pass' + `d_fail' + `d_skip'

            * Stamp the completion sentinel into the case log ONLY when the
            * do-file actually returned control. The stamp is appended to the
            * file (not displayed) so it lands in the case log and not in any
            * enclosing suite log. A file that died leaves no sentinel, which
            * is what makes "no sentinel -> NOT COMPLETED" detectable.
            * A file that returned control but left a test block OPEN did not
            * finish that block, so stqa_endtest never booked its verdict. rc is
            * 0 and the counters look clean, which is precisely the shape of a
            * silent pass. Book it as a failure before the sentinel is chosen.
            local unclosed 0
            if `rc' == 0 & `"$stqa_test_id"' != "" {
                local unclosed 1
                di as error `"FAIL: $stqa_test_id test block was never closed (missing stqa_endtest)"'
                global stqa_n_fail = $stqa_n_fail + 1
                global stqa_failed_ids `"$stqa_failed_ids $stqa_test_id"'
                global stqa_test_id ""
                global stqa_test_name ""
                global stqa_block_failed 0
                local d_fail = `d_fail' + 1
                local d_tot  = `d_tot'  + 1
            }

            if `rc' == 0 {
                capture file open `stamp' using `"`tlog'"', write text append
                if _rc == 0 {
                    * d_tot == 0 is NOT a pass. A file that verified nothing --
                    * every block targeted out, or no block at all -- would
                    * otherwise leave a case log byte-identical to one from a
                    * file that verified everything.
                    if `d_fail' == 0 & `d_tot' > 0 {
                        file write `stamp' "ALL CHECKS PASSED (`d_tot' checks)" _n
                    }
                    else if `d_fail' == 0 {
                        file write `stamp' "STATAQA SUITE COMPLETE (0 checks, 0 failed, 0 incomplete)" _n
                    }
                    else {
                        file write `stamp' "STATAQA SUITE COMPLETE (`d_tot' checks, `d_fail' failed, 0 incomplete)" _n
                    }
                    file close `stamp'
                }
            }
            else {
                di as txt "  do-file returned rc = `rc'; no completion sentinel stamped"
            }

            * ---- the verdict is read from the log, never from `rc' -------
            * the -using- form is used deliberately: a positional path is
            * re-tokenized by the scanner's own -syntax anything()- and a log
            * directory containing a space then arrives truncated at "c:"
            capture noisily stqa_scanlog using `"`tlog'"'
            local scanrc = _rc

            if `scanrc' {
                local verdict "NOTCOMPLETED"
                local reason  "stqa_scanlog failed on `tlog' (rc = `scanrc')"
            }
            else {
                local s_pass = cond(missing(r(pass)), 0, r(pass))
                local s_fail = cond(missing(r(fail)), 0, r(fail))
                local s_skip = cond(missing(r(skip)), 0, r(skip))
                local s_done = cond(missing(r(done)), 0, r(done))
                local s_ids  `"`r(ids)'"'
                local s_ids = trim(`"`macval(s_ids)'"')

                * a failing assertion exits 9 and so aborts the do-file before any
                * sentinel can be stamped; a recorded failure is therefore judged
                * before the missing-sentinel case, or every real failure would be
                * mislabelled "did not complete"
                if `s_fail' > 0 {
                    local verdict "FAILED"
                    local reason  "`s_fail' check(s) failed: `s_ids'"
                }
                else if `s_done' == 0 {
                    local verdict "NOTCOMPLETED"
                    local reason  "no completion sentinel in `tlog' (rc = `rc')"
                }
                else if `s_pass' > 0 {
                    local verdict "PASSED"
                    local reason  "`s_pass' check(s) passed"
                }
                else if `s_skip' > 0 {
                    local verdict "SKIPPED"
                    local reason  "`s_skip' check(s) skipped, none executed"
                }
                else {
                    * A file that ran to completion and stamped its sentinel,
                    * yet recorded no verdict of any kind, verified nothing.
                    * Calling that SKIPPED let it pass through to a green
                    * suite -- the same silent success the package exists to
                    * catch. A deliberate skip emits SKIP: tokens and is
                    * handled by the branch above.
                    local verdict "NOTCOMPLETED"
                    local reason  "no checks recorded in `tlog' -- the file ran but verified nothing"
                }
            }

            * ---- per-family attribution ------------------------------
            * The suite counters cannot be broken down by family from the
            * globals: a test file is free to -clear all-, which drops
            * everything stqa_test wrote.  The families are therefore read
            * back out of the case log, from the same line-initial verdict
            * tokens the scanner counts, so the breakdown rests on the same
            * evidence as the verdict.
            *
            * Every reference to a log line sits inside -capture-.  A log
            * echoes the suite's own source, and macro-expanding a line that
            * carries a backtick or an odd number of double quotes is what
            * kills an ordinary Stata file-reading loop (see the long note at
            * the top of stqa_scanlog.ado, which is why THAT scanner is in
            * Mata).  Here a line that cannot be parsed is skipped: it costs
            * one row of attribution and nothing else, because the counts
            * that decide the gate come from the Mata scanner, not from here.
            capture file open `fh' using `"`tlog'"', read text
            if _rc == 0 {
                file read `fh' fline
                local feof = r(eof)
                while `feof' == 0 {
                    local vkind ""
                    local famkey ""
                    capture {
                        local vl = trim(`"`macval(fline)'"')
                        local vhead = substr(`"`macval(vl)'"', 1, 5)
                        if "`vhead'" == "PASS:" local vkind p
                        if "`vhead'" == "FAIL:" local vkind f
                        if "`vhead'" == "SKIP:" local vkind s
                        if "`vkind'" != "" {
                            local vid = trim(substr(`"`macval(vl)'"', 6, 40))
                            local vsp = strpos(`"`macval(vid)'"', " ")
                            if `vsp' > 0 local vid = substr(`"`macval(vid)'"', 1, `vsp' - 1)
                            local famkey "_other"
                            if regexm(`"`macval(vid)'"', "^T[0-9][0-9][0-9][0-9]*$") {
                                local famkey "_auto"
                            }
                            else {
                                local dpos = strpos(`"`macval(vid)'"', "-")
                                if `dpos' > 2 {
                                    local fcand = substr(`"`macval(vid)'"', 1, `dpos' - 1)
                                    local ncand = substr(`"`macval(vid)'"', `dpos' + 1, .)
                                    if regexm("`fcand'", "^[A-Z0-9][A-Z0-9]+$") & length("`fcand'") <= 8 ///
                                        & regexm("`ncand'", "^[0-9][0-9]+$") {
                                        local famkey "`fcand'"
                                    }
                                }
                            }
                        }
                    }
                    if "`vkind'" != "" & "`famkey'" != "" {
                        if "`famkey'" == "_auto" local sawauto 1
                        local fix : list posof "`famkey'" in famnames
                        if `fix' == 0 {
                            local nfam = `nfam' + 1
                            local famnames `"`famnames' `famkey'"'
                            local fix = `nfam'
                            local f`fix'_p 0
                            local f`fix'_f 0
                            local f`fix'_s 0
                        }
                        local f`fix'_`vkind' = `f`fix'_`vkind'' + 1
                    }
                    file read `fh' fline
                    local feof = r(eof)
                }
                file close `fh'
            }
        }

        * ---- accounting ------------------------------------------------
        local c_pass = `c_pass' + `s_pass'
        local c_fail = `c_fail' + `s_fail'
        local c_skip = `c_skip' + `s_skip'

        if "`verdict'" == "PASSED" {
            local n_files_pass = `n_files_pass' + 1
            di as result "PASS: `stub' `reason'"
        }
        else if "`verdict'" == "FAILED" {
            local n_files_fail = `n_files_fail' + 1
            local failed_ids `"`failed_ids' `stub'"'
            di as error "FAIL: `stub' `reason'"
        }
        else if "`verdict'" == "NOTCOMPLETED" {
            local n_files_nc = `n_files_nc' + 1
            local failed_ids `"`failed_ids' `stub'"'
            di as error "FAIL: `stub' did not complete - `reason'"
        }
        else {
            local n_files_skip = `n_files_skip' + 1
            di as txt "SKIP: `stub' `reason'"
            if `"$stqa_skip_notes"' == "" {
                global stqa_skip_notes `"`stub': `reason'"'
            }
            else {
                global stqa_skip_notes `"$stqa_skip_notes|`stub': `reason'"'
            }
        }

        * ---- buffer the JUnit testcase ---------------------------------
        if `"`junit'"' != "" {
            local xname `"`stub'"'
            local xname = subinstr(`"`macval(xname)'"', "&", "&amp;", .)
            local xname = subinstr(`"`macval(xname)'"', "<", "&lt;", .)
            local xname = subinstr(`"`macval(xname)'"', ">", "&gt;", .)
            local xname = subinstr(`"`macval(xname)'"', `"`dq'"', "&quot;", .)
            local xname = subinstr(`"`macval(xname)'"', "'", "&apos;", .)

            local xmsg `"`reason'"'
            local xmsg = subinstr(`"`macval(xmsg)'"', "&", "&amp;", .)
            local xmsg = subinstr(`"`macval(xmsg)'"', "<", "&lt;", .)
            local xmsg = subinstr(`"`macval(xmsg)'"', ">", "&gt;", .)
            local xmsg = subinstr(`"`macval(xmsg)'"', `"`dq'"', "&quot;", .)
            local xmsg = subinstr(`"`macval(xmsg)'"', "'", "&apos;", .)

            capture file open `cbw' using `"`casebuf'"', write text append
            if _rc == 0 {
                if "`verdict'" == "PASSED" {
                    local xline `"    <testcase name="`xname'" classname="stataqa" time="`secs'"/>"'
                    file write `cbw' `"`macval(xline)'"' _n
                }
                else if "`verdict'" == "SKIPPED" {
                    local xline `"    <testcase name="`xname'" classname="stataqa" time="`secs'">"'
                    file write `cbw' `"`macval(xline)'"' _n
                    local xline `"      <skipped message="`xmsg'"/>"'
                    file write `cbw' `"`macval(xline)'"' _n
                    file write `cbw' "    </testcase>" _n
                }
                else {
                    local xline `"    <testcase name="`xname'" classname="stataqa" time="`secs'">"'
                    file write `cbw' `"`macval(xline)'"' _n
                    local xline `"      <failure message="`xmsg'" type="`verdict'">`xmsg'</failure>"'
                    file write `cbw' `"`macval(xline)'"' _n
                    file write `cbw' "    </testcase>" _n
                }
                file close `cbw'
            }
        }
    }

    local suite_t1 = clock(c(current_time), "hms")
    local tend = c(current_time)
    local ssec = (`suite_t1' - `suite_t0') / 1000
    if missing(`ssec') local ssec = 0
    if `ssec' < 0 local ssec = `ssec' + 86400
    local stime = trim(string(`ssec', "%12.3f"))

    local failed_ids = trim(`"`failed_ids'"')
    local xfail = `n_files_fail' + `n_files_nc'

    * ---- JUnit XML ------------------------------------------------------
    if `"`junit'"' != "" {
        local xsuite `"`path'"'
        local xsuite = subinstr(`"`macval(xsuite)'"', "&", "&amp;", .)
        local xsuite = subinstr(`"`macval(xsuite)'"', "<", "&lt;", .)
        local xsuite = subinstr(`"`macval(xsuite)'"', ">", "&gt;", .)
        local xsuite = subinstr(`"`macval(xsuite)'"', `"`dq'"', "&quot;", .)
        local xsuite = subinstr(`"`macval(xsuite)'"', "'", "&apos;", .)

        tempname xml
        tempname cbr
        capture file open `xml' using `"`junit'"', write text replace
        local xrc = _rc
        if `xrc' {
            di as error "FAIL: _junit could not open JUnit output `junit' (rc = `xrc')"
            local junit_failed = 1
        }
        else {
            local xline `"<?xml version="1.0" encoding="UTF-8"?>"'
            file write `xml' `"`macval(xline)'"' _n
            local xline `"<testsuites name="stataqa" tests="`nfiles'" failures="`xfail'" errors="0" skipped="`n_files_skip'" time="`stime'">"'
            file write `xml' `"`macval(xline)'"' _n
            local xline `"  <testsuite name="`xsuite'" tests="`nfiles'" failures="`xfail'" errors="0" skipped="`n_files_skip'" time="`stime'">"'
            file write `xml' `"`macval(xline)'"' _n

            capture file open `cbr' using `"`casebuf'"', read text
            if _rc == 0 {
                file read `cbr' cline
                local eof = r(eof)
                while `eof' == 0 {
                    file write `xml' `"`macval(cline)'"' _n
                    file read `cbr' cline
                    local eof = r(eof)
                }
                file close `cbr'
            }

            file write `xml' "  </testsuite>" _n
            file write `xml' "</testsuites>" _n
            file close `xml'

            * judged by the artifact, not by the return code of the writes
            capture confirm file `"`junit'"'
            if _rc {
                di as error "FAIL: _junit report was not written: `junit'"
                local junit_failed = 1
            }
            else {
                di as txt "JUnit report written: `junit'"
            }
        }
    }

    * ---- totals fed straight from the live counters ---------------------
    * n_checks counts CHECKS and nothing else, so that it reconciles with the
    * breakdown printed directly beneath it. It used to fold in the
    * file-level not-completed count and the JUnit write failure, which made
    * the header say 85 while its own next line said 79 + 3 + 2 = 84, and made
    * the sentinel report a FILE count under the word "checks". A ledger whose
    * arithmetic does not close is not evidence of anything.
    local n_checks     = `c_pass' + `c_fail' + `c_skip'
    local n_incomplete = `n_files_nc' + `junit_failed'
    local n_fail_total = `c_fail'

    * The gate stays exactly as strict as it was: an incomplete file or an
    * unwritable JUnit report still makes the run red. What changes is that it
    * is now reported as what it is, in its own field, rather than added to a
    * failure count and then relabelled.
    local gate_red = (`n_fail_total' > 0) | (`n_incomplete' > 0)

    * A run that counted no checks at all is red unless the caller said
    * allowempty. Files were found and executed, yet nothing was verified --
    * which happens when every block is targeted out, when a file lost its
    * blocks, or when the runner itself was invoked under plain -capture-
    * (which suppresses output, so no verdict token ever reaches the case log
    * and the scanner honestly reports zero). Exiting 0 there is the silent
    * success that reads exactly like a pass.
    if `n_checks' == 0 & "`allowempty'" == "" {
        di as error "FAIL: _roster the run counted no checks; nothing was verified"
        di as error "Expected: at least one check to execute"
        di as error "Got: none -- every block targeted out, or the runner was called under -capture- (use -capture noisily-), or allowempty was intended"
        local gate_red 1
        local n_incomplete = `n_incomplete' + 1
        global stqa_n_incomplete `n_incomplete'
    }

    global stqa_n_pass  `c_pass'
    global stqa_n_fail  `n_fail_total'
    global stqa_n_skip  `c_skip'
    global stqa_n_total `n_checks'
    global stqa_n_incomplete `n_incomplete'
    global stqa_failed_ids `"`failed_ids'"'

    di as txt "{hline 64}"
    di as txt "stataqa summary  (`nfiles' file(s), `n_checks' check(s), `stime's)"
    di as txt "  files : `n_files_pass' passed, `n_files_fail' failed, `n_files_nc' not completed, `n_files_skip' skipped"
    di as txt "  checks: `c_pass' passed, `c_fail' failed, `c_skip' skipped"
    if `n_incomplete' > 0 {
        di as txt "  gate  : `n_incomplete' incomplete (files that did not finish, or an unwritable report) -- counted red, not counted as checks"
    }

    * ---- per-family breakdown -------------------------------------------
    * Only when there is something to break down: one family is the summary
    * line above, said twice.
    if `nfam' > 1 {
        di as txt "    " %-8s "family" %6s "run" %8s "passed" %8s "failed" %9s "skipped" "  meaning"
        local fj 0
        foreach fm of local famnames {
            local fj = `fj' + 1
            local fr = `f`fj'_p' + `f`fj'_f' + `f`fj'_s'
            local fmean ""
            if substr("`fm'", 1, 1) != "_" {
                * the family table belongs to stqa_families; a missing or
                * erroring stqa_families costs the meaning column, nothing else
                capture {
                    quietly stqa_families `fm'
                    local fmean `"`r(meaning)'"'
                }
            }
            else if "`fm'" == "_auto" {
                local fmean "auto-generated ids (unstable)"
            }
            else {
                local fmean "ids outside the FAMILY-NN taxonomy"
            }
            if `"`fmean'"' == "" local fmean "(no declared meaning)"
            capture local fmean = substr(`"`fmean'"', 1, 38)
            * the meaning is text this command did not write; if it cannot be
            * displayed, the counts still are.  -noisily- is required: a bare
            * -capture- would swallow the very line it is protecting.
            capture noisily di as txt "    " %-8s "`fm'" %6.0f `fr' %8.0f `f`fj'_p' %8.0f `f`fj'_f' %9.0f `f`fj'_s' "  " `"`fmean'"'
            if _rc {
                di as txt "    " %-8s "`fm'" %6.0f `fr' %8.0f `f`fj'_p' %8.0f `f`fj'_f' %9.0f `f`fj'_s'
            }
        }
    }

    if `"`failed_ids'"' != "" {
        di as error "  failed: `failed_ids'"
    }
    di as txt "{hline 64}"

    * ---- unstable identifiers are a ledger problem ----------------------
    * Auto ids are legal for scratch and ad-hoc tests, but they have no
    * business in a permanent record, so the warning is raised exactly here:
    * immediately before the run would be written to the history ledger.
    * Two independent signals are honoured - the flag stqa_test raises, and
    * the auto-form ids read back out of the case logs - because a test file
    * is free to -clear all- and drop the flag.  This warns; it never refuses.
    if "$stqa_used_autoids" == "1" | `sawauto' == 1 {
        di as error "WARNING: this run used auto-generated test ids (T001, T002, ...)."
        di as txt   "  Auto ids renumber when a test is inserted, so a record that names one"
        di as txt   "  stops being interpretable: T007 in March is not T007 in August, and a"
        di as txt   "  single-test re-run then targets a different test than it did before."
        di as txt   "  Replace them with stable FAMILY-NN ids (see -help stqa_families-)"
        di as txt   "  before this run is treated as a certification record."
    }

    * ---- run history: certify-role full runs only ------------------------
    * The counters were written to the globals just above, which is where
    * stqa_history reads them from; the verdict is passed explicitly because
    * this command is the one that holds the sentinel result.  A family-filtered
    * run is a partial run for the same reason a single-test run is: most of
    * the suite did not execute, so its result is not a gate record.  And a
    * REVIEW run -- however complete -- is not a certification: if every clone
    * that runs the suite appends, a stanza stops identifying a maintainer's
    * deliberate act and becomes "somebody ran something".  Nine accidental
    * stanzas entered this repo's own ledger in one day before this gate.
    if "`role'" == "review" & `"`targ'"' == "" & `"`famtarg'"' == "" {
        di as txt "note: review role; the run was NOT recorded in the certification ledger."
        di as txt "      To certify (append the stanza), run:  stataqa certify `path'"
    }
    if "`role'" == "certify" & `"`targ'"' == "" & `"`famtarg'"' == "" {
        * gate_red, not n_fail_total: since the incomplete/failed split,
        * n_fail_total counts CHECK failures only, and a run that is red
        * solely because a file never finished would have been recorded as
        * GATE GREEN -- a false green written into the one artifact whose
        * whole purpose is to be trustworthy.  Found live on 07aug2026 by the
        * first consumer-example run (rc 9, 1 incomplete, stanza said GREEN).
        local vd "GATE GREEN"
        if `n_checks' <= 0 local vd "INCOMPLETE"
        if `gate_red' local vd "GATE RED"
        capture noisily stqa_history, verdict("`vd'") ///
            starttime("`tstart'") endtime("`tend'") ///
            notes(`"path=`path' pattern=`pattern'"')
        local hrc = _rc
        if `hrc' {
            di as txt "note: stqa_history unavailable or failed (rc = `hrc'); run record not appended."
        }
    }
    else if `"`targ'"' != "" {
        di as txt "note: single-test mode; run record not appended to history."
    }
    else if `"`famtarg'"' != "" {
        di as txt "note: family mode; a filtered run is not a full run, so no record was appended to history."
    }
    * a full review run was already explained above; nothing further to say

    * do not let targeting or tracing leak into the next run
    global stqa_target ""
    global stqa_target_family ""
    global stqa_verbose ""
    global stqa_role_run ""
    global stqa_depth = `depth' - 1

    * ---- completion sentinel --------------------------------------------
    * The red sentinel now carries all three figures. stqa_scanlog reads the
    * "N failed" and "N incomplete" clauses and treats their sum as the
    * declared failure count, so a run that is red ONLY because a file did not
    * finish still reads red to every consumer of the log. Logs written before
    * this change have no incomplete clause; it parses as zero, which is what
    * they meant.
    if `gate_red' == 0 & `n_checks' > 0 {
        di as result "ALL CHECKS PASSED (`n_checks' checks)"
        exit 0
    }
    if `gate_red' == 0 {
        * green gate, nothing verified: say so rather than claiming a pass
        di as txt "STATAQA SUITE COMPLETE (0 checks, 0 failed, 0 incomplete)"
        exit 0
    }
    di as error "STATAQA SUITE COMPLETE (`n_checks' checks, `n_fail_total' failed, `n_incomplete' incomplete)"
    exit 9
end
