*! version 2.1.0  06aug2026
* stqa_unique: Distinct value count assertion
* Description: Asserts the number of distinct values meets a comparator.  On
*              failure it emits the FAIL: verdict token for the open test block,
*              reports the comparison and the count found, flags the block and
*              exits 9.  No-op when the block is skipped or targeted out.
* Options: count(), gt, lt, ge, le, msg(), noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_unique
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * varname() accepts none of name=, min= or max=; supplying them makes the
    * specification itself invalid and every call dies with rc 197.  Plain
    * -syntax varname- already means exactly one variable, and returns it in
    * `varlist'.  count() is REQUIRED, so it takes no default.
    syntax varname , COUNT(integer) [GT LT GE LE msg(string) NOIsily]

    local cmp "eq"
    local cmp_count 0
    foreach c in gt lt ge le {
        if "``c''" != "" {
            local cmp "`c'"
            local cmp_count = `cmp_count' + 1
        }
    }
    if `cmp_count' > 1 {
        di as error "Specify only one comparison option: gt, lt, ge, or le."
        exit 198
    }

    * r(r) is the number of distinct nonmissing values levelsof just found.
    * The former -: word count of `levels'- counted the literal word "of" as
    * well, so every count came back one too high.
    quietly levelsof `varlist'
    local uniq = r(r)

    local pass 0
    if "`cmp'" == "eq" {
        if `uniq' == `count' local pass 1
    }
    else if "`cmp'" == "gt" {
        if `uniq' > `count' local pass 1
    }
    else if "`cmp'" == "lt" {
        if `uniq' < `count' local pass 1
    }
    else if "`cmp'" == "ge" {
        if `uniq' >= `count' local pass 1
    }
    else if "`cmp'" == "le" {
        if `uniq' <= `count' local pass 1
    }

    if !`pass' {
        local sym "=="
        if "`cmp'" == "gt" local sym ">"
        if "`cmp'" == "lt" local sym "<"
        if "`cmp'" == "ge" local sym ">="
        if "`cmp'" == "le" local sym "<="

        local tid `"$stqa_test_id"'
        local desc `"$stqa_test_name"'
        if `"`tid'"' == "" local tid "stqa_unique"
        if `"`desc'"' == "" local desc "unique value count mismatch for `varlist'"

        di as error `"FAIL: `tid' `desc'"'
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        di as error `"Expected: distinct nonmissing values of `varlist' `sym' `count'"'
        di as error `"Got: `uniq'"'

        global stqa_block_failed 1
        exit 9
    }

    if "`noisily'" != "" {
        di as txt "  > Unique values check passed: `varlist' has `uniq' distinct nonmissing values"
    }
end
