*! version 2.1.0  06aug2026
* stqa_dir_exists: Directory existence assertion
* Description: Checks directory existence and optionally creates it.  On failure
*              it emits the FAIL: verdict token for the open test block, names the
*              directory, flags the block and exits 9.  No-op when the block is
*              skipped or targeted out.
* Options: create, msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_dir_exists
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    syntax anything(name=dirpath) [, CREATE msg(string)]

    * -anything- hands the path back with its quotes still attached, so a quoted
    * path interpolated into a display or a -confirm- reopens the quoting and
    * dies with r(198) before any verdict can be written.  Strip one matched
    * pair.  char(34) is used rather than a literal quote so this line cannot
    * itself become the accident it prevents.
    if (substr(`"`dirpath'"', 1, 1) == char(34)) {
        local _len = length(`"`dirpath'"')
        local dirpath = substr(`"`dirpath'"', 2, `_len' - 2)
    }

    * Stata has no -confirm dir-: -confirm dir "path"- is a syntax error, r(198),
    * for every path that exists and every path that does not, so this command
    * could never pass.  The macro extended function -dir- is the portable
    * existence test and returns r(601) for a directory that is not there.  The
    * file pattern is deliberately one that cannot match, so no large directory
    * is ever built into a macro just to ask whether it exists.
    capture local __stqa_ls__ : dir `"`dirpath'"' files "*.__stqa_probe__"
    local drc = _rc

    if `drc' {
        if "`create'" != "" {
            capture mkdir `"`dirpath'"'
            local mrc = _rc
            if `mrc' {
                local tid  `"$stqa_test_id"'
                local desc `"$stqa_test_name"'
                if `"`tid'"'  == "" local tid  "stqa_dir_exists"
                if `"`desc'"' == "" local desc "assertion outside a test block"

                di as error `"FAIL: `tid' `desc' -- could not create directory `dirpath'"'
                if `"`msg'"' != "" {
                    di as error `"Message: `msg'"'
                }
                di as error `"Expected: directory `dirpath' to exist or to be creatable"'
                di as error `"Got: mkdir failed (rc = `mrc')"'

                global stqa_block_failed 1
                exit 9
            }
            exit 0
        }

        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_dir_exists"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- directory `dirpath' not found"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: directory `dirpath' to exist"'
        di as error `"Got: directory not found (rc = `drc')"'

        global stqa_block_failed 1
        exit 9
    }
end
