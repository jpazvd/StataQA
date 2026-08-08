*! version 2.1.0  07aug2026
* stqa_assert: General assertion
* Description: Asserts that an expression is true.  On failure it emits the
*              FAIL: verdict token for the open test block, echoes the failing
*              condition and the original return code, flags the block and
*              exits 9.  No-op when the block is skipped or targeted out.
*              The null option additionally fails an assertion whose if/in
*              qualifier selects zero observations -- without it such an
*              assertion passes vacuously, having verified nothing.
* Options: msg() null
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_assert
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * ------------------------------------------------------------------
    * Parse by hand.  -syntax anything()- mangles expressions that contain
    * quoted strings ("`c(os)'" == "Windows"), and anything(name=exp) is
    * itself invalid (exp is a reserved token in a syntax specification,
    * rc 197).  Rebuild the expression token by token instead, stopping at
    * the first top-level comma: -quotes- keeps string literals intact and
    * -bind- keeps commas inside parentheses, as in inlist(x,1,2).
    * ------------------------------------------------------------------
    local cond ""
    local rest `"`0'"'
    local guard 0
    while `"`rest'"' != "" & `guard' < 500 {
        local guard = `guard' + 1
        gettoken tok rest : rest, parse(",") quotes bind
        if `"`tok'"' == "," {
            continue, break
        }
        if `"`cond'"' == "" {
            local cond `"`tok'"'
        }
        else {
            local cond `"`cond' `tok'"'
        }
    }
    local 0 ""
    if `"`rest'"' != "" {
        local 0 `", `rest'"'
    }
    syntax [, msg(string) NULL]

    local condblank : subinstr local cond " " "", all
    if `"`condblank'"' == "" {
        di as error "stqa_assert: an expression is required"
        exit 198
    }

    * ------------------------------------------------------------------
    * The vacuity guard, opt-in as -null-, matching official -assert- syntax.
    *
    * Measured on Stata 17: a SCALAR false assertion fails even at _N==0
    * (assert 0==1 -> rc 9), so scalar checks need no guard.  The hole is a
    * variable expression under an if/in qualifier that selects nothing:
    * -assert price < 0 if foreign == 99- returns rc 0 on auto.dta, a false
    * assertion passing.  Adopted from adotest (Dutey), whose test_assert
    * carries the same option; the mechanism is StataCorp's own.
    *
    * assert's null option exists from Stata 16, and this program declares
    * version 14.0, so the guard is gated on the BINARY (c(stata_version)),
    * not the declared version: on 16+ assert enforces it natively; below,
    * the selection is counted by hand.  The emulation locates the last
    * top-level " if " in the expression, which is a heuristic -- an
    * expression carrying the literal word if inside a string would confuse
    * it -- so the native path is preferred wherever the binary allows.
    * ------------------------------------------------------------------
    if "`null'" != "" & c(stata_version) >= 16 {
        capture assert `cond', null
        local arc = _rc
    }
    else {
        if "`null'" != "" {
            local nsel = _N
            local ifpos = strpos(`" `cond' "', " if ")
            if `ifpos' > 0 {
                local ifexp = substr(`" `cond' "', `ifpos' + 4, .)
                capture quietly count if `ifexp'
                if _rc == 0 local nsel = r(N)
            }
            if `nsel' == 0 {
                local id `"$stqa_test_id"'
                local nm `"$stqa_test_name"'
                if `"`id'"' == "" local id "ADHOC"
                if `"`nm'"' == "" local nm `"assertion outside a test block"'
                di as error `"FAIL: `id' `nm'"'
                if `"`msg'"' != "" {
                    di as error `"Message: `msg'"'
                }
                di as error `"Expected: `cond' over at least one observation"'
                di as error `"Got: the qualifier selected zero observations; nothing was verified"'
                global stqa_block_failed 1
                exit 9
            }
        }
        capture assert `cond'
        local arc = _rc
    }

    if `arc' {
        local id `"$stqa_test_id"'
        local nm `"$stqa_test_name"'
        if `"`id'"' == "" local id "ADHOC"
        if `"`nm'"' == "" local nm `"assertion outside a test block"'

        di as error `"FAIL: `id' `nm'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `cond'"'
        * rc 8 is what -assert, null- returns when the qualifier selected no
        * observations: not a false assertion, an unverified one.
        if `arc' == 8 & "`null'" != "" {
            di as error `"Got: the qualifier selected zero observations; nothing was verified (assert returned rc = 8)"'
        }
        else {
            di as error `"Got: assertion false (assert returned rc = `arc')"'
        }

        global stqa_block_failed 1
        exit 9
    }
end
