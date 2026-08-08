*! tests/test_expanded_assertions.do  version 2.1.0  06aug2026
* DATA family -- stqa_hasvar, stqa_shape, stqa_unique and stqa_svyset, in both
* their passing and their failing mode.
*
* Syntax corrections against the shipped command set:
*   stqa_hasvar takes ONE variable, not a varlist, so the two-name call is split
*   stqa_shape's observation option is nobs(); obs() is not a legal abbreviation
*   stqa_unique requires count(), and a failing case needs a count it cannot meet
*
* Every failing-mode block clears $stqa_block_failed after reading the return
* code.  An assertion that fails sets that flag, and leaving it set would book
* THIS block as red for doing exactly what it was written to do.  Same idiom as
* qa/test_harness.do.
* Author: Joao Pedro Azevedo (UNICEF)

stqa_test DATA-31 "a variable that is present is confirmed"
    sysuse auto, clear
    stqa_hasvar price
    stqa_hasvar mpg
stqa_endtest

stqa_test DATA-32 "a variable that is absent is rejected"
    sysuse auto, clear
    capture stqa_hasvar non_existent_var
    local rc = _rc
    global stqa_block_failed ""
    * -syntax varlist- rejects an unknown name with 111 before the body of the
    * command can exit 9; either code is a rejection, silence is not
    stqa_assert inlist(`rc', 9, 111), msg("an absent variable was accepted (rc `rc')")
stqa_endtest

stqa_test DATA-33 "the shape of a known dataset is confirmed"
    sysuse auto, clear
    stqa_shape, nobs(74) vars(12)
stqa_endtest

stqa_test DATA-34 "a wrong observation count is rejected"
    sysuse auto, clear
    capture stqa_shape, nobs(100)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("74 observations were accepted as 100 (rc `rc')")
stqa_endtest

stqa_test DATA-35 "a wrong variable count is rejected"
    sysuse auto, clear
    capture stqa_shape, vars(99)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("12 variables were accepted as 99 (rc `rc')")
stqa_endtest

stqa_test DATA-36 "an identifier has as many distinct values as observations"
    sysuse auto, clear
    gen id = _n
    stqa_unique id, count(74)
stqa_endtest

stqa_test DATA-37 "a distinct-value count that is not met is rejected"
    sysuse auto, clear
    capture stqa_unique foreign, count(50)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("foreign has 2 distinct values but 50 was accepted (rc `rc')")
stqa_endtest

stqa_test DATA-38 "a declared survey design is confirmed"
    sysuse auto, clear
    svyset [pw=weight], strata(foreign)
    stqa_svyset, weight(weight) strata(foreign)
stqa_endtest

stqa_test DATA-39 "a survey design missing a stratum variable is rejected"
    sysuse auto, clear
    svyset [pw=weight]
    capture stqa_svyset, strata(foreign)
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("an unstratified design was accepted as stratified (rc `rc')")
stqa_endtest
