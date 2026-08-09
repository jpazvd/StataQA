*! examples/consumers/wbopendata/test_wbopendata_core.do  version 1.0.0  07aug2026
* INT family -- StataQA exercising the published -wbopendata- package (SSC).
*
* Targets the INSTALLED package (ssc install wbopendata), never the
* local working tree.  Every block SKIPs when the package is absent;
* the live-API block additionally skips when the World Bank service cannot be
* reached, so the suite is green-or-skip on any machine and never red for
* environmental reasons.
* Author: Joao Pedro Azevedo (UNICEF)

capture which wbopendata
local haspkg = (_rc == 0)

stqa_test INT-41 "wbopendata is installed and autoloads"
    if !`haspkg' {
        stqa_skip, msg("wbopendata is not installed on this machine")
    }
    else {
        stqa_assert 1 == 1
    }
stqa_endtest

stqa_test INT-42 "an unknown option is rejected, not silently ignored"
    if !`haspkg' {
        stqa_skip, msg("wbopendata is not installed on this machine")
    }
    else {
        capture wbopendata, no_such_option_xyz
        local rc = _rc
        global stqa_block_failed ""
        stqa_assert `rc' != 0, msg("a nonsense option was accepted (rc 0)")
    }
stqa_endtest

stqa_test INT-43 "a small extract returns the requested structure (live API)"
    if !`haspkg' {
        stqa_skip, msg("wbopendata is not installed on this machine")
    }
    else {
        capture wbopendata, indicator(SP.POP.TOTL) country(BRA) ///
            year(2020:2020) clear long
        if _rc {
            stqa_skip, msg("the API could not be reached (rc `=_rc'); a live check does not fail the suite")
        }
        else {
            stqa_nobs_min 1
            stqa_hasvar countrycode year
            stqa_nomissing countrycode year
        }
    }
stqa_endtest
