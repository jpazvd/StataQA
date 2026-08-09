*! examples/consumers/datalib/test_datalib_core.do  version 1.0.0  07aug2026
* INT family -- StataQA exercising the published -datalib- package.
*
* Targets the INSTALLED package, never a local working tree.  datalib
* loads microdata from a mounted library root, so beyond the usual
* absent-package skip, the data-touching block skips when no root is
* configured -- a machine without the share must read as SKIP, not red.
* Author: Joao Pedro Azevedo (UNICEF)

capture which datalib
local haspkg = (_rc == 0)

stqa_test INT-51 "datalib is installed and autoloads"
    if !`haspkg' {
        stqa_skip, msg("datalib is not installed on this machine")
    }
    else {
        stqa_assert 1 == 1
    }
stqa_endtest

stqa_test INT-52 "with no arguments and no library, the error is an error"
    if !`haspkg' {
        stqa_skip, msg("datalib is not installed on this machine")
    }
    else {
        * Whatever the configuration, a bare call must not exit 0 having
        * loaded nothing: rc 601 (no file) and 198 (bad syntax) are both
        * honest; 0 would be the silent success this framework hunts.
        capture datalib
        local rc = _rc
        global stqa_block_failed ""
        stqa_assert `rc' != 0, msg("datalib with no arguments returned rc 0 without loading anything")
    }
stqa_endtest

stqa_test INT-53 "the library root is reachable (mounted environments only)"
    if !`haspkg' {
        stqa_skip, msg("datalib is not installed on this machine")
    }
    else if `"${datalib}"' == "" {
        stqa_skip, msg("no library root configured in global datalib; data checks need the mounted share")
    }
    else {
        capture confirm file `"${datalib}/."'
        if _rc {
            stqa_skip, msg(`"the configured library root (${datalib}) is not reachable from this machine"')
        }
        else {
            stqa_assert 1 == 1, msg("root reachable")
        }
    }
stqa_endtest
