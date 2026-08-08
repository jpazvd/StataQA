*! version 2.0.0  06aug2026
* stqa_skip: Skip the current test block, conditionally
* Description: Emits the SKIP: verdict token, books the skip and neutralises the
*              rest of the block.  A skipped test is never counted as passed and
*              never as failed.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_skip
    version 14.0
    syntax [if] [, msg(string)]

    * already skipped, or the whole block was targeted out: no-op, and above
    * all do not book the skip twice
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * -syntax [if]- returns the qualifier WITH its leading "if" keyword, so
    * `if' expands to "if <exp>".  Strip the keyword before evaluating.
    * An omitted qualifier means "skip unconditionally".
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
        local reason `"`msg'"'
        if `"`reason'"' == "" {
            local reason "condition met"
        }

        local id `"$stqa_test_id"'
        if `"`id'"' == "" {
            local id "-"
        }

        di as txt `"SKIP: `id' `reason'"'

        local nskip `"$stqa_n_skip"'
        if `"`nskip'"' == "" local nskip 0
        global stqa_n_skip = `nskip' + 1

        local notes `"$stqa_skip_notes"'
        if `"`notes'"' == "" {
            local notes `"`id': `reason'"'
        }
        else {
            local notes `"`notes'|`id': `reason'"'
        }
        global stqa_skip_notes `"`notes'"'

        * neutralise the remainder of the block: assertions become no-ops and
        * stqa_endtest emits no further verdict for this block
        global stqa_skip_block 1

        * legacy globals still read by the runner to classify a whole file
        global stqa_SKIP_FLAG 1
        global stqa_SKIP_MSG `"`reason'"'
    }
end
