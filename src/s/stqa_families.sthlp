{smcl}
{* *! version 2.1.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_test" "help stqa_test"}{...}
{vieweralsosee "stqa_target" "help stqa_target"}{...}
{vieweralsosee "stqa_run" "help stqa_run"}{...}
{vieweralsosee "stqa_history" "help stqa_history"}{...}
{viewerjumpto "Syntax" "stqa_families##syntax"}{...}
{viewerjumpto "Description" "stqa_families##description"}{...}
{viewerjumpto "Options" "stqa_families##options"}{...}
{viewerjumpto "Why ids are stable, not sequential" "stqa_families##why"}{...}
{viewerjumpto "The id format" "stqa_families##format"}{...}
{viewerjumpto "The core families" "stqa_families##families"}{...}
{viewerjumpto "Package-specific families" "stqa_families##extra"}{...}
{viewerjumpto "Stored results" "stqa_families##results"}{...}
{viewerjumpto "Examples" "stqa_families##examples"}{...}
{title:Title}

{phang}
{bf:stqa_families} {hline 2} The test-family vocabulary

{marker syntax}{...}
{title:Syntax}

{pstd}List the core families as a table{p_end}
{p 8 17 2}
{cmd:stqa_families}

{pstd}Describe one family{p_end}
{p 8 17 2}
{cmd:stqa_families} {it:family}

{pstd}Return the codes only{p_end}
{p 8 17 2}
{cmd:stqa_families}{cmd:,} {opt codes}

{pstd}Parse and check a test id{p_end}
{p 8 17 2}
{cmd:stqa_families}{cmd:,} {opt val:idate(id)}

{pstd}Register a package-specific family for this session{p_end}
{p 8 17 2}
{cmd:stqa_families}{cmd:,} {opt add(code "meaning")}

{pstd}
One form per call.  The forms answer different questions, so their stored
results mean different things and cannot be combined.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_families} is the package's machine-readable statement of the test-family
taxonomy: the sixteen family codes that give a test id its {cmd:FAMILY-NN} form,
what each one means, and whether a given id conforms.

{pstd}
It exists so that the taxonomy is stated in {it:one} place.  A command that needs
to know whether {cmd:DET-03} is a legitimate id asks {cmd:stqa_families}; it does
not carry a hardcoded family list of its own.  Inside this command the same rule
holds: the display path, the codes path, the lookup path and the validator all
read a single table, so the roster shown to a human and the roster enforced on a
machine cannot drift apart.

{pstd}
Nothing here is enforced at run time.  {help stqa_test} accepts any single token
as an id.  {cmd:stqa_families} is what a runner, a linter or a ledger writer uses
to say that an id is off-vocabulary, and what a reader uses to find out what a
family covers.

{marker options}{...}
{title:Options}

{phang}
{opt codes} displays the family codes on one line, space separated, and returns
them in {cmd:r(families)}.  This is the form a caller uses when it wants the
roster rather than the prose.

{phang}
{opt validate(id)} parses one test id and reports whether it is well formed and
whether its family is on the roster.  It displays nothing when the id conforms;
a malformed id draws a message naming the rule it breaks.  The verdict is in
{cmd:r(wellformed)} and {cmd:r(known)}, which are separate answers on purpose:
{cmd:WASH-02} is perfectly well formed and belongs to no known family.

{phang}
{opt add(code "meaning")} registers a family for the remainder of the Stata
session, so that a package with its own families does not trip validation.  The
code must satisfy the same format rule as a core code, or ids built from it could
never be well formed.  Registering an existing code replaces its meaning rather
than adding a second entry, so a test file that declares its families at the top
can be run repeatedly in one session.  Registering a core code does nothing.

{marker why}{...}
{title:Why ids are stable, not sequential}

{pstd}
A test identifier is not an internal label.  It escapes into the certification
ledger ({cmd:Failed IDs: DET-03}), into CI record validation, into commit
messages and issue trackers.

{pstd}
Sequential identifiers renumber when a test is inserted, and at that point three
things break at once.  The ledger's own history stops being interpretable:
{cmd:T007} in March is a different test from {cmd:T007} in August, so the record
no longer says what it appears to say.  Single-test targeting silently runs the
wrong test, because {help stqa_target} matches on the id.  And a regression
cannot be bisected across the record, because the thing being traced does not
keep its name.

{pstd}
Stable, semantic identifiers are therefore the default.  The family prefix
additionally carries the failure mode, so a reader knows what {cmd:DET-03}
exercises -- a deterministic, offline check against frozen inputs -- without
opening it.

{pstd}
The auto-generated form {cmd:T001}, {cmd:T002}, ... assigned by the one-argument
form of {help stqa_test} remains legal for scratch and ad-hoc tests.  It is
reported by {opt validate()} as an auto id rather than as an error, and it sets
{cmd:r(auto)}.  A run that writes the certification ledger warns when auto ids
are present, because an unstable id has no business in a permanent record.

{marker format}{...}
{title:The id format}

{p 8 8 2}
{cmd:FAMILY-NN}

{p 8 8 2}
{cmd:FAMILY} {space 2}2 to 8 characters from {cmd:A-Z} {cmd:0-9}, upper case{p_end}
{p 8 8 2}
{cmd:NN} {space 6}a zero-padded integer, at least two digits{p_end}

{pstd}
{cmd:DET-01}, {cmd:ERR-07}, {cmd:XPLAT-05} and {cmd:PERF-01} conform.
{cmd:DET-1} does not (one digit), {cmd:det-01} does not (lower case), and
{cmd:T001} is the auto form described above.

{pstd}
The two-digit floor is what keeps a family's tests sorting in run order once it
grows past nine, and the zero padding is what keeps that true in a plain text
sort of the ledger.

{marker families}{...}
{title:The core families}

{pstd}
These sixteen are what the package ships and documents.  They are drawn from the
four production suites this framework generalizes, and each one names a failure
mode rather than a location in a file.

{p2colset 8 18 20 2}{...}
{p2col:{cmd:ENV}}Environment and setup: dependencies present, version stamps, adopath, install integrity{p_end}
{p2col:{cmd:SMOKE}}Smoke tests: the package loads and its principal command runs at all{p_end}
{p2col:{cmd:DET}}Deterministic / offline: frozen inputs, pinned values, no network{p_end}
{p2col:{cmd:REGR}}Regression baselines: current output still matches a stored baseline{p_end}
{p2col:{cmd:ERR}}Error conditions: invalid input is rejected with the right return code{p_end}
{p2col:{cmd:EDGE}}Edge cases: N=1, empty results, special characters, boundary values{p_end}
{p2col:{cmd:EXT}}Extreme inputs: large or stress-scale queries and datasets{p_end}
{p2col:{cmd:PERF}}Performance: timing or resource assertions against a stated threshold{p_end}
{p2col:{cmd:DATA}}Data structure: variable types, value ranges, duplicates, identifiers{p_end}
{p2col:{cmd:TRANS}}Transformations: reshape, rename, derived variables, wide/long{p_end}
{p2col:{cmd:META}}Metadata operations: labels, notes, enrichment, codelist health{p_end}
{p2col:{cmd:DISC}}Discovery: search, listing, catalog queries{p_end}
{p2col:{cmd:SYNC}}Metadata synchronization: regenerating metadata from an authority{p_end}
{p2col:{cmd:INT}}Integration: interaction with a sibling package or external service{p_end}
{p2col:{cmd:DOC}}Documentation as tests: help-file examples execute{p_end}
{p2col:{cmd:XPLAT}}Cross-platform: outputs agree across languages or implementations{p_end}
{p2colreset}{...}

{marker extra}{...}
{title:Package-specific families}

{pstd}
A package is free to declare families of its own.  Declare them at the top of the
suite, before any test file runs, and validation stops treating them as
off-vocabulary:

{phang2}{cmd:. stqa_families, add(WASH "JMP ladder codes and ALB/SM shares")}{p_end}
{phang2}{cmd:. stqa_families, add(GEO "Geography joins against the master list")}{p_end}

{pstd}
Registrations are held in the global {cmd:$stqa_extra_families} as
{cmd:CODE|meaning;} entries, which is why neither {cmd:;} nor {cmd:|} may appear
in a meaning.  They last for the Stata session and are not written anywhere.
Clear them with:

{phang2}{cmd:. global stqa_extra_families ""}{p_end}

{pstd}
Session-registered families are listed under their own heading by the table form,
are reported as {cmd:r(source)} {cmd:session} by the lookup form, and count as
known by {opt validate()}.  {cmd:r(core)} and {cmd:r(extra)} keep the two apart
for a caller that needs to know whether a suite invented a family.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:stqa_families} is {cmd:rclass}.  Every form returns the roster:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(families)}}every known code, core first, space separated{p_end}
{synopt:{cmd:r(core)}}the sixteen core codes{p_end}
{synopt:{cmd:r(extra)}}codes registered this session, empty if none{p_end}
{p2colreset}{...}

{pstd}
{cmd:stqa_families} {it:family} additionally returns:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(known)}}{cmd:1} if the family is core or session-registered{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(family)}}the canonical upper-case code, or the query as typed if unknown{p_end}
{synopt:{cmd:r(meaning)}}the one-line meaning, empty if unknown{p_end}
{synopt:{cmd:r(source)}}{cmd:core}, {cmd:session}, or empty if unknown{p_end}
{p2colreset}{...}

{pstd}
{opt validate()} additionally returns:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(wellformed)}}{cmd:1} if the id is {cmd:FAMILY-NN}{p_end}
{synopt:{cmd:r(known)}}{cmd:1} if the family part is on the roster{p_end}
{synopt:{cmd:r(auto)}}{cmd:1} if the id is the auto form {cmd:T001}, {cmd:T002}, ...{p_end}
{synopt:{cmd:r(number)}}the number part, if it is all digits{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(id)}}the id as given{p_end}
{synopt:{cmd:r(family)}}the family part, as given{p_end}
{p2colreset}{...}

{pstd}
The lookup form is forgiving about case, because it answers a question; the
validator is strict, because it certifies.  {cmd:stqa_families det} describes
{cmd:DET}, while {cmd:stqa_families, validate(det-01)} reports a malformed id.

{marker examples}{...}
{title:Examples}

{pstd}What the families are:{p_end}
{phang2}{cmd:. stqa_families}{p_end}
{phang2}{cmd:. stqa_families DET}{p_end}

{pstd}Check an id before it reaches a ledger:{p_end}
{phang2}{cmd:. stqa_families, validate(DET-03)}{p_end}
{phang2}{cmd:. di r(wellformed), r(known)}{p_end}

{pstd}Gate a suite on its own ids -- the reason the command is {cmd:rclass}.  The
command reports each offending id itself; the loop only has to collect them:{p_end}
{phang2}{cmd:. local bad ""}{p_end}
{phang2}{cmd:. foreach id in DET-01 ERR-07 T003 {c -(}}{p_end}
{phang2}{cmd:.     stqa_families, validate(`id')}{p_end}
{phang2}{cmd:.     if r(wellformed) == 0 | r(known) == 0 local bad `bad' `id'}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}Declare a package's own family, then use it:{p_end}
{phang2}{cmd:. stqa_families, add(WASH "JMP ladder codes and ALB/SM shares")}{p_end}
{phang2}{cmd:. stqa_test WASH-01 "Ladder shares sum to one"}{p_end}
{phang2}{cmd:.     stqa_approx r(total) 1, tol(1e-8)}{p_end}
{phang2}{cmd:. stqa_endtest}{p_end}

{pstd}The roster, for a caller that validates against it:{p_end}
{phang2}{cmd:. quietly stqa_families, codes}{p_end}
{phang2}{cmd:. local roster "`r(families)'"}{p_end}
