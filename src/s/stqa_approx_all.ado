*! version 2.1.0  06aug2026
* stqa_approx_all: Approximate numeric equality for all observations
* Description: Assert all values are within tolerance of a target.  On failure it
*              emits the FAIL: verdict token for the open test block, names the
*              variable that failed, flags the block and exits 9.  No-op when the
*              block is skipped or targeted out.
* Options: target(), tolerance(), msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_approx_all
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * -syntax varlist- aborts with r(111) when the variable is absent, so the
    * "variable not found" branch below could never be reached.  Worse, under
    * the documented -capture stqa_*- idiom that r(111) leaves no verdict token
    * in the log at all.  The name is therefore resolved by hand, with -unab-,
    * which applies exactly the varlist rules (wildcards, abbreviation under
    * -set varabbrev on-) and returns 111 for a name that is not there.
    * ------------------------------------------------------------------
    syntax anything(name=vname) [, Target(real 0) TOLerance(real 1e-6) msg(string)]

    capture unab uvname : `vname'
    local urc = _rc

    if `urc' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_approx_all"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- variable `vname' not found"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: variable `vname' to exist in the dataset"'
        di as error `"Got: variable not found (unab returned rc = `urc')"'

        global stqa_block_failed 1
        exit 9
    }

    * the old varlist(max=1) specification allowed one variable only
    local nv : word count `uvname'
    if `nv' > 1 {
        di as error "stqa_approx_all: only one variable may be specified"
        exit 103
    }

    local v : word 1 of `uvname'

    tempvar __stqa_diff__
    quietly generate double `__stqa_diff__' = abs(`v' - `target')
    quietly summarize `__stqa_diff__', meanonly
    local maxdiff = r(max)

    if (`maxdiff' > `tolerance') {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_approx_all"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- `v' deviates from `target' by more than `tolerance'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: every value of `v' within `tolerance' of `target'"'
        di as error `"Got: maximum absolute deviation `maxdiff'"'

        global stqa_block_failed 1
        exit 9
    }
end
