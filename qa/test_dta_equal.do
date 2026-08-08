*! tests/test_dta_equal.do  version 2.1.0  06aug2026
* REGR family -- stqa_dta_equal against a saved copy of the dataset.
*
* The failing-mode block clears $stqa_block_failed after reading the return
* code, as in qa/test_harness.do.
* Author: Joao Pedro Azevedo (UNICEF)

stqa_test REGR-11 "a dataset compares equal to a saved copy of itself"
    sysuse auto, clear
    tempfile t1
    quietly save "`t1'"

    stqa_dta_equal using "`t1'"
stqa_endtest

stqa_test REGR-12 "a one-cell difference is caught"
    sysuse auto, clear
    tempfile t2
    quietly save "`t2'"

    quietly replace price = price + 1 in 1
    capture stqa_dta_equal using "`t2'"
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("a changed price in observation 1 compared equal (rc `rc')")
stqa_endtest
