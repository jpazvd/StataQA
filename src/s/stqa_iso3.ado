*! version 2.2.0  07aug2026
* stqa_iso3: Assert that a string variable contains only ISO3 country codes
* Description: Validates distinct values against ISO 3166-1 alpha-3 whitelist.
*              On failure it emits the FAIL: verdict token for the open test
*              block, lists the offending codes, flags the block and exits 9.
*              No-op when the block is skipped or targeted out.
* Options: allowmissing, msg(), noisily
* Author: Joao Pedro Azevedo (UNICEF) | https://jpazvd.github.io
* License: MIT
program define stqa_iso3
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * varname() accepts no name= argument; supplying it makes the specification
    * itself invalid and every call dies with rc 197.  Plain -syntax varname-
    * returns the variable in `varlist'.
    syntax varname [, ALLOWMissing msg(string) NOIsily]

    local tid `"$stqa_test_id"'
    local desc `"$stqa_test_name"'
    if `"`tid'"' == "" local tid "stqa_iso3"
    if `"`desc'"' == "" local desc "non-ISO3 codes in `varlist'"

    * A numeric variable cannot hold ISO3 codes, so this is a failed check and
    * not a usage error.  It is captured because a bare -confirm- exits with
    * its own return code and prints nothing under -capture-, which would leave
    * the failure with no verdict token and no flagged block.
    capture confirm string variable `varlist'
    local crc = _rc
    if `crc' {
        di as error `"FAIL: `tid' `desc'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: `varlist' to be a string variable of ISO3 codes"'
        di as error `"Got: `varlist' is not a string variable (confirm returned rc = `crc')"'

        global stqa_block_failed 1
        exit 9
    }

    /* ISO3 whitelist (ISO 3166-1 alpha-3, incl. standard territories) */
    local iso3list "AFG ALA ALB DZA ASM AND AGO AIA ATA ATG ARG ARM ABW AUS AUT AZE BHS BHR BGD BRB BLR BEL BLZ BEN BMU BTN BOL BES BIH BWA BVT BRA IOT BRN BGR BFA BDI CPV KHM CMR CAN CYM CAF TCD CHL CHN CXR CCK COL COM COG COD COK CRI CIV HRV CUB CUW CYP CZE DNK DJI DMA DOM ECU EGY SLV GNQ ERI EST SWZ ETH FLK FRO FSM FJI FIN FRA GUF PYF ATF GAB GMB GEO DEU GHA GIB GRC GRL GRD GLP GUM GTM GGY GIN GNB GUY HTI HMD VAT HND HKG HUN ISL IND IDN IRN IRQ IRL IMN ISR ITA JAM JPN JEY JOR KAZ KEN KIR PRK KOR KWT KGZ LAO LVA LBN LSO LBR LBY LIE LTU LUX MAC MDG MWI MYS MDV MLI MLT MHL MTQ MRT MUS MYT MEX FSM MDA MCO MNG MNE MSR MAR MOZ MMR NAM NRU NPL NLD NCL NZL NIC NER NGA NIU NFK MNP MKD MNP NOR OMN PAK PLW PSE PAN PNG PRY PER PHL PCN POL PRT PRI QAT ROU RUS RWA REU BLM SHN KNA LCA MAF SPM VCT WSM SMR STP SAU SEN SRB SYC SLE SGP SXM SVK SVN SLB SOM ZAF SGS SSD ESP LKA SDN SUR SJM SWE CHE SYR TWN TJK TZA THA TLS TGO TKL TON TTO TUN TUR TKM TCA TUV UGA UKR ARE GBR USA UMI URY UZB VUT VEN VNM VGB VIR WLF ESH YEM ZMB ZWE"

    * -levelsof- drops missing values unless told otherwise, so the missing
    * branch below could never fire and allowmissing could never change any
    * outcome. Worse, a column the pipeline had stopped populating -- every
    * value "" -- produced an empty level list, an empty loop and a PASS.
    * Count the missing explicitly instead of hoping levelsof surfaces them.
    quietly levelsof `varlist', local(levels)

    capture confirm string variable `varlist'
    if _rc == 0 {
        quietly count if missing(`varlist') | trim(`varlist') == ""
    }
    else {
        quietly count if missing(`varlist')
    }
    local nmiss = r(N)

    local bad ""
    if `nmiss' > 0 & "`allowmissing'" == "" {
        local bad "`bad' <`nmiss' missing>"
    }
    foreach c of local levels {
        local ok : list c in iso3list
        if !`ok' {
            local bad "`bad' `c'"
        }
    }

    * Nothing to check is not the same as everything checked.
    if `"`levels'"' == "" & `nmiss' >= _N & _N > 0 & "`allowmissing'" == "" {
        local bad "`bad' <no non-missing values>"
    }
    * ...and zero observations is the extreme case of nothing to check: the
    * 07aug2026 guard above only covered an all-missing column on _N>0, so an
    * EMPTIED dataset still certified its ISO3 codes as valid. Same day.
    if _N == 0 {
        local bad "`bad' <no observations>"
    }

    if "`bad'" != "" {
        di as error `"FAIL: `tid' `desc'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: every value of `varlist' to be an ISO 3166-1 alpha-3 code"'
        di as error `"Got: `=trim("`bad'")'"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        di as txt "  > ISO3 check passed for `varlist'"
    }
end
