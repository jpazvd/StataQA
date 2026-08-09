*! version 1.0.0  08aug2026
* stqa_manifest: Bless and verify the data column of the certification record
* Description: One typed manifest, qa/manifest.txt, covering frozen inputs
*              (qa/fixtures/) and blessed replay pairs (qa/replay/).  add
*              blesses a file: .dta entries carry the datasignature (values,
*              platform-independent), everything else the %15.0f checksum plus
*              file length.  verify recomputes and compares; any drift is a
*              FAIL with the token contract, because a fixture that changed
*              since blessing invalidates every test that consumes it.
*              Blessing is a certify-side ceremony: add refuses inside a
*              review-role run.  This is a guardrail, not access control.
* Options: see subcommands
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_manifest, rclass
    version 14.0

    gettoken sub 0 : 0, parse(" ,")
    local sub = trim("`sub'")

    local mf "qa/manifest.txt"

    * ==================================================================
    if "`sub'" == "add" {
        syntax using/ [, TYPE(string)]

        * The blessing ceremony belongs to certify. A review-role run that
        * could re-bless a fixture could silently move the goalposts of the
        * very test it is reviewing. ($stqa_role_run is set by stqa_run for
        * the duration of a run; a test file that issues -clear all- drops
        * it, so this is a guardrail against accident, not against intent --
        * as documented.)
        if "$stqa_role_run" == "review" {
            di as error "stqa_manifest add: blessing is a certify ceremony; a review run cannot re-bless"
            exit 9
        }

        capture confirm file `"`using'"'
        if _rc {
            di as error `"stqa_manifest add: file not found: `using'"'
            exit 601
        }

        if "`type'" == "" {
            local type "fixture"
            if strpos(`"`using'"', "/replay/") | strpos(`"`using'"', "\replay\") local type "replay"
        }
        if !inlist("`type'", "fixture", "replay") {
            di as error "stqa_manifest add: type() must be fixture or replay"
            exit 198
        }

        * ---- compute the entry ---------------------------------------
        local method ""
        local value  ""
        local flen   "."
        local sver   "."
        if lower(substr(`"`using'"', -4, 4)) == ".dta" {
            * datasignature: values, not bytes -- platform- and re-save-
            * independent, which a checksum is not.  The caller's data are
            * preserved around the load.
            preserve
            capture use `"`using'"', clear
            if _rc {
                restore
                di as error `"stqa_manifest add: could not load `using' (rc `=_rc')"'
                exit 9
            }
            quietly datasignature
            local value `"`r(datasignature)'"'
            restore
            local method "sig"
        }
        else {
            capture checksum `"`using'"'
            if _rc {
                di as error `"stqa_manifest add: checksum failed on `using' (rc `=_rc')"'
                exit 9
            }
            * %15.0f: r(checksum) arrives as a float and prints in
            * scientific notation by default, which loses precision and lets
            * two different files compare equal -- measured, and exactly the
            * silent-equality defect this file exists to prevent.
            local value : display %15.0f r(checksum)
            local value = trim("`value'")
            local flen  = r(filelen)
            local method "sum"
        }
        if "`type'" == "replay" local sver = string(c(stata_version))

        * ---- rewrite the manifest with this entry replaced/appended ---
        capture mkdir "qa"
        tempname out
        tempfile newmf
        file open `out' using "`newmf'", write text replace
        file write `out' "* stataqa manifest -- one line per blessed file; see help stqa_manifest" _n
        file write `out' "* <type> <method> <value> <filelen> <stata> <path>" _n

        capture confirm file "`mf'"
        if _rc == 0 {
            tempname in
            file open `in' using "`mf'", read text
            file read `in' line
            while r(eof) == 0 {
                local keep 1
                capture {
                    local lt = trim(`"`macval(line)'"')
                    if substr(`"`macval(lt)'"', 1, 1) == "*" | `"`macval(lt)'"' == "" {
                        * header and blank lines are regenerated, not copied,
                        * or every rewrite would stack another header
                        local keep 0
                    }
                    else {
                        * the path is everything after the five typed fields,
                        * stripped BY LENGTH from the front -- a value-content
                        * search (strpos on word 5) once matched inside a
                        * checksum that happened to contain the digits "17",
                        * kept the stale row, and a fresh blessing coexisted
                        * with its own ghost until the ghost "drifted"
                        local oldpath = trim(`"`macval(lt)'"')
                        forvalues w = 1/5 {
                            local wz : word 1 of `macval(oldpath)'
                            local oldpath = trim(substr(`"`macval(oldpath)'"', strlen(`"`wz'"') + 1, .))
                        }
                        if `"`macval(oldpath)'"' == `"`using'"' local keep 0
                    }
                }
                if `keep' {
                    file write `out' `"`macval(line)'"' _n
                }
                file read `in' line
            }
            file close `in'
        }
        file write `out' `"`type' `method' `value' `flen' `sver' `using'"' _n
        file close `out'
        capture erase "`mf'"
        copy "`newmf'" "`mf'", replace

        di as result `"stqa_manifest: blessed `type' `using' (`method' `value')"'
        return local method "`method'"
        return local value  `"`value'"'
        exit 0
    }

    * ==================================================================
    if "`sub'" == "verify" {
        syntax [using/] [, Quiet]

        capture confirm file "`mf'"
        if _rc {
            local tid `"$stqa_test_id"'
            if `"`tid'"' == "" local tid "stqa_manifest"
            di as error `"FAIL: `tid' no manifest at `mf'; nothing has been blessed"'
            global stqa_block_failed 1
            exit 9
        }

        local nchecked 0
        local nbad     0
        local badlist  ""

        tempname in
        file open `in' using "`mf'", read text
        file read `in' line
        while r(eof) == 0 {
            * The per-entry confirmation is composed inside the capture and
            * displayed outside it. Displaying it in place produced nothing at
            * all -- capture suppresses output before it reaches the screen or
            * a log -- so verify had no observable behaviour on success whether
            * or not -quiet- was given, and r(n) was the only way to tell the
            * sweep had run. That is the outer-capture seam this package
            * documents in stqa_cmdline's help, occurring in its own code.
            local okmsg ""
            capture {
                local lt = trim(`"`macval(line)'"')
                if substr(`"`macval(lt)'"', 1, 1) != "*" & `"`macval(lt)'"' != "" {
                    local etype   : word 1 of `macval(lt)'
                    local emethod : word 2 of `macval(lt)'
                    local evalue  : word 3 of `macval(lt)'
                    local eflen   : word 4 of `macval(lt)'
                    local esver   : word 5 of `macval(lt)'
                    local rest    = `"`macval(lt)'"'
                    foreach z in `"`etype'"' `"`emethod'"' `"`evalue'"' `"`eflen'"' `"`esver'"' {
                        local rest = trim(substr(`"`macval(rest)'"', strlen(`"`z'"') + 1, .))
                    }
                    local epath `"`macval(rest)'"'

                    local want 1
                    if `"`using'"' != "" & `"`epath'"' != `"`using'"' local want 0

                    if `want' {
                        local nchecked = `nchecked' + 1
                        local ok 0
                        capture confirm file `"`epath'"'
                        if _rc == 0 {
                            if "`emethod'" == "sig" {
                                preserve
                                capture use `"`epath'"', clear
                                if _rc == 0 {
                                    quietly datasignature
                                    if `"`r(datasignature)'"' == `"`evalue'"' local ok 1
                                }
                                restore
                            }
                            else {
                                capture checksum `"`epath'"'
                                if _rc == 0 {
                                    local now : display %15.0f r(checksum)
                                    local now = trim("`now'")
                                    if "`now'" == "`evalue'" & "`eflen'" == "`=r(filelen)'" local ok 1
                                }
                            }
                        }
                        if !`ok' {
                            local nbad = `nbad' + 1
                            local badlist `"`badlist' `epath'"'
                        }
                        else if "`quiet'" == "" {
                            local okmsg `"  manifest ok: `etype' `epath'"'
                        }
                    }
                }
            }
            if `"`okmsg'"' != "" di as txt `"`macval(okmsg)'"'
            file read `in' line
        }
        file close `in'

        if `"`using'"' != "" & `nchecked' == 0 {
            local tid `"$stqa_test_id"'
            if `"`tid'"' == "" local tid "stqa_manifest"
            di as error `"FAIL: `tid' `using' is not in the manifest; bless it with stqa_manifest add"'
            global stqa_block_failed 1
            exit 9
        }
        if `nbad' > 0 {
            local tid `"$stqa_test_id"'
            if `"`tid'"' == "" local tid "stqa_manifest"
            di as error `"FAIL: `tid' `nbad' blessed file(s) drifted or missing:`badlist'"'
            di as error `"Expected: every manifest entry to verify"'
            di as error `"Got: drift -- a fixture that changed since blessing invalidates the tests that consume it"'
            global stqa_block_failed 1
            exit 9
        }
        * A sweep that verified nothing and a sweep that verified everything
        * both returned rc 0 and printed nothing. Say what was checked.
        if "`quiet'" == "" {
            di as txt `"  manifest: `nchecked' entr(y/ies) verified"'
        }
        return scalar n = `nchecked'
        exit 0
    }

    di as error "stqa_manifest: subcommand must be add or verify"
    exit 198
end
