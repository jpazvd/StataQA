*! stataqa_example.do  version 1.0.0  07aug2026
* The worked example accompanying
*   Azevedo, J. P.  stataqa: Local certification and license-aware
*   continuous integration for Stata packages.
*
* Runs out of the box, from any directory, with stataqa installed:
*   . do stataqa_example.do
* No directories need to be created in advance, no paths are edited, no timer
* is set, and nothing here touches the network.  The log shipped alongside
* this file (stataqa_example.log) was produced by exactly this script.
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

* ---- Everything is written under ./stataqa_example/, created here, so the ----
* ---- script runs wherever it is placed and leaves the reader's own files  ----
* ---- alone.  Only relative paths are used, so nothing in the log names    ----
* ---- this machine.  The tree is cleared first, so a second run reproduces ----
* ---- the first rather than reporting leftovers from it.                   ----
capture mkdir "stataqa_example"
cd "stataqa_example"

capture erase "demo_tests/test_demo.do"
capture erase "demo_tests/test_example.do"
capture erase "demo_tests/logs/test_demo_stqa.log"
capture erase "demo_tests/logs/test_example_stqa.log"
capture erase "qa/test_history.txt"
capture erase "demo_help.sthlp"
capture erase "demo_gallery.ado"

* ---------------------------------------------------------------------------
* 1. Scaffold a test tree
* ---------------------------------------------------------------------------
stataqa init demo_tests

* ---------------------------------------------------------------------------
* 2. Write a test file: three blocks, the third exercising the FAILURE path
*    (it captures a deliberately false assertion and asserts the rc, so the
*    suite proves red CAN fire and still certifies green)
* ---------------------------------------------------------------------------
tempname fh
file open `fh' using "demo_tests/test_demo.do", write text replace
file write `fh' `"stqa_test SMOKE-01 "a computed statistic matches its expected value""' _n
file write `fh' `"    sysuse auto, clear"' _n
file write `fh' `"    quietly summarize price"' _n
file write `fh' `"    local mean = r(mean)"' _n
file write `fh' `"    stqa_approx \`mean' 6165.2568, tolerance(0.01)"' _n
file write `fh' `"stqa_endtest"' _n
file write `fh' `""' _n
file write `fh' `"stqa_test DATA-01 "the identifier is unique""' _n
file write `fh' `"    sysuse auto, clear"' _n
file write `fh' `"    stqa_uniqueid make"' _n
file write `fh' `"stqa_endtest"' _n
file write `fh' `""' _n
file write `fh' `"stqa_test EDGE-01 "a false assertion is caught, not absorbed""' _n
file write `fh' `"    sysuse auto, clear"' _n
file write `fh' `"    capture stqa_assert price < 0, msg("prices are not negative; this failure is deliberate")"' _n
file write `fh' `"    local rc = _rc"' _n
file write `fh' `"    global stqa_block_failed"' _n
file write `fh' `"    stqa_assert \`rc' == 9"' _n
file write `fh' `"stqa_endtest"' _n
file close `fh'

* ---------------------------------------------------------------------------
* 3. Certify the suite: the verdict is read out of the per-file log, and a stanza
*    is appended to the certification ledger qa/test_history.txt
* ---------------------------------------------------------------------------
stataqa certify demo_tests

* ---------------------------------------------------------------------------
* 4. Read the record back, the way CI pattern B would
* ---------------------------------------------------------------------------
stataqa history, check

* ---------------------------------------------------------------------------
* 5. Documentation as tests: stqa_examples in both of its modes.
*    A help file's clickable {stata ...} directives are harvested and run;
*    an examples gallery's named programs are harvested with the gallery's
*    own entry point excluded.
* ---------------------------------------------------------------------------
file open `fh' using "demo_help.sthlp", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{title:Examples}" _n
file write `fh' "{phang2}{cmd:.} {stata sysuse auto, clear}{p_end}" _n
file write `fh' "{phang2}{cmd:.} {stata summarize price}{p_end}" _n
file close `fh'
stqa_examples using "demo_help.sthlp"

file open `fh' using "demo_gallery.ado", write text replace
file write `fh' "program demo_gallery" _n
file write `fh' "    args EXAMPLE" _n
file write `fh' "    \`EXAMPLE'" _n
file write `fh' "end" _n
file write `fh' "program example01" _n
file write `fh' `"    display "gallery example one""' _n
file write `fh' "end" _n
file write `fh' "program example02" _n
file write `fh' `"    display "gallery example two""' _n
file write `fh' "end" _n
file close `fh'
stqa_examples using "demo_gallery.ado"

* ---------------------------------------------------------------------------
* 6. The vacuity guard: a false assertion over an empty selection passes
*    vacuously under plain assert semantics; -null- makes it fail
* ---------------------------------------------------------------------------
sysuse auto, clear
capture noisily stqa_assert price < 0 if foreign == 99, null
di as txt "rc = " _rc "  (9: the empty selection was caught, not passed)"
