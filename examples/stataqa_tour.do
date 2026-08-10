*! stataqa_tour.do  version 1.0.0  08aug2026
* A sequential tour of stataqa: every user-facing command, in the order a
* project meets them, accompanying
*   Azevedo, J. P.  stataqa: Local certification of Stata packages and
*   license-aware patterns for continuous integration.
*
* Runs out of the box, from any directory, with stataqa installed:
*   . do stataqa_tour.do
* Nothing needs to be created in advance and no path needs editing. The script
* makes a stataqa_tour/ subdirectory of wherever it is run, works entirely
* inside it, and clears it first so a second run reproduces the first. Every
* path is relative, so nothing in the log names this machine. No timer is set
* and nothing here touches the network.
*
* The tour is itself a test: if any command in it were to stop working, the
* certify step at part 7 would go red and the log would say which check failed.
* Author: Joao Pedro Azevedo (UNICEF)

version 14.0
clear all

* ---- Which stataqa produced this log? ------------------------------------
* Stated here, at the top, and read from the running package rather than typed.
* The version does appear further down inside a ledger stanza, but only as a
* side effect of that stanza being printed: a reader should not have to hunt
* for it, and a check should not rest on a display that exists for some other
* reason.
*
* Read from the dispatcher's own *! header rather than shown with -which-,
* because -which- prints the install path and nothing in this log may name a
* machine. Read in Mata, because a macro cannot safely hold arbitrary file text.
*
* Both steps are guarded, because this banner is what the log says about its
* own provenance. Unguarded, a missing package aborts on Stata's own r(601),
* naming a file the reader never asked for; and an unreadable header prints an
* empty version, shipping a log that states nothing while looking like it
* states something.
capture quietly findfile stataqa.ado
if _rc {
    * The command is printed whole, exactly as README gives it, so it can be
    * copied. The URL goes through a local only so that the echoed source line
    * stays inside the log's width; spelled inline it wraps across two lines.
    local stqa_url "https://raw.githubusercontent.com/jpazvd/StataQA/main/src"
    display as error "stataqa is not installed, or is not on the adopath."
    display as error "This example demonstrates stataqa. Install it with"
    display as error `"    net install stataqa, from("`stqa_url'") replace"'
    exit 601
}
local stqa_ado `"`r(fn)'"'
mata:
    v = ""
    L = cat(st_local("stqa_ado"))
    if (rows(L) > 0) {
        s = strtrim(L[1])
        p = strpos(s, "version ")
        if (p > 0) {
            v = strtrim(substr(s, p + 8, .))
            q = strpos(v, " ")
            if (q > 0) v = substr(v, 1, q - 1)
        }
    }
    st_local("stqaver", v)
end
if "`stqaver'" == "" {
    display as error "no version header could be read from the installed stataqa.ado."
    display as error "This log could not state which stataqa produced it, so it is not written."
    exit 9
}
display "stataqa version : `stqaver'"

* clear all does NOT drop global macros, and block state is carried in
* globals. A standalone script must therefore reset them itself, or an
* earlier run that died inside a skipped block leaves $stqa_skip_block set
* and every assertion below becomes a silent no-op -- the exact false green
* this framework exists to prevent, arriving through its own front door.
global stqa_skip_block   ""
global stqa_block_failed ""
global stqa_role_run     ""
global stqa_test_id      ""

capture mkdir "stataqa_tour"
cd "stataqa_tour"

* a true first run every time
capture erase "qa/test_suite.do"
capture erase "qa/test_example.do"
capture erase "qa/logs/test_suite_stqa.log"
capture erase "qa/logs/test_example_stqa.log"
capture erase "qa/test_history.txt"
capture erase "qa/manifest.txt"
capture erase "qa/fixtures/panel.dta"
capture erase "qa/fixtures/reference.dta"
capture erase "qa/fixtures/config.txt"
capture erase "qa/replay/demo.do"
capture erase "qa/replay/demo.log"
capture erase "demo_help.sthlp"
capture erase "demo_gallery.ado"

* =====================================================================
* 1. The failure-mode vocabulary
*    A suite is classified by the class of failure each test rules out.
* =====================================================================
stataqa families

* =====================================================================
* 2. Scaffold a test tree
* =====================================================================
stataqa init qa
capture mkdir "qa/fixtures"
capture mkdir "qa/replay"

* init leaves a sample test to edit. A real project replaces it; the tour
* does too, and for a reason worth knowing: under a targeted run every file
* is executed, and a file containing no matching block books no verdict at
* all, which the runner counts as incomplete rather than as a pass.
capture erase "qa/test_example.do"

* =====================================================================
* 3. Build the frozen inputs, then bless them into the manifest.
*    Blessing is a certify-side ceremony: it records the version of the
*    file the suite is entitled to expect from now on.
* =====================================================================
quietly {
    clear
    set obs 12
    gen str3 iso3 = ""
    replace iso3 = "BRA" in 1/3
    replace iso3 = "KEN" in 4/6
    replace iso3 = "IND" in 7/9
    replace iso3 = "ZAF" in 10/12
    gen int    year    = 2019 + mod(_n - 1, 3)
    gen double value   = 0.5 + mod(_n, 4) / 10
    gen long   cluster = ceil(_n / 3)
    gen byte   region  = mod(_n, 2) + 1
    gen double wt      = 1
    label variable value "Indicator value"
    * the design travels with the data: svyset settings survive save/use, so
    * the suite asserts the design the fixture carries rather than declaring
    * one of its own
    svyset cluster [pweight=wt], strata(region)
    save "qa/fixtures/panel.dta", replace
    save "qa/fixtures/reference.dta", replace

    tempname fh
    file open `fh' using "qa/fixtures/config.txt", write text replace
    file write `fh' "indicator: literacy" _n
    file close `fh'
}

* quietly, because -file open ..., replace- on a not-yet-existing temporary
* file makes Stata print a "file not found" notice naming the temp directory,
* which would put this machine's paths in a log meant to be portable
quietly stqa_manifest add using "qa/fixtures/panel.dta"
quietly stqa_manifest add using "qa/fixtures/reference.dta"
quietly stqa_manifest add using "qa/fixtures/config.txt"
di as text "the manifest now reads:"
type "qa/manifest.txt"
stqa_manifest verify

* =====================================================================
* 4. Bless a golden-master replay pair: a do-file and the output it
*    produced, both shipped, so a later run can be diffed against it.
* =====================================================================
quietly {
    tempname fh
    file open `fh' using "qa/replay/demo.do", write text replace
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
stqa_replay using "qa/replay/demo.do", update

* =====================================================================
* 5. Write the suite. Every assertion the package ships appears here,
*    each inside a test block, because the block is what books the
*    verdict: stqa_endtest emits the PASS: token and an assertion that
*    holds prints nothing at all.
* =====================================================================
quietly {
    tempname fh
    file open `fh' using "qa/test_suite.do", write text replace

    file write `fh' "* generated by stataqa_tour.do" _n
    file write `fh' "*" _n
    file write `fh' "* Note the -capture- on the raw Stata lines that need loaded data." _n
    file write `fh' "* When a block is targeted out, its stqa_ assertions become no-ops but" _n
    file write `fh' "* its ordinary Stata commands still execute, so any setup that assumes" _n
    file write `fh' "* the fixture is in memory must be safe to run when it is not." _n _n

    * ---- verified fixture access, structure, domain, design ----------
    file write `fh' `"stqa_test DATA-01 "the blessed panel has the shape and domain it claims""' _n
    file write `fh' `"    stqa_fixture using "qa/fixtures/panel.dta""' _n
    file write `fh' `"    stqa_shape, nobs(12) vars(6)"' _n
    file write `fh' `"    stqa_hasvar iso3 year value"' _n
    file write `fh' `"    stqa_vartype value, type(double)"' _n
    file write `fh' `"    stqa_nomissing iso3 year value"' _n
    file write `fh' `"    stqa_nobs_min 10"' _n
    file write `fh' `"    stqa_iso3 iso3"' _n
    file write `fh' `"    stqa_unique iso3, count(4)"' _n
    file write `fh' `"    stqa_uniqueid iso3 year"' _n
    file write `fh' `"    stqa_svyset, psu(cluster) strata(region) weight(wt)"' _n
    file write `fh' `"    capture local lbl : variable label value"' _n
    file write `fh' `"    stqa_assert_equal_str "\`lbl'" "Indicator value""' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- numeric assertions ------------------------------------------
    file write `fh' `"stqa_test DET-01 "the pinned statistics still hold""' _n
    file write `fh' `"    stqa_fixture using "qa/fixtures/panel.dta""' _n
    file write `fh' `"    capture quietly summarize value"' _n
    file write `fh' `"    local mean = r(mean)"' _n
    file write `fh' `"    local n    = r(N)"' _n
    file write `fh' `"    stqa_assert_equal_num \`n' 12"' _n
    file write `fh' `"    stqa_approx \`mean' 0.65, tolerance(0.01)"' _n
    file write `fh' `"    stqa_inrange \`mean' 0 1"' _n
    file write `fh' `"    stqa_assert \`n' > 0, msg("the fixture came back empty")"' _n
    file write `fh' `"    capture quietly gen double diff = value - value"' _n
    file write `fh' `"    stqa_approx_all diff, target(0) tolerance(1e-9)"' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- whole-dataset comparison ------------------------------------
    file write `fh' `"stqa_test REGR-01 "the panel still equals its blessed reference""' _n
    file write `fh' `"    stqa_fixture using "qa/fixtures/panel.dta""' _n
    file write `fh' `"    stqa_dta_equal using "qa/fixtures/reference.dta""' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- golden-master replay ----------------------------------------
    file write `fh' `"stqa_test REGR-02 "the blessed do-file still prints what it printed""' _n
    file write `fh' `"    stqa_replay using "qa/replay/demo.do""' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- return codes: zero, and a specific nonzero -------------------
    file write `fh' `"stqa_test ERR-01 "a good call returns zero, a bad one returns 601""' _n
    file write `fh' `"    capture confirm file "qa/fixtures/config.txt""' _n
    file write `fh' `"    stqa_rc_zero"' _n
    file write `fh' `"    stqa_rcof "confirm file no_such_file.dta", rc(601)"' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- filesystem ---------------------------------------------------
    file write `fh' `"stqa_test INT-01 "the inputs and the output directory are where they should be""' _n
    file write `fh' `"    stqa_file_exists "qa/fixtures/panel.dta""' _n
    file write `fh' `"    stqa_dir_exists "output", create"' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- a text fixture resolved, not loaded --------------------------
    file write `fh' `"stqa_test DATA-02 "a text fixture is verified and its path handed back""' _n
    file write `fh' `"    stqa_fixture using "qa/fixtures/config.txt", resolve"' _n
    file write `fh' `"    stqa_assert_equal_str "\`r(fn)'" "qa/fixtures/config.txt""' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- documentation as tests ---------------------------------------
    file write `fh' `"stqa_test DOC-01 "the help file's own examples still run""' _n
    file write `fh' `"    stqa_examples using "demo_help.sthlp""' _n
    file write `fh' "stqa_endtest" _n _n

    file write `fh' `"stqa_test DOC-02 "the examples gallery still runs""' _n
    file write `fh' `"    stqa_examples using "demo_gallery.ado""' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- an arbitrary command line booked ------------------------------
    file write `fh' `"stqa_test DOC-03 "an external command line is booked from its return code""' _n
    file write `fh' `"    stqa_cmdline "sysuse auto, clear""' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- the third verdict: a skip with a recorded reason ---------------
    file write `fh' `"stqa_test INT-02 "a live-service check skips when the service is absent""' _n
    file write `fh' `"    capture confirm file "no_credentials_here.txt""' _n
    file write `fh' `"    stqa_skip if _rc, msg("no credentials in this environment")"' _n
    file write `fh' `"    stqa_assert 1 == 1"' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- the failure path, proven to fire ------------------------------
    * capture, then assert the return code: the suite stays green while
    * demonstrating that red CAN fire. Without this a reader cannot tell a
    * check that passes from a check that cannot fail.
    file write `fh' `"stqa_test EDGE-01 "a false assertion is caught, not absorbed""' _n
    file write `fh' `"    sysuse auto, clear"' _n
    file write `fh' `"    capture stqa_assert price < 0, msg("deliberate: prices are not negative")"' _n
    file write `fh' `"    local rc = _rc"' _n
    file write `fh' `"    global stqa_block_failed"' _n
    file write `fh' `"    stqa_assert \`rc' == 9, msg("the false assertion did not fail")"' _n
    file write `fh' "stqa_endtest" _n _n

    * ---- the vacuity guard ----------------------------------------------
    file write `fh' `"stqa_test EDGE-02 "an empty selection fails under null instead of passing vacuously""' _n
    file write `fh' `"    sysuse auto, clear"' _n
    file write `fh' `"    capture stqa_assert price < 0 if foreign == 99, null"' _n
    file write `fh' `"    local rc = _rc"' _n
    file write `fh' `"    global stqa_block_failed"' _n
    file write `fh' `"    stqa_assert \`rc' == 9, msg("the vacuous selection passed")"' _n
    file write `fh' "stqa_endtest" _n

    file close `fh'
}

* the two documentation sources the DOC blocks harvest
quietly {
    tempname fh
    file open `fh' using "demo_help.sthlp", write text replace
    file write `fh' "{smcl}" _n
    file write `fh' "{title:Examples}" _n
    file write `fh' "{phang2}{cmd:.} {stata sysuse auto, clear}{p_end}" _n
    file write `fh' "{phang2}{cmd:.} {stata summarize price}{p_end}" _n
    file close `fh'

    * the capture-program-drop guard is the conventional gallery idiom, and
    * it is load-bearing here: the suite is run twice below, once to review
    * and once to certify, in one Stata session
    file open `fh' using "demo_gallery.ado", write text replace
    file write `fh' "capture program drop demo_gallery" _n
    file write `fh' "program demo_gallery" _n
    file write `fh' "    args EXAMPLE" _n
    file write `fh' "    \`EXAMPLE'" _n
    file write `fh' "end" _n
    file write `fh' "capture program drop example01" _n
    file write `fh' "program example01" _n
    file write `fh' `"    display "gallery example one""' _n
    file write `fh' "end" _n
    file write `fh' "capture program drop example02" _n
    file write `fh' "program example02" _n
    file write `fh' `"    display "gallery example two""' _n
    file write `fh' "end" _n
    file close `fh'
}

* =====================================================================
* 6. Review: execute and record NOTHING. This is the default role and
*    the one that is safe to point at a repository you do not own.
* =====================================================================
stataqa review qa, logdir("qa/logs")

* =====================================================================
* 7. Certify: execute and append one stanza to the append-only ledger,
*    pinning branch, commit and dirty state of what actually ran.
* =====================================================================
stataqa certify qa

* =====================================================================
* 8. Read the record back -- the three commands a release gate uses,
*    and the two that summarize a run for a human.
* =====================================================================
stataqa scanlog "qa/logs/test_suite_stqa.log"
stataqa history using "qa/test_history.txt", check
stataqa report

* validate judges the record without running anything: a stanza exists, it is
* green with its sentinel, its own arithmetic reconciles, and no certified
* file has changed since it was written. The fourth check needs git, so here
* -- in a scratch directory that is not a repository -- it reports that the
* question cannot be answered rather than answering it in the affirmative.
* (nofresh would suppress that check deliberately; it is not needed to cope
* with the absence of a repository.)
stataqa validate using "qa/test_history.txt"

* =====================================================================
* 9. Targeting: the catalog, one test by name, and the interactive form.
*    A targeted run is a development aid and is never recorded.
* =====================================================================
stataqa review qa, list
stataqa review qa, test(DET-01) logdir("qa/logs")

stqa_target DATA-01
stqa_target
stqa_target, clear

* =====================================================================
* 10. The blessing ceremonies refuse under the review role. This is the
*     guardrail that stops a reviewer moving the goalposts of the very
*     test being reviewed.
* =====================================================================
* the sweep returns the number of entries it checked in r(n); it prints
* nothing on success, so report the count
stqa_manifest verify
di as text "manifest sweep: " r(n) " blessed file(s) verified"

* =====================================================================
* 11. Drift is caught, not absorbed: change a blessed fixture and the
*     verification that consumes it fails by name.
* =====================================================================
quietly {
    use "qa/fixtures/panel.dta", clear
    replace value = value + 1 in 1
    save "qa/fixtures/panel.dta", replace
}
capture stqa_manifest verify using "qa/fixtures/panel.dta", quiet
di as text "drifted fixture -> rc = " _rc "  (9: the change was caught)"
global stqa_block_failed ""

* =====================================================================
* 12. Reporting a whole inventory. stqa_assert stops the block at the
*     first failure, which is right for a precondition and wrong for an
*     inventory: a check confirming forty files should name every missing
*     one, not the first and then nothing. The two emitters book a
*     verdict and return control instead, so a loop can report each row.
*
*     Every row below is good, so stqa_fail books nothing -- a log that
*     must stay green cannot demonstrate the multi-failure case, which is
*     ERR-16 in the package's own suite. What is shown here is the idiom:
*     the emitters are guarded by an -if- evaluated as a scalar, so the
*     loop decides per row.
*
*     Used outside a test block, as here, each emitter counts itself.
*     Inside an open block stqa_endtest does the counting -- so a
*     stqa_pass there would put a second PASS: in the log for one block
*     and the summary's arithmetic would stop reconciling.
* =====================================================================
*     The affirmative is conditioned on what the loop found, not on some
*     neighbouring fact. Keyed on anything else -- _N > 0, say -- a run with a
*     missing column would emit a FAIL: for that column and a PASS: for the
*     same inventory, and the log would assert both.
sysuse auto, clear
local missing 0
foreach v in price mpg weight {
    capture confirm variable `v'
    if _rc local ++missing
    stqa_fail if _rc, id(INVENTORY) msg("`v' is missing from the inventory")
}
stqa_pass if `missing' == 0, id(INVENTORY) ///
    msg("all three columns present over `=_N' rows")

di _n as result "STATAQA TOUR COMPLETE"
