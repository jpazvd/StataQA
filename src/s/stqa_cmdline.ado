*! version 2.2.0  06aug2026
* stqa_cmdline: Run an arbitrary command line as a check
* Description: Executes any command, optionally capturing its output to a log,
*              and books a verdict from the return code -- and, when a sentinel
*              is given, from whether the command actually reached the end.
*              Written for docs-as-tests and example suites, where the property
*              under test is simply "this still runs".
* Options: id(), msg(), rc(), log(), sentinel(), soft, noisily
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_cmdline, rclass
    version 14.0

    * a skipped or targeted-out block must not run the command at all
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    * equalok so an assignment inside the command parses, e.g.
    * stqa_cmdline "generate x = 1/0"
    syntax anything(name=cmd equalok) [, ///
        id(string)      ///
        msg(string)     ///
        rc(integer 0)   ///
        log(string)     ///
        SENTinel(string) ///
        SOFT            ///
        NOIsily         ///
    ]

    * ------------------------------------------------------------------
    * Strip at most ONE enclosing pair of quotes, plain or compound, so that
    * both  stqa_cmdline "use my.dta"  and  stqa_cmdline `"use "my file.dta""'
    * work and any inner quotes survive.  char() spells the delimiters so no
    * bare quote has to appear in the comparisons: 34 is the double quote,
    * 96 the left single quote, 39 the right single quote.
    * ------------------------------------------------------------------
    local len = length(`"`cmd'"')
    if `len' > 3 & substr(`"`cmd'"', 1, 2) == char(96) + char(34) ///
                 & substr(`"`cmd'"', `len' - 1, 2) == char(34) + char(39) {
        local cmd = substr(`"`cmd'"', 3, `len' - 4)
    }
    else if `len' > 1 & substr(`"`cmd'"', 1, 1) == char(34) ///
                      & substr(`"`cmd'"', `len', 1) == char(34) {
        local cmd = substr(`"`cmd'"', 2, `len' - 2)
    }

    local cmdblank : subinstr local cmd " " "", all
    if `"`cmdblank'"' == "" {
        di as error "stqa_cmdline: a command is required"
        exit 198
    }

    local tid `"`id'"'
    if `"`tid'"' == "" local tid `"$stqa_test_id"'
    if `"`tid'"' == "" local tid "stqa_cmdline"

    local desc `"`msg'"'
    if `"`desc'"' == "" local desc `"$stqa_test_name"'
    if `"`desc'"' == "" local desc `"`cmd'"'

    * ------------------------------------------------------------------
    * Logging.  A -quietly- command produces no log output at all, so asking
    * for a log implies noisily; saying otherwise would hand back an empty
    * file.  The log carries a distinctive name so it cannot collide with the
    * case log stqa_run opens.
    * ------------------------------------------------------------------
    local shownoi "`noisily'"
    if `"`log'"' != "" {
        local shownoi "noisily"
        capture log close stqa_cmd
        capture log using `"`log'"', replace text name(stqa_cmd)
        if _rc {
            di as error `"FAIL: `tid' `desc'"'
            di as error `"Expected: a writable log at `log'"'
            di as error `"Got: could not open the log (rc = `=_rc')"'
            global stqa_block_failed 1
            return scalar rc = .
            exit 9
        }
    }

    * ------------------------------------------------------------------
    * Run it.  -capture- traps the return code without aborting, which is the
    * whole mechanism: the command under test is allowed to fail, and its
    * failure is data rather than an accident.
    * ------------------------------------------------------------------
    capture `shownoi' `cmd'
    local arc = _rc

    if `"`log'"' != "" {
        capture log close stqa_cmd
    }

    * ------------------------------------------------------------------
    * Completion, when a sentinel is given.  A zero return code does NOT prove
    * a command reached its end: a do-file that hits -exit 0- early returns 0
    * having skipped most of itself, which is precisely how a skipped example
    * gets recorded as a pass.  If the caller can name a line the command
    * prints last, that is stronger evidence than rc, so it is checked too.
    * ------------------------------------------------------------------
    local reached 1
    if `"`sentinel'"' != "" {
        if `"`log'"' == "" {
            di as error "stqa_cmdline: sentinel() requires log()"
            exit 198
        }
        mata: stqa_cmdline_sentinel()
        local reached = `s_reached'
    }

    return scalar rc      = `arc'
    return local  cmdline `"`cmd'"'
    if `"`log'"' != ""      return local logfile `"`log'"'
    if `"`sentinel'"' != "" return scalar reached = `reached'

    * ------------------------------------------------------------------
    * Verdict.
    * ------------------------------------------------------------------
    if `arc' == `rc' & `reached' {
        exit 0
    }

    di as error `"FAIL: `tid' `desc'"'
    if `"`msg'"' != "" & `"`msg'"' != `"`desc'"' {
        di as error `"Message: `msg'"'
    }
    if `arc' != `rc' {
        di as error `"Expected: return code `rc'"'
        di as error `"Got: `arc'  (command: `cmd')"'
    }
    else {
        di as error `"Expected: the command to reach the end, marked by "`sentinel'""'
        di as error `"Got: return code `arc' but the sentinel never appeared in `log'"'
    }

    global stqa_block_failed 1

    * -soft- books the failure and lets the caller continue, which is what an
    * example sweep needs: the value of such a suite is which of the fifty
    * examples broke, not that the first one did.
    if "`soft'" != "" {
        exit 0
    }
    exit 9
end

version 14.0
mata:
// Scan the log for a line-initial sentinel.
//
// In Mata, and line-initially, for the two reasons the rest of this package
// documents: a Stata log echoes the command's own source, which is full of
// backticks and compound quotes, so reading it through a macro-expanded string
// expression dies with r(132); and a line that merely CONTAINS the sentinel --
// an echo of the source that prints it -- is not evidence that it was printed.
void stqa_cmdline_sentinel()
{
    string colvector lines
    string scalar    path, mark, s
    real scalar      i, n, hit

    path = st_local("log")
    mark = strtrim(st_local("sentinel"))
    hit  = 0

    if (path == "" | !fileexists(path)) {
        st_local("s_reached", "0")
        return
    }

    lines = cat(path)
    n     = rows(lines)

    for (i = 1; i <= n; i++) {
        s = strtrim(lines[i])
        // strip SMCL directives so a log opened without -text- still matches
        while (substr(s, 1, 1) == "{") {
            if (strpos(s, "}") == 0) break
            s = strtrim(substr(s, strpos(s, "}") + 1, .))
        }
        if (substr(s, 1, strlen(mark)) == mark) hit = 1
    }

    st_local("s_reached", strofreal(hit))
}
end
