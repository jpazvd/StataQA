*! qa/test_scanlog.do  version 1.0.0  06aug2026
* DET family -- the log-sentinel verdict reader, against frozen synthetic logs.
*
* This is the load-bearing component: every verdict the framework reports is
* whatever this program says a log contains.  The logs below are written by
* hand rather than captured from a run, so each case is exact and the tests
* are deterministic and offline.
* Author: Joao Pedro Azevedo (UNICEF)

tempfile clean hung failing skipped empty

*---------------------------------------------------------------------------
* A log that mimics a real one: genuine verdict lines PLUS echoed source lines
* that merely contain the tokens.  Stata echoes the suite's own source into
* the log prefixed by "." or a line number, so only line-initial tokens count.
*---------------------------------------------------------------------------
file open fh using "`clean'", write replace
file write fh "PASS: DET-01 first" _n
file write fh "PASS: DET-02 second" _n
file write fh "FAIL: DET-03 third" _n
file write fh ". di as result PASS: this is echoed source, not a verdict" _n
file write fh "  5. di as error FAIL: also echoed source" _n
file write fh "ALL CHECKS PASSED (2 checks)" _n
file close fh

stqa_test DET-01 "line-initial verdict tokens are counted"
    quietly stqa_scanlog using "`clean'"
    local p = r(pass)
    local f = r(fail)
    stqa_assert `p' == 2, msg("expected 2 passes, got `p'")
    stqa_assert `f' == 1, msg("expected 1 failure, got `f'")
stqa_endtest

stqa_test DET-02 "echoed source lines containing the tokens are NOT counted"
    quietly stqa_scanlog using "`clean'"
    local p = r(pass)
    local f = r(fail)
    * the log holds 3 lines containing PASS: and 2 containing FAIL:, but only
    * 2 and 1 respectively begin with the token
    stqa_assert `p' + `f' == 3, msg("echoed source leaked into the counts")
stqa_endtest

stqa_test DET-03 "the completion sentinel is detected"
    quietly stqa_scanlog using "`clean'"
    local d = r(done)
    stqa_assert `d' == 1, msg("sentinel present but not detected")
stqa_endtest

stqa_test DET-04 "failed identifiers are collected"
    quietly stqa_scanlog using "`clean'"
    local ids = trim(`"`r(ids)'"')
    stqa_assert_equal_str "`ids'" "DET-03"
stqa_endtest

*---------------------------------------------------------------------------
* The case the whole design exists for: a run that was killed or hung leaves
* a log full of passes and no sentinel.  It must never read as green.
*---------------------------------------------------------------------------
file open fh2 using "`hung'", write replace
file write fh2 "PASS: X-01 ok" _n
file write fh2 "PASS: X-02 ok" _n
file close fh2

stqa_test DET-05 "a log without the sentinel is NOT complete, despite zero failures"
    quietly stqa_scanlog using "`hung'"
    local d = r(done)
    local f = r(fail)
    stqa_assert `f' == 0, msg("fixture should contain no failures")
    stqa_assert `d' == 0, msg("a hung run was reported as complete")
stqa_endtest

*---------------------------------------------------------------------------
* A missing log is the same situation as a hung run, and must be reported
* rather than raised: an abort here would take down the runner that is trying
* to record the failure.
*---------------------------------------------------------------------------
stqa_test EDGE-01 "a missing log is reported, not raised as an error"
    capture stqa_scanlog using "c:/nonexistent/never/written.log"
    local rc = _rc
    stqa_assert `rc' == 0, msg("missing log aborted with rc `rc'")
stqa_endtest

stqa_test EDGE-02 "an empty log reads as incomplete with no verdicts"
    file open fh3 using "`empty'", write replace
    file close fh3
    quietly stqa_scanlog using "`empty'"
    local p = r(pass)
    local f = r(fail)
    local d = r(done)
    stqa_assert `p' == 0 & `f' == 0 & `d' == 0, msg("empty log did not read as empty")
stqa_endtest

*---------------------------------------------------------------------------
* SKIP is a third verdict: neither pass nor failure.
*---------------------------------------------------------------------------
file open fh4 using "`skipped'", write replace
file write fh4 "PASS: Y-01 ok" _n
file write fh4 "SKIP: Y-02 prerequisite absent" _n
file write fh4 "ALL CHECKS PASSED (1 checks)" _n
file close fh4

stqa_test DET-06 "a skip marker is detected and is not counted as a failure"
    quietly stqa_scanlog using "`skipped'"
    local s = r(skip)
    local f = r(fail)
    stqa_assert `s' == 1, msg("skip marker not detected")
    stqa_assert `f' == 0, msg("a skip was counted as a failure")
stqa_endtest

*---------------------------------------------------------------------------
* Provenance: the format header, and telling "not a stataqa log" apart from
* "a stataqa run that did not finish".
*
* Before 2.5.0 those two were indistinguishable in every returned figure --
* pass, fail, skip and done all read zero for both -- so a caller who mistyped
* a path was told the suite was red. They are different defects with different
* remedies, which is the distinction these checks pin.
*---------------------------------------------------------------------------
tempfile marked unmarked halfrun

file open fh5 using "`marked'", write replace
file write fh5 "STATAQA LOG 9.9.9" _n
file write fh5 "PASS: Z-01 ok" _n
file write fh5 "ALL CHECKS PASSED (1 checks)" _n
file close fh5

* an ordinary Stata log: no verdict tokens, no sentinel, no format header
file open fh6 using "`unmarked'", write replace
file write fh6 "an ordinary log from some other do-file" _n
file write fh6 ". summarize price" _n
file close fh6

* a genuine stataqa run that died before its sentinel: marked, but incomplete
file open fh7 using "`halfrun'", write replace
file write fh7 "STATAQA LOG 9.9.9" _n
file write fh7 "PASS: Z-01 ok" _n
file close fh7

stqa_test DET-19 "the log states which version wrote it, and the scanner reads it back"
    quietly stqa_scanlog using "`marked'"
    local lv `"`r(logversion)'"'
    local mk = r(stataqa)
    stqa_assert `"`lv'"' == "9.9.9", msg("format header not read back; got `lv'")
    stqa_assert `mk' == 1, msg("a log with a format header was not recognised as a stataqa log")
stqa_endtest

stqa_test DET-20 "a log stataqa never wrote is distinguished from a run that did not finish"
    * the unmarked file and the half-run file agree on EVERY count and on the
    * sentinel; r(stataqa) is the only thing that tells them apart, which is
    * the whole reason it exists
    quietly stqa_scanlog using "`unmarked'"
    local u_done = r(done)
    local u_fail = r(fail)
    local u_mark = r(stataqa)

    quietly stqa_scanlog using "`halfrun'"
    local h_done = r(done)
    local h_fail = r(fail)
    local h_mark = r(stataqa)

    stqa_assert `u_done' == `h_done', msg("the fixture is wrong: the two logs must agree on done")
    stqa_assert `u_fail' == `h_fail', msg("the fixture is wrong: the two logs must agree on fail")
    stqa_assert `u_mark' == 0, msg("a log with no stataqa markers reported r(stataqa)=1")
    stqa_assert `h_mark' == 1, msg("an unfinished run with a format header reported r(stataqa)=0")
stqa_endtest

stqa_test DET-21 "a stataqa log with no format header is still recognised by its verdict tokens"
    * logs written before 2.5.0 carry no format header. They must not suddenly
    * read as foreign, or every archived log in every consumer repository would.
    quietly stqa_scanlog using "`clean'"
    local mk = r(stataqa)
    local lv `"`r(logversion)'"'
    stqa_assert `mk' == 1, msg("a pre-2.5.0 log was not recognised as a stataqa log")
    stqa_assert `"`lv'"' == "", msg("a log with no format header reported a version: `lv'")
stqa_endtest

*---------------------------------------------------------------------------
* Failing elegantly on a format this scanner does not claim to read.
*
* Three ways a format header can be unusable -- older than the window, newer
* than it, or not a version at all -- and none of them may abort. The scanner
* reports, the caller judges; a scanner that raised here would destroy the
* evidence needed to record WHY nothing could be trusted, which is the same
* reason a missing log is reported rather than raised.
*---------------------------------------------------------------------------
tempfile vnew vold vbad vquote

foreach _p in "vnew 9.9.9" "vold 1.0.0" "vbad notaversion" {
    gettoken _nm _vv : _p
    file open fhv using "``_nm''", write replace
    file write fhv "STATAQA LOG `_vv'" _n
    file write fhv "PASS: Z-01 ok" _n
    file write fhv "ALL CHECKS PASSED (1 checks)" _n
    file close fhv
}

* a format header carrying a quote: untrusted input reaching a macro, which is
* the accident this package's scanner is written in Mata to avoid
file open fhq using "`vquote'", write replace
file write fhq `"STATAQA LOG 2.5"0"' _n
file write fhq "PASS: Z-01 ok" _n
file write fhq "ALL CHECKS PASSED (1 checks)" _n
file close fhq

stqa_test DET-22 "a log from outside the readable window is reported, not raised"
    capture quietly stqa_scanlog using "`vnew'"
    local rc_new = _rc
    local su_new = r(logsupported)
    local pa_new = r(pass)

    capture quietly stqa_scanlog using "`vold'"
    local rc_old = _rc
    local su_old = r(logsupported)

    stqa_assert `rc_new' == 0, msg("a newer-format log raised rc `rc_new' instead of reporting")
    stqa_assert `rc_old' == 0, msg("an older-format log raised rc `rc_old' instead of reporting")
    stqa_assert `su_new' == 0, msg("a log newer than the window was reported as supported")
    stqa_assert `su_old' == 0, msg("a log older than the window was reported as supported")
    * the counts are still returned: unsupported means "do not trust these",
    * not "there are none"
    stqa_assert `pa_new' == 1, msg("an unsupported log returned no counts at all")
stqa_endtest

stqa_test DET-23 "a malformed format header degrades rather than aborting"
    * this fired as rc 198 before 2.5.0 shipped: the note interpolated the
    * offending string into a quoted macro, so the report meant to flag a
    * bad format header died on one
    capture quietly stqa_scanlog using "`vbad'"
    local rc_bad = _rc
    local su_bad = r(logsupported)
    stqa_assert `rc_bad' == 0, msg("a malformed format header raised rc `rc_bad'")
    stqa_assert `su_bad' == 0, msg("a malformed format header was reported as supported")

    capture quietly stqa_scanlog using "`vquote'"
    local rc_q = _rc
    stqa_assert `rc_q' == 0, msg("a format header carrying a quote raised rc `rc_q'")
stqa_endtest

*---------------------------------------------------------------------------
* Every exit path returns the same r() names.
*
* stqa_scanlog.ado says so in a comment, and until 2.5.0 the comment was false:
* the Mata-failure path posted five of seven results, and adding three more
* made it five of nine. A caller reading r(logsupported) after a Mata failure
* got a missing value indistinguishable from a log that had not been checked.
*
* The failure path is reachable on purpose -- dropping the Mata scanner makes
* the next call return rc 3499 -- so it can be compared against a normal scan
* rather than reasoned about. Comparing NAMES, not values: the values differ
* legitimately between a real scan and a failed one; what must not differ is
* which questions the caller can ask.
*---------------------------------------------------------------------------
stqa_test DET-24 "the Mata-failure path returns the same result names as a normal scan"
    quietly stqa_scanlog using "`clean'"
    local good : r(scalars)
    local goodm : r(macros)
    local good  = trim("`good'")
    local goodm = trim("`goodm'")

    * force the failure path: drop the scanner, then call
    capture mata: mata drop stqa_scanlog_impl()
    capture quietly stqa_scanlog using "`clean'"
    local frc = _rc
    local bad : r(scalars)
    local badm : r(macros)
    local bad  = trim("`bad'")
    local badm = trim("`badm'")

    * put the scanner back before anything else in the suite needs it
    quietly discard
    quietly stqa_scanlog using "`clean'"

    stqa_assert `frc' == 0, msg("the Mata-failure path raised rc `frc' instead of reporting")
    stqa_assert "`bad'" == "`good'", ///
        msg("failure path returns scalars {`bad'}, a normal scan returns {`good'}")
    stqa_assert "`badm'" == "`goodm'", ///
        msg("failure path returns macros {`badm'}, a normal scan returns {`goodm'}")
stqa_endtest
