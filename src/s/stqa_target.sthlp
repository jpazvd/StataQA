{smcl}
{* *! version 2.0.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{vieweralsosee "stqa_endtest" "help stqa_endtest"}{...}
{vieweralsosee "stqa_skip" "help stqa_skip"}{...}
{viewerjumpto "Syntax" "stqa_target##syntax"}{...}
{viewerjumpto "Description" "stqa_target##description"}{...}
{viewerjumpto "Options" "stqa_target##options"}{...}
{viewerjumpto "Remarks" "stqa_target##remarks"}{...}
{viewerjumpto "Globals" "stqa_target##globals"}{...}
{viewerjumpto "Examples" "stqa_target##examples"}{...}
{title:Title}

{phang}
{bf:stqa_target} {hline 2} Set, clear or show the single-test target

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_target} {it:id}

{p 8 17 2}
{cmd:stqa_target}{cmd:,} {opt clear}

{p 8 17 2}
{cmd:stqa_target}

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_target} controls single-test mode.  With an {it:id} it sets
{cmd:$stqa_target}, so that only the block whose id matches produces a verdict.
With {opt clear} it empties {cmd:$stqa_target} and the whole suite runs again.
With no arguments it reports the current target.

{pstd}
It is used interactively while debugging one failing test, and by the runner when
it is asked to re-run a single test id.

{marker options}{...}
{title:Options}

{phang}
{opt clear} clears the target.  It may not be combined with an {it:id}.

{marker remarks}{...}
{title:Remarks}

{pstd}
Targeting matches the {it:id} of a block exactly, as it was given to
{help stqa_test} -- {cmd:DET-01}, or an automatic id such as {cmd:T007}.  It is
not a pattern and it is case sensitive.  A target that matches no block produces
a run in which no verdict token is emitted at all, which is worth remembering
when a targeted run looks suspiciously quiet.

{pstd}
Blocks that do not match are switched off rather than skipped: they emit no
token, and they are counted neither as passes, nor failures, nor skips.  They do
still increment {cmd:$stqa_n_total}, which counts blocks encountered, so
automatic ids do not shift between a full run and a targeted run.  A closing
banner that has to agree with what actually ran should therefore be built from
{cmd:$stqa_n_pass}, {cmd:$stqa_n_fail} and {cmd:$stqa_n_skip}.

{pstd}
{bf:Honest limitation.}  A Stata program cannot skip the lines that follow it in
a do-file, so ordinary Stata code in the body of a switched-off block still runs;
only the harness commands in it are neutralised.  See {help stqa_test##targeting}
for the guard pattern that also skips the body's own work.

{pstd}
Set the target before the test file is executed.  Setting it in the middle of a
file affects only the blocks that open after it.

{marker globals}{...}
{title:Globals}

{pstd}
Writes and reads {cmd:$stqa_target}.

{marker examples}{...}
{title:Examples}

{pstd}Run one block only, then restore the full suite:{p_end}
{phang2}{cmd:. stqa_target DET-01}{p_end}
{phang2}{cmd:. do tests/test_det.do}{p_end}
{phang2}{cmd:. stqa_target, clear}{p_end}

{pstd}Report the current target:{p_end}
{phang2}{cmd:. stqa_target}{p_end}
{phang2}{cmd:  stqa_target: current target is DET-01}{p_end}
