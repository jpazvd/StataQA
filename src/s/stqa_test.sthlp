{smcl}
{* *! version 2.1.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_endtest" "help stqa_endtest"}{...}
{vieweralsosee "stqa_assert" "help stqa_assert"}{...}
{vieweralsosee "stqa_skip" "help stqa_skip"}{...}
{vieweralsosee "stqa_target" "help stqa_target"}{...}
{vieweralsosee "stqa_families" "help stqa_families"}{...}
{viewerjumpto "Syntax" "stqa_test##syntax"}{...}
{viewerjumpto "Description" "stqa_test##description"}{...}
{viewerjumpto "Test ids" "stqa_test##ids"}{...}
{viewerjumpto "Test families" "stqa_test##families"}{...}
{viewerjumpto "Targeting" "stqa_test##targeting"}{...}
{viewerjumpto "Verbose tracing" "stqa_test##verbose"}{...}
{viewerjumpto "Globals" "stqa_test##globals"}{...}
{viewerjumpto "Examples" "stqa_test##examples"}{...}
{title:Title}

{phang}
{bf:stqa_test} {hline 2} Open a test block

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_test} {cmd:"}{it:description}{cmd:"}

{p 8 17 2}
{cmd:stqa_test} {it:id} {cmd:"}{it:description}{cmd:"}

{pstd}
A block opened by {cmd:stqa_test} must be closed by {help stqa_endtest}.  The
verdict token for the block is emitted by {cmd:stqa_endtest}, never by
{cmd:stqa_test}.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_test} opens a test block.  It records the block's id and description,
clears the per-block failure flag, prints a {cmd:[TEST]} banner, and honours
single-test targeting.

{pstd}
Everything between {cmd:stqa_test} and {cmd:stqa_endtest} is the block body.  A
body is ordinary Stata code; assertions such as {help stqa_assert} report
against the id of the open block.

{pstd}
Exactly one verdict line is written per block, always at column 1 so that a log
scanner can count line-initial tokens:

{p 8 8 2}{cmd:PASS: }{it:id}{cmd: }{it:description} {space 3}the block ran clean{p_end}
{p 8 8 2}{cmd:FAIL: }{it:id}{cmd: }{it:description} {space 3}emitted by the failing assertion{p_end}
{p 8 8 2}{cmd:SKIP: }{it:id}{cmd: }{it:reason} {space 6}emitted by {help stqa_skip}{p_end}

{marker ids}{...}
{title:Test ids}

{pstd}
The single-argument form assigns an automatic id of the form {cmd:T001},
{cmd:T002}, ... taken from the running block counter {cmd:$stqa_n_total}.  The
two-argument form takes an explicit id, which is what makes a test addressable
by {help stqa_target} and legible in a verdict token.  Explicit ids are strongly
preferred for anything a report or a CI job will refer to.

{pstd}
An id is a single token, and its expected form is
{it:FAMILY}{cmd:-}{it:NN}: {cmd:DET-01}, {cmd:ERR-07}, {cmd:XPLAT-05}.  A
description with blanks must be quoted; an unquoted multi-word description is
accepted and taken whole, but quoting is clearer.  A lone argument is always
read as the description, never as an id:

{p 8 12 2}{cmd:. stqa_test DET-01} {space 8}opens a block described "DET-01" with an auto id{p_end}

{pstd}
{cmd:$stqa_n_total} counts blocks {it:encountered} and is incremented for every
{cmd:stqa_test}, including blocks that targeting switches off, so automatic ids
do not shift between a full run and a targeted run.

{marker families}{...}
{title:Test families}

{pstd}
A test id is not an internal label.  It escapes into the certification ledger
({cmd:Failed IDs: DET-03}), into CI record validation, into commit messages and
into issue trackers.  Sequential identifiers renumber the moment a test is
inserted, and at that point the ledger's own history stops being interpretable:
{cmd:T007} in March is not {cmd:T007} in August, single-test targeting silently
runs the wrong test, and a regression cannot be bisected across the record.
That is why stable, semantic identifiers are the default, and why the family
prefix carries the failure mode: a reader knows what {cmd:DET-03} exercises
without opening it.

{pstd}
The form is {it:FAMILY}{cmd:-}{it:NN}, where {it:FAMILY} is 2 to 8 characters
from {cmd:A-Z 0-9} and {it:NN} is a zero-padded integer of at least two digits.
Family codes are {bf:upper case}: {cmd:det-01} is not {cmd:DET-01} spelled
differently, it is an id the package's own validator rejects.  The families
themselves live in {helpb stqa_families}, which is also where a package
declares one of its own.

{pstd}
After it resolves an id, {cmd:stqa_test} classifies it and, {it:only} when
something is worth saying, prints a note.  The common case is silent.

{p 8 12 2}{bf:well formed, known family} {space 3}nothing is printed;{p_end}
{p 8 12 2}{bf:well formed, unknown family} {space 1}a one-line note the {it:first}
time that family is seen in a run, suggesting
{cmd:stqa_families, add()};{p_end}
{p 8 12 2}{bf:auto id} ({cmd:T001}) {space 14}legal, and silent here; the run
is warned about it by {helpb stqa_run} at the point where it would be written
to the history ledger;{p_end}
{p 8 12 2}{bf:anything else} {space 15}one note per run, naming the id.{p_end}

{pstd}
{bf:These are notes, never failures.}  A taxonomy problem cannot turn a passing
suite red and cannot abort a test.  Every call to {cmd:stqa_families} is
captured, so a {cmd:stqa_families} that is missing, not yet installed or
erroring degrades to {it:no} validation rather than breaking every test in
every suite.

{marker targeting}{...}
{title:Targeting}

{pstd}
When {cmd:$stqa_target} is non-empty, only the block whose id matches it
produces a verdict.  For every other block {cmd:stqa_test} sets
{cmd:$stqa_skip_block} to {cmd:1}, which makes the block's assertions no-ops and
makes {help stqa_endtest} emit nothing at all: a block switched off by targeting
is not a pass, not a failure, and not a reported skip.

{pstd}
When {cmd:$stqa_target_family} is non-empty, the same mechanism keeps only the
blocks whose family is in that space-separated list; this is what
{cmd:stataqa run, family()} sets.  An id with no family never matches a family
filter.  The two filters are {bf:ANDed}: setting both selects the intersection,
so {cmd:test(DET-01)} together with {cmd:family(ERR)} runs nothing.

{pstd}
{bf:Honest limitation.}  A Stata program cannot skip the lines that follow it in
a do-file.  {cmd:stqa_test} therefore cannot stop the body from executing; it can
only neutralise the harness commands inside it.  Ordinary Stata code in the body
of a targeted-out block {it:still runs}.  If a body does expensive or destructive
work, guard it yourself:

{phang2}{cmd:. stqa_test DET-01 "Slow fixture"}{p_end}
{phang2}{cmd:.     if "$stqa_skip_block" != "1" {c -(}}{p_end}
{phang2}{cmd:.         use "big_fixture.dta", clear}{p_end}
{phang2}{cmd:.         stqa_assert _N > 0}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{marker verbose}{...}
{title:Verbose tracing}

{pstd}
When {cmd:$stqa_verbose} is {cmd:"1"}, {cmd:stqa_test} issues {cmd:set tracedepth 4}
and {cmd:set trace on}.

{pstd}
{bf:Honest limitation.}  Stata restores the {help trace} setting to its value on
entry when the program that changed it exits, so this traces the tail of
{cmd:stqa_test} only -- it cannot trace the do-file lines of the block body.
Tracing of test bodies has to be switched on by a caller that is still on the
stack while the body runs, that is by {cmd:stataqa run} around its {cmd:do} of
the test file, or by hand at the top of the test file:

{phang2}{cmd:. set tracedepth 4}{p_end}
{phang2}{cmd:. set trace on}{p_end}

{marker globals}{...}
{title:Globals}

{pstd}
The harness carries its state in globals, not locals, because test files are free
to issue {cmd:clear all}.  {cmd:stqa_test} writes:

{p 8 8 2}{cmd:$stqa_n_total} {space 5}blocks encountered so far (incremented always){p_end}
{p 8 8 2}{cmd:$stqa_test_id} {space 5}id of the open block{p_end}
{p 8 8 2}{cmd:$stqa_test_name} {space 3}description of the open block{p_end}
{p 8 8 2}{cmd:$stqa_block_failed} {space 1}cleared at open{p_end}
{p 8 8 2}{cmd:$stqa_skip_block} {space 2}{cmd:1} when the block is switched off by targeting, cleared otherwise{p_end}

{pstd}
and, for the taxonomy:

{p 8 8 2}{cmd:$stqa_families_seen} {space 2}families of the blocks that actually ran, space separated{p_end}
{p 8 8 2}{cmd:$stqa_used_autoids} {space 3}{cmd:1} once a block that ran was given an auto id{p_end}
{p 8 8 2}{cmd:$stqa_families_noted} {space 1}unknown families already noted, so each is noted once{p_end}
{p 8 8 2}{cmd:$stqa_badid_noted} {space 4}the id that drew the malformed-id note, so it is drawn once{p_end}
{p 8 8 2}{cmd:$stqa_families_ok} {space 4}{cmd:1} when {helpb stqa_families} answered the one-shot probe{p_end}

{pstd}
It reads {cmd:$stqa_target}, {cmd:$stqa_target_family} and
{cmd:$stqa_verbose}.  All of these are reset by {helpb stqa_run} at the start
of a run.  {cmd:$stqa_families_seen} describes what ran, so it is written after
targeting, not before; note that a test file is free to issue {cmd:clear all},
which drops it, and that is why the runner's per-family table is read back out
of the case logs rather than out of this global.

{marker examples}{...}
{title:Examples}

{pstd}Automatic id:{p_end}
{phang2}{cmd:. stqa_test "Basic arithmetic"}{p_end}
{phang2}{cmd:.     stqa_assert 1 + 1 == 2}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}Explicit id, which targeting and reports can address:{p_end}
{phang2}{cmd:. stqa_test DET-01 "Fixture loads"}{p_end}
{phang2}{cmd:.     use "fixtures/det.dta", clear}{p_end}
{phang2}{cmd:.     stqa_assert _N == 1000, msg("fixture row count changed")}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}Run that one block only:{p_end}
{phang2}{cmd:. stqa_target DET-01}{p_end}
{phang2}{cmd:. do tests/test_det.do}{p_end}
{phang2}{cmd:. stqa_target, clear}{p_end}

{pstd}Run every block in two families, and see the meaning of a family:{p_end}
{phang2}{cmd:. stataqa run, family(DET ERR)}{p_end}
{phang2}{cmd:. stqa_families DET}{p_end}

{pstd}Use a family of your own, declared once at the top of the test file:{p_end}
{phang2}{cmd:. stqa_families, add(WASH "JMP ladder checks")}{p_end}
{phang2}{cmd:. stqa_test WASH-01 "Ladder codes are ALB/SM"}{p_end}
{phang2}{cmd:.     stqa_assert 1 == 1}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}
