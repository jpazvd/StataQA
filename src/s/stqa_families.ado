*! version 2.1.0  06aug2026
* stqa_families: The test-family vocabulary
* Description: The package's machine-readable statement of the test-family
*              taxonomy that gives a test id its FAMILY-NN form. Lists the core
*              families, describes one family, parses an id into family and
*              number, and registers a package-specific family for the session.
*              Other commands validate against this command rather than carrying
*              a hardcoded family list of their own.
* Options: codes validate() add()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_families, rclass
    version 14.0
    syntax [anything(name=fam)] [, CODES VALidate(string) ADD(string)]

    * ------------------------------------------------------------------
    * A family code is one token.  Extra tokens are a user error, not a
    * family whose name happens to contain a blank.
    * ------------------------------------------------------------------
    if `"`fam'"' != "" {
        gettoken fam ftail : fam
        local ftail : subinstr local ftail " " "", all
        if `"`ftail'"' != "" {
            di as error "stqa_families: specify exactly one family code"
            exit 198
        }
    }

    * ------------------------------------------------------------------
    * Exactly one mode per call.  The modes disagree about what the return
    * values mean -- r(known) answers a different question for a family
    * query than it does for an id validation -- so combining them would
    * produce an r() set nobody could read.
    * ------------------------------------------------------------------
    local nmode 0
    if `"`fam'"'      != "" local nmode = `nmode' + 1
    if "`codes'"      != "" local nmode = `nmode' + 1
    if `"`validate'"' != "" local nmode = `nmode' + 1
    if `"`add'"'      != "" local nmode = `nmode' + 1
    if `nmode' > 1 {
        di as error "stqa_families: give a family, or codes, or validate(), or add() - one at a time"
        exit 198
    }

    *===================================================================
    * THE TABLE
    *===================================================================
    * This is the single source of truth for the core vocabulary.  Every
    * path below -- the listing, the codes list, the one-family lookup and
    * the id validator -- reads this local and nothing else, so the table
    * displayed to a human and the table validated against by a machine
    * cannot drift apart.  Adding a core family means editing exactly one
    * line here.
    *
    * Encoding: CODE|meaning; repeated.  The semicolon terminates every
    * entry (it does not merely separate them), which is what lets the
    * session-registered families in $stqa_extra_families be concatenated
    * onto the end and parsed by the same loop.  Neither ";" nor "|" may
    * appear inside a meaning; add() enforces that for registered families.
    *===================================================================
    local FAM ""
    local FAM `"`FAM'ENV|Environment and setup: dependencies present, version stamps, adopath, install integrity;"'
    local FAM `"`FAM'SMOKE|Smoke tests: the package loads and its principal command runs at all;"'
    local FAM `"`FAM'DET|Deterministic / offline: frozen inputs, pinned values, no network;"'
    local FAM `"`FAM'REGR|Regression baselines: current output still matches a stored baseline;"'
    local FAM `"`FAM'ERR|Error conditions: invalid input is rejected with the right return code;"'
    local FAM `"`FAM'EDGE|Edge cases: N=1, empty results, special characters, boundary values;"'
    local FAM `"`FAM'EXT|Extreme inputs: large or stress-scale queries and datasets;"'
    local FAM `"`FAM'PERF|Performance: timing or resource assertions against a stated threshold;"'
    local FAM `"`FAM'DATA|Data structure: variable types, value ranges, duplicates, identifiers;"'
    local FAM `"`FAM'TRANS|Transformations: reshape, rename, derived variables, wide/long;"'
    local FAM `"`FAM'META|Metadata operations: labels, notes, enrichment, codelist health;"'
    local FAM `"`FAM'DISC|Discovery: search, listing, catalog queries;"'
    local FAM `"`FAM'SYNC|Metadata synchronization: regenerating metadata from an authority;"'
    local FAM `"`FAM'INT|Integration: interaction with a sibling package or external service;"'
    local FAM `"`FAM'DOC|Documentation as tests: help-file examples execute;"'
    local FAM `"`FAM'XPLAT|Cross-platform: outputs agree across languages or implementations;"'

    * ------------------------------------------------------------------
    * THE ID FORMAT, likewise stated once.  add() and validate() both apply
    * these three rules; neither one restates them.
    *     FAMILY-NN   FAMILY: `famin' to `famax' characters from A-Z 0-9
    *                 NN    : at least two digits, zero padded
    * `autore' is the auto-generated scratch form T001, T002, ... which is
    * legal but unstable, and is reported as such rather than as garbage.
    * ------------------------------------------------------------------
    local famre  "^[A-Z0-9][A-Z0-9]*$"
    local numre  "^[0-9][0-9]+$"
    local autore "^T[0-9][0-9][0-9][0-9]*$"
    local famin  2
    local famax  8

    *===================================================================
    * add(): register a package-specific family for this session
    *===================================================================
    if `"`add'"' != "" {
        * add(CODE "meaning").  gettoken strips the outer quotes of a
        * quoted token and leaves the remainder with its leading blank, so
        * an unquoted multi-word meaning is taken whole (as in stqa_test).
        gettoken acode ameaning : add
        gettoken atok atail : ameaning
        local atailb : subinstr local atail " " "", all
        if `"`atailb'"' == "" {
            local ameaning `"`atok'"'
        }
        mata: st_local("ameaning", strtrim(st_local("ameaning")))

        if `"`acode'"' == "" | `"`ameaning'"' == "" {
            di as error `"stqa_families: add() takes a code and a meaning, as in add(WASH "JMP ladder checks")"'
            exit 198
        }

        local lc = length(`"`acode'"')
        if !regexm(`"`acode'"', "`famre'") | `lc' < `famin' | `lc' > `famax' {
            di as error `"stqa_families: "`acode'" cannot be a family code"'
            di as error `"    a code is `famin' to `famax' characters from A-Z 0-9, so that FAMILY-NN ids built from it are well formed"'
            exit 198
        }

        * ";" and "|" are the table's own delimiters: a meaning carrying one
        * would corrupt every later read of the roster.
        local mchk : subinstr local ameaning ";" ";", all count(local nsemi)
        local mchk : subinstr local ameaning "|" "|", all count(local nbar)
        if `nsemi' > 0 | `nbar' > 0 {
            di as error `"stqa_families: a family meaning may not contain ";" or "|""'
            exit 198
        }

        local hay `";`FAM'"'
        if strpos(`"`hay'"', `";`acode'|"') > 0 {
            di as txt `"stqa_families: `acode' is a core family; nothing registered"'
        }
        else {
            * Re-registration replaces.  A suite that declares its families
            * at the top of every test file is run more than once per
            * session, and the roster must not grow a duplicate each time.
            local ex `"$stqa_extra_families"'
            local hay `";`ex'"'
            local p = strpos(`"`hay'"', `";`acode'|"')
            local verb "registered"
            if `p' > 0 {
                local tail = substr(`"`hay'"', `p' + 1, .)
                local e = strpos(`"`tail'"', ";")
                local before = substr(`"`ex'"', 1, `p' - 1)
                local after  = substr(`"`tail'"', `e' + 1, .)
                local ex `"`before'`after'"'
                local verb "re-registered"
            }
            global stqa_extra_families `"`ex'`acode'|`ameaning';"'
            di as txt `"stqa_families: `verb' `acode' for this session"'
        }
    }

    *===================================================================
    * PARSE the effective roster: core table first, session extras after.
    *===================================================================
    * ncore is the number of ";" in the core table, so the boundary between
    * core and session-registered families is derived from the table too.
    local junk : subinstr local FAM ";" ";", all count(local ncore)

    local nf 0
    local rest `"`FAM'$stqa_extra_families"'
    while `"`rest'"' != "" {
        local p = strpos(`"`rest'"', ";")
        if `p' == 0 {
            * an unterminated tail cannot be an entry; stop rather than loop
            continue, break
        }
        local entry = substr(`"`rest'"', 1, `p' - 1)
        local rest  = substr(`"`rest'"', `p' + 1, .)
        local q = strpos(`"`entry'"', "|")
        if `q' == 0 {
            continue
        }
        local nf = `nf' + 1
        local code`nf' = substr(`"`entry'"', 1, `q' - 1)
        local mean`nf' = substr(`"`entry'"', `q' + 1, .)

        * The display line is built once, here, and every display path below
        * shows it.  The padding is {space #} rather than a %-9s format
        * because SMCL paragraph mode collapses runs of blanks, which
        * silently destroys the CODE column; {p 0 11 2} is what wraps a long
        * meaning back under the meaning column instead of under the code.
        local pad = 9 - length(`"`code`nf''"')
        if `pad' < 1 local pad 1
        local line`nf' `"{p 0 11 2}{result:`code`nf''}{space `pad'}`mean`nf''{p_end}"'
    }

    local corelist ""
    local extralist ""
    forvalues i = 1/`nf' {
        if `i' <= `ncore' {
            local corelist  `"`corelist' `code`i''"'
        }
        else {
            local extralist `"`extralist' `code`i''"'
        }
    }
    local corelist  = trim(`"`corelist'"')
    local extralist = trim(`"`extralist'"')
    local alllist   = trim(`"`corelist' `extralist'"')

    *===================================================================
    * DISPATCH
    *===================================================================

    * ---- , codes : the roster as one space-separated line --------------
    if "`codes'" != "" {
        di as result `"`alllist'"'
    }

    * ---- , validate(ID) : parse one test id ---------------------------
    else if `"`validate'"' != "" {
        gettoken id itail : validate
        local itailb : subinstr local itail " " "", all

        local wf     0
        local kn     0
        local isauto 0
        local numok  0
        local vfam ""
        local vnum ""

        * An id is a single token.  Two tokens is not a badly spelled id,
        * it is not an id.
        local multi = (`"`itailb'"' != "")
        if `multi' == 0 {
            local d = strpos(`"`id'"', "-")
            if `d' > 0 {
                local vfam = substr(`"`id'"', 1, `d' - 1)
                local vnum = substr(`"`id'"', `d' + 1, .)
                local lf = length(`"`vfam'"')
                if regexm(`"`vnum'"', "`numre'") local numok 1
                if regexm(`"`vfam'"', "`famre'") & `lf' >= `famin' & `lf' <= `famax' & `numok' {
                    local wf 1
                }
            }
            else if regexm(`"`id'"', "`autore'") {
                local isauto 1
            }
        }

        * Membership is asked of the family part whenever there is one, so
        * that DET-1 reports a known family with a malformed number rather
        * than a flat "no".  The test is exact: family codes are upper case.
        if `"`vfam'"' != "" {
            forvalues i = 1/`nf' {
                if `"`code`i''"' == `"`vfam'"' local kn 1
            }
        }

        if `multi' {
            di as error `"stqa_families: "`validate'" is not a test id - an id is a single token"'
        }
        else if `wf' == 0 & `isauto' == 0 {
            di as error `"stqa_families: "`id'" is not a well-formed test id"'
            di as error `"    expected FAMILY-NN, as in DET-01: FAMILY `famin'-`famax' characters from A-Z 0-9, NN at least two digits"'
            if `d' > 0 & `"`id'"' != upper(`"`id'"') {
                di as error `"    family codes are upper case: DET-01, not det-01"'
            }
        }
        else if `isauto' {
            di as txt `"stqa_families: `id' is an auto-generated id"'
            di as txt `"    auto ids are legal for scratch tests, but they renumber when a test is"'
            di as txt `"    inserted; give the test a stable FAMILY-NN id before it reaches a ledger"'
        }

        return local id     `"`id'"'
        return local family `"`vfam'"'
        if `numok' return scalar number = real(`"`vnum'"')
        return scalar auto       = `isauto'
        return scalar known      = `kn'
        return scalar wellformed = `wf'
    }

    * ---- FAMILY : describe one family ---------------------------------
    else if `"`fam'"' != "" {
        * Describing is a query, not a certification, so it is forgiving
        * about case and answers with the canonical upper-case code.
        * validate() is the strict path.
        local want = upper(`"`fam'"')
        local kn 0
        local hit 0
        forvalues i = 1/`nf' {
            if `hit' == 0 & `"`code`i''"' == `"`want'"' {
                local hit = `i'
                local kn 1
            }
        }

        if `kn' {
            local src = cond(`hit' <= `ncore', "core", "session")
            di as txt `"`line`hit''"'
            if "`src'" == "session" {
                di as txt "    registered for this session by stqa_families, add()"
            }
            return local meaning `"`mean`hit''"'
            return local source  "`src'"
            return local family  `"`code`hit''"'
        }
        else {
            di as error `"stqa_families: "`fam'" is not a known test family"'
            if strpos(`"`fam'"', "-") > 0 {
                di as error `"    that looks like a test id; to parse one use: stqa_families, validate(`fam')"'
            }
            di as txt `"    known: `alllist'"'
            di as txt `"    a package may declare its own: stqa_families, add(CODE "meaning")"'
            return local meaning ""
            return local source  ""
            return local family  `"`fam'"'
        }
        return scalar known = `kn'
    }

    * ---- no argument : the whole table --------------------------------
    else if `"`add'"' == "" {
        di as txt ""
        di as txt "Test families"
        di as txt "{hline 72}"
        di as txt %-9s "CODE" "MEANING"
        di as txt "{hline 72}"
        forvalues i = 1/`ncore' {
            di as txt `"`line`i''"'
        }
        if `nf' > `ncore' {
            di as txt "{hline 72}"
            di as txt "Registered for this session"
            local next = `ncore' + 1
            forvalues i = `next'/`nf' {
                di as txt `"`line`i''"'
            }
        }
        di as txt "{hline 72}"
        di as txt "A test id is FAMILY-NN, as in DET-01.  See {help stqa_families}."
    }

    * ------------------------------------------------------------------
    * The roster is returned by every path, so a caller can validate
    * against it whatever else it asked for.
    * ------------------------------------------------------------------
    return local extra    `"`extralist'"'
    return local core     `"`corelist'"'
    return local families `"`alllist'"'
end
