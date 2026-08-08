*! qa/test_varabbrev.do  version 1.0.0  07aug2026
* ENV family -- the assertion library survives -set varabbrev off-.
*
* SSC's submission checklist requires programs to work under
* -set varabbrev off-, and until 07aug2026 nothing in qa/ had ever run under
* it: an unwritten check whose absence reads exactly like a pass.  These
* blocks re-exercise the variable-facing assertions with abbreviation
* disabled, then restore the caller's setting UNCONDITIONALLY -- including
* when a captured assertion has already thrown.
* Author: Joao Pedro Azevedo (UNICEF)

local va0 = c(varabbrev)

stqa_test ENV-08 "variable-facing assertions run under set varabbrev off"
    sysuse auto, clear
    set varabbrev off
    stqa_hasvar price mpg
    stqa_vartype price, type(int)
    stqa_nomissing price
    stqa_uniqueid make
    stqa_shape, nobs(74) vars(12)
    stqa_unique make, count(74)
    quietly summarize price
    stqa_inrange r(mean) 6000 6300
    stqa_assert price > 0 if foreign == 0, null
    set varabbrev `va0'
stqa_endtest

stqa_test ENV-09 "an abbreviated name is rejected under varabbrev off, exact rc preserved"
    sysuse auto, clear
    set varabbrev off
    * -pri- abbreviates price; with abbreviation off it must NOT resolve, and
    * the assertion library must report that as a failure rather than resolve
    * it anyway or die with an unrelated code.
    capture stqa_hasvar pri
    local rc = _rc
    global stqa_block_failed ""
    set varabbrev `va0'
    stqa_assert `rc' == 9, msg("stqa_hasvar on an abbreviation under varabbrev off returned rc `rc', expected the assertion failure 9")
stqa_endtest

stqa_test ENV-10 "the caller's varabbrev setting is what it was"
    stqa_assert_equal_str "`c(varabbrev)'" "`va0'", msg("a block above failed to restore varabbrev")
stqa_endtest
