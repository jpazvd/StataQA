*! version 2.2.0  07aug2026
* stqa_assert_equal_str: String equality assertion
* Description: Assert two string expressions are identical.  On failure it emits
*              the FAIL: verdict token for the open test block, flags the block
*              and exits 9.  No-op when the block is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_assert_equal_str
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * Same contract repair as the numeric variant (07aug2026): the header has
    * always documented msg() as an option, -args- took it positionally. The
    * two values stay positional and keep their quotes via -quotes-.
    gettoken val1 rest : 0, quotes
    gettoken val2 rest : rest, quotes
    local 0 `"`rest'"'
    syntax [, msg(string)]

    local val1 = subinstr(`"`val1'"', `"""', "", .)
    local val2 = subinstr(`"`val2'"', `"""', "", .)

    if `"`val1'"' != `"`val2'"' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_assert_equal_str"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- "`val1'" != "`val2'""'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: "`val1'" == "`val2'""'
        di as error `"Got: "`val1'" != "`val2'""'

        global stqa_block_failed 1
        exit 9
    }
end
