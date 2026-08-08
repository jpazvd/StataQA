*! version 2.2.0  07aug2026
* stqa_uniqueid: Unique identifier assertion
* Description: Asserts that a varlist uniquely identifies the observations in
*              memory (an -isid- wrapper).  On failure it emits the FAIL:
*              verdict token for the open test block, reports how many duplicate
*              key values were found, flags the block and exits 9.  No-op when
*              the block is skipped or targeted out.
* Options: msg(), noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_uniqueid
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * NOIsily, not noisily: -syntax [, noisily]- is parsed as a no-prefixed
    * toggle, which puts the value in a local named -isily- and leaves
    * `noisily' permanently empty.
    syntax varlist(min=1) [, msg(string) NOIsily]

    * -isid- passes on zero observations -- no rows, no duplicate keys -- so a
    * pipeline that silently emptied its output certified a unique identifier
    * over no data.  Asserting a data property of no data is the vacuous pass
    * this package hunts; a suite that MEANS to allow emptiness asserts it
    * explicitly with -stqa_shape, nobs(0)-.  Measured 07aug2026.
    if _N == 0 {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_uniqueid"
        if `"`desc'"' == "" local desc "assertion outside a test block"
        di as error `"FAIL: `tid' `desc' -- no observations in memory"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `varlist' to uniquely identify at least one observation"'
        di as error `"Got: _N = 0; nothing was verified"'
        global stqa_block_failed 1
        exit 9
    }

    capture isid `varlist'
    local irc = _rc

    if `irc' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_uniqueid"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        * Count the offending observations so the diagnostic says how badly the
        * key fails, not merely that it does.  Both steps are captured: on a
        * dataset that cannot be sorted the assertion must still report through
        * the contract rather than abort with an unrelated return code.
        local ndup "unknown"
        capture {
            tempvar dupct
            quietly bysort `varlist' : generate long `dupct' = _N
            quietly count if `dupct' > 1
            local ndup = r(N)
        }

        di as error `"FAIL: `tid' `desc' -- `varlist' does not uniquely identify observations"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `varlist' to uniquely identify the observations in memory"'
        di as error `"Got: `ndup' observation(s) share a key value (isid returned rc = `irc')"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        di as txt "  > Unique identifier confirmed: `varlist'"
    }
end
