*! qa/_ci_run.do  version 2.2.0  06aug2026
* Entry point for a self-hosted CI runner.  Not a test file: it opens the log
* the workflow reads the verdict out of, points Stata at the working tree, and
* hands over to the runner.
*
* The underscore prefix keeps it outside stqa_run's discovery pattern, so the
* runner cannot try to execute its own launcher.
* Author: Joao Pedro Azevedo (UNICEF)

version 14.0
clear all
macro drop stqa_*

capture log close _all
log using "qa/_ci_run.log", replace text

* Test the checkout, never an installed copy that happens to be on the machine.
adopath ++ "`c(pwd)'/src/s"
discard

di as txt "stataqa CI run"
di as txt "  date    : `c(current_date)' `c(current_time)'"
di as txt "  Stata   : `c(stata_version)' `c(flavor)' (`c(os)')"
di as txt "  pwd     : `c(pwd)'"
capture which stataqa
di as txt ""

stataqa certify qa

* The workflow reads the verdict from the log rather than from this exit code,
* for the reason documented there.  The code is still set so an interactive run
* behaves sensibly.
local rc = _rc
capture log close _all
exit `rc'
