*! version 2.1.0  06aug2026
* stqa_rc_zero: Return code zero assertion
* Description: Asserts last return code equals zero.  On failure it emits the FAIL:
*              verdict token for the open test block, reports the return code that
*              was actually seen, flags the block and exits 9.  No-op when the block
*              is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_rc_zero
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * _rc is a system value, not a macro: "`_rc'" expands to nothing at all,
    * which is why the old diagnostic read "Return code is , expected 0" and
    * told the reader nothing.  Copy it into a local and report that.  It is
    * read before -syntax- so that nothing between here and the test can
    * disturb the value the caller left behind.
    local rc = _rc

    syntax [, msg(string)]

    if `rc' != 0 {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_rc_zero"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- return code `rc', expected 0"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: return code 0"'
        di as error `"Got: return code `rc'"'

        global stqa_block_failed 1
        exit 9
    }
end
