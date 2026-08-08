{smcl}
{* *! version 2.2.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_cmdline" "help stqa_cmdline"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{vieweralsosee "stqa_fail" "help stqa_fail"}{...}
{viewerjumpto "Syntax" "stqa_examples##syntax"}{...}
{viewerjumpto "Description" "stqa_examples##description"}{...}
{viewerjumpto "Two sources" "stqa_examples##sources"}{...}
{viewerjumpto "Options" "stqa_examples##options"}{...}
{viewerjumpto "Which examples are skipped, and by whom" "stqa_examples##skips"}{...}
{viewerjumpto "Stored results" "stqa_examples##results"}{...}
{viewerjumpto "Examples" "stqa_examples##examples"}{...}
{title:Title}

{phang}
{bf:stqa_examples} {hline 2} Harvest and run the examples that ship with a package

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_examples} {cmd:using} {it:filename}
[{cmd:,}
{opt ext:ract}
{opt list}
{opt skip(regex)}
{opt nonint:eractive}
{opt disp:atch(command)}
{opt id(string)}
{opt logd:ir(path)}
{opt soft}
{opt noi:sily}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_examples} reads the examples a user can actually run and runs them,
booking a verdict for each.  It is the mechanism behind {it:documentation as
tests}: a help file whose examples are never executed drifts away from the code
it documents, and nothing notices until a user pastes one and it fails.

{pstd}
On success it returns rc 0.  If any example fails it emits a {cmd:FAIL:} token
per failure, sets {cmd:$stqa_block_failed}, and exits 9 {hline 2} or, with
{opt soft}, returns rc 0 so a sweep reports every broken example rather than
stopping at the first.  That is usually what you want here: the value of an
example suite is {it:which} of the fifty broke.

{marker sources}{...}
{title:Two sources}

{pstd}
The file extension selects the reader.  Both reduce to the same thing, a list of
commands, so everything downstream is shared.

{phang}
{bf:.sthlp} {hline 2} every {cmd:{c -(}stata ...{c )-}} directive, which is
exactly the set of examples a reader can click.  Five directive shapes occur in
real help files and all five are handled, including
{cmd:{c -(}stata `"use "`r(fn)'""'{c )-}} {hline 2} a compound-quoted command
wrapping an inner quoted macro.  The reader is written in Mata for that reason:
pulling such a line through a macro-expanded string expression closes the quote
early and dies with r(132), or silently expands the macro while merely reading
it.  Prose code blocks are not covered, because they are not executable and
nothing claims they are.

{phang}
{bf:.ado} {hline 2} an examples {it:gallery}: a file of
{cmd:program} {it:name} ... {cmd:end} blocks, each a multi-line example that a
dispatcher invokes by name (the pattern of {cmd:wbopendata_examples.ado}).  Both
{cmd:program name} and {cmd:program define name} are recognised.  The gallery's
own entry point {hline 2} the program named after the file {hline 2} is not an
example and is excluded.  The file is {helpb run} once so its programs exist,
which is more reliable than trusting the ado-path to resolve a copy: the copy on
the ado-path may not be the one under test, and testing the wrong copy is the
failure a suite exists to prevent.

{marker options}{...}
{title:Options}

{phang}
{opt extract} harvest without running.  The commands come back in
{cmd:r(cmd1)}, {cmd:r(cmd2)}, ... so the caller can filter or reorder them and
run them itself.

{phang}
{opt list} print the harvest, marking what would be skipped and why, and run
nothing.  Use it before wiring a gallery into a suite.

{phang}
{opt skip(regex)} exclude examples whose command matches {it:regex}.

{phang}
{opt noninteractive} exclude commands beginning {cmd:doedit}, {cmd:edit},
{cmd:browse}, {cmd:view}, {cmd:help}, {cmd:net}, {cmd:ssc}, {cmd:shell},
{cmd:winexec}, {cmd:exit}, {cmd:update} or {cmd:db}.  Each opens a window, waits
for input, fetches over the network, or ends the session.  The list is printed
here rather than hidden in the code because it is a judgement, not a fact.

{phang}
{opt dispatch(command)} for a gallery, invoke each example as
{it:command} {it:name} instead of calling {it:name} directly.  Use it when the
examples are only reachable through their dispatcher.

{phang}
{opt id(string)} the id used in verdict tokens.  Defaults to
{cmd:$stqa_test_id}, then to {cmd:DOC}.

{phang}
{opt logdir(path)} write each example's output to
{it:path}{cmd:/example_}{it:n}{cmd:.log}, so a failure can be diagnosed without
re-running the suite.

{phang}
{opt soft} book failures and return rc 0.

{phang}
{opt noisily} show each example's output, and the reason for every skip.

{marker skips}{...}
{title:Which examples are skipped, and by whom}

{pstd}
Two kinds of exclusion, kept apart deliberately.

{phang}
{bf:Structural} exclusions are mechanical facts about the text and are applied
always: an empty directive, and {hline 2} for help files {hline 2} one whose
parentheses do not balance or which ends in {cmd:///}, both of which mean the
example was wrapped across lines in the source and has arrived truncated.
Running half a command tests nothing.

{phang}
{bf:Policy} exclusions are yours.  Which examples are too slow, too destructive
or too interactive to run in a suite is a judgement about a particular package,
and this command will not make it for you.  Supply {opt skip()}, or opt into the
named convenience set with {opt noninteractive}.

{pstd}
Every skip is counted and reported.  A skipped example is never a pass: an
example suite that quietly stopped running most of its examples still looks
green, which is the failure mode this distinction exists to prevent.

{marker results}{...}
{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(n_found)}}examples harvested{p_end}
{synopt:{cmd:r(n_run)}}examples executed{p_end}
{synopt:{cmd:r(n_skipped)}}examples excluded{p_end}
{synopt:{cmd:r(n_failed)}}examples that returned nonzero{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(cmd}{it:n}{cmd:)}}the {it:n}th harvested command{p_end}
{synopt:{cmd:r(skipped)}}indices of the excluded examples{p_end}
{synopt:{cmd:r(failed)}}indices of the failed examples{p_end}
{synopt:{cmd:r(source)}}{cmd:sthlp} or {cmd:ado}{p_end}
{synopt:{cmd:r(helpfile)}}the file read{p_end}

{marker examples}{...}
{title:Examples}

{pstd}See what is there before running anything{p_end}
{phang2}{cmd:. stqa_examples using "src/u/unicefdata.sthlp", list noninteractive}{p_end}

{pstd}Run every clickable example in a help file, reporting all failures{p_end}
{phang2}{cmd:. stqa_test DOC-01 "every clickable example in the help file runs"}{p_end}
{phang2}{cmd:.     stqa_examples using "src/w/wbopendata.sthlp", noninteractive soft logdir("qa/logs/doc")}{p_end}
{phang2}{cmd:.     stqa_assert r(n_failed) == 0, msg("`r(n_failed)' of `r(n_run)' examples failed")}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}Run a multi-line examples gallery{p_end}
{phang2}{cmd:. stqa_examples using "src/w/wbopendata_examples.ado", skip("example01|example02") soft}{p_end}

{pstd}Harvest and filter yourself{p_end}
{phang2}{cmd:. stqa_examples using "src/y/yaml.sthlp", extract}{p_end}
{phang2}{cmd:. forvalues i = 1/`r(n_found)' {c -(}}{p_end}
{phang2}{cmd:.     local c `"`r(cmd`i')'"'}{p_end}
{phang2}{cmd:.     if !regexm(`"`c'"', "^yaml write") stqa_cmdline `"`c'"', id(DOC-02) soft}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}A ratchet, for a package whose examples are not all fixable today{p_end}
{phang2}{cmd:. stqa_examples using "src/d/datalib.sthlp", noninteractive soft}{p_end}
{phang2}{cmd:. stqa_assert r(n_failed) <= 5, msg("baseline 5; the count must not grow")}{p_end}
