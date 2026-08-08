*! version 2.0.0  06aug2026
* stqa_rcof: Expected return code assertion for commands
* Description: Executes a command and checks its return code matches expectation.
* Options: rc(), msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_rcof
    version 14.0

    * A skipped block must not run its assertions.
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * equalok so that an assignment inside the command under test parses,
    * e.g. stqa_rcof "generate x = 1/0", rc(0)
    syntax anything(name=cmd equalok), rc(integer) [msg(string)]

    * Strip at most ONE enclosing pair of quotes, plain or compound.  The
    * previous version removed EVERY double quote from the command, which
    * destroyed quoted arguments such as  use "my file.dta".  char() spells the
    * delimiters so that no bare quote character has to appear in the
    * comparisons: 34 is the double quote, 96 the left single quote, 39 the right
    * single quote, so 96+34 opens a compound quote and 34+39 closes it.
    local len = length(`"`cmd'"')
    if `len' > 3 & substr(`"`cmd'"', 1, 2) == char(96) + char(34) ///
                 & substr(`"`cmd'"', `len' - 1, 2) == char(34) + char(39) {
        * compound double quotes
        local cmd = substr(`"`cmd'"', 3, `len' - 4)
    }
    else if `len' > 1 & substr(`"`cmd'"', 1, 1) == char(34) ///
                      & substr(`"`cmd'"', `len', 1) == char(34) {
        * plain double quotes:  " ... "
        local cmd = substr(`"`cmd'"', 2, `len' - 2)
    }

    capture noisily `cmd'
    local actual_rc = _rc

    if `actual_rc' != `rc' {
        local tid "$stqa_test_id"
        if "`tid'" == "" {
            local tid "stqa_rcof"
        }
        local desc "unexpected return code `actual_rc'"
        if `"`msg'"' != "" {
            local desc `"`msg'"'
        }

        di as error `"FAIL: `tid' `desc'"'
        di as error "Expected: return code `rc'"
        di as error "Got: return code `actual_rc'"
        di as error `"Command: `cmd'"'
        global stqa_block_failed 1
        exit 9
    }
end
