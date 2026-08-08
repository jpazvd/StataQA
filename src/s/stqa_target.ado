*! version 2.0.0  06aug2026
* stqa_target: Set, clear or show the single-test target
* Description: Sets $stqa_target so that only the test block whose id matches
*              runs.  With no arguments it reports the current target.
* Options: clear
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_target
    version 14.0
    syntax [anything(name=tgt)] [, CLEAR]

    if `"`tgt'"' != "" & "`clear'" != "" {
        di as error "stqa_target: specify a test id or clear, not both"
        exit 198
    }

    if "`clear'" != "" {
        global stqa_target ""
        di as txt "stqa_target: target cleared (all tests will run)"
        exit 0
    }

    if `"`tgt'"' != "" {
        * a target is a single test id; extra tokens are a user error
        gettoken id rest : tgt
        local restblank : subinstr local rest " " "", all
        if `"`restblank'"' != "" {
            di as error "stqa_target: specify exactly one test id"
            exit 198
        }
        global stqa_target `"`id'"'
        di as txt `"stqa_target: only test `id' will run"'
        exit 0
    }

    if `"$stqa_target"' == "" {
        di as txt "stqa_target: no target set (all tests will run)"
    }
    else {
        di as txt `"stqa_target: current target is $stqa_target"'
    }
end
