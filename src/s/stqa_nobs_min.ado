*! version 2.1.0  06aug2026
* stqa_nobs_min: Minimum observation count assertion
* Description: Asserts dataset has at least a specified number of observations.
*              On failure it emits the FAIL: verdict token for the open test
*              block, reports the floor and the count found, flags the block and
*              exits 9.  No-op when the block is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_nobs_min
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * -integer- is not a legal leading element of a syntax specification at all,
    * so the former -syntax integer(name=min_obs min=0)- made every call die
    * with rc 197.  The argument is taken as anything() and confirmed by hand.
    syntax anything(name=min_obs) [, msg(string)]

    capture confirm integer number `min_obs'
    if _rc {
        di as error "stqa_nobs_min: min_obs must be an integer number; got `min_obs'"
        exit 198
    }

    if _N < `min_obs' {
        local tid `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"' == "" local tid "stqa_nobs_min"
        if `"`desc'"' == "" local desc "too few observations"

        di as error `"FAIL: `tid' `desc'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: at least `min_obs' observation(s)"'
        di as error `"Got: `=_N' observation(s)"'

        global stqa_block_failed 1
        exit 9
    }
end
