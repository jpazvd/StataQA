*! qa/test_smoke.do  version 1.0.0  06aug2026
* SMOKE family -- does the package load and answer at all?
*
* Every command must autoload by filename from the adopath.  This is the check
* that would have caught the seven self-recursive compat shims the rename left
* behind: a program that calls itself loads fine and then never returns.
* Author: Joao Pedro Azevedo (UNICEF)

stqa_test SMOKE-01 "the dispatcher and its subcommand programs autoload"
    foreach c in stataqa stqa_run stqa_init stqa_report {
        capture which `c'
        stqa_assert _rc == 0, msg("`c' does not autoload")
    }
stqa_endtest

stqa_test SMOKE-02 "the harness core autoloads"
    foreach c in stqa_test stqa_endtest stqa_skip stqa_assert stqa_target {
        capture which `c'
        stqa_assert _rc == 0, msg("`c' does not autoload")
    }
stqa_endtest

stqa_test SMOKE-03 "the certification mechanics autoload"
    foreach c in stqa_scanlog stqa_history stqa_gitinfo stqa_validate        ///
                 stqa_manifest stqa_fixture stqa_replay {
        capture which `c'
        stqa_assert _rc == 0, msg("`c' does not autoload")
    }
stqa_endtest

stqa_test SMOKE-04 "the assertion library autoloads"
    foreach c in stqa_approx stqa_approx_all stqa_assert_equal_num           ///
                 stqa_assert_equal_str stqa_inrange stqa_rcof stqa_rc_zero   ///
                 stqa_dta_equal stqa_hasvar stqa_vartype                     ///
                 stqa_nomissing stqa_nobs_min stqa_shape stqa_unique         ///
                 stqa_uniqueid stqa_iso3 stqa_file_exists stqa_dir_exists    ///
                 stqa_svyset {
        capture which `c'
        stqa_assert _rc == 0, msg("`c' does not autoload")
    }
stqa_endtest

* SMOKE-05 (check modules) retired 07aug2026 with the strip-to-core cut; the
* id is never reused.  See qa/README.md.

stqa_test SMOKE-06 "an unknown subcommand is rejected, not silently ignored"
    capture stataqa no_such_subcommand
    stqa_assert _rc != 0, msg("stataqa accepted an unknown subcommand")
stqa_endtest

stqa_test SMOKE-09 "a cut command is gone, not lingering on the adopath"
    foreach c in stqa_check stqa_check_pii stqa_scan stqa_lint stqa_repro    ///
                 stqa_install_deps stqa_varexists {
        capture which `c'
        stqa_assert _rc != 0, msg("`c' was cut but still resolves on the adopath")
    }
stqa_endtest
