*! version 2.2.0  07aug2026
* stqa_svyset: Survey design assertion
* Description: Verifies svyset matches expected psu/strata/weight settings.  On
*              failure it emits the FAIL: verdict token for the open test block,
*              names the setting that did not match, flags the block and exits 9.
*              No-op when the block is skipped or targeted out.
* Options: psu(), strata(), weight(), msg(), noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_svyset
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * Weight, not WEIGHT: all capitals means the whole word is the minimum
    * abbreviation, so w(), we() and wei() were all rejected with r(198) --
    * while the help file has always advertised {opt w:eight(varname)}. And
    * r(198) is not r(9), so that failure carried no verdict token.
    syntax [, psu(varname) STRata(varname) Weight(varname) msg(string) NOIsily]

    * ------------------------------------------------------------------
    * -svyset, list- is not a legal command: it exits 198 on a dataset that is
    * perfectly well svyset, so this assertion could never pass.  Plain -svyset-
    * displays and returns the current design.  It also returns rc 0 whether or
    * not a design is set, so "is it svyset at all" is read from r(settings),
    * which is ", clear" exactly when there is no design.
    * The returned names are r(su1)/r(strata1)/r(wvar); r(psu) and r(strata) do
    * not exist and always came back empty.
    * ------------------------------------------------------------------
    capture quietly svyset
    local svrc = _rc

    local cur_psu      "`r(su1)'"
    local cur_strata   "`r(strata1)'"
    local cur_weight   "`r(wvar)'"
    local cur_settings `"`r(settings)'"'

    if `svrc' | `"`cur_settings'"' == ", clear" {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_svyset"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- dataset is not svyset"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: a survey design to be declared with -svyset-"'
        di as error `"Got: no design set (svyset returned rc = `svrc', settings = `cur_settings')"'

        global stqa_block_failed 1
        exit 9
    }

    if "`cur_psu'" == "."    local cur_psu ""
    if "`cur_strata'" == "." local cur_strata ""
    if "`cur_weight'" == "." local cur_weight ""

    local failed 0
    local reasons ""

    if "`psu'`strata'`weight'" == "" {
        if "`cur_psu'" == "" {
            local failed 1
            local reasons `"`reasons' survey design not set with a PSU variable;"'
        }
    }
    else {
        if "`psu'" != "" {
            if "`cur_psu'" == "" {
                local failed 1
                local reasons `"`reasons' PSU not set, expected `psu';"'
            }
            else if "`psu'" != "`cur_psu'" {
                local failed 1
                local reasons `"`reasons' PSU mismatch, expected `psu' found `cur_psu';"'
            }
        }

        if "`strata'" != "" {
            if "`cur_strata'" == "" {
                local failed 1
                local reasons `"`reasons' strata not set, expected `strata';"'
            }
            else if "`strata'" != "`cur_strata'" {
                local failed 1
                local reasons `"`reasons' strata mismatch, expected `strata' found `cur_strata';"'
            }
        }

        if "`weight'" != "" {
            if "`cur_weight'" == "" {
                local failed 1
                local reasons `"`reasons' weight not set, expected `weight';"'
            }
            else if "`weight'" != "`cur_weight'" {
                local failed 1
                local reasons `"`reasons' weight mismatch, expected `weight' found `cur_weight';"'
            }
        }
    }

    if `failed' {
        local reasons = trim(`"`reasons'"')
        if substr(`"`reasons'"', -1, 1) == ";" {
            local reasons = substr(`"`reasons'"', 1, length(`"`reasons'"') - 1)
        }

        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_svyset"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        local want ""
        if "`psu'"    != "" local want `"`want' psu=`psu'"'
        if "`strata'" != "" local want `"`want' strata=`strata'"'
        if "`weight'" != "" local want `"`want' weight=`weight'"'
        if `"`want'"' == "" local want " a survey design with a PSU variable"
        local want = trim(`"`want'"')

        local have ""
        if "`cur_psu'"    != "" local have `"`have' psu=`cur_psu'"'
        if "`cur_strata'" != "" local have `"`have' strata=`cur_strata'"'
        if "`cur_weight'" != "" local have `"`have' weight=`cur_weight'"'
        if `"`have'"' == "" local have " nothing"
        local have = trim(`"`have'"')

        di as error `"FAIL: `tid' `desc' -- `reasons'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `want'"'
        di as error `"Got: `have'"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        local summary ""
        if "`cur_psu'"    != "" local summary "`summary' psu=`cur_psu'"
        if "`cur_strata'" != "" local summary "`summary' strata=`cur_strata'"
        if "`cur_weight'" != "" local summary "`summary' weight=`cur_weight'"

        if "`summary'" == "" {
            di as txt "  > svyset verified"
        }
        else {
            local summary = trim("`summary'")
            di as txt "  > svyset verified (`summary')"
        }
    }
end
