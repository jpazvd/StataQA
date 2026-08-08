*! version 2.1.0  06aug2026
* stqa_file_exists: File existence assertion
* Description: Confirms a file path exists.  On failure it emits the FAIL: verdict
*              token for the open test block, names the file, keeps the original
*              r(601) in the Got: line, flags the block and exits 9.  No-op when
*              the block is skipped or targeted out.
* Options: msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_file_exists
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * The path stays positional so that a quoted absolute path with spaces
    * survives; the options are parsed by -syntax-, because that is what the
    * help file documents. With -args- the documented comma form left `msg'
    * holding a bare "," and the real message was dropped.
    gettoken filepath rest : 0
    local 0 `"`rest'"'
    syntax [, msg(string) NOIsily]

    if `"`filepath'"' == "" {
        di as error "stqa_file_exists: specify a file path"
        exit 198
    }

    capture confirm file "`filepath'"
    local frc = _rc

    if `frc' {
        local tid  `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"'  == "" local tid  "stqa_file_exists"
        if `"`desc'"' == "" local desc "assertion outside a test block"

        di as error `"FAIL: `tid' `desc' -- file `filepath' not found"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: file `filepath' to exist"'
        di as error `"Got: file not found (confirm returned rc = `frc')"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        di as txt "  > file `filepath' exists"
    }
end
