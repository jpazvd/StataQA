* src/02_clean.do - toy example
use "qa/fixtures/pipeline/output/tmp_raw.dta", clear
keep id raw
rename raw value
save "qa/fixtures/pipeline/output/tmp_clean.dta", replace
