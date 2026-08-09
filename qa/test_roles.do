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

* ---------------------------------------------------------------------------
* META-24: a ledger committed into the repository it certifies stays fresh.
*
* The regression test for a defect found on this package's own public repo.
* validate used to require the recorded commit to EQUAL HEAD, which is
* unusable: committing the stanza is itself a commit, so the record was stale
* the instant it was filed and every certification failed its own validation
* one commit later. Two-sided on purpose -- a test that only checked the
* ledger-only case would also pass against a validate that never fails.
* ---------------------------------------------------------------------------
local gitsand "`c(tmpdir)'/stqa_freshsand"
capture shell rmdir /s /q "`gitsand'"
capture shell rm -rf "`gitsand'"
capture mkdir "`gitsand'"

local fresh_rc = -1
local stale_rc = -1

capture noisily {
    cd "`gitsand'"
    capture mkdir "src"
    capture mkdir "qa"
    quietly {
        tempname gh
        file open `gh' using "src/thing.ado", write text replace
        file write `gh' "program thing" _n "end" _n
        file close `gh'
    }
    shell git init -q .
    shell git add -A
    shell git -c user.email=a@b -c user.name=t commit -q -m src

    quietly stqa_gitinfo, nodirty
    local gc = r(commit)
    quietly {
        file open `gh' using "qa/test_history.txt", write text replace
        file write `gh' "==============================================================================" _n
        file write `gh' "Test Run:    9 Aug 2026" _n
        file write `gh' "Commit:     `gc'" _n
        file write `gh' "Dirty:      no" _n
        file write `gh' "Version:    2.3.0" _n
        file write `gh' "Run:        3" _n
        file write `gh' "Passed:     3" _n
        file write `gh' "Failed:     0" _n
        file write `gh' "Skipped:    0" _n
        file write `gh' "Result:     GATE GREEN" _n
        file write `gh' "==============================================================================" _n
        file close `gh'
    }

    * (a) commit the LEDGER only -- the record must remain fresh
    shell git add -A
    shell git -c user.email=a@b -c user.name=t commit -q -m record
    capture quietly stqa_validate using "qa/test_history.txt"
    local fresh_rc = _rc
    global stqa_block_failed ""

    * (b) now change certified SOURCE -- the record must go stale
    quietly {
        file open `gh' using "src/thing.ado", write text replace
        file write `gh' "program thing" _n "    di 1" _n "end" _n
        file close `gh'
    }
    shell git add -A
    shell git -c user.email=a@b -c user.name=t commit -q -m edit
    capture quietly stqa_validate using "qa/test_history.txt"
    local stale_rc = _rc
    global stqa_block_failed ""
}
cd "`home'"

stqa_test META-24 "a ledger committed into its own repository stays fresh, until the source moves"
    stqa_assert `fresh_rc' == 0, msg("committing the stanza made the record stale (rc `fresh_rc'); a ledger kept in the repo it certifies could never validate")
    stqa_assert `stale_rc' == 9, msg("a source change after the record did NOT go stale (rc `stale_rc'); the freshness check has stopped checking")
stqa_endtest

stqa_test META-22 "validate fails loudly when nothing was ever certified"
    capture quietly stqa_validate using "`sand'/no_such_ledger.txt"
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 9, msg("validating a missing ledger returned rc `rc', expected 9")
stqa_endtest
