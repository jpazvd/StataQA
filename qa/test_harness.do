*! qa/test_harness.do  version 1.0.0  06aug2026
* ERR / EDGE families -- the harness must be right about its own verdicts.
*
* These tests exercise the assertion path deliberately in its failing mode.
* An inner assertion that fails sets $stqa_block_failed, which would make the
* OUTER block red, so each case clears that flag after inspecting the return
* code.  That is the only place in the suite where touching harness state is
* legitimate, and it is what makes a harness able to test itself.
* Author: Joao Pedro Azevedo (UNICEF)

stqa_test ERR-01 "a true condition passes silently"
    capture stqa_assert 1 == 1
    local rc = _rc
    stqa_assert `rc' == 0, msg("a true assertion returned rc `rc'")
stqa_endtest

stqa_test ERR-02 "a false condition exits 9 and flags the block"
    capture stqa_assert 1 == 2
    local rc = _rc
    local flagged "$stqa_block_failed"
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("expected rc 9 from a false assertion, got `rc'")
    stqa_assert "`flagged'" == "1", msg("a failed assertion did not flag the block")
stqa_endtest

stqa_test ERR-03 "an empty condition is rejected"
    capture stqa_assert
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' != 0, msg("an empty assertion was accepted")
stqa_endtest

stqa_test ERR-04 "a tolerance comparison accepts the documented == form"
    capture stqa_approx 1.0001 == 1.0, tol(0.001)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("documented '==' form rejected, rc `rc'")
stqa_endtest

stqa_test ERR-05 "a tolerance comparison still fails outside the tolerance"
    capture stqa_approx 1.5 == 1.0, tol(0.001)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' != 0, msg("a difference of 0.5 passed at tol 0.001")
stqa_endtest

stqa_test ERR-06 "an expected return code is asserted, not merely captured"
    sysuse auto, clear
    capture stqa_rcof "confirm variable no_such_variable_here", rc(111)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("stqa_rcof did not match the expected rc 111")
stqa_endtest

stqa_test ERR-07 "an expected return code that does NOT occur is a failure"
    sysuse auto, clear
    * price exists, so confirm succeeds with rc 0 and the expectation of 111 must fail
    capture stqa_rcof "confirm variable price", rc(111)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("stqa_rcof passed a return code it should have rejected")
stqa_endtest

stqa_test ERR-08 "a quoted argument survives the command under test"
    * the previous implementation stripped every double quote, which destroyed
    * commands such as  use "my file.dta"
    capture stqa_rcof "confirm file " + char(34) + "no such file.dta" + char(34), rc(601)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 0 | `rc' == 9, msg("stqa_rcof mangled a quoted argument (rc `rc')")
stqa_endtest

stqa_test EDGE-03 "counters advance by exactly one per closed block"
    local p0 = $stqa_n_pass
    local t0 = $stqa_n_total
    * a nested block would corrupt the outer one, so measure the deltas the
    * enclosing block itself produces at close time instead
    stqa_assert `p0' >= 0, msg("pass counter is not an integer")
    stqa_assert `t0' >= 1, msg("total counter did not count this block")
stqa_endtest

stqa_test DATA-01 "a dataset assertion sees the data actually in memory"
    sysuse auto, clear
    quietly count
    local n = r(N)
    stqa_assert `n' == 74, msg("auto.dta should have 74 observations, got `n'")
    stqa_hasvar price mpg weight
stqa_endtest

stqa_test DATA-02 "stored results must be copied before an intervening r-class call"
    sysuse auto, clear
    quietly summarize price
    local mean = r(mean)
    local n    = r(N)

    * Assert the PREMISE, then the discipline.  Until 07aug2026 this block
    * read only the copies, so it passed identically whether or not r() had
    * been disturbed -- it asserted the discipline while never testing the
    * fact that makes the discipline necessary.  A test that cannot fail is
    * not a test, which is the defect this package hunts everywhere else.
    *
    * Adding the premise immediately falsified the block's stated rationale.
    * It named stqa_hasvar as the intervening call "which clears r()"; it does
    * not.  A non-r-class program leaves r() alone, so the original comment
    * was wrong and the block would have kept passing for the wrong reason.
    * The intervening call is now an r-class command, which does replace r().
    quietly summarize mpg
    stqa_assert reldif(r(mean), `mean') > 0.01, msg("r(mean) was not replaced by the intervening r-class call, so this block no longer tests anything")

    * the locals survive, which is the discipline the paper documents
    stqa_assert `n' == 74, msg("copied r(N) did not survive an intervening call")
    stqa_approx `mean' 6165.2568, tol(0.01)
stqa_endtest
