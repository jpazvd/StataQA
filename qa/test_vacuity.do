*! qa/test_vacuity.do  version 1.0.0  07aug2026
* EDGE family -- vacuous assertions: nothing to check must never read as
* everything checked.
*
* Written after the 07aug2026 review of adotest (Dutey), whose test_assert
* carries StataCorp's own -assert, null- guard and whose committed test suite
* is the reason stqa_assert now has the option.  Measured baselines, Stata 17:
*   assert 0==1                 on _N==0  -> rc 9  (scalar checks are SAFE)
*   assert price<0 if foreign==99         -> rc 0  (FALSE assertion PASSES)
*   stqa_uniqueid / stqa_nomissing / stqa_iso3 on _N==0 -> rc 0 before the
*   guards these blocks now pin.
*
* The failing-mode blocks clear $stqa_block_failed after reading the return
* code, as in qa/test_harness.do.
* Author: Joao Pedro Azevedo (UNICEF)

stqa_test EDGE-06 "an empty if-selection fails under null instead of passing vacuously"
    sysuse auto, clear
    capture stqa_assert price < 0 if foreign == 99, null
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("a false assertion over zero selected observations passed (rc `rc')")
stqa_endtest

stqa_test EDGE-07 "null does not disturb a true assertion over a real selection"
    sysuse auto, clear
    stqa_assert price > 0 if foreign == 0, null
stqa_endtest

stqa_test EDGE-08 "without null the vacuous pass is documented, not accidental"
    * The unguarded form still passes -- that is assert's own semantics and
    * callers may rely on it.  This block PINS the behaviour so that if a
    * future change makes the guard the default, this test forces the change
    * to be a documented decision rather than a drift.
    sysuse auto, clear
    capture stqa_assert price < 0 if foreign == 99
    local rc = _rc
    stqa_assert `rc' == 0, msg("the unguarded form changed behaviour (rc `rc'); if deliberate, update this pin and the help")
stqa_endtest

stqa_test EDGE-09 "a scalar assertion still fails honestly on empty data"
    clear
    capture stqa_assert 0 == 1
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("a false scalar assertion passed on _N==0 (rc `rc')")
stqa_endtest

stqa_test EDGE-10 "uniqueid over zero observations is a failure, not a pass"
    clear
    set obs 0
    gen id = .
    capture stqa_uniqueid id
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("stqa_uniqueid certified a unique id over no data (rc `rc')")
stqa_endtest

stqa_test EDGE-11 "nomissing over zero observations is a failure, not a pass"
    clear
    set obs 0
    gen id = .
    capture stqa_nomissing id
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("stqa_nomissing certified completeness of no data (rc `rc')")
stqa_endtest

stqa_test EDGE-12 "iso3 over zero observations is a failure, not a pass"
    clear
    set obs 0
    gen str3 c = ""
    capture stqa_iso3 c
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("stqa_iso3 certified country codes of no data (rc `rc')")
stqa_endtest

stqa_test EDGE-13 "intentional emptiness has an explicit spelling"
    * The guards above must not leave "the output is genuinely empty today"
    * unsayable: stqa_shape nobs(0) is the assertion for that.
    clear
    set obs 0
    stqa_shape, nobs(0)
stqa_endtest
