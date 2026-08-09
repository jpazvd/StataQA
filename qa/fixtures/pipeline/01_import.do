* src/01_import.do - toy example
clear all
* Seeded so the stage is reproducible. Unseeded, this pipeline produced
* different numbers on every run, so nothing downstream could pin a VALUE --
* INT-13 could only assert that the indicator is a proportion, which is true
* of any pipeline that happens to write a 0/1 variable. With the seed, the
* replay master in qa/replay/ can pin what the pipeline actually computes.
set seed 20260809
set obs 100
gen id = _n
gen raw = runiform()
save "qa/fixtures/pipeline/output/tmp_raw.dta", replace
