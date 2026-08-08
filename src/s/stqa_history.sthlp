{smcl}
{* *! version 2.0.0  06aug2026}{...}
{viewerjumpto "Syntax" "stqa_history##syntax"}{...}
{viewerjumpto "Description" "stqa_history##description"}{...}
{viewerjumpto "Options" "stqa_history##options"}{...}
{viewerjumpto "The stanza" "stqa_history##stanza"}{...}
{viewerjumpto "Check mode" "stqa_history##check"}{...}
{viewerjumpto "Stored results" "stqa_history##results"}{...}
{viewerjumpto "Examples" "stqa_history##examples"}{...}
{title:Title}

{phang}
{bf:stqa_history} {hline 2} Append-only certification ledger for gate runs

{marker syntax}{...}
{title:Syntax}

{pstd}Record a run{p_end}
{p 8 17 2}
{cmd:stqa_history}
[{cmd:using} {it:filename}]
[{cmd:,} {opt verd:ict(string)} {opt not:es(string)} {opt startt:ime(string)} {opt endt:ime(string)}]

{pstd}Read the last record back{p_end}
{p 8 17 2}
{cmd:stqa_history}
[{cmd:using} {it:filename}]
{cmd:, check}

{pstd}
{it:filename} defaults to {cmd:qa/test_history.txt}.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_history} appends one structured stanza per gate run to a ledger file:
the date, the start and end times, the elapsed duration, the git branch, the
installed {cmd:stataqa} version, the Stata version and flavour, the counts of
checks run, passed, failed and skipped, the ids of the failed checks, the skip
notes, any free-text note, and the verdict.

{pstd}
The ledger is {bf:append only}. There is deliberately no {cmd:replace} option.
A red run and an incomplete run are recorded in exactly the same shape as a
green one -- this is Gould's (2001) principle that tests are never thrown away,
applied to the record of the runs themselves. The alternative, a hand-maintained
green snapshot, once asserted success about a run that had in fact hung. A file
that can only grow cannot tell that lie.

{pstd}
Counts are taken from the live global counters {cmd:$stqa_n_total},
{cmd:$stqa_n_pass}, {cmd:$stqa_n_fail} and {cmd:$stqa_n_skip}, and the failed
ids and skip notes from {cmd:$stqa_failed_ids} and {cmd:$stqa_skip_notes}, so
the stanza can never drift from what actually ran. Globals are used rather than
locals because they survive the {cmd:clear all} that test files issue.

{pstd}
{bf:Single-test mode is refused.} If {cmd:$stqa_target} is non-empty, only one
check ran; nothing is appended and the command says so on screen. A partial run
is not a gate record.

{pstd}
The branch is obtained by running {cmd:git branch --show-current}, redirecting
its output to a temporary file, and then {bf:reading that file}. Under Windows
{cmd:shell} returns 0 whether or not the command it launched succeeded, so its
return code proves nothing; the artefact is what is judged. Content containing a
space is rejected, because a branch name never contains one, which discards
shell and git error text that lands in the same file. If the branch cannot be
established it is recorded as {cmd:(unknown)} -- a missing branch name is worth
less than a lost gate record.

{pstd}
The package version is parsed from the {cmd:*! version X.Y.Z} header of the
{bf:installed} {cmd:stataqa.ado}, located with {help which}, so the ledger
records the version that actually ran rather than a constant compiled into this
file.

{pstd}
The Stata flavour is taken from {cmd:c(MP)} and {cmd:c(SE)}, not from
{cmd:c(flavor)} alone: {cmd:c(flavor)} reports {cmd:IC} on a Stata/MP
installation, and a ledger built from it would certify the wrong binary.

{marker options}{...}
{title:Options}

{phang}
{cmd:using} {it:filename} names the ledger. Default {cmd:qa/test_history.txt};
the {cmd:qa} directory is created if the default is used.

{phang}
{opt verdict(string)} records the verdict verbatim. Callers that hold the
sentinel result from {help stqa_scanlog} should pass it. When omitted, the
verdict is derived from the counters: {cmd:GATE RED} if any check failed,
{cmd:INCOMPLETE} if no check was counted at all, {cmd:GATE GREEN} otherwise. A
suite that never ran is not a suite that passed, which is why an empty run is
{cmd:INCOMPLETE} and not green.

{phang}
{opt notes(string)} free text recorded in the stanza -- the trigger, the CI job,
the reason the run was made.

{phang}
{opt starttime(string)} the wall time the run began, {cmd:HH:MM:SS}, normally
captured with {cmd:local t0 = c(current_time)} before the suites start. Defaults
to the end time, giving a zero duration.

{phang}
{opt endtime(string)} the wall time the run finished, {cmd:HH:MM:SS}. Defaults
to {cmd:c(current_time)}.

{phang}
{opt check} reads the {bf:last} stanza of the ledger and returns its fields in
{cmd:r()} instead of writing anything. See {it:Check mode} below.

{pstd}
Duration is computed from the two clock times with a midnight-wraparound
correction: {cmd:c(current_time)} is a clock, not a stopwatch, so a run that
crosses 00:00:00 yields a negative difference, to which one day is added. One
day is the only correction it is safe to assume -- a suite still running 24
hours later is not a suite anybody is waiting on. Unparseable times are
recorded as duration {cmd:(unknown)} rather than as a wrong number.

{marker stanza}{...}
{title:The stanza}

{pstd}
Every field is written on every run, including the empty ones, so that the
record has a uniform shape for a reader:

{p 8 8 2}{c -(}78 equals signs{c )-}{p_end}
{p 8 8 2}{cmd:Test Run:   6 Aug 2026}{p_end}
{p 8 8 2}{cmd:Started:    14:03:11}{p_end}
{p 8 8 2}{cmd:Ended:      14:07:52}{p_end}
{p 8 8 2}{cmd:Duration:   4m 41s}{p_end}
{p 8 8 2}{cmd:Branch:     dev}{p_end}
{p 8 8 2}{cmd:Version:    2.0.0}{p_end}
{p 8 8 2}{cmd:Stata:      18 MP (Windows)}{p_end}
{p 8 8 2}{cmd:Run:        12}{p_end}
{p 8 8 2}{cmd:Passed:     10}{p_end}
{p 8 8 2}{cmd:Failed:     1}{p_end}
{p 8 8 2}{cmd:Skipped:    1}{p_end}
{p 8 8 2}{cmd:Failed IDs: T007}{p_end}
{p 8 8 2}{cmd:Skip notes: T011: fixtures missing}{p_end}
{p 8 8 2}{cmd:Notes:      nightly}{p_end}
{p 8 8 2}{cmd:Result:     GATE RED}{p_end}
{p 8 8 2}{c -(}78 equals signs{c )-}{p_end}

{marker check}{...}
{title:Check mode}

{pstd}
{cmd:stqa_history, check} reads the last stanza and returns its fields. This is
what CI runs to validate the record without re-running any Stata tests: the
ledger is the artefact, so the ledger is what gets inspected.

{pstd}
The stanza is parsed in Mata, for the same reason {help stqa_scanlog} is written
in Mata: the ledger carries free text supplied by whoever ran the suite, and a
line carrying an opening backtick or an odd number of double quotes breaks a
macro-expanded read with {err:too few quotes}, r(132). Mata reads the file as
data, so the ledger can never break the command that reads it. Values are
additionally stripped of backticks, dollar signs and quotes before being
returned.

{pstd}
A missing ledger, or one with no run stanza in it, sets {cmd:r(found)=0} and
displays a message rather than aborting.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:stqa_history} is {cmd:rclass}. Writing, it stores:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(written)}}1 if a stanza was appended, 0 otherwise{p_end}
{synopt:{cmd:r(run)}}checks run{p_end}
{synopt:{cmd:r(pass)}}checks passed{p_end}
{synopt:{cmd:r(fail)}}checks failed{p_end}
{synopt:{cmd:r(skip)}}checks skipped{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(verdict)}}the verdict written{p_end}
{synopt:{cmd:r(file)}}the ledger written to{p_end}
{synopt:{cmd:r(branch)}}git branch recorded{p_end}
{synopt:{cmd:r(version)}}{cmd:stataqa} version recorded{p_end}
{synopt:{cmd:r(duration)}}elapsed time recorded{p_end}
{p2colreset}{...}

{pstd}
In {cmd:check} mode it stores:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(found)}}1 if a stanza was read, 0 otherwise{p_end}
{synopt:{cmd:r(green)}}1 if the recorded verdict is exactly {cmd:GATE GREEN}{p_end}
{synopt:{cmd:r(run)}, {cmd:r(pass)}, {cmd:r(fail)}, {cmd:r(skip)}}counts from the stanza{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(date)}, {cmd:r(start)}, {cmd:r(end)}, {cmd:r(duration)}}when the run happened{p_end}
{synopt:{cmd:r(branch)}, {cmd:r(version)}, {cmd:r(stata)}}what was tested, and where{p_end}
{synopt:{cmd:r(ids)}}ids of the failed checks{p_end}
{synopt:{cmd:r(skipnotes)}}skip notes{p_end}
{synopt:{cmd:r(notes)}}free-text note{p_end}
{synopt:{cmd:r(verdict)}}the recorded verdict{p_end}
{synopt:{cmd:r(file)}}the ledger read{p_end}
{p2colreset}{...}

{marker examples}{...}
{title:Examples}

{pstd}1. Record a run{p_end}
{phang2}{cmd:. local t0 = c(current_time)}{p_end}
{phang2}{cmd:. stqa_run "tests"}{p_end}
{phang2}{cmd:. stqa_history, starttime("`t0'") notes("nightly")}{p_end}

{pstd}2. Record a run whose verdict came from the sentinel{p_end}
{phang2}{cmd:. quietly stqa_scanlog using "qa/logs/smoke.log"}{p_end}
{phang2}{cmd:. local v = cond(r(done)==0, "INCOMPLETE", cond(r(fail)>0, "GATE RED", "GATE GREEN"))}{p_end}
{phang2}{cmd:. stqa_history, starttime("`t0'") verdict("`v'")}{p_end}

{pstd}3. Validate the record in CI{p_end}
{phang2}{cmd:. stqa_history using "qa/test_history.txt", check}{p_end}
{phang2}{cmd:. if (r(found)==0 | r(green)==0) exit 9}{p_end}

{pstd}4. Keep the ledger somewhere else{p_end}
{phang2}{cmd:. stqa_history using "ci/gate_ledger.txt", verdict("GATE GREEN")}{p_end}

{title:Reference}

{pstd}
Gould, W. 2001. Statistical software certification. {it:Stata Journal} 1(1):
29-50.

{title:See also}

{pstd}
{help stqa_scanlog}, {help stqa_run}, {help stqa_test}, {help stqa_skip},
{help stataqa:stataqa hub}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
