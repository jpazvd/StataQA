{smcl}
{* *! version 1.0.0  08aug2026}{...}
{vieweralsosee "stqa_manifest" "help stqa_manifest"}{...}
{vieweralsosee "stqa_fixture" "help stqa_fixture"}{...}
{viewerjumpto "Syntax" "stqa_replay##syntax"}{...}
{viewerjumpto "Description" "stqa_replay##description"}{...}
{viewerjumpto "The determinism contract" "stqa_replay##contract"}{...}
{viewerjumpto "Remarks" "stqa_replay##remarks"}{...}
{viewerjumpto "Stored results" "stqa_replay##results"}{...}
{title:Title}

{phang}
{bf:stqa_replay} {hline 2} Re-run a blessed do-file and require the same output

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_replay} {cmd:using} {it:dofile} [{cmd:,} {opt log(filename)} {opt update} {opt msg(string)}]

{marker description}{...}
{title:Description}

{pstd}
The output half of the chain of custody.  The pair
{cmd:qa/replay/}{it:name}{cmd:.do} + {it:name}{cmd:.log} is a golden master:
the do-file is the recipe, the log is the blessed output.  By default the
command verifies {hline 2} it re-runs the do-file under a pinned environment
and diffs the normalized candidate output against the blessed log, failing
with the {cmd:FAIL:} token on the first differing line, expected and got
both named.  Both sides of the comparison ship in the repository, so a diff
gives the same guarantee as a stored hash plus a diagnostic a hash cannot.

{pstd}
Verification runs in a fixed order, each step falsifiable on its own:

{phang2}1. Pair integrity: both files verify against {cmd:qa/manifest.txt}
(see {help stqa_manifest}).  A changed do-file cannot claim its old blessed
log; a tampered master proves nothing.{p_end}
{phang2}2. Version gate: a pair blessed under a different Stata version
{cmd:SKIP}s with the reason, rather than false-redding on display drift.
Display formats change across versions; re-bless to compare.{p_end}
{phang2}3. Re-run: the do-file executes with {cmd:linesize} pinned at 80 and
output captured to a headerless log ({cmd:quietly log using}), so neither
wrap points nor timestamps enter the comparison.  The caller's linesize is
restored unconditionally.{p_end}
{phang2}4. The determinism contract is enforced on the candidate (below).{p_end}
{phang2}5. Normalized line diff: carriage returns and trailing blanks are
stripped, trailing empty lines dropped, and the first differing line is
named in the failure.{p_end}

{pstd}
{opt update} re-blesses the pair: the do-file is re-run, the contract is
enforced on the new log, and both files are re-entered in the manifest with
the running Stata version recorded.  Like all blessing, this is a certify
ceremony {hline 2} refused inside a review-role run (see {help stqa_run}).

{phang}
{opt log(filename)} names the blessed log; the default replaces the
do-file's {cmd:.do} with {cmd:.log}.{p_end}
{phang}
{opt msg(string)} adds a caller's line to a diff failure.{p_end}

{marker contract}{...}
{title:The determinism contract}

{pstd}
A replay log that names the temporary directory or any drive-absolute path
can never reproduce on another machine, so it is rejected as an invalid
fixture at the moment that is cheap to fix {hline 2} blessing or
verification, not a colleague's failing build.  The scan covers
{cmd:c(tmpdir)} in both separator spellings and any {it:X}{cmd::\} or
{it:X}{cmd::/} path.  Replay do-files must therefore print values, not
locations: fixed seeds, fixed observation counts, no clock, no {cmd:pwd}.

{pstd}
During an {cmd:update} ceremony a contract violation is a plain command
error.  During verification it is a check failure carrying the {cmd:FAIL:}
token, framed at the verify call site.

{marker remarks}{...}
{title:Remarks}

{pstd}
A test exercising the {cmd:update} ceremony must call it under
{cmd:capture noisily}, never bare {cmd:capture}: a bare {cmd:capture}
suppresses the replayed do-file's output before it reaches any named log, so
the candidate arrives empty and blesses cleanly {hline 2} the outer-capture
seam documented in {help stqa_cmdline}.

{marker results}{...}
{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros (verify, on success)}{p_end}
{synopt:{cmd:r(fn)}}the do-file{p_end}
{synopt:{cmd:r(log)}}the blessed log{p_end}

{title:Also see}

{pstd}{help stqa_manifest}, {help stqa_fixture}, {help stqa_dta_equal}, {help stataqa:stataqa hub}{p_end}
