{smcl}
{* *! version 2.1.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{vieweralsosee "stqa_endtest" "help stqa_endtest"}{...}
{vieweralsosee "stqa_target" "help stqa_target"}{...}
{viewerjumpto "Syntax" "stqa_skip##syntax"}{...}
{viewerjumpto "Description" "stqa_skip##description"}{...}
{viewerjumpto "Options" "stqa_skip##options"}{...}
{viewerjumpto "What stqa_skip cannot do" "stqa_skip##limits"}{...}
{viewerjumpto "Globals" "stqa_skip##globals"}{...}
{viewerjumpto "Examples" "stqa_skip##examples"}{...}
{title:Title}

{phang}
{bf:stqa_skip} {hline 2} Skip the current test block, conditionally

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_skip} [{it:{help if}} {it:exp}] [{cmd:,} {opt msg(string)}]

{pstd}
With no {it:if} qualifier the skip is unconditional.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_skip} marks the open test block as skipped when {it:exp} is true.  It
emits the verdict token

{p 8 8 2}{cmd:SKIP: }{it:id}{cmd: }{it:reason}{p_end}

{pstd}
at column 1, increments {cmd:$stqa_n_skip}, appends {it:id}{cmd:: }{it:reason} to
{cmd:$stqa_skip_notes}, and sets {cmd:$stqa_skip_block} to {cmd:1} so that the
assertions remaining in the block become no-ops.  {help stqa_endtest} then closes
the block silently.  A skipped test is never counted as passed and never as
failed.

{pstd}
Use it for tests that depend on a Stata version, an operating system, an
optional dependency, a network service or a fixture that is not present on the
machine running the suite.

{pstd}
{cmd:stqa_skip} is a no-op when the block is already skipped or was switched off
by {help stqa_target}, so a skip is never booked twice.

{marker options}{...}
{title:Options}

{phang}
{opt msg(string)} gives the reason the test was skipped.  It is written into the
{cmd:SKIP:} token and into {cmd:$stqa_skip_notes}.  Supply it: a skip without a
reason is an unexplained hole in the suite.  The default reason is
{cmd:condition met}.

{marker limits}{...}
{title:What stqa_skip cannot do}

{pstd}
{bf:1. {cmd:stqa_skip} must be followed by {help stqa_endtest}.}  It reports the
skip; it does not close the block.  A block left open makes the next
{cmd:stqa_test} warn and makes the counters drift.

{pstd}
{bf:2. {cmd:stqa_skip} cannot halt the rest of the do-file by itself.}  This is a
Stata language constraint, not a design choice: {cmd:exit} inside an ado-file
returns from the {it:program}, not from the do-file that called it.  Earlier
versions relied on {cmd:exit 0} here, which did nothing to the caller -- the rest
of the file ran anyway, and a later real failure could then be reported as a
skip.  {cmd:stqa_skip} now neutralises the {it:rest of its own block} through
{cmd:$stqa_skip_block}, and nothing more.

{pstd}
To skip a whole file, exit the do-file yourself.  {cmd:exit} typed at do-file
level does terminate the do-file.  Clear the flag before you go: a file-level
skip is not inside a test block, so no {help stqa_endtest} follows it to clear
the flag, and a flag left standing makes the {it:next} file exit at its own
guard line without running a check:

{phang2}{cmd:. stqa_skip if c(os) != "Windows", msg("Windows-only fixtures")}{p_end}
{phang2}{cmd:. if "$stqa_SKIP_FLAG" == "1" {c -(}}{p_end}
{phang2}{cmd:.     global stqa_SKIP_FLAG ""}{p_end}
{phang2}{cmd:.     global stqa_SKIP_MSG ""}{p_end}
{phang2}{cmd:.     exit}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}
{bf:3. Ordinary Stata code in the block still runs.}  {cmd:$stqa_skip_block}
silences the harness commands, not the body.  Guard expensive work explicitly:

{phang2}{cmd:. stqa_test API-01 "Live endpoint answers"}{p_end}
{phang2}{cmd:.     stqa_skip if "$SDMX_TOKEN" == "", msg("no token in the environment")}{p_end}
{phang2}{cmd:.     if "$stqa_skip_block" != "1" {c -(}}{p_end}
{phang2}{cmd:.         qui copy "https://api.example.org/flow" "tmp.json", replace}{p_end}
{phang2}{cmd:.         stqa_assert fileexists("tmp.json")}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{marker globals}{...}
{title:Globals}

{pstd}
Writes {cmd:$stqa_n_skip}, {cmd:$stqa_skip_notes} (pipe-separated
{it:id}{cmd:: }{it:reason} entries) and {cmd:$stqa_skip_block}.  It also sets the
legacy {cmd:$stqa_SKIP_FLAG} and {cmd:$stqa_SKIP_MSG}.  Reads
{cmd:$stqa_test_id}; when no block is open the id in the token is {cmd:-}.

{pstd}
{bf:The legacy flags are transient.}  {cmd:$stqa_SKIP_FLAG} and
{cmd:$stqa_SKIP_MSG} exist for the do-file-level guard shown above and for
nothing else.  No command in the package reads them once a test file has
returned; the runner classifies a file from the verdict tokens in that file's
own log, through {help stqa_scanlog}.  They are cleared by the next
{help stqa_endtest} along with the rest of the block state, so read them
{it:immediately} after the {cmd:stqa_skip} call that set them.

{pstd}
Earlier versions never cleared them, and that was a silent false pass across
files: one skip anywhere in the suite left the flag standing, every later file
exited at its own guard line without running a check, and a file that runs
nothing fails nothing, so the suite reported far fewer checks than it has and
still read green.

{marker examples}{...}
{title:Examples}

{pstd}Skip a block on old Stata:{p_end}
{phang2}{cmd:. stqa_test FMT-03 "Uses frames"}{p_end}
{phang2}{cmd:.     stqa_skip if c(stata_version) < 16, msg("frames require Stata 16+")}{p_end}
{phang2}{cmd:.     stqa_assert 1 == 1}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}Skip a block unconditionally while a fixture is being rebuilt:{p_end}
{phang2}{cmd:. stqa_test DET-07 "Panel balance"}{p_end}
{phang2}{cmd:.     stqa_skip, msg("fixture regenerating, see issue #41")}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}
