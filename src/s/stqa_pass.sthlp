{smcl}
{* *! version 2.4.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_fail" "help stqa_fail"}{...}
{vieweralsosee "stqa_skip" "help stqa_skip"}{...}
{vieweralsosee "stqa_assert" "help stqa_assert"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{viewerjumpto "Syntax" "stqa_pass##syntax"}{...}
{viewerjumpto "Description" "stqa_pass##description"}{...}
{viewerjumpto "Options" "stqa_pass##options"}{...}
{viewerjumpto "When not to use it" "stqa_pass##caution"}{...}
{viewerjumpto "Who counts the pass" "stqa_pass##counters"}{...}
{viewerjumpto "Examples" "stqa_pass##examples"}{...}
{title:Title}

{phang}
{bf:stqa_pass} {hline 2} Book a passing check explicitly, conditionally

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_pass} [{it:{help if}} {it:exp}] [{cmd:,} {opt id(string)} {opt msg(string)}]

{pstd}
With no {it:if} qualifier the pass is booked unconditionally.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_pass} records a check that the caller decided rather than an assertion.
It emits

{p 8 8 2}{cmd:PASS: }{it:id}{cmd: }{it:message}{p_end}

{pstd}
at column 1.  Together with {help stqa_fail} and {help stqa_skip} it completes the
three verdict emitters, so a suite written in the capture-then-decide idiom can be
ported without being restructured into assertion blocks.

{pstd}
It is a no-op when {cmd:$stqa_skip_block} is {cmd:1}.  A skip that silently became
a pass is precisely the defect this framework exists to prevent.

{marker options}{...}
{title:Options}

{phang}
{opt id(string)} names the check.  Defaults to {cmd:$stqa_test_id}, then to
{cmd:ADHOC}.

{phang}
{opt msg(string)} the message printed after the id.  Defaults to
{cmd:$stqa_test_name}.

{marker caution}{...}
{title:When not to use it}

{pstd}
{cmd:stqa_pass} books a pass on your word.  Nothing verifies anything.  That makes
it the easiest command in this package to misuse, and misuse of exactly this shape
is common in the wild: a test that calls a pass emitter on a branch where no
property was established, or on {it:both} branches of an {cmd:if}, cannot fail and
is therefore not a test.

{pstd}
Prefer {help stqa_assert}, which ties the verdict to a condition, whenever the
check can be written as an expression.  Reach for {cmd:stqa_pass} only when the
decision genuinely lives in the caller {hline 2} for example when the acceptable
outcomes are several ({cmd:rc 0} or {cmd:rc 601}), or when the evidence is
assembled across several commands.

{pstd}
A useful discipline: if you write {cmd:stqa_pass} in both arms of a conditional,
delete the conditional and ask what the test is for.

{marker counters}{...}
{title:Who counts the pass}

{phang}
{bf:Inside an open block}: the emitted token is the record; {help stqa_endtest}
does the counting when the block closes.  Counting here as well would double it.

{phang}
{bf:Outside a block}: {cmd:stqa_pass} increments {cmd:$stqa_n_pass} and
{cmd:$stqa_n_total} itself.

{marker examples}{...}
{title:Examples}

{pstd}Several outcomes are acceptable, so the caller decides{p_end}
{phang2}{cmd:. capture noisily unicefdata, indicator(ALL) dataflow(ECD) clear}{p_end}
{phang2}{cmd:. local rc = _rc}{p_end}
{phang2}{cmd:. stqa_pass if inlist(`rc', 0, 677), id(EXT-05) msg("bulk pull ok or graceful API refusal")}{p_end}
{phang2}{cmd:. stqa_fail if !inlist(`rc', 0, 677), id(EXT-05) msg("unexpected rc `rc'")}{p_end}

{pstd}Evidence assembled across commands{p_end}
{phang2}{cmd:. quietly count if !missing(region)}{p_end}
{phang2}{cmd:. local ok = (r(N) == _N)}{p_end}
{phang2}{cmd:. stqa_pass if `ok', id(META-01) msg("region populated for every observation")}{p_end}
{phang2}{cmd:. stqa_fail if !`ok', id(META-01) msg("region missing on some observations")}{p_end}
