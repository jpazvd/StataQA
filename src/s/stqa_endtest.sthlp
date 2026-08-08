{smcl}
{* *! version 2.1.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{vieweralsosee "stqa_assert" "help stqa_assert"}{...}
{vieweralsosee "stqa_skip" "help stqa_skip"}{...}
{viewerjumpto "Syntax" "stqa_endtest##syntax"}{...}
{viewerjumpto "Description" "stqa_endtest##description"}{...}
{viewerjumpto "Outcomes" "stqa_endtest##outcomes"}{...}
{viewerjumpto "Globals" "stqa_endtest##globals"}{...}
{viewerjumpto "Examples" "stqa_endtest##examples"}{...}
{title:Title}

{phang}
{bf:stqa_endtest} {hline 2} Close a test block and emit its verdict

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_endtest}

{pstd}
{cmd:stqa_endtest} takes no arguments.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_endtest} closes the block opened by {help stqa_test}, books the outcome
in the live counters, and clears the block state so the next block starts from a
known position.  It is the only command that emits a {cmd:PASS:} token.

{marker outcomes}{...}
{title:Outcomes}

{pstd}
{cmd:stqa_endtest} resolves exactly one of four cases:

{p 8 8 2}1. {bf:skipped block} ({cmd:$stqa_skip_block} is {cmd:1}).  Nothing is
emitted and no counter moves.  Either the block was switched off by targeting,
in which case nothing should be reported at all, or {help stqa_skip} fired, in
which case it already emitted the {cmd:SKIP:} token and incremented
{cmd:$stqa_n_skip}.  A skipped test is never counted as passed and never as
failed.{p_end}

{p 8 8 2}2. {bf:failed block} ({cmd:$stqa_block_failed} is {cmd:1}).  The
{cmd:FAIL:} token was already written by the assertion that failed, so
{cmd:stqa_endtest} does not write a second one; it increments
{cmd:$stqa_n_fail} and appends the block id to {cmd:$stqa_failed_ids}.{p_end}

{p 8 8 2}3. {bf:clean block}.  {cmd:PASS: }{it:id}{cmd: }{it:description} is
displayed at column 1 and {cmd:$stqa_n_pass} is incremented.{p_end}

{p 8 8 2}4. {bf:no open block}.  A warning is displayed, no verdict is emitted
and no counter moves.  This is deliberate: a verdict line with an empty id would
be a phantom PASS in the log.  The run is allowed to continue so the log still
reaches its completion sentinel.{p_end}

{pstd}
{bf:Note on aborted blocks.}  An assertion that fails exits with return code 9,
which aborts the enclosing do-file unless the caller used {cmd:capture}.  In that
common case {cmd:stqa_endtest} never runs for the failing block, so
{cmd:$stqa_n_fail} does not move.  The {cmd:FAIL:} token is in the log either
way, which is why a suite's verdict is read from the log -- line-initial tokens
plus the completion sentinel -- and never from counters or from a batch exit
code alone.

{marker globals}{...}
{title:Globals}

{pstd}
Reads {cmd:$stqa_test_id}, {cmd:$stqa_test_name}, {cmd:$stqa_skip_block},
{cmd:$stqa_block_failed} and {cmd:$stqa_verbose}.  Writes {cmd:$stqa_n_pass},
{cmd:$stqa_n_fail} and {cmd:$stqa_failed_ids}, and clears {cmd:$stqa_test_id},
{cmd:$stqa_test_name}, {cmd:$stqa_block_failed}, {cmd:$stqa_skip_block},
{cmd:$stqa_SKIP_FLAG} and {cmd:$stqa_SKIP_MSG}.

{pstd}
{bf:Why the legacy skip flags are cleared here.}  {cmd:$stqa_SKIP_FLAG} and
{cmd:$stqa_SKIP_MSG} used to be left set, on the claim that the runner read them
after a test file had run in order to classify the whole file as skipped.  No
command in the package reads them at that point: the runner classifies a file
from the verdict tokens in the file's own log, through
{help stqa_scanlog}.  What the surviving flag did instead was leak.  Since
{help stqa_skip} set it and nothing ever unset it, one skip anywhere in the suite
made every later file that opens with the documented guard line

{p 8 8 2}{cmd:if "$stqa_SKIP_FLAG" == "1" exit}{p_end}

{pstd}
exit before running a single check, and a file that runs nothing fails nothing,
so the suite reported far fewer checks than it has and still read green.  The
flags are block state, and {cmd:stqa_endtest} clears block state.

{pstd}
{bf:This does not cover every case.}  A file-level {cmd:stqa_skip} written
{it:outside} any test block is followed by {cmd:exit}, not by
{cmd:stqa_endtest}, so nothing clears the flag for it; that idiom must clear it
itself (see {help stqa_skip##limits}).  A runner should also reset both globals
once per test file and once per suite, so that the state of one file can never
be observed by the next.

{pstd}
If {cmd:$stqa_verbose} is {cmd:"1"}, {cmd:set trace off} is issued before the
verdict is displayed, so the verdict line is not echoed by the tracer.  Stata
restores the {help trace} setting when a program exits, so this affects
{cmd:stqa_endtest} only; tracing switched on further up the stack, for instance
by {cmd:stataqa run} around its {cmd:do} of the test file, is left alone.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. stqa_test DET-02 "No missing ids"}{p_end}
{phang2}{cmd:.     stqa_assert !missing(id), msg("id has gaps")}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}
