*! version 2.4.0  06aug2026
* stqa_fail: Book a failure WITHOUT aborting, conditionally
* Description: Emits the FAIL: verdict token and flags the open block, then
*              RETURNS rc 0.  It never exits, so the caller's own
*              -capture- / -if _rc- control flow is untouched and the checks
*              that follow still run.  This is the emitter for the
*              capture-then-decide idiom that most hand-rolled Stata suites are
*              written in, and the counterpart to stqa_assert, which aborts.
* Options: id(), msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_fail
    version 14.0
    syntax [if] [, id(string) msg(string)]

    * a skipped or targeted-out block must not be able to book a failure
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * -syntax [if]- returns the qualifier WITH its leading "if" keyword, so
    * `if' expands to "if <exp>".  Strip the keyword before evaluating.
    * An omitted qualifier means "fail unconditionally".
    * ------------------------------------------------------------------
    local cond `"`if'"'
    gettoken kw rest : cond
    if "`kw'" == "if" {
        local cond `"`rest'"'
    }
    local condblank : subinstr local cond " " "", all
    if `"`condblank'"' == "" {
        local cond 1
    }

    if `cond' {
        local tid `"`id'"'
        if `"`tid'"' == "" local tid `"$stqa_test_id"'
        if `"`tid'"' == "" local tid "ADHOC"

        local reason `"`msg'"'
        if `"`reason'"' == "" local reason `"$stqa_test_name"'
        if `"`reason'"' == "" local reason "failure booked without a message"

        * line-initial, because the log scanner counts only line-initial tokens
        di as error `"FAIL: `tid' `reason'"'

        * --------------------------------------------------------------
        * Counter ownership.  This is the one thing implementers get wrong.
        * INSIDE an open block, stqa_endtest does the counting when it sees
        * the flag, so booking the count here as well would double it.
        * OUTSIDE a block there is nothing to close, so the emitter counts
        * itself and records the id.
        * --------------------------------------------------------------
        global stqa_block_failed 1

        if `"$stqa_test_id"' == "" {
            local nfail `"$stqa_n_fail"'
            if `"`nfail'"' == "" local nfail 0
            global stqa_n_fail = `nfail' + 1

            local fids `"$stqa_failed_ids"'
            if `"`fids'"' == "" {
                local fids `"`tid'"'
            }
            else {
                local fids `"`fids' `tid'"'
            }
            global stqa_failed_ids `"`fids'"'
        }
    }

    * deliberately no exit: the caller keeps going
end
