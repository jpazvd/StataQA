{smcl}
{* *! version 2.4.0  08aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_examples" "help stqa_examples"}{...}
{vieweralsosee "stqa_rcof" "help stqa_rcof"}{...}
{vieweralsosee "stqa_scanlog" "help stqa_scanlog"}{...}
{viewerjumpto "Syntax" "stqa_cmdline##syntax"}{...}
{viewerjumpto "Description" "stqa_cmdline##description"}{...}
{viewerjumpto "Options" "stqa_cmdline##options"}{...}
{viewerjumpto "Why a return code is not proof of completion" "stqa_cmdline##sentinel"}{...}
{viewerjumpto "Integrating external tools" "stqa_cmdline##external"}{...}
{viewerjumpto "Stored results" "stqa_cmdline##results"}{...}
{viewerjumpto "Limitations" "stqa_cmdline##limits"}{...}
{viewerjumpto "Examples" "stqa_cmdline##examples"}{...}
{title:Title}

{phang}
{bf:stqa_cmdline} {hline 2} Run an arbitrary command line as a check

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_cmdline} {it:"command"}
[{cmd:,}
{opt id(string)}
{opt msg(string)}
{opt rc(integer)}
{opt log(filename)}
{opt sent:inel(string)}
{opt soft}
{opt noi:sily}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_cmdline} executes {it:command} under {helpb capture}, optionally
captures its output to a log, and books a verdict from the return code.  The
property under test is simply {it:this still runs}, which is what a
documentation example, a shipped demo script or a downstream integration needs
to prove.

{pstd}
{it:command} is taken whole.  One enclosing pair of quotes is stripped, so both
{cmd:stqa_cmdline "yaml_example 1"} and
{cmd:stqa_cmdline `"use "my file.dta""'} work, and inner quotes survive.

{pstd}
It is a no-op when {cmd:$stqa_skip_block} is {cmd:1}: a skipped block does not
run the command at all.

{marker options}{...}
{title:Options}

{phang}
{opt id(string)} names the check.  Defaults to {cmd:$stqa_test_id}.

{phang}
{opt msg(string)} description printed with the verdict.  Defaults to
{cmd:$stqa_test_name}, then to the command itself.

{phang}
{opt rc(integer)} the expected return code; default {cmd:0}.  For asserting that
a command fails as it should, {helpb stqa_rcof} states the intent more clearly.

{phang}
{opt log(filename)} capture the command's output.  Implies {opt noisily},
because a {cmd:quietly} command produces no log output and the file would be
empty.  The log is named {cmd:stqa_cmd} so it cannot collide with the case log
{helpb stqa_run} opens.

{phang}
{opt sentinel(string)} a line the command prints when it reaches the end.
Requires {opt log()}.  See below.

{phang}
{opt soft} book the failure and return rc 0 instead of exiting 9.

{phang}
{opt noisily} show the command's output.  Off by default, because a suite that
echoes every example is unreadable.

{marker sentinel}{...}
{title:Why a return code is not proof of completion}

{pstd}
A zero return code means {it:nothing raised an error}.  It does not mean the
command reached its end.  A do-file that hits {cmd:exit 0} early returns 0 having
skipped most of itself {hline 2} which is not hypothetical: it is exactly how a
test that bailed out for a missing fixture ends up recorded as a pass.

{pstd}
If the command prints something identifiable last, name it in {opt sentinel()}
and it is checked as well.  The scan requires the sentinel to begin a line, for
the same reason {helpb stqa_scanlog} does: a line that merely {it:contains} the
text {hline 2} the echo of the source that prints it {hline 2} is not evidence
that it was printed.

{marker external}{...}
{title:Integrating external tools}

{pstd}
This command is how the wider reproducibility ecosystem plugs into the
certification record.  Early versions of this package shipped a wrapper
command per external tool; they were retired in favor of this one generic
mechanism.  A wrapper freezes assumptions about the wrapped tool's interface
and output, and a wrapper that misparses a changed output format fails toward
silence {hline 2} the false pass this package exists to prevent.
{cmd:stqa_cmdline} reads nothing but the tool's return code and, if you name
one, a completion sentinel, so the integration cannot rot when the tool's
report format changes.

{pstd}
One question decides the idiom for any given tool: {it:when the property it
checks is violated, what reaches the caller?}  Read the tool's documentation
{hline 2} or its source {hline 2} before trusting its return code; being a
checking tool is no guarantee of an honest one.

{pstd}
{bf:Tools that raise on violation} integrate completely.  {cmd:require}
(Correia and Seay, {it:Stata Journal} 2024) exits 601 when a package is
absent and 2226 when a version pin fails; {cmd:iecodebook verify} from
{helpb iefieldkit} errors on a codebook mismatch; {cmd:datasignature confirm}
exits 9 when the data have changed.  Guard on availability, skip {hline 2}
never fail {hline 2} where the tool is absent, and the return code carries
the whole verdict:

{phang2}{cmd:. stqa_test ENV-11 "declared dependencies are present at pinned versions"}{p_end}
{phang2}{cmd:.     capture which require}{p_end}
{phang2}{cmd:.     if _rc {c -(}}{p_end}
{phang2}{cmd:.         stqa_skip, msg("require is not installed")}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:.     else {c -(}}{p_end}
{phang2}{cmd:.         stqa_cmdline "require using qa/requirements.txt"}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}
{bf:Tools that print a definite success line but return 0 either way} carry
their verdict through {opt sentinel()}.  {cmd:project, validate} (Picard)
returns 0 whether or not it found differences, but prints
{cmd:No change found, project results are validated} at column 1 on success
{hline 2} which is exactly what the option exists for:

{phang2}{cmd:. stqa_cmdline "project myproj, validate", log("qa/logs/proj.log") sentinel("No change found, project results are validated")}{p_end}

{pstd}
{bf:Tools whose return code does not carry the finding at all} can be booked
only for {it:completion}, and the check's wording must say so.
{cmd:stata_linter} (v1.02) reports style issues on screen and returns 0
regardless; {cmd:reprun} from {helpb repkit} writes reproducibility
differences into a report, also returning 0.  Booked through this command,
each certifies {it:the tool ran to its end} {hline 2} valuable, but not
``the source is clean'' or ``the run reproduces,'' and a check must never be
named as if it were.  For finding-level verdicts from such tools, assert on
stored results where the tool leaves them ({cmd:cfout} leaves
{cmd:r(discrep)}; official {cmd:assert} raises where {cmd:assertlist} only
lists), or read the tool's report as its own fixture.

{pstd}
The same machinery serves a {cmd:python script} or {cmd:rsource} step in a
mixed-language pipeline, or any user-written command: whatever runs on a
command line can be booked, with its outcome counted, logged, and recorded in
the ledger like every native assertion.

{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(rc)}}the command's return code{p_end}
{synopt:{cmd:r(reached)}}1 if the sentinel was found (only with {opt sentinel()}){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(cmdline)}}the command as executed{p_end}
{synopt:{cmd:r(logfile)}}the log written (only with {opt log()}){p_end}

{marker limits}{...}
{title:Limitations}

{phang}
{bf:A command that closes all logs closes this one.}  If {it:command} issues
{cmd:log close _all}, the capture log ends there and {opt sentinel()} finds
nothing after that point.  The fix is to remove that line from the script being
run; the runner owns logging.

{phang}
{bf:It cannot tell a hang from a long run.}  {cmd:capture} returns when the
command returns; nothing here bounds the wait.  Bounding execution needs an
external process driver, which is deliberately outside this package.

{marker examples}{...}
{title:Examples}

{pstd}A shipped example must still run{p_end}
{phang2}{cmd:. stqa_cmdline "yaml_example 1", id(EX-01)}{p_end}

{pstd}A whole script, with its output kept{p_end}
{phang2}{cmd:. stqa_cmdline "do examples/test_yaml.do", id(EX-02) log("qa/logs/ex02.log")}{p_end}

{pstd}Insisting it reached the end, not merely that it did not error{p_end}
{phang2}{cmd:. stqa_cmdline "do examples/demo.do", id(EX-03) log("qa/logs/ex03.log") sentinel("DEMO COMPLETE")}{p_end}

{pstd}A sweep in which every failure must be reported{p_end}
{phang2}{cmd:. foreach e of local examples {c -(}}{p_end}
{phang2}{cmd:.     stqa_cmdline "`e'", id(DOC-03) msg("`e'") soft}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}A command that is supposed to fail{p_end}
{phang2}{cmd:. stqa_cmdline "use no_such_file.dta", id(ERR-04) rc(601)}{p_end}
