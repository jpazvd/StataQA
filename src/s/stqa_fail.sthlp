{smcl}
{* *! version 2.4.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_pass" "help stqa_pass"}{...}
{vieweralsosee "stqa_skip" "help stqa_skip"}{...}
{vieweralsosee "stqa_assert" "help stqa_assert"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{viewerjumpto "Syntax" "stqa_fail##syntax"}{...}
{viewerjumpto "Description" "stqa_fail##description"}{...}
{viewerjumpto "Options" "stqa_fail##options"}{...}
{viewerjumpto "Why it does not abort" "stqa_fail##whynoabort"}{...}
{viewerjumpto "Who counts the failure" "stqa_fail##counters"}{...}
{viewerjumpto "Examples" "stqa_fail##examples"}{...}
{title:Title}

{phang}
{bf:stqa_fail} {hline 2} Book a failure without aborting, conditionally

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_fail} [{it:{help if}} {it:exp}] [{cmd:,} {opt id(string)} {opt msg(string)}]

{pstd}
With no {it:if} qualifier the failure is booked unconditionally.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_fail} records a failed check.  It emits the verdict token

{p 8 8 2}{cmd:FAIL: }{it:id}{cmd: }{it:message}{p_end}

{pstd}
at column 1, sets {cmd:$stqa_block_failed} to {cmd:1}, and {bf:returns with a
return code of zero}.  It never exits.

{pstd}
That last property is the whole point.  {help stqa_assert} exits 9 on failure,
which aborts the do-file; that is right for a check whose failure makes
everything after it meaningless.  {cmd:stqa_fail} is for the opposite case: a
suite that has decided the verdict itself and needs the remaining checks to run
anyway.

{pstd}
It is a no-op when {cmd:$stqa_skip_block} is {cmd:1}, so a skipped or targeted-out
block cannot book a failure.

{marker options}{...}
{title:Options}

{phang}
{opt id(string)} names the check.  Defaults to {cmd:$stqa_test_id}, then to
{cmd:ADHOC} when called outside a test block.

{phang}
{opt msg(string)} the message printed after the id.  Defaults to
{cmd:$stqa_test_name}.

{marker whynoabort}{...}
{title:Why it does not abort}

{pstd}
Most hand-rolled Stata suites are written in the capture-then-decide idiom:

{p 8 8 2}{cmd:capture noisily} {it:command}{p_end}
{p 8 8 2}{cmd:if _rc } ...{p_end}

{pstd}
An emitter that exits cannot be dropped into that shape, because the exit
unwinds the very control flow the author wrote.  Worse, in a suite whose value
is an inventory {hline 2} "which of these twenty files failed to ship?" {hline 2}
aborting on the first failure turns "three helpers are missing" into "one helper
is missing", which is a different and much less useful answer.

{pstd}
So the rule is: use {help stqa_assert} when a failure invalidates what follows,
and {cmd:stqa_fail} when the suite should carry on and report everything.

{marker counters}{...}
{title:Who counts the failure}

{pstd}
This is the part implementers get wrong, so it is stated explicitly.

{phang}
{bf:Inside an open block} ({cmd:$stqa_test_id} is set): {cmd:stqa_fail} emits the
token and sets the flag; {help stqa_endtest} does the counting when the block
closes.  The block is booked once no matter how many times {cmd:stqa_fail} was
called inside it.

{phang}
{bf:Outside a block}: there is nothing to close, so {cmd:stqa_fail} increments
{cmd:$stqa_n_fail} and appends the id to {cmd:$stqa_failed_ids} itself.

{marker examples}{...}
{title:Examples}

{pstd}An inventory that must report every missing file, not just the first{p_end}
{phang2}{cmd:. foreach f of local shipped {c -(}}{p_end}
{phang2}{cmd:.     capture findfile "`f'"}{p_end}
{phang2}{cmd:.     stqa_fail if _rc, id(V2) msg("`f' is in the manifest but did not install")}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}Porting a capture-then-decide block unchanged{p_end}
{phang2}{cmd:. capture noisily datalib, country(BRA) clear}{p_end}
{phang2}{cmd:. local rc = _rc}{p_end}
{phang2}{cmd:. stqa_fail if `rc', id(V17) msg("datalib failed from the scratch install (rc `rc')")}{p_end}
{phang2}{cmd:. stqa_pass if !`rc', id(V17) msg("datalib runs from the scratch install")}{p_end}

{pstd}Unconditional, when the branch itself is the decision{p_end}
{phang2}{cmd:. if `found' == 0 stqa_fail, id(S19) msg("consent gate did not refuse")}{p_end}
