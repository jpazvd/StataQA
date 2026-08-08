*! version 2.0.0  06aug2026
* stqa_approx: Approximate numeric equality
* Description: Assert two numbers are within tolerance; accepts "a b" and "a == b".
* Options: tol()/tolerance(), msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_approx
    version 14.0

    * A skipped block must not run its assertions.
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * equalok is required for the documented "val1 == val2" form.
    * TOLerance() has minimum abbreviation tol, so tol() and tolerance() both work.
    syntax anything(name=args equalok) [, TOLerance(string) msg(string)]

    if "`tolerance'" == "" {
        local tolerance 1e-7
    }

    * Accept BOTH documented forms: "val1 val2" and "val1 == val2".
    * The old tokenize-only parser rejected the == form that the README and the
    * manuscript document, so users following the docs got a syntax error.
    local eqpos = strpos(`"`args'"', "==")
    if `eqpos' > 0 {
        local val1 = trim(substr(`"`args'"', 1, `eqpos' - 1))
        local val2 = trim(substr(`"`args'"', `eqpos' + 2, .))
    }
    else {
        tokenize `args'
        local val1 `1'
        local val2 `2'
    }

    if `"`val1'"' == "" | `"`val2'"' == "" {
        di as error "stqa_approx requires two numeric arguments"
        exit 198
    }

    if abs(`val1' - `val2') > `tolerance' {
        tempname diff
        scalar `diff' = abs(`val1' - `val2')

        local tid "$stqa_test_id"
        if "`tid'" == "" {
            local tid "stqa_approx"
        }
        local desc "`val1' not within `tolerance' of `val2'"
        if `"`msg'"' != "" {
            local desc `"`msg'"'
        }

        di as error `"FAIL: `tid' `desc'"'
        di as error "Expected: `val1' approximately equal to `val2' (tolerance `tolerance')"
        di as error "Got: difference of " `diff'
        global stqa_block_failed 1
        exit 9
    }
end
