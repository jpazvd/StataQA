*! version 1.0.0  08aug2026
* stqa_gitinfo: Read git provenance for the working directory
* Description: Returns the current branch, commit SHA and (optionally) dirty
*              state in r(), reading .git directly rather than shelling out.
*              One implementation, shared by stqa_history (which records the
*              fields into the certification ledger) and stqa_validate (which
*              compares a recorded stanza against the tree being validated).
*              Never errors: a missing repository is a reported STATE, not a
*              failure -- r(branch) and r(commit) then say so in words.
* Options: nodirty
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_gitinfo, rclass
    version 14.0
    syntax [, NODirty]

    * ------------------------------------------------------------------
    * Branch and commit come from plain file reads:
    *   .git/HEAD                -> "ref: refs/heads/<branch>"  (or a raw
    *                               SHA when HEAD is detached)
    *   .git/refs/heads/<branch> -> the commit SHA
    *   .git/packed-refs         -> the SHA when the loose ref is packed
    * No process spawn, no dependency on git being installed, and it works
    * where -shell- is refused outright (batch Stata on a locked-down
    * machine is the case that motivated it).  Only DIRTY state genuinely
    * requires invoking git, and its absence degrades to "." with a state
    * string, never to a guess.
    * ------------------------------------------------------------------
    local branch "(unknown)"
    local commit "(unknown)"
    local gitdir ".git"

    * a worktree or submodule has .git as a FILE holding "gitdir: <path>"
    capture confirm file ".git/HEAD"
    if (_rc) {
        capture confirm file ".git"
        if (_rc == 0) {
            tempname wh
            capture file open `wh' using ".git", read text
            if (_rc == 0) {
                file read `wh' wline
                file close `wh'
                capture local wline = trim(`"`macval(wline)'"')
                if (_rc) local wline ""
                if (substr(`"`wline'"', 1, 8) == "gitdir: ") {
                    local gitdir = trim(substr(`"`wline'"', 9, .))
                }
            }
        }
    }

    capture confirm file "`gitdir'/HEAD"
    if (_rc) {
        * Not a git repository at all -- which is exactly what a reader of
        * the Stata Journal package gets after unzipping it.
        return local  branch "(not a git repository)"
        return local  commit "(not a git repository)"
        return scalar inrepo = 0
        return scalar dirty  = .
        return local  dirtystate "(not a git repository)"
        exit 0
    }

    tempname gh
    local headline ""
    capture file open `gh' using "`gitdir'/HEAD", read text
    if (_rc == 0) {
        file read `gh' headline
        file close `gh'
        capture local headline = trim(`"`macval(headline)'"')
        if (_rc) local headline ""
    }

    if (substr(`"`headline'"', 1, 5) == "ref: ") {
        local refpath = trim(substr(`"`headline'"', 6, .))
        * a branch name never contains a space, so anything that does is
        * not a ref and is rejected on sight
        if (strpos(`"`refpath'"', " ") == 0 & `"`refpath'"' != "") {
            if (substr(`"`refpath'"', 1, 11) == "refs/heads/") {
                local branch = substr(`"`refpath'"', 12, .)
            }
            else {
                local branch `"`refpath'"'
            }

            capture confirm file "`gitdir'/`refpath'"
            if (_rc == 0) {
                tempname rh
                capture file open `rh' using "`gitdir'/`refpath'", read text
                if (_rc == 0) {
                    file read `rh' sline
                    file close `rh'
                    capture local sline = trim(`"`macval(sline)'"')
                    if (_rc) local sline ""
                    if (strlen(`"`sline'"') >= 40) local commit = substr(`"`sline'"', 1, 40)
                }
            }
            else {
                * the loose ref is packed; find it in packed-refs
                capture confirm file "`gitdir'/packed-refs"
                if (_rc == 0) {
                    tempname ph
                    capture file open `ph' using "`gitdir'/packed-refs", read text
                    if (_rc == 0) {
                        local peof 0
                        file read `ph' pline
                        local peof = r(eof)
                        while (`peof' == 0 & "`commit'" == "(unknown)") {
                            capture local pl = trim(`"`macval(pline)'"')
                            if (_rc) local pl ""
                            if (strlen(`"`pl'"') > 41) {
                                if (trim(substr(`"`pl'"', 42, .)) == `"`refpath'"') {
                                    local commit = substr(`"`pl'"', 1, 40)
                                }
                            }
                            file read `ph' pline
                            local peof = r(eof)
                        }
                        file close `ph'
                    }
                }
            }
        }
    }
    else if (strlen(`"`headline'"') >= 40) {
        * detached HEAD: the file holds the SHA itself
        local branch "(detached HEAD)"
        local commit = substr(`"`headline'"', 1, 40)
    }

    * ------------------------------------------------------------------
    * Dirty state.  This is the one field that requires invoking git, and
    * -shell-'s return code proves nothing on Windows, so the verdict is
    * judged by the ARTIFACT: the output file exists and is empty exactly
    * when the tree is clean.  Any doubt -- shell refused, git absent, the
    * artifact unreadable -- degrades to "." with the state named, never
    * to a clean-looking guess.
    * ------------------------------------------------------------------
    local dirty .
    local dirtystate "(not determined)"
    if ("`nodirty'" == "") {
        tempfile gsf
        capture shell git status --porcelain > "`gsf'" 2>&1
        capture confirm file "`gsf'"
        if (_rc == 0) {
            tempname sh2
            capture file open `sh2' using "`gsf'", read text
            if (_rc == 0) {
                file read `sh2' sline1
                local seof = r(eof)
                file close `sh2'
                capture local sline1 = trim(`"`macval(sline1)'"')
                if (_rc) local sline1 ""
                if (`seof' & `"`sline1'"' == "") {
                    local dirty 0
                    local dirtystate "no"
                }
                else if (`"`sline1'"' != "") {
                    * git errors ("fatal: ...") also land here; a status line
                    * never starts with the word fatal, so tell them apart
                    if (substr(`"`sline1'"', 1, 6) == "fatal:") {
                        local dirty .
                        local dirtystate "(git not available)"
                    }
                    else {
                        local dirty 1
                        local dirtystate "yes"
                    }
                }
            }
        }
    }

    return local  branch `"`branch'"'
    return local  commit `"`commit'"'
    return scalar inrepo = 1
    return scalar dirty  = `dirty'
    return local  dirtystate `"`dirtystate'"'
end
