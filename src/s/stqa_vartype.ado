*! version 2.1.0  06aug2026
* stqa_vartype: Variable storage type assertion
* Description: Asserts a variable matches the expected storage type.  On failure it
*              emits the FAIL: verdict token for the open test block, names the
*              variable, flags the block and exits 9.  No-op when the block is
*              skipped or targeted out.
* Options: type(), msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_vartype
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * -syntax varlist- aborts with r(111) when the variable is absent, so the
    * "variable not found" branch below could never be reached, and under the
    * documented -capture stqa_*- idiom that r(111) left no verdict token in the
    * log.  The name is resolved by hand with -unab-, which applies the varlist
    * rules and returns 111 for a name that is not there.
    * ------------------------------------------------------------------
    syntax anything(name=vname) , TYPE(string) [msg(string)]

    capture unab uvname : `vname'
    local urc = _rc

    if `urc' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_vartype"
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
        di as error "stqa_vartype: only one variable may be specified"
        exit 103
    }

    local v : word 1 of `uvname'

    local actual : type `v'
    if lower("`actual'") != lower("`type'") {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_vartype"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- `v' is `actual', not `type'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `v' stored as `type'"'
        di as error `"Got: `v' stored as `actual'"'

        global stqa_block_failed 1
        exit 9
    }
end
