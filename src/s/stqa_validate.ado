*! version 1.1.0  09aug2026
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
    *
    * The question is NOT whether the recorded commit equals HEAD. That rule
    * is the obvious one and it is unusable: committing the stanza is itself a
    * commit, so a ledger kept in the repository it certifies is stale the
    * instant it is filed, and every certification fails its own validation
    * one commit later. Measured on this package's own public repository,
    * which is how the defect was found.
    *
    * Nor is it whether the recorded commit equals the last commit that
    * touched the source: a certification made at a HEAD legitimately ahead of
    * that commit, because the commits since were documentation, would then be
    * rejected though nothing certified had moved.
    *
    * The question is whether any CERTIFIED CONTENT changed between the
    * recorded commit and now. The ledger and the run logs are the record OF a
    * run, not the thing certified, so they are excluded; src/ and the tests
    * are not. This is the rule Section 7 already states for the hosted-runner
    * validator: the run must not predate the most recent change to the source.
    *
    * Three outcomes, kept distinct on purpose. Git absent -> cannot be
    * checked. Recorded commit absent from this repository -> FAILURE, because
    * the record demonstrably describes another tree; conflating that with
    * "cannot be checked" would rebuild the false green this check exists to
    * close. Certified files differing -> FAILURE, and they are named.
    local fresh .
    if ("`nofresh'" == "") {
        capture stqa_gitinfo, nodirty
        local inrepo = 0
        if (_rc == 0) local inrepo = r(inrepo)

        if (`inrepo' != 1) {
            di as text "validate: not a git repository; freshness cannot be checked"
        }
        else if (substr(`"`v_commit'"', 1, 1) == "(" | `"`v_commit'"' == "") {
            di as text "validate: the stanza records no commit; freshness cannot be checked"
        }
        else {
            * is git usable?
            local gitok = 0
            tempfile gvf
            capture shell git --version > "`gvf'" 2>&1
            capture confirm file "`gvf'"
            if (_rc == 0) {
                tempname gvh
                capture file open `gvh' using "`gvf'", read text
                if (_rc == 0) {
                    file read `gvh' gline
                    file close `gvh'
                    capture local gline = trim(`"`macval(gline)'"')
                    if (_rc) local gline ""
                    if (substr(`"`gline'"', 1, 11) == "git version") local gitok = 1
                }
            }

            * does this repository contain the recorded commit?
            local haverev = 0
            if (`gitok' == 1) {
                tempfile cbf
                capture shell git cat-file -t `v_commit' > "`cbf'" 2>&1
                capture confirm file "`cbf'"
                if (_rc == 0) {
                    tempname cbh
                    capture file open `cbh' using "`cbf'", read text
                    if (_rc == 0) {
                        file read `cbh' cline
                        file close `cbh'
                        capture local cline = trim(`"`macval(cline)'"')
                        if (_rc) local cline ""
                        if (`"`cline'"' == "commit") local haverev = 1
                    }
                }
            }

            * did any certified file change since?
            local changed = -1
            local firstfile ""
            if (`gitok' == 1 & `haverev' == 1) {
                tempfile dsf
                capture shell git diff --name-only `v_commit' HEAD -- src qa ":(exclude)qa/test_history.txt" ":(exclude)qa/logs" > "`dsf'" 2>&1
                capture confirm file "`dsf'"
                if (_rc == 0) {
                    tempname dfh
                    capture file open `dfh' using "`dsf'", read text
                    if (_rc == 0) {
                        file read `dfh' dline
                        local deof = r(eof)
                        file close `dfh'
                        capture local dline = trim(`"`macval(dline)'"')
                        if (_rc) local dline ""
                        if (`deof' & `"`dline'"' == "") {
                            local changed = 0
                        }
                        else {
                            local changed = 1
                            local firstfile `"`macval(dline)'"'
                        }
                    }
                }
            }

            if (`gitok' == 0) {
                di as text "validate: git is not available; freshness cannot be checked"
            }
            else if (`haverev' == 0) {
                di as error "validate: the record names a commit this repository does not contain"
                di as error "  recorded : `v_commit'"
                di as error "  the record was made against a different tree"
                local fresh = 0
                local vfail = 1
            }
            else if (`changed' == 1) {
                di as error "validate: the certified content has CHANGED since the record was made"
                di as error "  recorded    : `v_commit'"
                di as error "  changed, e.g.: `macval(firstfile)'"
                local fresh = 0
                local vfail = 1
            }
            else if (`changed' == 0) {
                local fresh = 1
            }
            else {
                di as text "validate: git output unreadable; freshness cannot be checked"
            }
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
