*! version 2.1.0  06aug2026
* stqa_hasvar: Assert variable presence
* Description: Confirms the variables exist in the current dataset.  On failure it
*              emits the FAIL: verdict token for the open test block, names the
*              variables that are missing, flags the block and exits 9.  No-op when
*              the block is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_hasvar
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * -syntax varlist- aborts with r(111) when a variable is absent, which is
    * precisely the condition this command exists to report: the failure branch
    * below was unreachable, and under the documented -capture stqa_*- idiom the
    * r(111) left no verdict token in the log.  Each name is resolved by hand
    * with -unab-, which applies the varlist rules (wildcards, abbreviation
    * under -set varabbrev on-) and returns 111 for a name that is not there.
    * Resolving one name at a time is what lets the FAIL: line say WHICH
    * variable is missing rather than only that something was.
    * ------------------------------------------------------------------
    syntax anything(name=vlist) [, msg(string) NOIsily]

    local missingvars ""
    local urc 0
    foreach v of local vlist {
        capture unab __stqa_one__ : `v'
        if _rc {
            local urc = _rc
            local missingvars `"`missingvars' `v'"'
        }
    }

    if `"`missingvars'"' != "" {
        local missingvars = trim(`"`missingvars'"')

        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_hasvar"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- variable(s) not found: `missingvars'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `vlist' to exist in the dataset"'
        di as error `"Got: not found: `missingvars' (unab returned rc = `urc')"'

        global stqa_block_failed 1
        exit 9
    }

    * The help file has always documented this option; the syntax line did not
    * declare it, so every call that followed the help died with r(198) -- and
    * r(198) is not r(9), so the failure carried no FAIL: verdict token.
    if "`noisily'" != "" {
        di as txt "  > variable(s) present: `vlist'"
    }
end
