*! version 1.0.0  08aug2026
* stqa_validate: Validate the certification record without executing anything
* Description: The publisher role.  Reads the ledger's last stanza and judges
*              whether the RECORD supports a release of THIS tree: the stanza
*              exists, its verdict is green, its own arithmetic reconciles,
*              and -- the check that closes the compound false green -- its
*              recorded commit matches the commit of the tree being validated.
*              Runs no tests, writes nothing, appends nothing.  Every check
*              here is a file read, which is what lets CI pattern B implement
*              the same contract in a shell script on a runner with no Stata.
* Options: using(filename), nofresh
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_validate, rclass
    version 14.0
    syntax [using/] [, NOFresh]

    local vfail 0

    * ---- 1. the stanza exists and is readable ---------------------------
    if `"`using'"' != "" {
        capture noisily stqa_history using `"`using'"', check
    }
    else {
        capture noisily stqa_history, check
    }
    if (_rc) {
        di as error "validate: the ledger could not be read"
        exit 9
    }
    if (r(found) != 1) {
        di as error "validate: no certification stanza found -- nothing has been certified"
        exit 9
    }

    * copy everything before any other r-class call can clear it
    local v_green   = r(green)
    local v_run     = r(run)
    local v_pass    = r(pass)
    local v_fail    = r(fail)
    local v_skip    = r(skip)
    local v_verdict `"`r(verdict)'"'
    local v_commit  `"`r(commit)'"'
    local v_dirty   `"`r(dirty)'"'
    local v_version `"`r(version)'"'
    local v_date    `"`r(date)'"'

    * ---- 2. the verdict is green ----------------------------------------
    if (`v_green' != 1) {
        di as error `"validate: the last certification is not green (verdict: `v_verdict')"'
        local vfail 1
    }

    * ---- 3. the stanza's own arithmetic reconciles -----------------------
    * A record whose header disagrees with its own breakdown is not evidence
    * of anything -- the 85-vs-84 defect this package once shipped, now a
    * standing check on every validation.
    if (`v_run' != `v_pass' + `v_fail' + `v_skip') {
        di as error "validate: the stanza's counts do not reconcile (`v_run' run != `v_pass' + `v_fail' + `v_skip')"
        local vfail 1
    }

    * ---- 4. freshness: the record certifies THIS tree --------------------
    * Without this check the compound false green is live: a run that forgot
    * to certify leaves the PREVIOUS green stanza in place, and a validator
    * that reads only the verdict waves through a tree the record never saw.
    * Version-matching was always a proxy for this; the commit is exact.
    local fresh .
    if ("`nofresh'" == "") {
        capture stqa_gitinfo, nodirty
        if (_rc == 0 & r(inrepo) == 1) {
            local herecommit `"`r(commit)'"'
            if (substr(`"`v_commit'"', 1, 1) == "(" | `"`v_commit'"' == "") {
                di as text "validate: the stanza records no commit; freshness cannot be checked"
            }
            else if (`"`herecommit'"' == "(unknown)") {
                di as text "validate: the current commit could not be read; freshness cannot be checked"
            }
            else if (`"`v_commit'"' == `"`herecommit'"') {
                local fresh 1
            }
            else {
                di as error "validate: the record certifies a DIFFERENT tree"
                di as error "  recorded : `v_commit'"
                di as error "  this tree: `herecommit'"
                local fresh 0
                local vfail 1
            }
        }
        else {
            di as text "validate: not a git repository; freshness cannot be checked"
        }
    }

    * ---- 5. a dirty certification is flagged, not failed -----------------
    if (`"`v_dirty'"' == "yes") {
        di as text "validate: note -- the certification was made on a DIRTY tree; the commit does not fully describe what ran"
    }

    * ---- verdict ---------------------------------------------------------
    return scalar green = `v_green'
    return scalar fresh = `fresh'
    return local  commit  `"`v_commit'"'
    return local  version `"`v_version'"'

    if (`vfail') {
        di as error "validate: FAILED"
        return scalar ok = 0
        exit 9
    }
    di as result "validate: OK -- `v_verdict', `v_run' checks on `v_date', commit `=substr(`"`v_commit'"',1,8)'"
    return scalar ok = 1
end
