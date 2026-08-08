*! version 2.1.0  06aug2026
* stqa_inrange: Numeric range assertion
* Description: Asserts a value lies within given bounds.  On failure it emits the
*              FAIL: verdict token for the open test block, flags the block and
*              exits 9.  No-op when the block is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_inrange
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * The help file documents a comma-delimited msg() option, and -args- does
    * not tokenize on commas: for the documented call
    *     stqa_inrange 5 1 10, msg("out of range")
    * the third token became "10," and the command died on an invalid
    * expression instead of returning a verdict -- and r(198) is not r(9), so
    * no FAIL: token reached the log. Take the three values positionally, then
    * hand the remainder to -syntax- like every sibling assertion.
    gettoken val  rest : 0
    gettoken min  rest : rest
    gettoken max  rest : rest
    local 0 `"`rest'"'
    syntax [, msg(string) NOIsily]

    if `"`val'"' == "" | `"`min'"' == "" | `"`max'"' == "" {
        di as error "stqa_inrange: specify value, min and max"
        exit 198
    }

    if !inrange(`val', `min', `max') {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_inrange"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- `val' outside [`min', `max']"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `val' in range [`min', `max']"'
        di as error `"Got: `val'"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        di as txt "  > `val' is within [`min', `max']"
    }
end
