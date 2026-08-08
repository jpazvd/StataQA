*! tests/test_pipeline.do  version 2.1.0  06aug2026
* INT family -- the toy three-stage pipeline under src/ runs and produces its
* output dataset.  Paths are relative to the repository root, which is the
* directory stataqa run is invoked from.
*
* The stages are executed BEFORE the first block opens.  Each of them begins
* with -clear all-, which drops every global in the session, the harness's own
* block state ($stqa_test_id, $stqa_test_name) included; running them inside a
* block would therefore close a block that no longer exists.  Local macros are
* not touched by -clear all-, so the return codes are parked in locals and
* asserted afterwards.
*
* This file used to call assert_rc_zero, assert_file_exists and assert_inrange
* from tests/assert_utils.ado, which could not autoload; the package's own
* assertions replace them.
*
* INT-12/INT-13 asserted "output/indicators.dta" until 07aug2026 -- a path from
* before the fixtures moved under qa/.  The stages had been updated and the
* assertions had not, so INT-12 failed on a pipeline that had in fact written
* its output, and INT-13 never ran at all.
* Author: Joao Pedro Azevedo (UNICEF)

capture mkdir "qa/fixtures/pipeline/output"

capture noisily do "qa/fixtures/pipeline/01_import.do"
local rc_import = _rc
capture noisily do "qa/fixtures/pipeline/02_clean.do"
local rc_clean = _rc
capture noisily do "qa/fixtures/pipeline/03_construct.do"
local rc_construct = _rc

stqa_test INT-11 "every pipeline stage returns cleanly"
    stqa_assert `rc_import' == 0, msg("pipeline stage 01_import returned rc `rc_import'")
    stqa_assert `rc_clean' == 0, msg("pipeline stage 02_clean returned rc `rc_clean'")
    stqa_assert `rc_construct' == 0, msg("pipeline stage 03_construct returned rc `rc_construct'")
stqa_endtest

stqa_test INT-12 "the pipeline writes its output dataset"
    stqa_file_exists "qa/fixtures/pipeline/output/indicators.dta"
stqa_endtest

stqa_test INT-13 "the constructed indicator is a proportion"
    use "qa/fixtures/pipeline/output/indicators.dta", clear
    quietly summarize indicator_value, meanonly
    local m = r(mean)
    stqa_inrange `m' 0 1
stqa_endtest
