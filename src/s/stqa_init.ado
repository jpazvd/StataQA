*! version 2.0.0  06aug2026
* stqa_init: Initialize a stataqa test suite
* Description: Creates the test directory, its logs/ subdirectory (which stqa_run
*              writes per-test logs into) and a sample test file. Directory creation
*              is judged by the artifact produced, never by the mkdir return code.
* Options: none (an optional directory argument, default "tests")
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_init
    version 14.0
    * The directory is peeled off with gettoken rather than -syntax anything()-,
    * which mangles a quoted path carrying a drive letter or spaces (defect #11).
    gettoken target_dir rest : 0
    local rest = trim(`"`macval(rest)'"')
    if `"`rest'"' != "" {
        di as error "stqa_init accepts a single directory argument"
        exit 198
    }
    if `"`target_dir'"' == "" local target_dir "tests"

    * ---- test directory ------------------------------------------------
    capture mkdir `"`target_dir'"'
    capture local probe : dir `"`target_dir'"' files "*"
    if _rc {
        di as error "Could not create or access directory: `target_dir'"
        exit 693
    }
    di as result "Test directory ready: `target_dir'"

    * ---- logs subdirectory (stqa_run writes per-test logs here) --------
    capture mkdir `"`target_dir'/logs"'
    capture local probe : dir `"`target_dir'/logs"' files "*"
    if _rc {
        di as error "Could not create or access directory: `target_dir'/logs"
        exit 693
    }
    di as result "Log directory ready: `target_dir'/logs"

    * ---- sample test file ----------------------------------------------
    local sample `"`target_dir'/test_example.do"'

    capture confirm file `"`sample'"'
    if _rc == 0 {
        di as txt "Sample test file already exists; left untouched: `sample'"
        exit 0
    }

    tempname fh
    capture file open `fh' using `"`sample'"', write text replace
    if _rc {
        di as error "Could not create sample test file: `sample'"
        exit 603
    }

    file write `fh' "*! Example stataqa test file" _n
    file write `fh' "* Run the suite with:  stataqa run" _n
    file write `fh' "" _n
    file write `fh' `"stqa_test example_arith "Basic arithmetic""' _n
    file write `fh' "    assert 1 + 1 == 2" _n
    file write `fh' "stqa_endtest" _n
    file close `fh'

    * judged by the artifact, not by the return code of the write
    capture confirm file `"`sample'"'
    if _rc {
        di as error "Sample test file was not written: `sample'"
        exit 603
    }
    di as result "Created sample test file: `sample'"
end
