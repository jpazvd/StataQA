*! version 2.1.0  06aug2026
* stqa_shape: Assert dataset shape
* Description: Checks number of observations and variables when specified.  On
*              failure it emits the FAIL: verdict token for the open test block,
*              reports the expected and actual dimensions, flags the block and
*              exits 9.  No-op when the block is skipped or targeted out.
* Options: nobs(), vars(), msg(), noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_shape
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * An OPTIONAL integer option must declare a default, or the specification
    * itself is invalid and every call dies with rc 197.  -1 is the sentinel
    * for "not specified": the macros are always populated from here on, so the
    * guards below test the value, not the emptiness, of the macro.
    syntax [, NOBS(integer -1) VARS(integer -1) msg(string) NOIsily]

    * Both sentinels still set means the call stated no criterion. Left alone
    * it compared nothing and reported "Shape check passed", which is the
    * package's own definition of a defect: a check that cannot fire is
    * indistinguishable from a check that passed. A caller whose nobs() came
    * from a macro that expanded empty gets an error here instead of a green.
    if `nobs' < 0 & `vars' < 0 {
        di as error "stqa_shape: specify nobs(), vars(), or both"
        exit 198
    }

    local failed 0
    local expected ""
    local got ""

    if `nobs' >= 0 {
        if _N != `nobs' {
            local failed 1
            local expected `"`nobs' observation(s)"'
            local got `"`=_N' observation(s)"'
        }
    }

    if `vars' >= 0 {
        if c(k) != `vars' {
            local failed 1
            if `"`expected'"' != "" {
                local expected `"`expected', "'
                local got `"`got', "'
            }
            local expected `"`expected'`vars' variable(s)"'
            local got `"`got'`=c(k)' variable(s)"'
        }
    }

    if `failed' {
        local tid `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"' == "" local tid "stqa_shape"
        if `"`desc'"' == "" local desc "dataset shape mismatch"

        di as error `"FAIL: `tid' `desc'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `expected'"'
        di as error `"Got: `got'"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        di as txt "  > Shape check passed (nobs=" _N ", vars=" c(k) ")"
    }
end
