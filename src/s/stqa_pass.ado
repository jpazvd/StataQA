*! version 2.4.0  06aug2026
* stqa_pass: Book a passing check explicitly, conditionally
* Description: Emits the PASS: verdict token for a check that was decided by the
*              caller rather than by an assertion.  The counterpart to
*              stqa_fail; together with stqa_skip they are the three verdict
*              emitters, so a suite written in the capture-then-decide idiom can
*              be ported without restructuring it into assertion blocks.
* Options: id(), msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_pass
    version 14.0
    syntax [if] [, id(string) msg(string)]

    * a skipped or targeted-out block must not book a pass either: a skip that
    * silently became a pass is the defect this framework exists to prevent
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * -syntax [if]- returns the qualifier WITH its leading "if" keyword; strip
    * it before evaluating. An omitted qualifier means "pass unconditionally".
    local cond `"`if'"'
    gettoken kw rest : cond
    if "`kw'" == "if" {
        local cond `"`rest'"'
    }
    local condblank : subinstr local cond " " "", all
    if `"`condblank'"' == "" {
        local cond 1
    }

    if `cond' {
        local tid `"`id'"'
        if `"`tid'"' == "" local tid `"$stqa_test_id"'
        if `"`tid'"' == "" local tid "ADHOC"

        local reason `"`msg'"'
        if `"`reason'"' == "" local reason `"$stqa_test_name"'
        if `"`reason'"' == "" local reason "check passed"

        di as result `"PASS: `tid' `reason'"'

        * --------------------------------------------------------------
        * Counter ownership, mirroring stqa_fail.  Inside an open block
        * stqa_endtest books the pass when the block closes, so counting here
        * would double it; the emitted token is the record.  Outside a block
        * the emitter counts itself.
        * --------------------------------------------------------------
        if `"$stqa_test_id"' == "" {
            local npass `"$stqa_n_pass"'
            if `"`npass'"' == "" local npass 0
            global stqa_n_pass = `npass' + 1

            local ntot `"$stqa_n_total"'
            if `"`ntot'"' == "" local ntot 0
            global stqa_n_total = `ntot' + 1
        }
    }
end
