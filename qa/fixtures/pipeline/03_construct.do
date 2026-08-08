* src/03_construct.do - toy example
use "qa/fixtures/pipeline/output/tmp_clean.dta", clear
gen indicator_value = value > 0.5
save "qa/fixtures/pipeline/output/indicators.dta", replace
