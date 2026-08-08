*! version 2.1.0  06aug2026
* stqa_dta_equal: Dataset equality assertion
* Description: Compares dataset in memory to a reference .dta file.  On failure it
*              emits the FAIL: verdict token for the open test block, preserves the
*              return code -cf- actually raised, flags the block and exits 9.
*              No-op when the block is skipped or targeted out.
* Options: msg(), noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_dta_equal
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    syntax using/ [, msg(string) NOIsily]

    if "`noisily'" != "" {
        local quiet ""
    }
    else {
        local quiet "quietly"
    }

    capture `quiet' cf _all using "`using'"
    local rc = _rc

    if `rc' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_dta_equal"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        * rc 9 is a genuine data difference; anything else means the comparison
        * itself could not be made (missing file, variable mismatch), and a
        * broken test must stay distinguishable from a failing one.
        if `rc' == 9 {
            local reason "dataset in memory differs from `using'"
            local gotten "cf reported a difference (rc = 9)"
        }
        else {
            local reason "comparison against `using' could not be made"
            local gotten "cf failed, e.g. file not found or variable mismatch (rc = `rc')"
        }

        di as error `"FAIL: `tid' `desc' -- `reason'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: dataset in memory identical to `using'"'
        di as error `"Got: `gotten'"'

        global stqa_block_failed 1
        exit 9
    }
end
