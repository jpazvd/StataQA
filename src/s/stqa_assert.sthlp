{smcl}
{* *! version 2.0.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{vieweralsosee "stqa_endtest" "help stqa_endtest"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{viewerjumpto "Syntax" "stqa_assert##syntax"}{...}
{viewerjumpto "Description" "stqa_assert##description"}{...}
{viewerjumpto "Options" "stqa_assert##options"}{...}
{viewerjumpto "Failure output" "stqa_assert##failure"}{...}
{viewerjumpto "Expressions" "stqa_assert##expressions"}{...}
{viewerjumpto "Globals" "stqa_assert##globals"}{...}
{viewerjumpto "Examples" "stqa_assert##examples"}{...}
{title:Title}

{phang}
{bf:stqa_assert} {hline 2} General assertion inside a test block

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_assert} {it:exp} [{cmd:,} {opt msg(string)} {opt null}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_assert} verifies that {it:exp} is true.  It wraps Stata's
{help assert} and adds the reporting protocol the harness depends on.

{pstd}
When {it:exp} is true, {cmd:stqa_assert} is silent.  When it is false, or when
evaluating it errors, {cmd:stqa_assert}

{p 8 8 2}1. displays {cmd:FAIL: }{it:id}{cmd: }{it:description} at column 1,
naming the open test block;{p_end}
{p 8 8 2}2. displays the diagnostics -- the optional message, the failing
condition, and the return code {cmd:assert} actually returned;{p_end}
{p 8 8 2}3. sets {cmd:$stqa_block_failed} to {cmd:1} so {help stqa_endtest} books
the failure without emitting a second token;{p_end}
{p 8 8 2}4. exits with return code 9.{p_end}

{pstd}
Because it exits non-zero, a failing assertion aborts the enclosing do-file
unless the caller wrapped it in {cmd:capture}.  That is intended: the remaining
assertions in a block are usually meaningless once the first one has failed, and
the {cmd:FAIL:} token is already in the log.

{pstd}
{opt null} additionally fails the assertion when its {cmd:if}/{cmd:in}
qualifier selects zero observations.  Without it, a variable expression over an
empty selection passes {it:vacuously} -- {cmd:assert price < 0 if foreign == 99}
returns 0 on {cmd:auto.dta}, a false assertion passing -- so a filter typo or a
pipeline that emptied its output reads as a green check.  Scalar expressions
need no guard: a false scalar assertion fails even with no data in memory.
On Stata 16 or newer the guard is Stata's own {cmd:assert, null}; on older
binaries the selection is counted before asserting.  The option follows
official {help assert} syntax; its adoption here was prompted by the same
option in {browse "https://github.com/peterdutey/adotest":adotest} (Dutey).

{pstd}
{cmd:stqa_assert} is a no-op when {cmd:$stqa_skip_block} is {cmd:1}, that is when
the block was skipped by {help stqa_skip} or switched off by {help stqa_target}.
A neutralised assertion cannot fail and cannot emit a token.

{marker options}{...}
{title:Options}

{phang}
{opt msg(string)} is a custom message explaining what the assertion protects.  It
is displayed on its own {cmd:Message:} line under the {cmd:FAIL:} token.  It does
not replace the echo of the condition; both are shown.

{marker failure}{...}
{title:Failure output}

{pstd}
A failure inside block {cmd:DET-03} described "Deliberate failure" prints:

{p 8 8 2}{cmd:FAIL: DET-03 Deliberate failure}{p_end}
{p 8 8 2}{cmd:Message: this must fail}{p_end}
{p 8 8 2}{cmd:Expected: 1 == 2}{p_end}
{p 8 8 2}{cmd:Got: assertion false (assert returned rc = 9)}{p_end}

{pstd}
Only the first line starts with a verdict token, which is what lets a log scanner
count line-initial tokens without double counting diagnostics.  The return code
reported on the {cmd:Got:} line is the one {help assert} returned -- 9 for a false
assertion, but 111, 198 and friends when the expression itself could not be
evaluated -- so a typo in a test is distinguishable from a genuine failure.  The
command itself always exits 9.

{pstd}
When no block is open, the id shown is {cmd:ADHOC} and the description is
{cmd:assertion outside a test block}.  Assertions belong inside blocks; this
fallback exists so an interactive call still reports something intelligible.

{marker expressions}{...}
{title:Expressions}

{pstd}
{it:exp} is any expression {help assert} accepts, including one that refers to
variables, {cmd:r()} results, {cmd:c()} settings and macros.  It may contain
parentheses and commas -- {cmd:inlist(x,1,2)} is parsed correctly -- and it may
contain quoted strings, including a leading one:

{phang2}{cmd:. stqa_assert "`c(os)'" == "Windows", msg("Windows-only path")}{p_end}

{pstd}
Options are separated from the expression by the first comma that is not inside
parentheses, brackets or quotes.  An expression whose own top-level comma is not
protected must be parenthesised.

{marker globals}{...}
{title:Globals}

{pstd}
Reads {cmd:$stqa_skip_block}, {cmd:$stqa_test_id} and {cmd:$stqa_test_name}.
Writes {cmd:$stqa_block_failed}.

{marker examples}{...}
{title:Examples}

{pstd}Plain assertion:{p_end}
{phang2}{cmd:. stqa_test DET-01 "Row count"}{p_end}
{phang2}{cmd:.     use "fixtures/det.dta", clear}{p_end}
{phang2}{cmd:.     stqa_assert _N == 1000, msg("fixture row count changed")}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}Assertion on a saved result:{p_end}
{phang2}{cmd:. stqa_test DET-02 "Prices are positive"}{p_end}
{phang2}{cmd:.     summarize price}{p_end}
{phang2}{cmd:.     stqa_assert r(min) > 0{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{title:See also}

{pstd}{help stqa_approx}, {help stqa_approx_all}, {help stqa_inrange},
{help stqa_rc_zero}, {help stqa_rcof}, {help stataqa:stataqa hub}{p_end}
