{smcl}
{* *! version 2.0.0  06aug2026}{...}
{viewerjumpto "Syntax" "stqa_scanlog##syntax"}{...}
{viewerjumpto "Description" "stqa_scanlog##description"}{...}
{viewerjumpto "Why Mata" "stqa_scanlog##whymata"}{...}
{viewerjumpto "What counts" "stqa_scanlog##counts"}{...}
{viewerjumpto "Stored results" "stqa_scanlog##results"}{...}
{viewerjumpto "Examples" "stqa_scanlog##examples"}{...}
{title:Title}

{phang}
{bf:stqa_scanlog} {hline 2} Read a suite log and report what it actually says

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_scanlog}
{cmd:using} {it:logfile}

{pstd}
The log may also be given positionally, {cmd:stqa_scanlog} {it:logfile}, for
convenience inside runners. There are no options: the command reports, it does
not judge.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_scanlog} opens a Stata log written by a {help stataqa} suite and
counts the verdict tokens it contains. It reports how many checks passed, how
many failed, how many were skipped, which test ids failed, and -- the field
that matters most -- whether the run reached its {it:completion sentinel}.

{pstd}
A suite is green only if its log carries the sentinel {bf:and} has zero
line-initial {cmd:FAIL:} tokens. Either one alone is insufficient. A suite that
was killed, hung or crashed leaves behind a log full of {cmd:PASS:} lines and
no sentinel, and must never be recorded green. That is what {cmd:r(done)} is
for.

{pstd}
Verdicts are read from the log and never from a batch exit code. Under Windows,
batch Stata returns exit codes that cannot be relied upon and may hang after
finishing its work, so the log is the only trustworthy artefact.

{pstd}
A {bf:missing} log file is reported, not raised as an error. {cmd:r(done)} is
set to 0 and a message is displayed. Aborting with r(601) here would destroy
the evidence in exactly the case the sentinel exists to catch: the run that
never produced a log at all.

{marker whymata}{...}
{title:Why the scanner is written in Mata}

{pstd}
This is not a style preference. A Stata log echoes the suite's own source code,
and that source is full of backticks and compound double quotes. The ordinary
Stata idiom for reading a file line by line ends up wrapping the line just read
in compound quotes and passing it to a string function such as {cmd:trim()}.
The moment a line carrying an opening backtick, or an odd number of double
quotes, reaches that macro-expanded string expression, the quote closes early
and the reader dies with {err:too few quotes}, r(132) -- on a log that is
perfectly well formed.

{pstd}
Mata reads the file as {it:data}, with {cmd:cat()}. Nothing in the content is
ever offered to the parser, so no log can break the scanner that reads it.

{marker counts}{...}
{title:What counts}

{pstd}
{bf:Verdicts} are counted only when the line {bf:starts} with the token, after
leading whitespace and any leading SMCL directives are removed:

{p 8 8 2}{cmd:PASS: }{it:id description}{p_end}
{p 8 8 2}{cmd:FAIL: }{it:id description}{p_end}
{p 8 8 2}{cmd:SKIP: }{it:id reason}{p_end}

{pstd}
The line-initial rule is load-bearing. Stata echoes the suite's own source into
the log, and those echoes begin with a period or with a line number, so an
echoed {cmd:display} statement does not inflate the count. This is why the
{help stataqa} contract requires verdict tokens to be emitted at the start of a
line.

{pstd}
{bf:The sentinel} is detected anywhere on a line. Both current spellings are
recognised,

{p 8 8 2}{cmd:ALL CHECKS PASSED} ({it:n} checks){p_end}
{p 8 8 2}{cmd:STATAQA SUITE COMPLETE} ({it:n} checks, {it:f} failed){p_end}

{pstd}
as are the legacy spellings {cmd:ALL SMOKE TESTS PASSED}, {cmd:ALL TESTS PASSED}
and {cmd:ACCEPTANCE PASSED}, so that logs written by earlier runners remain
legible. Both current spellings mean "the suite ran to completion"; only the
first also means green.

{pstd}
{bf:Skips} are counted from a line-initial {cmd:SKIP: } token or from the
marker {cmd:Fixtures missing} (matched without regard to case). At most one
skip is counted per line, so a line reading {cmd:SKIP: T004 Fixtures missing}
counts once. A skipped test is never counted as passed and never as failed: a
missing prerequisite is not a defect in the code under test.

{pstd}
Logs opened with the {cmd:text} option are the expected input, but a SMCL log
is read correctly too: leading {cmd:{c -(}res{c )-}}-style directives are
stripped before the line-initial test is applied.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:stqa_scanlog} is {cmd:rclass}. It stores:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(pass)}}number of line-initial {cmd:PASS:} tokens{p_end}
{synopt:{cmd:r(fail)}}number of line-initial {cmd:FAIL:} tokens{p_end}
{synopt:{cmd:r(skip)}}number of skipped checks{p_end}
{synopt:{cmd:r(done)}}1 if the completion sentinel was found, 0 otherwise{p_end}
{synopt:{cmd:r(counted)}}failures counted from line-initial tokens{p_end}
{synopt:{cmd:r(declared)}}failures declared by the closing sentinel{p_end}
{synopt:{cmd:r(stataqa)}}1 if the log carries any marker only {cmd:stataqa} writes
(a verdict token, a completion sentinel, or the version watermark), 0 if it
carries none. A log with no markers may still be a genuine run that died
before its first test, so this reports what was found, not what the file is{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(ids)}}space-separated ids of the failed checks{p_end}
{synopt:{cmd:r(logversion)}}the version of {cmd:stataqa} the log says wrote it,
empty for a log written before 2.5.0, when the watermark was introduced{p_end}
{p2colreset}{...}

{pstd}
The ids in {cmd:r(ids)} are stripped of backticks, dollar signs and quotes
before being returned, so that a malformed log cannot break the caller either.

{pstd}
{cmd:stqa_scanlog} always exits 0, including on a log full of failures. The
gate decision belongs to the caller ({help stqa_run}), which owns the counters
and the closing banner.

{marker examples}{...}
{title:Examples}

{pstd}1. Scan one suite log{p_end}
{phang2}{cmd:. stqa_scanlog using "qa/logs/smoke.log"}{p_end}

{pstd}2. Decide a gate the way a runner does{p_end}
{phang2}{cmd:. quietly stqa_scanlog using "qa/logs/smoke.log"}{p_end}
{phang2}{cmd:. if (r(done)==1 & r(fail)==0) di as result "suite green"}{p_end}
{phang2}{cmd:. else if (r(done)==0) di as error "suite did not finish"}{p_end}
{phang2}{cmd:. else di as error "failed: " r(ids)}{p_end}

{pstd}3. Roll the counts into the shared globals{p_end}
{phang2}{cmd:. quietly stqa_scanlog using "qa/logs/smoke.log"}{p_end}
{phang2}{cmd:. global stqa_n_pass = $stqa_n_pass + r(pass)}{p_end}
{phang2}{cmd:. global stqa_n_fail = $stqa_n_fail + r(fail)}{p_end}

{title:See also}

{pstd}
{help stqa_history}, {help stqa_run}, {help stqa_test}, {help stqa_skip},
{help stataqa:stataqa hub}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
