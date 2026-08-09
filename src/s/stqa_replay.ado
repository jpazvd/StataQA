*! version 1.0.0  08aug2026
* stqa_replay: Re-run a blessed do-file and require the same output
* Description: The output half of the chain of custody: the pair
*              qa/replay/<name>.do + <name>.log is a golden master.  verify
*              (the default) re-runs the do-file under a pinned environment
*              and DIFFS the normalized candidate log against the blessed
*              one, failing on the first differing line -- both sides are
*              shipped, so a diff gives the same guarantee as a hash plus a
*              diagnostic a hash cannot.  The determinism contract is
*              enforced, not assumed: a candidate log carrying a tmpdir or
*              absolute path is rejected as an invalid fixture.  A pair
*              blessed under a different Stata version SKIPs with the reason
*              rather than false-redding on display drift.  update re-blesses
*              -- a certify ceremony, refused inside a review-role run.
* Options: log(), update, msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_replay, rclass
    version 14.0

    if "$stqa_skip_block" == "1" {
        exit 0
    }

    syntax using/ [, LOG(string) UPDATE msg(string)]

    local tid `"$stqa_test_id"'
    if `"`tid'"' == "" local tid "stqa_replay"

    if `"`log'"' == "" {
        * "demo.do" -> "demo.log": drop the trailing "do", keep the dot
        local stem = substr(`"`using'"', 1, strlen(`"`using'"') - 2)
        local log `"`stem'log"'
    }

    capture confirm file `"`using'"'
    if _rc {
        di as error `"FAIL: `tid' replay do-file not found: `using'"'
        global stqa_block_failed 1
        exit 9
    }

    * ---- update: the blessing ceremony -----------------------------------
    if "`update'" != "" {
        if "$stqa_role_run" == "review" {
            di as error "stqa_replay update: re-blessing a golden master is a certify ceremony; a review run cannot do it"
            exit 9
        }
        capture noisily stqa_replay_exec `"`using'"' `"`log'"'
        if _rc {
            exit _rc
        }
        capture noisily stqa_replay_contract `"`log'"' "`tid'"
        if _rc {
            exit _rc
        }
        quietly stqa_manifest add using `"`using'"', type(replay)
        quietly stqa_manifest add using `"`log'"',   type(replay)
        di as result `"stqa_replay: blessed `using' + `log' under Stata `c(stata_version)'"'
        exit 0
    }

    * ---- verify ----------------------------------------------------------
    capture confirm file `"`log'"'
    if _rc {
        di as error `"FAIL: `tid' blessed log not found: `log' -- bless the pair with stqa_replay, update"'
        global stqa_block_failed 1
        exit 9
    }

    * the pair's own integrity first: a tampered master proves nothing
    capture noisily stqa_manifest verify using `"`using'"', quiet
    if _rc {
        exit 9
    }
    capture noisily stqa_manifest verify using `"`log'"', quiet
    if _rc {
        exit 9
    }

    * version gate: display formats drift across Stata versions, and a
    * blessed log is only comparable under the version that blessed it --
    * the failure that broke adotest's own committed fixtures.
    local bver "."
    tempname mh
    capture file open `mh' using "qa/manifest.txt", read text
    if _rc == 0 {
        file read `mh' mline
        while r(eof) == 0 {
            capture {
                local lt = trim(`"`macval(mline)'"')
                if substr(`"`macval(lt)'"', 1, 1) != "*" & `"`macval(lt)'"' != "" {
                    local p5 : word 5 of `macval(lt)'
                    local w1 : word 1 of `macval(lt)'
                    local w2 : word 2 of `macval(lt)'
                    local w3 : word 3 of `macval(lt)'
                    local w4 : word 4 of `macval(lt)'
                    local rest = `"`macval(lt)'"'
                    foreach z in `"`w1'"' `"`w2'"' `"`w3'"' `"`w4'"' `"`p5'"' {
                        local rest = trim(substr(`"`macval(rest)'"', strlen(`"`z'"') + 1, .))
                    }
                    if `"`macval(rest)'"' == `"`log'"' local bver "`p5'"
                }
            }
            file read `mh' mline
        }
        file close `mh'
    }
    if "`bver'" != "." & "`bver'" != "`=string(c(stata_version))'" {
        stqa_skip, msg("blessed under Stata `bver', running Stata `=string(c(stata_version))'; re-bless to compare")
        exit 0
    }

    * ---- re-run into a candidate log -------------------------------------
    tempfile cand
    capture noisily stqa_replay_exec `"`using'"' `"`cand'"'
    if _rc {
        di as error `"FAIL: `tid' the replayed do-file errored (rc `=_rc'): `using'"'
        global stqa_block_failed 1
        exit 9
    }
    capture noisily stqa_replay_contract `"`cand'"' "`tid'"
    if _rc {
        di as error `"FAIL: `tid' the replay output violates the determinism contract"'
        global stqa_block_failed 1
        exit 9
    }

    * ---- normalized line diff, first difference named --------------------
    local diffline 0
    local gotline ""
    local wantline ""
    mata: stqa_replay_diff(`"`log'"', `"`cand'"')
    if `diffline' > 0 {
        di as error `"FAIL: `tid' replay output differs from the blessed log at line `diffline'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `macval(wantline)'"'
        di as error `"Got:      `macval(gotline)'"'
        global stqa_block_failed 1
        exit 9
    }
    return local fn  `"`using'"'
    return local log `"`log'"'
end

* ----------------------------------------------------------------------
* Run the do-file with output captured to `2', under a pinned linesize so
* wrap points cannot differ between blessing and verification.  The log is
* headerless (quietly log using) so no timestamp enters the comparison.
* The caller's linesize is restored unconditionally.
* ----------------------------------------------------------------------
program define stqa_replay_exec
    version 14.0
    args dofile logfile
    local ls0 = c(linesize)
    set linesize 80
    capture log close stqa_replay
    quietly log using `"`logfile'"', replace text name(stqa_replay)
    capture noisily do `"`dofile'"'
    local rc = _rc
    capture log close stqa_replay
    set linesize `ls0'
    exit `rc'
end

* ----------------------------------------------------------------------
* The determinism contract, enforced: a log that names the tmpdir or any
* drive-absolute path will never reproduce on another machine, so it is an
* invalid fixture NOW, at the moment that is cheap to fix.  The message is
* deliberately token-free: during an update ceremony this is a command
* error, not a check verdict, and a line-initial FAIL: here would be
* counted by the log scanner.  The verify path, where a violation IS a
* check verdict, frames its own FAIL: token at the call site.
* ----------------------------------------------------------------------
program define stqa_replay_contract
    version 14.0
    args logfile tid
    local viol 0
    mata: stqa_replay_scan(`"`logfile'"', `"`c(tmpdir)'"')
    if `viol' > 0 {
        di as error `"stqa_replay: `logfile' violates the determinism contract at line `viol'"'
        di as error "a log that names the tmpdir or an absolute path cannot reproduce on another machine"
        exit 9
    }
end

version 14.0
mata:
void stqa_replay_scan(string scalar f, string scalar tmp)
{
    real scalar   i, n
    string scalar s, tmp2
    string vector L

    L = cat(f)
    n = length(L)
    // the tmpdir arrives from the ado (c(tmpdir)); check both separator
    // spellings, since Stata prints either depending on who built the path
    tmp  = subinstr(tmp, "/", "\", .)
    tmp2 = subinstr(tmp, "\", "/", .)

    for (i = 1; i <= n; i++) {
        s = L[i]
        if (tmp != "" & (strpos(s, tmp) | strpos(s, tmp2))) {
            st_local("viol", strofreal(i))
            return
        }
        // drive-absolute path: X:\ or X:/
        if (stqa_replay_drivepath(s)) {
            st_local("viol", strofreal(i))
            return
        }
    }
    st_local("viol", "0")
}

real scalar stqa_replay_drivepath(string scalar s)
{
    // Does the line contain a Windows drive-absolute path?
    //
    // The obvious test, regexm(s, "[A-Za-z]:[/\]"), also matches ordinary
    // prose that joins two words with a slash -- "PASS:/FAIL:" contains "S:/"
    // -- and a log is arbitrary text. Measured 09aug2026: the first blessing
    // of this repository's own qa/replay/pipeline.do was refused because a
    // COMMENT in it named the two verdict tokens that way. The refusal was
    // conservative rather than false-green, but a contract that rejects
    // correct logs teaches its users to stop believing it.
    //
    // A drive letter is exactly one character, so whatever precedes it cannot
    // be a word character. That single extra condition removes the prose case
    // and keeps every real path, including quoted ones and paths at the start
    // of a line.
    real scalar   i, n
    string scalar c, prev, pre2

    n = strlen(s)
    for (i = 2; i <= n - 1; i++) {
        if (substr(s, i, 1) != ":") continue
        c = substr(s, i + 1, 1)
        if (c != "/" & c != "\") continue
        prev = substr(s, i - 1, 1)
        if (!regexm(prev, "^[A-Za-z]$")) continue
        if (i >= 3) {
            pre2 = substr(s, i - 2, 1)
            if (regexm(pre2, "^[A-Za-z0-9_]$")) continue
        }
        return(1)
    }
    return(0)
}

string scalar stqa_replay_norm(string scalar s)
{
    // strip CR and trailing blanks; the comparison is about content
    s = subinstr(s, char(13), "", .)
    while (strlen(s) > 0 & substr(s, -1, 1) == " ") {
        s = substr(s, 1, strlen(s) - 1)
    }
    return(s)
}

void stqa_replay_diff(string scalar blessed, string scalar cand)
{
    real scalar   i, nb, nc, n
    string vector B, C
    string scalar b, c

    B = cat(blessed)
    C = cat(cand)
    nb = length(B)
    nc = length(C)

    // drop trailing empty lines on both sides
    while (nb > 0 & stqa_replay_norm(B[nb]) == "") nb--
    while (nc > 0 & stqa_replay_norm(C[nc]) == "") nc--

    n = max((nb, nc))
    for (i = 1; i <= n; i++) {
        b = (i <= nb ? stqa_replay_norm(B[i]) : "<end of blessed log>")
        c = (i <= nc ? stqa_replay_norm(C[i]) : "<end of replay output>")
        if (b != c) {
            st_local("diffline", strofreal(i))
            st_local("wantline", b)
            st_local("gotline",  c)
            return
        }
    }
    st_local("diffline", "0")
}
end
