*! qa/test_roster.do  version 2.0.0  07aug2026
* META family -- the runner's own bookkeeping is falsifiable.
*
* Written because of a defect found in the yaml package's suite during a
* journal revision, recorded there as a lesson explicitly addressed to
* StataQA: a
* test nested inside a neighbour's -if- block ran only during full-suite runs,
* and asking for it directly executed nothing and exited rc=0 with ZERO tests.
* A silent success that reads exactly like a pass.
*
* The note's conclusion is the design of META-11: comparing a declared roster
* against the suite TOTAL would not have caught it, because the total was
* right.  What catches it is asserting that asking for one test runs exactly
* one test.
*
* WHY THIS TESTS THE MECHANISM AND NOT THE RUNNER.  The first draft called
* stqa_run recursively, and a nested run cannot be measured: the parent's case
* log is open while the child runs, so the child's output -- including the
* deliberate FAIL: lines a negative case exists to produce -- is captured by
* the parent's log and counted against the parent.  Two logs cannot separate
* one screen stream.  Targeting lives in $stqa_target and stqa_test, so it is
* exercised here directly.  (stqa_run has since been given per-depth log names
* so that a nested run cannot CLOSE its parent's log, which is a different and
* worse failure; but nesting remains an unsupported measurement pattern.)
* Author: Joao Pedro Azevedo (UNICEF)

* ---- the roster, read at file scope ----------------------------------
* -list- exits before the suite-state reset and emits no verdict tokens, so
* it is safe to call from inside a file the runner is measuring.
capture noisily stqa_run "qa", list
local ids `"$stqa_all_ids"'

* ---- targeting probe, at file scope ----------------------------------
* Skipped when the suite is itself running under a target, because the probe
* sets $stqa_target and would fight it.
local outer_target `"$stqa_target"'
local p0 = $stqa_n_pass
local f0 = $stqa_n_fail

if `"`outer_target'"' == "" {
    global stqa_target "META-14"

    stqa_test META-14 "the targeted block is the one that executes"
        stqa_assert 1 == 1
    stqa_endtest
    local p1 = $stqa_n_pass
    local f1 = $stqa_n_fail

    stqa_test META-15 "a block that is not the target must not execute"
        * This assertion is false on purpose. If targeting works the block is
        * never entered, so the assertion never runs and the counters do not
        * move. If targeting is broken this file goes red here, loudly, which
        * is the correct outcome.
        stqa_assert 1 == 2, msg("META-15 executed although META-14 was targeted")
    stqa_endtest
    local p2 = $stqa_n_pass
    local f2 = $stqa_n_fail

    global stqa_target ""
    local probe_ran 1
}
else {
    local probe_ran 0
}

stqa_test META-11 "asking for one test runs exactly one test, not zero"
    if !`probe_ran' {
        stqa_skip, msg("suite is running under an outer target")
    }
    else {
        local hit = `p1' - `p0'
        stqa_assert `hit' == 1, msg("the targeted block booked `hit' pass(es); zero is the failure mode this check exists for -- an id that resolves to nothing while the run still exits clean")
        local hitf = `f1' - `f0'
        stqa_assert `hitf' == 0, msg("the targeted block booked `hitf' failure(s)")
    }
stqa_endtest

stqa_test META-12 "a block that is not the target books nothing at all"
    if !`probe_ran' {
        stqa_skip, msg("suite is running under an outer target")
    }
    else {
        local miss  = `p2' - `p1'
        local missf = `f2' - `f1'
        stqa_assert `miss' == 0, msg("a non-targeted block booked `miss' pass(es); targeting is not filtering")
        stqa_assert `missf' == 0, msg("a non-targeted block booked `missf' failure(s); its deliberately false assertion executed")
    }
stqa_endtest

stqa_test META-13 "check ids are unique across the suite"
    * A duplicated id makes the ledger's Failed IDs field unresolvable and
    * makes test() ambiguous. Eight duplicates were live in this tree on
    * 07aug2026, before the strip-to-core sweep retired six and renumbered two.
    local n : word count `ids'
    local uniq : list uniq ids
    local nu : word count `uniq'
    stqa_assert `n' > 0, msg("the roster came back empty; stqa_run, list did not populate the id list")
    stqa_assert `n' == `nu', msg("`=`n'-`nu'' duplicate check id(s) in the suite: every id must name exactly one test")
stqa_endtest
