*! version 2.1.0  06aug2026
* stqa_test: Open a test block
* Description: Opens a test block, assigns an explicit or auto-generated test id,
*              classifies that id against the FAMILY-NN taxonomy, honours
*              single-test ($stqa_target) and family ($stqa_target_family)
*              targeting, and verbose tracing.  The closing verdict token is
*              emitted by stqa_endtest.
* Options: none (syntax: stqa_test "description" | stqa_test id "description")
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_test
    version 14.0

    * ------------------------------------------------------------------
    * A previous block that was never closed would make the counters drift
    * silently.  Warn loudly, but do not abort: the run must continue so the
    * log carries the completion sentinel.
    * ------------------------------------------------------------------
    if `"$stqa_test_id"' != "" {
        di as error `"stqa_test: block $stqa_test_id was never closed - stqa_endtest is missing"'
    }

    * ------------------------------------------------------------------
    * Parse.  Two accepted forms:
    *     stqa_test "description"                (auto id T001, T002, ...)
    *     stqa_test id "description"             (explicit id)
    * gettoken strips the outer quotes of a quoted token and leaves the
    * remainder with its leading blank, so the remainder is trimmed by hand.
    * ------------------------------------------------------------------
    gettoken tok1 rest : 0
    local id ""
    local nm ""

    local restblank : subinstr local rest " " "", all
    if `"`restblank'"' == "" {
        local nm `"`tok1'"'
    }
    else {
        local id `"`tok1'"'
        gettoken tok2 tail : rest
        local tailblank : subinstr local tail " " "", all
        if `"`tailblank'"' == "" {
            local nm `"`tok2'"'
        }
        else {
            * unquoted multi-word description: keep it whole, drop the blanks
            local nm `"`rest'"'
            mata: st_local("nm", strtrim(st_local("nm")))
        }
    }

    if `"`nm'"' == "" {
        di as error "stqa_test: a test description is required"
        exit 198
    }

    * ------------------------------------------------------------------
    * Counters.  $stqa_n_total counts blocks ENCOUNTERED and is incremented
    * unconditionally, so auto ids stay stable whether or not the block is
    * targeted out.  Globals may be undefined on the first call.
    * ------------------------------------------------------------------
    local ntot `"$stqa_n_total"'
    if `"`ntot'"' == "" local ntot 0
    local ntot = `ntot' + 1
    global stqa_n_total = `ntot'

    local autogen 0
    if `"`id'"' == "" {
        local id = "T" + string(`ntot', "%03.0f")
        * An auto id is stable only inside one edition of a suite: inserting a
        * block renumbers every block after it, so a ledger entry naming T007
        * stops being interpretable and a single-test re-run silently targets a
        * different test.  The flag this raises is reported by stqa_run at
        * ledger-writing time, which is where an unstable id does its damage.
        * It is raised further down, after targeting, so that "this run used
        * auto ids" describes the blocks that RAN and not the ones that were
        * filtered out.
        local autogen 1
    }

    * ------------------------------------------------------------------
    * Classify the id.  A test id is not an internal label: it escapes into
    * the certification ledger, into CI record validation and into issue
    * trackers.  FAMILY-NN carries the failure mode in its prefix, so a reader
    * of "Failed IDs: DET-03" knows what failed without opening the test.
    *
    *     famkey = <FAMILY>   well-formed FAMILY-NN
    *              _auto      the auto-generated T### form (legal, unstable)
    *              _other     anything else
    *
    * Family codes are upper case, and the test here is deliberately the same
    * test -stqa_families, validate()- applies: det-01 is not DET-01 spelled
    * differently, it is an id the package's own validator rejects.  Two
    * commands in one package that disagree about what a well-formed id is
    * would be worse than either rule on its own.
    *
    * The family TABLE is not here - it belongs to stqa_families, which is
    * asked further down whether the family is a declared one.  Only the
    * shape rule is applied locally, because the shape is what family
    * targeting needs and targeting must keep working when the taxonomy
    * command is unavailable.
    * ------------------------------------------------------------------
    local famkey "_other"
    if regexm(`"`id'"', "^T[0-9][0-9][0-9][0-9]*$") {
        local famkey "_auto"
    }
    else {
        local dpos = strpos(`"`id'"', "-")
        if `dpos' > 2 {
            local fcand = substr(`"`id'"', 1, `dpos' - 1)
            local ncand = substr(`"`id'"', `dpos' + 1, .)
            if regexm("`fcand'", "^[A-Z0-9][A-Z0-9]+$") & length("`fcand'") <= 8 ///
                & regexm("`ncand'", "^[0-9][0-9]+$") {
                local famkey "`fcand'"
            }
        }
    }
    local fam ""
    if substr("`famkey'", 1, 1) != "_" local fam "`famkey'"

    * ------------------------------------------------------------------
    * Open the block.  stqa_skip / stqa_assert / stqa_endtest read this state.
    * ------------------------------------------------------------------
    global stqa_test_id `"`id'"'
    global stqa_test_name `"`nm'"'
    global stqa_block_failed ""
    global stqa_skip_block ""

    * ------------------------------------------------------------------
    * Single-test targeting.  A Stata program cannot skip the lines that
    * follow it in a do-file, so a non-matching block is neutralised by
    * setting $stqa_skip_block: the body's assertions become no-ops and
    * stqa_endtest emits no verdict token for it.
    * ------------------------------------------------------------------
    if `"$stqa_target"' != "" {
        if `"`id'"' != `"$stqa_target"' {
            global stqa_skip_block 1
            exit 0
        }
    }

    * ------------------------------------------------------------------
    * Family targeting.  Same mechanism and the same honest limitation as
    * single-test targeting: only the harness commands are neutralised, the
    * body still executes.  The two filters are ANDed, so test() and family()
    * together select the intersection.  An id with no family can never match
    * a family filter.
    * ------------------------------------------------------------------
    if `"$stqa_target_family"' != "" {
        local ftargets `"$stqa_target_family"'
        local fhit 0
        if "`fam'" != "" {
            local fhit : list posof "`fam'" in ftargets
        }
        if `fhit' == 0 {
            global stqa_skip_block 1
            exit 0
        }
    }

    di as txt `"[TEST] `id': `nm'"'

    * ------------------------------------------------------------------
    * Record the family of the block that is actually going to run, for the
    * runner's per-family summary and for anything else that wants to know
    * what a suite covers.  Blocks switched off by targeting are not recorded:
    * the list describes what ran.
    * ------------------------------------------------------------------
    if "`fam'" != "" {
        local seen `"$stqa_families_seen"'
        local shit : list posof "`fam'" in seen
        if `shit' == 0 {
            global stqa_families_seen = trim(`"`seen' `fam'"')
        }
    }
    if `autogen' == 1 {
        global stqa_used_autoids 1
    }

    * ------------------------------------------------------------------
    * Taxonomy notes.  These are NOTES, never failures.  A taxonomy problem
    * must not turn a passing suite red and must not be able to abort a test,
    * so nothing below can raise an error and nothing below writes a verdict
    * token.  The common case - a well-formed id in a known family - is
    * silent.
    *
    * The family table lives in stqa_families.  Every call to it is captured:
    * a stqa_families that is missing, not yet installed, or erroring degrades
    * to NO validation rather than breaking every test in every suite.  The
    * one-shot probe below is what makes that degradation correct - without
    * it, an interface that answers nothing would be indistinguishable from
    * "every family is unknown", and every test would draw a bogus note.
    * ------------------------------------------------------------------
    if "$stqa_families_ok" == "" {
        global stqa_families_ok 0
        capture {
            quietly stqa_families DET
            if "`r(known)'" != "" global stqa_families_ok 1
        }
    }

    if "`fam'" != "" & "$stqa_families_ok" == "1" {
        local fknown 1
        capture {
            quietly stqa_families `fam'
            local _fm `"`r(meaning)'"'
            local _fk "`r(known)'"
            if "`_fk'" == "0" local fknown 0
            if "`_fk'" == "" & `"`_fm'"' == "" local fknown 0
        }
        if `fknown' == 0 {
            * once per family per run, not once per test
            local noted `"$stqa_families_noted"'
            local nhit : list posof "`fam'" in noted
            if `nhit' == 0 {
                di as txt `"note: `fam' is not a declared test family; declare it with -stqa_families, add(`fam' "meaning")-"'
                global stqa_families_noted = trim(`"`noted' `fam'"')
            }
        }
    }
    else if "`famkey'" == "_other" {
        * once per run: naming every offending id would drown the log, and the
        * runner's per-family summary reports the full _other count anyway
        if `"$stqa_badid_noted"' == "" {
            global stqa_badid_noted `"`id'"'
            di as txt `"note: test id `id' is not FAMILY-NN (for example DET-01); stable, semantic ids are what keep a certification ledger readable"'
            di as txt  "      further ids outside the taxonomy are not reported again in this run"
        }
    }

    * ------------------------------------------------------------------
    * Verbose tracing.  Stata restores -set trace- to its entry value when
    * the program that changed it exits, so this traces the tail of
    * stqa_test only: it cannot trace the do-file lines of the block body.
    * Verbose tracing of test bodies has to be switched on by the caller
    * that is still on the stack while the body runs, i.e. by stqa_run
    * around its -do- of the test file.  Kept here for contract parity and
    * for the case where a block body is itself inside a program.
    * ------------------------------------------------------------------
    if "$stqa_verbose" == "1" {
        set tracedepth 4
        set trace on
    }
end
