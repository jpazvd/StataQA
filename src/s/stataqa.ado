*! version 2.5.0  10aug2026
* stataqa: Stata testing and CI command suite
* Description: Dispatcher only. Routes the first token to the matching stqa_* command
*              and passes the remainder of the command line through verbatim so that
*              quoted absolute paths survive (defect #11). Each subcommand lives in
*              its own .ado file so that it can also be called directly (defect #9).
* Options: subcommand-specific; see the help file of each subcommand
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stataqa
    version 14.0

    if `"`macval(0)'"' == "" {
        di as error "stataqa requires a subcommand"
        di as error "Valid subcommands: review, certify, validate, run, init, report, scanlog, history, families"
        exit 198
    }

    * Split off the subcommand only.  parse(" ,") is required so that
    * -stataqa run, pattern(x)- (no space before the comma) parses; the remainder
    * is handed on with macval() so that neither quotes nor $ / ` characters inside
    * a path are re-evaluated or re-tokenized on the way through.
    gettoken subcommand rest : 0, parse(" ,")
    local subcommand = trim(`"`subcommand'"')

    * ------------------------------------------------------------------
    * The three roles.  review executes and records nothing; certify
    * executes and appends the ledger stanza; validate executes NOTHING and
    * judges the existing record against this tree.  run is review's alias:
    * the safe default for a verb that appears in four repos' documentation
    * and cannot simply vanish.
    *
    * The verb IS the role.  It is appended as role() to the remainder,
    * after the caller's own comma if one exists -- found by a quoted,
    * bound token scan, because strpos would mistake a comma inside
    * pattern("a,b") or a quoted path for the option separator.  A caller
    * who also passes role() gets syntax's repeated-option error, which is
    * the right outcome: the verb already said it.
    * ------------------------------------------------------------------
    if inlist("`subcommand'", "review", "certify", "run") {
        local vrole "review"
        if "`subcommand'" == "certify" local vrole "certify"

        local hascomma 0
        local scan `"`macval(rest)'"'
        local guard 0
        while `"`scan'"' != "" & `guard' < 500 {
            local guard = `guard' + 1
            gettoken tok scan : scan, parse(",") quotes bind
            if `"`tok'"' == "," {
                local hascomma 1
                continue, break
            }
        }
        if `hascomma' {
            stqa_run `macval(rest)' role(`vrole')
        }
        else {
            stqa_run `macval(rest)' , role(`vrole')
        }
    }
    else if "`subcommand'" == "validate" {
        stqa_validate `macval(rest)'
    }
    else if "`subcommand'" == "init" {
        stqa_init `macval(rest)'
    }
    else if "`subcommand'" == "report" {
        stqa_report `macval(rest)'
    }
    else if "`subcommand'" == "scanlog" {
        stqa_scanlog `macval(rest)'
    }
    else if "`subcommand'" == "history" {
        stqa_history `macval(rest)'
    }
    else if "`subcommand'" == "families" {
        stqa_families `macval(rest)'
    }
    else {
        di as error "Unknown subcommand: `subcommand'"
        di as error "Valid subcommands: review, certify, validate, run, init, report, scanlog, history, families"
        exit 198
    }
end
