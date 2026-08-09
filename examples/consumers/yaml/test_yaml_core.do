*! examples/consumers/yaml/test_yaml_core.do  version 1.0.0  07aug2026
* INT family -- StataQA exercising the published -yaml- package, as an example
* of testing a real package with this framework.
*
* The package under test is whatever -yaml- the adopath resolves, exactly as a
* user would have it (net install yaml).  It is NOT a local working tree:
* a suite that quietly tested the working tree would certify code nobody else
* has.  On a machine without yaml installed every block SKIPs -- reported, not
* silent, and never a failure.
*
* Call forms follow the shipped documentation (yaml.sthlp): scalar leaves come
* back in r(value); block sequences come back space-joined in r(value) with
* the count in r(n_attrs).  Stored results are copied to locals before any
* other command can clear them (qa/test_harness.do DATA-02 discipline).
*
* Ids INT-21+ (INT: interaction with a sibling package).  The fixture is
* deliberately trivial; the point of the example is the harness pattern, not
* yaml coverage -- yaml's own qa/ carries that.
* Author: Joao Pedro Azevedo (UNICEF)

capture which yaml
local hasyaml = (_rc == 0)

* ---- fixture, written fresh so the example is self-contained --------------
tempfile fix
quietly {
    tempname fh
    file open `fh' using "`fix'", write replace text
    file write `fh' "title: StataQA consumer example" _n
    file write `fh' "count: 3" _n
    file write `fh' "items:" _n
    file write `fh' "  - alpha" _n
    file write `fh' "  - beta" _n
    file write `fh' "  - gamma" _n
    file close `fh'
}

stqa_test INT-21 "yaml reads a well-formed file without error"
    if !`hasyaml' {
        stqa_skip, msg("yaml is not installed on this machine")
    }
    else {
        capture yaml read using "`fix'", replace
        local rc = _rc
        stqa_assert `rc' == 0, msg("yaml read returned rc `rc' on a well-formed file")
    }
stqa_endtest

stqa_test INT-22 "a scalar leaf returns the value the file carries in r(value)"
    if !`hasyaml' {
        stqa_skip, msg("yaml is not installed on this machine")
    }
    else {
        quietly yaml read using "`fix'", replace
        yaml get count, quiet
        local got `"`r(value)'"'
        stqa_assert `got' == 3, msg(`"count read back as "`got'", expected 3"')
    }
stqa_endtest

stqa_test INT-23 "a block-sequence item is addressable by index"
    * Written against indexed access (items:1 -> r(value)), which both the
    * installed v2.0.0 and the v2.0.1 documentation support.  The whole-node
    * form (yaml get items -> r(n_attrs)) is v2.0.1+ and errored r(198) on the
    * installed v2.0.0 when this example was first run -- itself a working
    * demonstration of why a consumer suite targets the INSTALLED package:
    * version drift between docs and binary is exactly what it exists to catch.
    if !`hasyaml' {
        stqa_skip, msg("yaml is not installed on this machine")
    }
    else {
        quietly yaml read using "`fix'", replace
        yaml get items:1, quiet
        local got `"`r(value)'"'
        stqa_assert `"`got'"' == "alpha", msg(`"items:1 read back as "`got'", expected alpha"')
    }
stqa_endtest

stqa_test INT-24 "a missing file is an error, not an empty success"
    if !`hasyaml' {
        stqa_skip, msg("yaml is not installed on this machine")
    }
    else {
        * stqa_rcof asserts an EXACT return code; a missing file is r(601).
        stqa_rcof `"yaml read using "no_such_file_xyz.yaml", replace"', rc(601)
    }
stqa_endtest
