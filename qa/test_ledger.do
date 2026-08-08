*! qa/test_ledger.do  version 2.3.0  08aug2026
* DET family -- stqa_history must read the ledger dialects the production
* suites actually keep, not only the stanzas this package writes.
*
* The four repos write four dialects of one skeleton, and two of the
* differences are traps:
*
*   Failed:   XPLAT-01, XPLAT-04     <- IDs, in every production repo
*   Failed:   2                      <- a COUNT, in this package's own stanza
*
*   Tests:    63 run, 61 passed, 2 failed        <- yaml, unicefdata, wbopendata
*   Run:/Passed:/Failed:/Skipped: on four lines  <- this package
*
* Reading the first convention with the second's parser puts "XPLAT-01,
* XPLAT-04" into a numeric field and reports zero tests run. These checks pin
* both readings against frozen captures of the four dialects, committed under
* qa/fixtures/ledgers/ (formats verified against the live production ledgers,
* 08aug2026; branch fields sanitized).  Frozen fixtures run everywhere the
* package does -- the earlier sibling-checkout reads skipped on any machine
* without the private development layout.
* Author: Joao Pedro Azevedo (UNICEF)

*---------------------------------------------------------------------------
* unicefdata: comma-separated failing IDs, compact Tests: line
*---------------------------------------------------------------------------
stqa_test DET-07 "a unicefdata ledger stanza is read correctly"
    local led "qa/fixtures/ledgers/unicefdata.txt"
    quietly stqa_history using "`led'", check
    local found = r(found)
    local run   = r(run)
    local ids   `"`r(ids)'"'
    local ver   `"`r(version)'"'

    stqa_assert `found' == 1, msg("no stanza found in the unicefdata fixture")
    stqa_assert `run' == 63, msg("Tests: line not parsed -- run came back `run', expected 63")
    stqa_assert `"`ver'"' != "", msg("Version: not parsed")
stqa_endtest

stqa_test DET-08 "failing IDs are not mistaken for a failure count"
    local led "qa/fixtures/ledgers/unicefdata.txt"
    quietly stqa_history using "`led'", check
    local f  = r(fail)
    local id `"`r(ids)'"'
    * the fixture's Failed: line carries "XPLAT-01, XPLAT-04" -- IDs; the
    * count lives in the Tests: line.  r(fail) must be the number 2, and the
    * ids must not have leaked into it.
    capture confirm number `f'
    stqa_assert _rc == 0, msg("r(fail) is not numeric -- ids leaked into the count")
    stqa_assert !regexm(`"`f'"', "[A-Za-z]"), msg("r(fail) contains letters: `f'")
    stqa_assert `f' == 2, msg("r(fail) is `f', expected 2 from the Tests: line")
stqa_endtest

*---------------------------------------------------------------------------
* yaml: space-separated failing IDs
*---------------------------------------------------------------------------
stqa_test DET-09 "a yaml ledger stanza is read correctly"
    local led "qa/fixtures/ledgers/yaml.txt"
    quietly stqa_history using "`led'", check
    local found = r(found)
    local run   = r(run)
    local raw   `"`r(tests_raw)'"'

    stqa_assert `found' == 1, msg("no stanza found in the yaml fixture")
    stqa_assert `run' == 36, msg("Tests: line not parsed -- run came back `run', expected 36")
    stqa_assert `"`raw'"' != "", msg("the raw Tests: line was not preserved")
stqa_endtest

*---------------------------------------------------------------------------
* wbopendata: carries Build:, and writes no Skipped: line at all
*---------------------------------------------------------------------------
stqa_test DET-10 "a wbopendata ledger stanza is read, including Build:"
    local led "qa/fixtures/ledgers/wbopendata.txt"
    quietly stqa_history using "`led'", check
    local found = r(found)
    local run   = r(run)
    local bld   `"`r(build)'"'

    stqa_assert `found' == 1, msg("no stanza found in the wbopendata fixture")
    stqa_assert `run' == 92, msg("Tests: line not parsed -- run came back `run', expected 92")
    stqa_assert `"`bld'"' != "", msg("Build: not parsed")
stqa_endtest

*---------------------------------------------------------------------------
* datalib: counts suites and checks separately, and has a per-suite breakdown
* whose indented lines must NOT be parsed as fields
*---------------------------------------------------------------------------
stqa_test DET-11 "a datalib ledger stanza is read, suites and checks separately"
    local led "qa/fixtures/ledgers/datalib.txt"
    quietly stqa_history using "`led'", check
    local found  = r(found)
    local checks = r(checks)
    local sruns  = r(suites_run)
    local verd   `"`r(verdict)'"'

    stqa_assert `found' == 1, msg("no stanza found in the datalib fixture")
    stqa_assert `checks' == 217, msg("Checks: not parsed -- got `checks', expected 217")
    stqa_assert `sruns' == 8, msg("Suites: not parsed -- got `sruns', expected 8")
    stqa_assert `"`verd'"' != "", msg("Result: not parsed")
stqa_endtest

*---------------------------------------------------------------------------
* A ledger that is not one, and a file that is not there.
*---------------------------------------------------------------------------
stqa_test EDGE-04 "a file with no stanza is reported, not treated as green"
    tempfile notaledger
    quietly {
        tempname fh
        file open `fh' using "`notaledger'", write replace text
        file write `fh' "this file is not a ledger" _n
        file close `fh'
    }
    capture quietly stqa_history using "`notaledger'", check
    local rc    = _rc
    local found = r(found)
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("reading a non-ledger aborted with rc `rc'")
    stqa_assert `found' == 0, msg("a file with no stanza reported found=1")
stqa_endtest

stqa_test EDGE-05 "a missing ledger is reported, not raised"
    capture quietly stqa_history using "c:/nonexistent/never_written.txt", check
    local rc    = _rc
    local found = r(found)
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("a missing ledger aborted with rc `rc'")
    stqa_assert `found' == 0, msg("a missing ledger reported found=1")
stqa_endtest
