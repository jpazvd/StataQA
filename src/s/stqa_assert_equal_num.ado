*! version 2.2.0  07aug2026
* stqa_assert_equal_num: Numeric equality assertion
* Description: Asserts two numeric expressions are exactly equal.  On failure
*              it emits the FAIL: verdict token for the open test block, flags
*              the block and exits 9.  No-op when the block is skipped or
*              targeted out.  For tolerance comparison use stqa_approx.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_assert_equal_num
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * The header has always documented msg() as an option; -args- took it as a
    * bare third token, so the documented comma form put "," into `msg' and
    * dropped the message. Same contract repair as stqa_inrange (07aug2026):
    * values positional, options parsed by -syntax-.
    gettoken val1 rest : 0
    gettoken val2 rest : rest
    local 0 `"`rest'"'
    syntax [, msg(string)]

    if `"`val1'"' == "" | `"`val2'"' == "" {
        di as error "stqa_assert_equal_num: specify two numeric expressions"
        exit 198
    }

    if `val1' != `val2' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_assert_equal_num"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- `val1' != `val2'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `val1' == `val2'"'
        di as error `"Got: `val1' != `val2'"'

        global stqa_block_failed 1
        exit 9
    }
end
