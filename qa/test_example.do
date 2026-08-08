*! tests/test_example.do  version 2.1.0  06aug2026
* SMOKE family -- the shipped assertions answer on a trivial dataset.
*
* This file used to open its own log, put tests/ on the adopath and call
* assert_equal_num and assert_rc_zero from tests/assert_utils.ado.  That file
* held five programs, and Stata autoloads only the one program whose name
* matches the .ado filename, so four of the five were unreachable and every run
* died with "command assert_equal_num is unrecognized" (r 199).  It is gone; the
* package's own assertions replace it.  The log is gone too: stataqa run opens a
* named log per test file and reads the verdict back out of it.
* Author: Joao Pedro Azevedo (UNICEF)

* SMOKE-07/08 were SMOKE-01/02 until 07aug2026, when the duplicate-id sweep
* found qa/test_smoke.do already owned those ids.  Renumbered, never reused.

stqa_test SMOKE-07 "a computed statistic matches its expected value"
    clear
    set obs 10
    gen x = _n
    quietly summarize x, meanonly
    local m = r(mean)
    stqa_assert_equal_num `m' 5.5
stqa_endtest

stqa_test SMOKE-08 "a built-in estimation command runs clean"
    sysuse auto, clear
    capture regress price mpg
    stqa_rc_zero, msg("regress price mpg did not run")
stqa_endtest
