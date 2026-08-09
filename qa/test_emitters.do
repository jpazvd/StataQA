*! qa/test_emitters.do  version 1.0.0  06aug2026
* ERR family -- the non-fatal verdict emitters stqa_fail and stqa_pass.
*
* These are the commands that let a capture-then-decide suite be ported without
* being restructured, so their contract is worth testing precisely: a booked
* failure must be visible, must flag the block, must NOT abort, and must not be
* counted twice when stqa_endtest closes the block.
*
* EVERY PROBE CALL BELOW IS -capture-, AND MUST STAY THAT WAY.
*
* These emitters exist to write a line-initial FAIL:/PASS: token, which is
* exactly what the log scanner counts. Run noisily, a probe is therefore
* indistinguishable from a real verdict: measured 09aug2026, on the first
* execution this file ever had, seven deliberate probes were booked as seven
* suite failures (PROBE-A, PROBE-B, PROBE-E, PROBE-F and PROBE-INV x3) and
* turned a green suite red. The file already cleared $stqa_block_failed after
* each probe -- the flag was anticipated; the emitted TEXT was not.
*
* Same defect class as the REGR-24 phantom, and it cannot be fixed by cleverer
* framing here: a nested log cannot be separated from the parent's screen
* stream inside one Stata session, so anything a probe prints reaches the case
* log. Silencing is the only route that leaves the suite's verdict meaningful.
*
* It must be -capture-, not -quietly-. Measured 09aug2026, one run apart:
* -quietly- silenced stqa_pass (which displays as RESULT) and left every
* stqa_fail token standing (it displays as ERROR), so five of the seven
* phantoms survived a fix that looked right. -capture- is the outer-capture
* seam this package documents in stqa_cmdline's help -- normally the hazard,
* used here deliberately, which is also how test_manifest.do silences its own
* expected-failure probes.
*
* What that costs, stated rather than hidden: these checks assert the emitters'
* observable STATE -- rc 0, the block flag, counter ownership, skip-safety, and
* that a loop books every failure rather than stopping at the first -- and not
* the wording of the token. The line-initial format is covered against
* synthetic logs by DET-01/DET-02 in qa/test_scanlog.do. Verifying this
* command's own text in situ would need a separate process, the same
* limitation already recorded for a nested stqa_run.
* Author: Joao Pedro Azevedo (UNICEF)

*---------------------------------------------------------------------------
* stqa_fail must not abort. This is the property that distinguishes it from
* stqa_assert and the reason it exists.
*---------------------------------------------------------------------------
stqa_test ERR-10 "stqa_fail books a failure and returns rc 0"
    local reached 0
    capture stqa_fail, id(PROBE-A) msg("deliberate")
    local rc_after = _rc
    local reached 1
    * clear the flag the inner call set, so this outer block is judged on its
    * own assertions rather than on the probe
    global stqa_block_failed ""
    stqa_assert `rc_after' == 0, msg("stqa_fail returned rc `rc_after', expected 0")
    stqa_assert `reached' == 1, msg("execution did not continue past stqa_fail")
stqa_endtest

stqa_test ERR-11 "stqa_fail sets the block-failed flag"
    capture stqa_fail, id(PROBE-B) msg("deliberate")
    local flagged "$stqa_block_failed"
    global stqa_block_failed ""
    stqa_assert_equal_str "`flagged'" "1"
stqa_endtest

*---------------------------------------------------------------------------
* The [if] qualifier, and the keyword-stripping that syntax [if] forces.
*---------------------------------------------------------------------------
stqa_test ERR-12 "stqa_fail with a false condition books nothing"
    global stqa_block_failed ""
    capture stqa_fail if 1 == 2, id(PROBE-C) msg("must not fire")
    local flagged "$stqa_block_failed"
    global stqa_block_failed ""
    stqa_assert_equal_str "`flagged'" ""
stqa_endtest

stqa_test ERR-13 "stqa_pass with a true condition emits without aborting"
    local reached 0
    capture stqa_pass if 1 == 1, id(PROBE-D) msg("deliberate pass")
    local rc_after = _rc
    local reached 1
    stqa_assert `rc_after' == 0, msg("stqa_pass returned rc `rc_after'")
    stqa_assert `reached' == 1, msg("execution did not continue past stqa_pass")
stqa_endtest

*---------------------------------------------------------------------------
* Counter ownership: inside an open block the emitter must NOT count, because
* stqa_endtest books the block when it closes. Double counting here would
* inflate every ported suite.
*---------------------------------------------------------------------------
stqa_test ERR-14 "an emitter inside a block does not book the count itself"
    local p0 = $stqa_n_pass
    local f0 = $stqa_n_fail
    capture stqa_fail, id(PROBE-E) msg("deliberate")
    capture stqa_fail, id(PROBE-F) msg("deliberate again")
    local p1 = $stqa_n_pass
    local f1 = $stqa_n_fail
    global stqa_block_failed ""
    stqa_assert `f1' == `f0', msg("stqa_fail incremented n_fail inside a block (`f0' -> `f1')")
    stqa_assert `p1' == `p0', msg("pass counter moved unexpectedly")
stqa_endtest

*---------------------------------------------------------------------------
* Skip precedence: a skipped block must not be able to book either verdict.
* A skip that silently became a pass is the defect the framework exists to
* prevent, so this is tested in both directions.
*---------------------------------------------------------------------------
stqa_test ERR-15 "a skipped block cannot book a pass or a failure"
    global stqa_skip_block 1
    global stqa_block_failed ""
    local pA = $stqa_n_pass
    capture stqa_fail, id(PROBE-G) msg("must be suppressed")
    capture stqa_pass, id(PROBE-H) msg("must be suppressed")
    local flagged "$stqa_block_failed"
    local pB = $stqa_n_pass
    global stqa_skip_block ""
    stqa_assert_equal_str "`flagged'" ""
    stqa_assert `pB' == `pA', msg("a suppressed stqa_pass still counted")
stqa_endtest

*---------------------------------------------------------------------------
* The datalib INSTALL shape: an inventory that must report EVERY missing item.
* With stqa_assert this loop would stop at the first failure and report one
* missing file instead of three -- the exact loss the emitter prevents.
*---------------------------------------------------------------------------
stqa_test ERR-16 "an inventory loop reports every failure, not just the first"
    global stqa_block_failed ""
    local booked 0
    foreach f in absent_one absent_two absent_three {
        capture confirm file "c:/nonexistent/`f'.ado"
        if _rc {
            local booked = `booked' + 1
            capture stqa_fail, id(PROBE-INV) msg("`f' is in the manifest but did not install")
        }
    }
    global stqa_block_failed ""
    stqa_assert `booked' == 3, msg("expected 3 booked failures, got `booked'")
stqa_endtest
