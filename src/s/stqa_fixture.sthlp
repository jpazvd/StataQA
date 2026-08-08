{smcl}
{* *! version 1.0.0  08aug2026}{...}
{vieweralsosee "stqa_manifest" "help stqa_manifest"}{...}
{vieweralsosee "stqa_replay" "help stqa_replay"}{...}
{viewerjumpto "Syntax" "stqa_fixture##syntax"}{...}
{viewerjumpto "Description" "stqa_fixture##description"}{...}
{viewerjumpto "Stored results" "stqa_fixture##results"}{...}
{title:Title}

{phang}
{bf:stqa_fixture} {hline 2} Verified access to a frozen input

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_fixture} {cmd:using} {it:filename} [{cmd:,} {opt res:olve} {opt msg(string)}]

{marker description}{...}
{title:Description}

{pstd}
The input half of the chain of custody.  Three things must hold before a test
touches a fixture: the file exists, it is listed in {cmd:qa/manifest.txt},
and its recorded signature still matches (see {help stqa_manifest}).  When
all three hold, a {cmd:.dta} is loaded into memory; any other file has its
verified path returned in {cmd:r(fn)} for the test to consume with its own
loader.  When any fails, the command emits the {cmd:FAIL:} verdict token,
flags the enclosing test block, and exits 9 {hline 2} a test that would have
run against an absent, unlisted, or silently-regenerated fixture is a red
check, not a quiet one.

{pstd}
There is no path guessing and no format dispatch: the command takes exactly
the path it is given, and it loads nothing it would need a user-written
parser for.  YAML and JSON fixtures are verified and resolved, not parsed
{hline 2} base Stata ships no parser for either, and dispatching into a
user-written one would embed the very dependency class the framework
certifies.

{phang}
{opt resolve} returns the verified path without loading, even for a
{cmd:.dta}.{p_end}
{phang}
{opt msg(string)} adds a caller's line to the failure diagnostic.{p_end}

{pstd}
Inside a skipped or targeted-out test block the command is a no-op, so a
fixture failure cannot fire from a block that was never meant to run.

{marker results}{...}
{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(fn)}}the verified path{p_end}
{synopt:{cmd:r(loaded)}}{cmd:1} if a {cmd:.dta} was loaded, else {cmd:0}{p_end}

{title:Also see}

{pstd}{help stqa_manifest}, {help stqa_replay}, {help stataqa:stataqa hub}{p_end}
