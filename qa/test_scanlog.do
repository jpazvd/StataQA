*! qa/test_scanlog.do  version 1.0.0  06aug2026
* DET family -- the log-sentinel verdict reader, against frozen synthetic logs.
*
* This is the load-bearing component: every verdict the framework reports is
* whatever this program says a log contains.  The logs below are written by
* hand rather than captured from a run, so each case is exact and the tests
* are deterministic and offline.
* Author: Joao Pedro Azevedo (UNICEF)

tempfile clean hung failing skipped empty

*---------------------------------------------------------------------------
* A log that mimics a real one: genuine verdict lines PLUS echoed source lines
* that merely contain the tokens.  Stata echoes the suite's own source into
* the log prefixed by "." or a line number, so only line-initial tokens count.
*---------------------------------------------------------------------------
file open fh using "`clean'", write replace
file write fh "PASS: DET-01 first" _n
file write fh "PASS: DET-02 second" _n
file write fh "FAIL: DET-03 third" _n
file write fh ". di as result PASS: this is echoed source, not a verdict" _n
file write fh "  5. di as error FAIL: also echoed source" _n
file write fh "ALL CHECKS PASSED (2 checks)" _n
file close fh

stqa_test DET-01 "line-initial verdict tokens are counted"
    quietly stqa_scanlog using "`clean'"
    local p = r(pass)
    local f = r(fail)
    stqa_assert `p' == 2, msg("expected 2 passes, got `p'")
    stqa_assert `f' == 1, msg("expected 1 failure, got `f'")
stqa_endtest

stqa_test DET-02 "echoed source lines containing the tokens are NOT counted"
    quietly stqa_scanlog using "`clean'"
    local p = r(pass)
    local f = r(fail)
    * the log holds 3 lines containing PASS: and 2 containing FAIL:, but only
    * 2 and 1 respectively begin with the token
    stqa_assert `p' + `f' == 3, msg("echoed source leaked into the counts")
stqa_endtest

stqa_test DET-03 "the completion sentinel is detected"
    quietly stqa_scanlog using "`clean'"
    local d = r(done)
    stqa_assert `d' == 1, msg("sentinel present but not detected")
stqa_endtest

stqa_test DET-04 "failed identifiers are collected"
    quietly stqa_scanlog using "`clean'"
    local ids = trim(`"`r(ids)'"')
    stqa_assert_equal_str "`ids'" "DET-03"
stqa_endtest

*---------------------------------------------------------------------------
* The case the whole design exists for: a run that was killed or hung leaves
* a log full of passes and no sentinel.  It must never read as green.
*---------------------------------------------------------------------------
file open fh2 using "`hung'", write replace
file write fh2 "PASS: X-01 ok" _n
file write fh2 "PASS: X-02 ok" _n
file close fh2

stqa_test DET-05 "a log without the sentinel is NOT complete, despite zero failures"
    quietly stqa_scanlog using "`hung'"
    local d = r(done)
    local f = r(fail)
    stqa_assert `f' == 0, msg("fixture should contain no failures")
    stqa_assert `d' == 0, msg("a hung run was reported as complete")
stqa_endtest

*---------------------------------------------------------------------------
* A missing log is the same situation as a hung run, and must be reported
* rather than raised: an abort here would take down the runner that is trying
* to record the failure.
*---------------------------------------------------------------------------
stqa_test EDGE-01 "a missing log is reported, not raised as an error"
    capture stqa_scanlog using "c:/nonexistent/never/written.log"
    local rc = _rc
    stqa_assert `rc' == 0, msg("missing log aborted with rc `rc'")
stqa_endtest

stqa_test EDGE-02 "an empty log reads as incomplete with no verdicts"
    file open fh3 using "`empty'", write replace
    file close fh3
    quietly stqa_scanlog using "`empty'"
    local p = r(pass)
    local f = r(fail)
    local d = r(done)
    stqa_assert `p' == 0 & `f' == 0 & `d' == 0, msg("empty log did not read as empty")
stqa_endtest

*---------------------------------------------------------------------------
* SKIP is a third verdict: neither pass nor failure.
*---------------------------------------------------------------------------
file open fh4 using "`skipped'", write replace
file write fh4 "PASS: Y-01 ok" _n
file write fh4 "SKIP: Y-02 prerequisite absent" _n
file write fh4 "ALL CHECKS PASSED (1 checks)" _n
file close fh4

stqa_test DET-06 "a skip marker is detected and is not counted as a failure"
    quietly stqa_scanlog using "`skipped'"
    local s = r(skip)
    local f = r(fail)
    stqa_assert `s' == 1, msg("skip marker not detected")
    stqa_assert `f' == 0, msg("a skip was counted as a failure")
stqa_endtest
