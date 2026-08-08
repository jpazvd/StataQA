*! version 2.2.0  07aug2026
* stqa_nomissing: Missing value assertion
* Description: Ensures variables contain no missing values.  On failure it emits
*              the FAIL: verdict token for the open test block, names the variables
*              that carry missing values, flags the block and exits 9.  No-op when
*              the block is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_nomissing
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * -syntax varlist- aborts with r(111) on an absent variable, and under the
    * documented -capture stqa_*- idiom that rc leaves no verdict token: a test
    * naming a variable that the pipeline stopped producing would pass silently.
    * The list is resolved by hand instead, so a name that is not there is
    * reported as a failure with its original rc.
    * ------------------------------------------------------------------
    syntax anything(name=vlist) [, msg(string)]

    capture unab uvlist : `vlist'
    local urc = _rc

    if `urc' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_nomissing"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- variable list `vlist' could not be resolved"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: every variable in `vlist' to exist in the dataset"'
        di as error `"Got: variable not found (unab returned rc = `urc')"'

        global stqa_block_failed 1
        exit 9
    }

    * "No missing values" over zero observations is vacuously true -- the
    * per-variable asserts below all pass at _N==0 having checked nothing, so
    * a pipeline that emptied its output certified completeness of no data.
    * A suite that means to allow emptiness asserts it with -stqa_shape,
    * nobs(0)-.  Measured 07aug2026.
    if _N == 0 {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_nomissing"
        if `"`desc'"' == "" local desc "assertion outside a test block"
        di as error `"FAIL: `tid' `desc' -- no observations in memory"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: no missing values of `uvlist' over at least one observation"'
        di as error `"Got: _N = 0; nothing was verified"'
        global stqa_block_failed 1
        exit 9
    }

    local badvars ""
    foreach v of varlist `uvlist' {
        capture assert !missing(`v')
        if _rc {
            local badvars `"`badvars' `v'"'
        }
    }

    if `"`badvars'"' != "" {
        local badvars = trim(`"`badvars'"')

        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_nomissing"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- missing values in `badvars'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: no missing values in `uvlist'"'
        di as error `"Got: missing values detected in `badvars'"'

        global stqa_block_failed 1
        exit 9
    }
end
