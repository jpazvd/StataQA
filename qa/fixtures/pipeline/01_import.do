* src/01_import.do - toy example
clear all
set obs 100
gen id = _n
gen raw = runiform()
save "qa/fixtures/pipeline/output/tmp_raw.dta", replace
