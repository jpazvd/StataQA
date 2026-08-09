*! qa/test_targeting.do  version 1.0.0  09aug2026
* META family -- every test file must survive a run that targets an id it does
* not contain.
*
* The failure this closes.  A targeted-out block still executes its ordinary
* commands; only the stqa_ commands inside it no-op.  So a file that feeds an
* r() value from one of ours into a loop bound dies r(198) under ANY
* single-test run -- and dies before reaching the id that was asked for, so the
* error names neither the id requested nor the command responsible.
* qa/test_docs.do did exactly that from the day it was written until
* 09aug2026, through four green certifications.
*
* META-11 could not see it.  It asserts that asking for one test runs exactly
* one test, but it targets an id in its own file, so it never exercises the
* case where every block in a file is targeted out.  That is the case this
* covers, for every file at once.
*
* Method: set a target that matches nothing, run each file, require rc 0.  With
* no block matching, nothing is booked and nothing is verified -- which is the
* point.  What is under test is that the FILE still completes.
* Author: Joao Pedro Azevedo (UNICEF)

local home "`c(pwd)'"
local files : dir "qa" files "test*.do"
local files : list sort files

local t_saved "$stqa_target"
local s_saved "$stqa_skip_block"
global stqa_target "NOSUCH-99"

local bad ""
local nran 0
foreach f of local files {
    * never recurse into this file
    if "`f'" == "test_targeting.do" continue
    local nran = `nran' + 1
    global stqa_skip_block ""
    global stqa_block_failed ""
    capture quietly do "qa/`f'"
    local rc = _rc
    * restore unconditionally: a file that died mid-excursion leaves the cwd
    * somewhere else, and every later file resolves its paths from here
    quietly cd "`home'"
    if `rc' != 0 local bad `"`bad' `f'(rc `rc')"'
}

global stqa_target      `"`t_saved'"'
global stqa_skip_block  `"`s_saved'"'
global stqa_block_failed ""

stqa_test META-25 "every test file completes under a target it does not contain"
    stqa_assert `nran' > 0, msg("no test files were exercised; the sweep verified nothing")
    stqa_assert `"`bad'"' == "", msg("file(s) died under a non-matching target:`bad'")
stqa_endtest
