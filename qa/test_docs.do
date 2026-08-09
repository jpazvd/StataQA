*! qa/test_docs.do  version 2.3.0  08aug2026
* DOC family -- documentation as tests.
*
* The package's own help files are the fixture: they are committed, they contain
* every directive shape the reader must handle, and they cannot go stale without
* this suite noticing.  Extraction is tested against them in -extract- mode, so
* these checks are deterministic and need no network.
* Author: Joao Pedro Azevedo (UNICEF)

*---------------------------------------------------------------------------
* Extraction: the five directive shapes that occur in real help files.
*---------------------------------------------------------------------------
stqa_test DOC-01 "clickable examples are harvested from a help file"
    quietly stqa_examples using "src/s/stataqa.sthlp", extract
    local n = r(n_found)
    stqa_assert `n' > 0, msg("no {stata } directives found in stataqa.sthlp")
stqa_endtest

stqa_test DOC-02 "a compound-quoted directive survives extraction"
    * A synthesized help file carrying a compound-quoted command that wraps an
    * inner quoted macro reference -- the shape the published yaml package's
    * help uses.  Reading it through a macro-expanded string expression would
    * die with r(132) or silently expand r(fn); the Mata reader must return
    * it intact.  The fixture line is assembled in Mata from char() codes so
    * that no macro expansion can fire while WRITING it either.
    local hf "`c(tmpdir)'/stqa_doc02_compound.sthlp"
    capture erase "`hf'"
    mata: fh = fopen(st_local("hf"), "w"); fput(fh, "{smcl}"); fput(fh, "{title:Examples}"); fput(fh, "{phang2}{cmd:.} {stata " + char(96) + char(34) + "display " + char(34) + "x " + char(96) + "r(fn)" + char(39) + char(34) + char(34) + char(39) + "}{p_end}"); fclose(fh)

    capture quietly stqa_examples using "`hf'", extract
    local rc = _rc
    local n  = r(n_found)
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("extraction aborted on a compound-quoted directive (rc `rc')")
    stqa_assert `n' > 0, msg("no directives extracted from the synthesized help file")
stqa_endtest

stqa_test DOC-03 "a missing help file is reported, not silently empty"
    capture quietly stqa_examples using "src/s/no_such_command.sthlp", extract
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 601, msg("expected rc 601 for a missing file, got `rc'")
stqa_endtest

*---------------------------------------------------------------------------
* Gallery extraction: program blocks, with the dispatcher excluded.
*---------------------------------------------------------------------------
stqa_test DOC-04 "an examples gallery yields its named programs, not its entry point"
    * A synthesized gallery in the conventional published shape (the pattern
    * of wbopendata's gallery): an entry point named after the file that
    * dispatches -args EXAMPLE-, guarded by -capture program drop- lines that
    * must not be harvested, plus five example programs in both accepted
    * spellings (program / program define).
    local gf "`c(tmpdir)'/stqa_doc04_gallery.ado"
    quietly {
        tempname fh
        file open `fh' using "`gf'", write text replace
        file write `fh' "capture program drop stqa_doc04_gallery" _n
        file write `fh' "program stqa_doc04_gallery" _n
        file write `fh' "    version 14.0" _n
        file write `fh' "    args EXAMPLE" _n
        file write `fh' "    \`EXAMPLE'" _n
        file write `fh' "end" _n
        forvalues i = 1/3 {
            file write `fh' "capture program drop example0`i'" _n
            file write `fh' "program example0`i'" _n
            file write `fh' `"    display "example 0`i'""' _n
            file write `fh' "end" _n
        }
        forvalues i = 4/5 {
            file write `fh' "capture program drop example0`i'" _n
            file write `fh' "program define example0`i'" _n
            file write `fh' `"    display "example 0`i'""' _n
            file write `fh' "end" _n
        }
    }

    quietly stqa_examples using "`gf'", extract
    local n = r(n_found)
    stqa_assert `n' == 5, msg("expected 5 gallery examples, found `n'")

    * the gallery's own entry point is named after the file and must not be
    * harvested: calling it with no argument does nothing useful
    local found_dispatcher 0
    * A targeted-out block still runs its ordinary commands, but stqa_examples
    * is one of ours and no-ops -- so r(n_found) comes back missing and the
    * loop below becomes -forvalues i = 1/.-, which is r(198) and kills the
    * whole FILE. That is why asking for any single id in this file used to
    * abort it: the failure had nothing to do with the id requested. Guard the
    * bound here; the durable fix is for stqa_examples to guarantee
    * r(n_found)=0 when it no-ops, which is logged against the command.
    if "`n'" == "" | "`n'" == "." local n 0
    forvalues i = 1/`n' {
        if `"`r(cmd`i')'"' == "stqa_doc04_gallery" {
            local found_dispatcher 1
        }
    }
    stqa_assert `found_dispatcher' == 0, msg("the dispatcher was harvested as an example")
stqa_endtest

*---------------------------------------------------------------------------
* Skips are counted, never silently converted into passes.
*---------------------------------------------------------------------------
stqa_test DOC-05 "skipped examples are reported as skipped, not as run"
    quietly stqa_examples using "src/s/stataqa.sthlp", extract skip(".")
    local found = r(n_found)
    local skipd = r(n_skipped)
    local ran   = r(n_run)
    stqa_assert `skipd' == `found', msg("skip(.) should exclude everything: `skipd' of `found'")
    stqa_assert `ran' == 0, msg("`ran' examples ran despite matching skip()")
stqa_endtest

*---------------------------------------------------------------------------
* stqa_cmdline: the single-command counterpart.
*---------------------------------------------------------------------------
stqa_test DOC-06 "an arbitrary command line runs and books rc 0"
    capture stqa_cmdline "sysuse auto, clear"
    local rc = _rc
    stqa_assert `rc' == 0, msg("stqa_cmdline failed on a valid command (rc `rc')")
stqa_endtest

stqa_test DOC-07 "a failing command line is booked, and rc() can expect it"
    capture stqa_cmdline "use no_such_file_xyz.dta"
    local rc_default = _rc
    global stqa_block_failed ""
    stqa_assert `rc_default' == 9, msg("an erroring command should fail the check")

    capture stqa_cmdline "use no_such_file_xyz.dta", rc(601)
    local rc_expected = _rc
    global stqa_block_failed ""
    stqa_assert `rc_expected' == 0, msg("rc(601) should accept the documented failure")
stqa_endtest

stqa_test DOC-08 "a quoted argument survives to the command under test"
    capture stqa_cmdline `"display "hello world""'
    local rc = _rc
    global stqa_block_failed ""
    stqa_assert `rc' == 0, msg("a quoted argument was mangled (rc `rc')")
stqa_endtest

*---------------------------------------------------------------------------
* The shipped examples are documentation with an executable claim attached:
* each ships beside the log it produced. A log recorded under an older build
* silently misdescribes the package -- the documentation drift this suite
* exists to catch, one level up. Found by hand on 09aug2026, when both example
* logs still recorded 2.3.0 after the package had moved to 2.3.1.
*
* Deterministic and cheap: these re-run nothing. They read the shipped logs
* and compare them against the version the package actually is.
*---------------------------------------------------------------------------
capture confirm file "examples/stataqa_tour.log"
local haveex = (_rc == 0)

* The scan runs in Mata, for the same reason stqa_scanlog does. A log is
* arbitrary text: the shipped example log contains a -file write- fixture
* whose payload carries an embedded compound quote, and reading such a line
* into a macro fails with r(132), "too few quotes". Mata strings never pass
* through macro expansion, so the scan cannot be broken by whatever the log
* happens to contain. The first attempt here used -file read- and died on
* exactly that line -- silently, since the read sat inside a -capture-, which
* left the version empty and the check red for the wrong reason.
mata:
    // the version the package actually is, from the dispatcher's *! header
    v = ""
    if (fileexists("src/s/stataqa.ado")) {
        L = cat("src/s/stataqa.ado")
        if (rows(L) > 0) {
            s = strtrim(L[1])
            p = strpos(s, "version ")
            if (p > 0) {
                v = strtrim(substr(s, p + 8, .))
                q = strpos(v, " ")
                if (q > 0) v = substr(v, 1, q - 1)
            }
        }
    }
    st_local("pkgver", v)

    // The version each shipped log says produced it, read from the banner each
    // example prints for itself: "stataqa version : X".
    //
    // It used to be read from the "version  : X" line of a ledger stanza. That
    // worked, but only because the examples happen to display a stanza -- the
    // version reached the log as a SIDE EFFECT of something else being shown,
    // sat 200-700 lines down, and would have vanished silently if an example
    // ever stopped printing its ledger. Each example now states the running
    // version outright, near the top, read from the installed dispatcher's own
    // header, and this check keys on that statement.
    //
    // The line-initial rule is the verdict scanner's: an echoed source line
    // reads `. display "stataqa version : ..."` and starts with a period, so
    // the echo cannot be mistaken for the output it produced.
    files = ("examples/stataqa_tour.log", "examples/stataqa_example.log")
    names = ("tourver", "exver")
    for (k = 1; k <= 2; k++) {
        v = ""
        if (fileexists(files[k])) {
            L = cat(files[k])
            for (i = 1; i <= rows(L); i++) {
                s = strtrim(L[i])
                if (substr(s, 1, 17) == "stataqa version :") {
                    v = strtrim(substr(s, 18, .))
                    q = strpos(v, " ")
                    if (q > 0) v = substr(v, 1, q - 1)
                    break
                }
            }
        }
        st_local(names[k], v)
    }
end

stqa_test DOC-09 "the shipped example logs were produced by this version of the package"
    stqa_skip if !`haveex', msg("examples/ is not present in this checkout")
    stqa_assert `"`pkgver'"' != "", msg("could not read the package version from src/s/stataqa.ado")
    stqa_assert `"`tourver'"' == `"`pkgver'"', msg("stataqa_tour.log records version `tourver' but the package is `pkgver'; regenerate the example logs")
    stqa_assert `"`exver'"' == `"`pkgver'"', msg("stataqa_example.log records version `exver' but the package is `pkgver'; regenerate the example logs")
stqa_endtest

stqa_test DOC-10 "the shipped tour log records a run that finished, and finished green"
    stqa_skip if !`haveex', msg("examples/ is not present in this checkout")
    * a truncated or red log would still LOOK like a shipped artifact; the
    * sentinel and the verdict are what make it evidence
    quietly stqa_scanlog "examples/stataqa_tour.log"
    local sdone = r(done)
    local sfail = r(fail)
    stqa_assert `sdone' == 1, msg("the shipped tour log carries no completion sentinel; the run it records did not finish")
    stqa_assert `sfail' == 0, msg("the shipped tour log records `sfail' failure(s); the example ships a red run")
stqa_endtest

*---------------------------------------------------------------------------
* The short example needs a different check from the tour, and that is the
* whole point of having one.
*
* DOC-10 can demand zero failures of the tour. It cannot of this log, because
* this log SHIPS a failure on purpose: section 6 demonstrates the vacuity
* guard, where an assertion over an empty selection passes vacuously under
* Stata's own -assert- semantics and fails under -null-. Scanning it the way
* DOC-10 scans the tour would report that demonstration as a red example.
*
* So the deliberate failure is pinned rather than dodged: exactly one, and it
* must be the ad-hoc one. Until 09aug2026 this log had no completion or
* verdict check at all -- DOC-09 compared its version stamp and nothing else,
* so a truncated or genuinely red example would have shipped with DOC-09 still
* passing. That is the gap this closes.
*
* If the example gains or loses a deliberate failure, this check fires and the
* count has to be changed on purpose. A pinned number that someone must edit
* knowingly is the point, not an inconvenience.
*---------------------------------------------------------------------------
mata: st_local("exgreen", strofreal(sum(strpos(cat("examples/stataqa_example.log"), "GATE GREEN") :> 0) > 0))

stqa_test DOC-11 "the shipped short example is green where it is graded, and red only where it means to be"
    stqa_skip if !`haveex', msg("examples/ is not present in this checkout")
    quietly stqa_scanlog "examples/stataqa_example.log"
    local edone = r(done)
    local efail = r(fail)
    * scanlog builds the id list with a space separator, so a single id arrives
    * as " ADHOC" -- trim before comparing, or the check fails on whitespace
    local eids = trim(`"`r(ids)'"')
    stqa_assert `edone' == 1, msg("the shipped example log carries no completion sentinel; the run it records did not finish")
    stqa_assert `"`exgreen'"' == "1", msg("the shipped example log records no GATE GREEN; its embedded suite run was not green")
    stqa_assert `efail' == 1, msg("the shipped example log records `efail' failure(s), expected exactly 1 -- the vacuity demonstration in section 6. More means something really failed; fewer means the demonstration stopped demonstrating.")
    stqa_assert `"`eids'"' == "ADHOC", msg("the one failure in the example log is booked against `eids', expected ADHOC -- a named check failed where only the ad-hoc vacuity demonstration should")
stqa_endtest
