*! qa/test_manifest.do  version 1.0.0  08aug2026
* DET + REGR families -- the data column of the record is falsifiable.
*
* stqa_manifest blesses and verifies; stqa_fixture is verified access to a
* frozen input; stqa_replay re-runs a blessed do-file and requires the same
* output.  Every path here executes in a SCRATCH working directory at file
* scope (the qa/test_roles.do pattern), with return codes parked in locals
* and asserted afterwards from the repo cwd -- so a failing excursion cannot
* strand the suite in the sandbox.
* Author: Joao Pedro Azevedo (UNICEF)

local home "`c(pwd)'"
local sand "`c(tmpdir)'/stataqa_manifest"
capture mkdir "`sand'"
capture mkdir "`sand'/qa"
capture mkdir "`sand'/qa/fixtures"
capture mkdir "`sand'/qa/replay"

* ---- materials --------------------------------------------------------
quietly {
    * a .dta fixture with known content
    sysuse auto, clear
    keep in 1/10
    keep make price mpg
    save "`sand'/qa/fixtures/cars.dta", replace

    * a text fixture
    tempname fh
    file open `fh' using "`sand'/qa/fixtures/config.txt", write text replace
    file write `fh' "alpha = 1" _n
    file close `fh'

    * a deterministic replay do-file: fixed values, no paths, no clock
    file open `fh' using "`sand'/qa/replay/demo.do", write text replace
    file write `fh' "quietly {" _n
    file write `fh' "    clear" _n
    file write `fh' "    set obs 5" _n
    file write `fh' "    gen x = _n" _n
    file write `fh' "    summarize x, meanonly" _n
    file write `fh' "}" _n
    file write `fh' `"display "mean of x = " %4.1f r(mean)"' _n
    file write `fh' `"display "REPLAY DEMO COMPLETE""' _n
    file close `fh'

}

* ---- excursion: everything that needs the sandbox cwd -----------------
cd "`sand'"

* fresh state every run: the sandbox persists across suite runs, and a
* stale manifest or blessed log from a previous run is exactly the kind of
* leftover that turns a test of blessing into a test of history
capture erase "qa/manifest.txt"
capture erase "qa/replay/demo.log"
capture erase "qa/replay/leaky.log"

* Blessing belongs to certify, and stqa_manifest/stqa_replay refuse it under
* the review role. This file TESTS blessing, so it takes certify semantics for
* the excursion and puts the caller's role back before returning. Nothing in
* the repository is touched: every ceremony below writes inside the sandbox.
* Without this, the whole file failed under -stataqa run- while passing under
* -stataqa certify- -- a red gate on a clean checkout, which is the false
* record this package exists to prevent, wearing the other colour. The
* guardrail is not waived, it is asserted: see DET-16.
local role_saved "$stqa_role_run"
global stqa_role_run "certify"

* bless the two fixtures and the replay pair
capture noisily stqa_manifest add using "qa/fixtures/cars.dta"
local rc_b1 = _rc
capture noisily stqa_manifest add using "qa/fixtures/config.txt"
local rc_b2 = _rc
capture noisily stqa_replay using "qa/replay/demo.do", update
local rc_b3 = _rc

* full-sweep verify on the freshly blessed state
capture noisily stqa_manifest verify, quiet
local rc_v0 = _rc

* verified fixture access: load and resolve
capture noisily stqa_fixture using "qa/fixtures/cars.dta"
local rc_f1 = _rc
local f1_n  = _N
capture noisily stqa_fixture using "qa/fixtures/config.txt"
local rc_f2 = _rc
local f2_fn `"`r(fn)'"'

* an unlisted file must be a named failure, not a quiet load
capture stqa_fixture using "qa/fixtures/unblessed.txt"
local rc_f3 = _rc
global stqa_block_failed ""

* replay verifies against its blessed log
capture noisily stqa_replay using "qa/replay/demo.do"
local rc_r1 = _rc

* drift in the DO-FILE is caught by the pair's own integrity check
quietly {
    tempname fh
    file open `fh' using "qa/replay/demo.do", write text append
    file write `fh' `"display "one line too many""' _n
    file close `fh'
}
capture stqa_replay using "qa/replay/demo.do"
local rc_r2 = _rc
global stqa_block_failed ""

* re-bless, then drift the OUTPUT (not the file list): edit the do so it
* prints a different value -- same length discipline, new content
capture noisily stqa_replay using "qa/replay/demo.do", update
quietly {
    tempname fh
    file open `fh' using "qa/replay/demo.do", write text replace
    file write `fh' "quietly {" _n
    file write `fh' "    clear" _n
    file write `fh' "    set obs 5" _n
    file write `fh' "    gen x = _n * 2" _n
    file write `fh' "    summarize x, meanonly" _n
    file write `fh' "}" _n
    file write `fh' `"display "mean of x = " %4.1f r(mean)"' _n
    file write `fh' `"display "REPLAY DEMO COMPLETE""' _n
    file close `fh'
}
* the do drifted, so integrity fails first -- which is correct and IS the
* output-drift protection: a changed do cannot claim its old log
capture stqa_replay using "qa/replay/demo.do"
local rc_r3 = _rc
global stqa_block_failed ""

* The determinism contract at blessing time, end to end.  capture NOISILY,
* not bare capture: bare capture suppresses the replayed do's output before
* it reaches the candidate log, so the contract would scan an EMPTY log and
* bless cleanly -- the outer-capture seam.  Running noisily is safe because
* the contract's rejection during an update ceremony is a plain command
* error, deliberately token-free; the line-initial FAIL: register belongs
* to verify-path violations, framed at that call site.  (A unit-level call
* to stqa_replay_contract is not an option: an ado-file's subprograms are
* not reachable from outside the file -- measured, rc 199 even immediately
* after a successful run of the main program.)
quietly {
    tempname fh
    file open `fh' using "qa/replay/leaky.do", write text replace
    file write `fh' `"display "scratch lives at \`c(tmpdir)'""' _n
    file close `fh'
}
capture noisily stqa_replay using "qa/replay/leaky.do", update
local rc_r4 = _rc
global stqa_block_failed ""

* The other side of that contract: it must NOT reject a line that merely looks
* like an absolute path.  A drive letter is one character, so "PASS:/FAIL:"
* contains "S:/", and the obvious regex fires on ordinary prose -- which is how
* the first blessing of this repository's own replay master was refused, over a
* comment.  Rejecting correct logs is not the safe direction it appears to be:
* it teaches users to stop believing the contract.  Blessed here in the sandbox,
* where the manifest is a throwaway.
quietly {
    tempname fh
    file open `fh' using "qa/replay/prose.do", write text replace
    file write `fh' `"display "the verdict tokens are spelled PASS:/FAIL: in the help""' _n
    file close `fh'
}
capture noisily stqa_replay using "qa/replay/prose.do", update
local rc_p1 = _rc
global stqa_block_failed ""

* fixture drift: change the blessed .dta and verify must fail
quietly {
    use "qa/fixtures/cars.dta", clear
    replace price = price + 1 in 1
    save "qa/fixtures/cars.dta", replace
}
capture stqa_manifest verify using "qa/fixtures/cars.dta", quiet
local rc_d1 = _rc
global stqa_block_failed ""

* ---- the guardrail itself ---------------------------------------------
* Refusing is only half of it: a refusal that still wrote would be worse than
* no guardrail, because the manifest would then carry an entry no certify run
* ever blessed. So the ceremony is attempted under review and the file is
* then looked for in the manifest, where it must be absent.
quietly {
    tempname fh
    file open `fh' using "qa/fixtures/guard.txt", write text replace
    file write `fh' "beta = 2" _n
    file close `fh'
}
global stqa_role_run "review"
capture stqa_manifest add using "qa/fixtures/guard.txt"
local rc_g1 = _rc
global stqa_block_failed ""
capture stqa_replay using "qa/replay/demo.do", update
local rc_g2 = _rc
global stqa_block_failed ""
capture stqa_manifest verify using "qa/fixtures/guard.txt", quiet
local rc_g3 = _rc
global stqa_block_failed ""

global stqa_role_run "`role_saved'"

cd "`home'"

* ---- the repository's own record --------------------------------------
* Everything above exercises the mechanism in a throwaway sandbox, which
* proves the commands work and proves nothing about this tree. These two run
* against what ships: qa/manifest.txt pins the four frozen ledger captures
* DET-07..11 parse and the three pipeline stages, and qa/replay/ holds the
* blessed pair for the pipeline's output. Both are checked on every run, so
* drift in the suite's own inputs is a failing check rather than a discovery
* made later by hand.
capture noisily stqa_manifest verify, quiet
local rc_own = _rc
local n_own  = r(n)
capture noisily stqa_replay using "qa/replay/pipeline.do"
local rc_rep = _rc

* verify must have observable behaviour on success. Until 2.3.2 it printed
* nothing whether or not -quiet- was given: the per-entry line was composed
* inside a -capture- that swallowed it before it reached the screen or a log,
* so a caller could not tell a sweep that checked every entry from one that
* checked none, except by reading r(n). The thing under test is output, so it
* is captured through a log and counted.
local vlog "`c(tmpdir)'/stqa_verify_loud.log"
local qlog "`c(tmpdir)'/stqa_verify_quiet.log"
capture erase "`vlog'"
capture erase "`qlog'"

capture log close stqavchk
quietly log using "`vlog'", replace text name(stqavchk)
capture noisily stqa_manifest verify
capture log close stqavchk

capture log close stqavchk
quietly log using "`qlog'", replace text name(stqavchk)
capture noisily stqa_manifest verify, quiet
capture log close stqavchk

local n_loud  = 0
local n_quiet = 0
capture {
    mata: st_local("n_loud",  strofreal(sum(strpos(cat(st_local("vlog")), "manifest ok:") :> 0)))
    mata: st_local("n_quiet", strofreal(sum(strpos(cat(st_local("qlog")), "manifest ok:") :> 0)))
}
capture erase "`vlog'"
capture erase "`qlog'"

* ---- assertions, from the repo cwd ------------------------------------
stqa_test DET-12 "blessing writes typed entries and the sweep verifies clean"
    stqa_assert `rc_b1' == 0, msg("blessing the .dta fixture failed (rc `rc_b1')")
    stqa_assert `rc_b2' == 0, msg("blessing the text fixture failed (rc `rc_b2')")
    stqa_assert `rc_b3' == 0, msg("blessing the replay pair failed (rc `rc_b3')")
    stqa_assert `rc_v0' == 0, msg("the full-sweep verify failed on a freshly blessed state (rc `rc_v0')")
stqa_endtest

stqa_test DET-13 "a verified .dta fixture loads; a text fixture resolves"
    stqa_assert `rc_f1' == 0, msg("verified load failed (rc `rc_f1')")
    stqa_assert `f1_n' == 10, msg("the loaded fixture has `f1_n' obs, expected 10")
    stqa_assert `rc_f2' == 0, msg("verified resolve failed (rc `rc_f2')")
    stqa_assert `"`f2_fn'"' == "qa/fixtures/config.txt", msg("resolve returned `f2_fn'")
stqa_endtest

stqa_test DET-14 "an unlisted fixture is a named failure, not a quiet load"
    stqa_assert `rc_f3' == 9, msg("stqa_fixture on an unblessed file returned rc `rc_f3', expected 9")
stqa_endtest

stqa_test DET-15 "a drifted fixture fails verification"
    stqa_assert `rc_d1' == 9, msg("a one-cell edit to a blessed .dta verified anyway (rc `rc_d1'); datasignature drift was not caught")
stqa_endtest

stqa_test DET-16 "blessing is refused under the review role, and writes nothing"
    stqa_assert `rc_g1' == 9, msg("stqa_manifest add blessed under the review role (rc `rc_g1')")
    stqa_assert `rc_g2' == 9, msg("stqa_replay update re-blessed under the review role (rc `rc_g2')")
    stqa_assert `rc_g3' == 9, msg("a file refused blessing under review was recorded anyway (rc `rc_g3')")
stqa_endtest

stqa_test REGR-21 "a blessed replay pair verifies clean"
    stqa_assert `rc_r1' == 0, msg("replay of an unchanged pair failed (rc `rc_r1')")
stqa_endtest

stqa_test REGR-22 "a changed do-file cannot claim its old blessed log"
    stqa_assert `rc_r2' == 9, msg("an edited replay do verified against the old blessing (rc `rc_r2')")
stqa_endtest

stqa_test REGR-23 "changed output is caught after re-editing under a fresh blessing"
    stqa_assert `rc_r3' == 9, msg("output drift went unnoticed (rc `rc_r3')")
stqa_endtest

stqa_test REGR-24 "the determinism contract rejects a log that names the tmpdir"
    stqa_assert `rc_r4' == 9, msg("a log carrying a tmpdir path passed the determinism contract (rc `rc_r4')")
stqa_endtest

stqa_test REGR-26 "the determinism contract accepts prose that looks like a drive path"
    stqa_assert `rc_p1' == 0, msg("a log whose text merely resembles an absolute path was refused (rc `rc_p1')")
stqa_endtest

stqa_test DET-17 "the repository's own blessed inputs still verify"
    stqa_assert `rc_own' == 0, msg("the repository's manifest did not verify clean (rc `rc_own')")
    * The count is pinned deliberately. A sweep that quietly checked fewer
    * entries than were blessed would report the same clean rc as one that
    * checked them all -- the false green this package exists to close. If you
    * bless something new, change this number in the same commit.
    stqa_assert `n_own' == 9, msg("the sweep checked `n_own' entries, expected 9 (7 frozen inputs + the replay pair's do and log)")
stqa_endtest

stqa_test DET-18 "a clean verify sweep says what it checked, and quiet still says nothing"
    stqa_assert `n_loud' == 9, msg("verify confirmed `n_loud' entries aloud, expected 9; a sweep with no observable behaviour cannot be distinguished from one that checked nothing")
    stqa_assert `n_quiet' == 0, msg("quiet printed `n_quiet' per-entry line(s); quiet must stay quiet")
stqa_endtest

stqa_test REGR-25 "the fixture pipeline still produces the numbers it produced"
    stqa_assert `rc_rep' == 0, msg("the blessed replay master did not reproduce (rc `rc_rep')")
stqa_endtest

stqa_test META-23 "the excursions restored the working directory"
    stqa_assert `"`c(pwd)'"' == `"`home'"', msg("the sandbox excursion failed to restore the cwd")
stqa_endtest
