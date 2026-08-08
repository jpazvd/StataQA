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
