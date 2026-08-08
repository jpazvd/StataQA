*! version 2.2.0  06aug2026
* stqa_examples: Harvest and run the executable examples that ship with a package
* Description: Reads the examples a user can actually run and runs them, booking
*              a verdict for each.  Two sources are understood and reduce to the
*              same thing -- a list of commands:
*                .sthlp  every {stata ...} directive, i.e. every clickable example
*                .ado    every named program in an examples gallery, each of
*                        which is a multi-line example invoked by name
*              Documentation that cannot be executed is documentation that drifts.
* Options: extract, list, skip(), noninteractive, dispatch(), id(), logdir(),
*          soft, noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_examples, rclass
    version 14.0

    if "$stqa_skip_block" == "1" {
        exit 0
    }

    syntax using/ [, ///
        EXTract        ///
        LIST           ///
        SKIP(string)   ///
        NONINTeractive ///
        DISPatch(string) ///
        id(string)     ///
        LOGDir(string) ///
        SOFT           ///
        ALLOWEmpty     ///
        NOIsily        ///
    ]

    capture confirm file `"`using'"'
    if _rc {
        di as error `"stqa_examples: file not found"'
        di as text  `"  file: `using'"'
        exit 601
    }

    * ------------------------------------------------------------------
    * Which kind of source is this?  The extension decides, because the two
    * carry examples in structurally different ways and there is no useful
    * middle case.
    * ------------------------------------------------------------------
    local ext = lower(substr(`"`using'"', -5, 5))
    local isado 0
    if substr(`"`ext'"', -4, 4) == ".ado" local isado 1

    * the stem is both the default dispatcher and the name of the program that
    * must NOT be harvested: a gallery's own entry point is not an example
    local stem = `"`using'"'
    local stem = subinstr(`"`stem'"', "\", "/", .)
    local slash = strrpos(`"`stem'"', "/")
    if `slash' > 0 local stem = substr(`"`stem'"', `slash' + 1, .)
    local dot = strrpos(`"`stem'"', ".")
    if `dot' > 0   local stem = substr(`"`stem'"', 1, `dot' - 1)

    * ------------------------------------------------------------------
    * Extraction runs in Mata, and it has to.  A help file is full of backticks
    * and compound quotes -- {stata `"yaml read using "`r(fn)'""'} is a real
    * directive from a real .sthlp -- and pulling such a line through a
    * macro-expanded string expression closes the quote early and dies with
    * r(132), or silently expands `r(fn)' while merely reading it.  Mata reads
    * the file as data, so nothing in it can be taken for syntax.
    * ------------------------------------------------------------------
    if `isado' {
        mata: stqa_examples_ado()
    }
    else {
        mata: stqa_examples_sthlp()
    }

    local nfound = `s_n'
    return scalar n_found = `nfound'
    return local  source  = cond(`isado', "ado", "sthlp")

    if `nfound' == 0 {
        return scalar n_run     = 0
        return scalar n_skipped = 0
        return scalar n_failed  = 0

        * Harvesting nothing is the failure mode this command exists to catch.
        * A .sthlp whose {stata ...} directives were reworded, or a gallery
        * whose programs were renamed, stops testing anything -- and exiting 0
        * with a text note made that indistinguishable from "every documented
        * example ran". The caller must say allowempty to accept it.
        if "`allowempty'" != "" {
            di as text `"stqa_examples: no examples found in `using' (allowempty)"'
            exit 0
        }
        local tid `"$stqa_test_id"'
        if `"`tid'"' == "" local tid "stqa_examples"
        di as error `"FAIL: `tid' no examples found in `using'"'
        di as error `"Expected: at least one executable example to harvest"'
        di as error `"Got: none -- the directives may have been reworded, or the path is wrong"'
        global stqa_block_failed 1
        exit 9
    }

    * ------------------------------------------------------------------
    * A gallery's programs must exist before they can be called.  Running the
    * file defines them all, which is more reliable than trusting the ado-path
    * to resolve a copy -- and the copy on the ado-path may not be the one
    * under test, which is the whole point of a suite.
    * ------------------------------------------------------------------
    local invoke ""
    if `isado' {
        if `"`dispatch'"' != "" {
            local invoke `"`dispatch' "'
        }
        else if "`extract'" == "" & "`list'" == "" {
            capture quietly run `"`using'"'
            if _rc {
                di as error `"FAIL: stqa_examples could not load `using' (rc `=_rc')"'
                di as error `"Expected: the gallery to define its example programs"'
                di as error `"Got: rc `=_rc' from -run-"'
                global stqa_block_failed 1
                return scalar n_run     = 0
                return scalar n_skipped = 0
                return scalar n_failed  = 1
                if "`soft'" != "" exit 0
                exit 9
            }
        }
    }

    local nrun  0
    local nskip 0
    local nfail 0
    local skipped_list ""
    local failed_list  ""

    forvalues i = 1/`nfound' {
        local cmd `"`invoke'`s_cmd`i''"'
        return local cmd`i' `"`cmd'"'

        * The policy filters below must see the HARVESTED command, not the
        * invocation string. Under dispatch() the invocation is prefixed with
        * the dispatcher name, so a caller's ^-anchored skip() regex could
        * never match and the noninteractive alternation -- also ^-anchored --
        * never fired either. Both filters were silently disabled in exactly
        * the mode where a stray -shell- or -db- does the most damage.
        local rawcmd `"`s_cmd`i''"'

        * ---- structural exclusions: mechanical facts about the text ----
        * An example wrapped across lines in a help file arrives here
        * truncated, and running half a command tests nothing.
        local why ""
        local blank : subinstr local cmd " " "", all
        if `"`blank'"' == "" {
            local why "empty"
        }
        else if !`isado' {
            local nopen  : subinstr local cmd "(" "(", all count(local c_open)
            local nclose : subinstr local cmd ")" ")", all count(local c_close)
            if `c_open' != `c_close' {
                local why "truncated (unbalanced parentheses)"
            }
            if substr(`"`cmd'"', -3, 3) == "///" {
                local why "truncated (line continuation)"
            }
        }

        * ---- policy exclusions: the caller's, because they must be ----
        if `"`why'"' == "" & `"`skip'"' != "" {
            if regexm(`"`rawcmd'"', `"`skip'"') {
                local why "matched skip()"
            }
        }
        if `"`why'"' == "" & "`noninteractive'" != "" {
            * Every member is terminated the same way -- a blank, a comma, or
            * end of string. The old alternation mixed bare prefixes with
            * space-terminated ones, so a bare -net-, -ssc- or -db- with no
            * argument slipped through, while -edit- also matched -editvar-.
            if regexm(`"`rawcmd'"', "^(doedit|edit|browse|view|help|net|ssc|shell|winexec|exit|update|db)([ ,]|$)") {
                local why "interactive or out-of-process"
            }
        }

        if `"`why'"' != "" {
            local nskip = `nskip' + 1
            local skipped_list `"`skipped_list' `i'"'
            if "`list'" != "" | "`noisily'" != "" {
                di as text `"  [skip `i'] `cmd'   -- `why'"'
            }
            continue
        }

        if "`list'" != "" {
            di as text `"  [`i'] `cmd'"'
            continue
        }
        if "`extract'" != "" {
            continue
        }

        * ---- run it ----
        local nrun = `nrun' + 1

        local eid `"`id'"'
        if `"`eid'"' == "" local eid `"$stqa_test_id"'
        if `"`eid'"' == "" local eid "DOC"

        if `"`logdir'"' != "" {
            capture mkdir `"`logdir'"'
            capture log close stqa_ex
            capture log using `"`logdir'/example_`i'.log"', replace text name(stqa_ex)
        }

        capture `noisily' `cmd'
        local erc = _rc

        if `"`logdir'"' != "" {
            capture log close stqa_ex
        }

        if `erc' {
            local nfail = `nfail' + 1
            local failed_list `"`failed_list' `i'"'
            di as error `"FAIL: `eid' example `i' returned rc `erc'"'
            di as error `"Expected: the documented example to run"'
            di as error `"Got: rc `erc' from: `cmd'"'
            global stqa_block_failed 1
        }
    }

    di as text ""
    di as text `"stqa_examples: `nfound' found, `nrun' run, `nskip' skipped, `nfail' failed"'
    di as text `"  source: `using'"'

    return scalar n_run     = `nrun'
    return scalar n_skipped = `nskip'
    return scalar n_failed  = `nfail'
    return local  skipped   `"`skipped_list'"'
    return local  failed    `"`failed_list'"'
    return local  helpfile  `"`using'"'

    if `nfail' == 0 exit 0
    if "`soft'" != "" exit 0
    exit 9
end

version 14.0
mata:

// ---------------------------------------------------------------------------
// .sthlp -- every clickable {stata ...} directive.
//
// Five shapes occur in real help files and all five must survive:
//   {stata cmd}                        unquoted
//   {stata "cmd"}                      plain quoted
//   {stata "cmd":label}                quoted with a display label
//   {stata `"cmd"'}                    compound quoted
//   {stata `"use "`r(fn)'""'}          compound quoted around an inner quote
// The last is why this is not a regex: the command contains the very
// delimiters a regex would key on.
// ---------------------------------------------------------------------------
void stqa_examples_sthlp()
{
    string colvector lines
    string scalar    path, s, payload, cmd
    real scalar      i, n, p, q, depth, j, k, found

    path  = st_local("using")
    found = 0

    if (path == "" | !fileexists(path)) {
        st_local("s_n", "0")
        return
    }

    lines = cat(path)
    n     = rows(lines)

    for (i = 1; i <= n; i++) {
        s = lines[i]

        p = strpos(s, "{stata ")
        while (p > 0) {
            depth = 1
            q     = p + 7
            k     = strlen(s)
            while (q <= k & depth > 0) {
                if (substr(s, q, 1) == "{") depth = depth + 1
                if (substr(s, q, 1) == "}") depth = depth - 1
                if (depth > 0) q = q + 1
            }
            if (depth != 0) break

            payload = strtrim(substr(s, p + 7, q - p - 7))

            if (substr(payload, 1, 2) == char(96) + char(34)) {
                j = strrpos(payload, char(34) + char(39))
                cmd = (j > 2 ? substr(payload, 3, j - 3) : "")
            }
            else if (substr(payload, 1, 1) == char(34)) {
                j = strpos(substr(payload, 2, .), char(34))
                cmd = (j > 0 ? substr(payload, 2, j - 1) : "")
            }
            else {
                j = strpos(payload, ":")
                cmd = (j > 0 ? strtrim(substr(payload, 1, j - 1)) : payload)
            }

            cmd = strtrim(cmd)
            if (cmd != "") {
                found = found + 1
                st_local("s_cmd" + strofreal(found), cmd)
            }

            s = substr(s, q + 1, .)
            p = strpos(s, "{stata ")
        }
    }

    st_local("s_n", strofreal(found))
}

// ---------------------------------------------------------------------------
// .ado gallery -- every named program, each a multi-line example.
//
// Both spellings occur:  program example01  /  program define example05
// The gallery's own entry point (the program named after the file) is not an
// example and is excluded; so is anything defined inside a -capture program
// drop- line, which names a program without defining one.
// ---------------------------------------------------------------------------
void stqa_examples_ado()
{
    string colvector lines
    string scalar    path, stem, s, nm
    real scalar      i, n, found, pos

    path  = st_local("using")
    stem  = st_local("stem")
    found = 0

    if (path == "" | !fileexists(path)) {
        st_local("s_n", "0")
        return
    }

    lines = cat(path)
    n     = rows(lines)

    for (i = 1; i <= n; i++) {
        s = strtrim(lines[i])

        // a definition, not a -capture program drop-
        if (substr(s, 1, 8) != "program ") continue

        nm = strtrim(substr(s, 9, .))
        if (substr(nm, 1, 7) == "define ") nm = strtrim(substr(nm, 8, .))
        if (substr(nm, 1, 5) == "drop ")   continue

        // strip anything after the name (options, comments)
        pos = strpos(nm, " ")
        if (pos > 0) nm = substr(nm, 1, pos - 1)
        pos = strpos(nm, ",")
        if (pos > 0) nm = substr(nm, 1, pos - 1)
        nm = strtrim(nm)

        if (nm == "" | nm == stem) continue

        found = found + 1
        st_local("s_cmd" + strofreal(found), nm)
    }

    st_local("s_n", strofreal(found))
}

end
