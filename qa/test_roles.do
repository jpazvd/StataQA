*! qa/test_roles.do  version 1.0.0  08aug2026
* META family -- the role contract is falsifiable.
*
* review executes and appends nothing; certify executes and appends exactly
* one stanza; validate executes nothing and judges the record against this
* tree.  A role contract without tests that would fail if a role wrote
* something it should not is a comment, not a contract.
*
* MECHANICS.  Nested stqa_run cannot be measured from inside a measured file
* (see qa/test_roster.do), so the nested runs here execute in a SCRATCH
* working directory at file scope, with their side effects asserted through
* the filesystem: the scratch qa/test_history.txt either exists or it does
* not.  The cwd is restored UNCONDITIONALLY after each excursion.  validate
* is exercised against purpose-built ledgers whose Commit: fields are
* controlled, so the freshness verdict does not depend on repository state.
* Author: Joao Pedro Azevedo (UNICEF)

local home "`c(pwd)'"
local sand "`c(tmpdir)'/stataqa_roles"
capture mkdir "`sand'"

* ---- a one-file throwaway suite in the sandbox ------------------------
quietly {
    capture mkdir "`sand'/demo"
    tempname fh
    file open `fh' using "`sand'/demo/test_tiny.do", write text replace
    file write `fh' `"stqa_test SMOKE-01 "one plus one""' _n
    file write `fh' `"    stqa_assert 1 + 1 == 2"' _n
    file write `fh' `"stqa_endtest"' _n
    file close `fh'
}

* ---- excursion 1: review must not create a ledger ---------------------
cd "`sand'"
capture erase "qa/test_history.txt"
capture quietly stqa_run "demo", role(review)
local rc_rev = _rc
capture confirm file "qa/test_history.txt"
local rev_wrote = (_rc == 0)
cd "`home'"

* ---- excursion 2: certify must create exactly one stanza --------------
cd "`sand'"
capture quietly stqa_run "demo", role(certify)
local rc_cert = _rc
local cert_stanzas 0
capture confirm file "qa/test_history.txt"
if _rc == 0 {
    tempname ch
    file open `ch' using "qa/test_history.txt", read text
    file read `ch' cline
    while r(eof) == 0 {
        if substr(`"`macval(cline)'"', 1, 9) == "Test Run:" {
            local cert_stanzas = `cert_stanzas' + 1
        }
        file read `ch' cline
    }
    file close `ch'
}
cd "`home'"

stqa_test META-16 "a review run appends nothing to any ledger"
    stqa_assert `rev_wrote' == 0, msg("review created a ledger in the sandbox; the non-destructive promise is broken")
stqa_endtest

stqa_test META-17 "a certify run appends exactly one stanza"
    stqa_assert `cert_stanzas' == 1, msg("certify left `cert_stanzas' stanza(s) in a fresh ledger, expected exactly 1")
stqa_endtest

stqa_test META-18 "the working directory came back from every excursion"
    stqa_assert `"`c(pwd)'"' == `"`home'"', msg("an excursion failed to restore the cwd")
stqa_endtest

* ---- validate: controlled ledgers --------------------------------------
* The current commit, read the same way validate reads it.
quietly stqa_gitinfo, nodirty
local herecommit `"`r(commit)'"'

quietly {
    tempname vh
    file open `vh' using "`sand'/ledger_fresh.txt", write text replace
    file write `vh' "==============================================================================" _n
    file write `vh' "Test Run:    8 Aug 2026" _n
    file write `vh' "Started:    10:00:00" _n
    file write `vh' "Ended:      10:00:05" _n
    file write `vh' "Branch:     test-branch" _n
    file write `vh' "Commit:     `herecommit'" _n
    file write `vh' "Version:    9.9.9" _n
    file write `vh' "Run:        5" _n
    file write `vh' "Passed:     5" _n
    file write `vh' "Failed:     0" _n
    file write `vh' "Skipped:    0" _n
    file write `vh' "Result:     GATE GREEN" _n
    file write `vh' "==============================================================================" _n
    file close `vh'

    file open `vh' using "`sand'/ledger_stale.txt", write text replace
    file write `vh' "==============================================================================" _n
    file write `vh' "Test Run:    8 Aug 2026" _n
    file write `vh' "Commit:     0000000000000000000000000000000000000000" _n
    file write `vh' "Run:        5" _n
    file write `vh' "Passed:     5" _n
    file write `vh' "Failed:     0" _n
    file write `vh' "Skipped:    0" _n
    file write `vh' "Result:     GATE GREEN" _n
    file write `vh' "==============================================================================" _n
    file close `vh'

    file open `vh' using "`sand'/ledger_broken.txt", write text replace
    file write `vh' "==============================================================================" _n
    file write `vh' "Test Run:    8 Aug 2026" _n
    file write `vh' "Commit:     `herecommit'" _n
    file write `vh' "Run:        5" _n
    file write `vh' "Passed:     3" _n
    file write `vh' "Failed:     0" _n
    file write `vh' "Skipped:    0" _n
    file write `vh' "Result:     GATE GREEN" _n
    file write `vh' "==============================================================================" _n
    file close `vh'
}

stqa_test META-19 "validate passes a green, fresh, reconciled record"
    capture quietly stqa_validate using "`sand'/ledger_fresh.txt"
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("a green stanza at the current commit failed validation (rc `rc')")
stqa_endtest

stqa_test META-20 "validate fails a record that certifies a different tree"
    capture quietly stqa_validate using "`sand'/ledger_stale.txt"
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("a stanza pinned to a different commit validated (rc `rc'); the compound false green is open")
stqa_endtest

stqa_test META-21 "validate fails a record whose own arithmetic does not reconcile"
    capture quietly stqa_validate using "`sand'/ledger_broken.txt"
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("a stanza with 5 != 3+0+0 validated (rc `rc')")
stqa_endtest

stqa_test META-22 "validate fails loudly when nothing was ever certified"
    capture quietly stqa_validate using "`sand'/no_such_ledger.txt"
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("validating a missing ledger returned rc `rc', expected 9")
stqa_endtest
