*! version 1.0.0  08aug2026
* stqa_fixture: Verified access to a frozen input
* Description: The input half of the chain of custody: the file exists, is
*              listed in qa/manifest.txt, and its signature matches -- then a
*              .dta is loaded, or the verified path is returned in r(fn) for
*              the test to consume with its own loader.  Any of the three
*              failing emits the FAIL: verdict token, flags the block and
*              exits 9: a test that would have run against an absent,
*              unlisted, or silently-regenerated fixture is a red check, not
*              a quiet one.  No path guessing, no format dispatch: the
*              command takes the path it is given and loads nothing it would
*              need a user-written parser for.
* Options: resolve, msg()
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_fixture, rclass
    version 14.0

    * skipped or targeted-out block: the assertion must not run and must not
    * be able to fail
    if "$stqa_skip_block" == "1" {
        exit 0
    }

    syntax using/ [, RESolve msg(string)]

    * ------------------------------------------------------------------
    * Integrity is delegated to the one reader of the manifest format:
    * stqa_manifest verify covers exists + listed + matches, and already
    * speaks the verdict-token contract on failure.
    * ------------------------------------------------------------------
    capture noisily stqa_manifest verify using `"`using'"', quiet
    if _rc {
        if `"`msg'"' != "" {
            di as error `"Message: `msg'"'
        }
        exit 9
    }

    * ------------------------------------------------------------------
    * Verified: load or resolve.  Only .dta is loaded -- everything else is
    * handed back verified for the test's own loader, because base Stata
    * ships no YAML or JSON parser and a dispatch into a user-written one
    * would recreate the retired wrapper liability.
    * ------------------------------------------------------------------
    if lower(substr(`"`using'"', -4, 4)) == ".dta" & "`resolve'" == "" {
        capture use `"`using'"', clear
        if _rc {
            local tid `"$stqa_test_id"'
            if `"`tid'"' == "" local tid "stqa_fixture"
            di as error `"FAIL: `tid' verified fixture failed to load: `using' (rc `=_rc')"'
            if `"`msg'"' != "" {
                di as error `"Message: `msg'"'
            }
            global stqa_block_failed 1
            exit 9
        }
        return local loaded 1
    }
    else {
        return local loaded 0
    }
    return local fn `"`using'"'
end
