{smcl}
{* *! version 1.0.0  08aug2026}{...}
{vieweralsosee "stqa_fixture" "help stqa_fixture"}{...}
{vieweralsosee "stqa_replay" "help stqa_replay"}{...}
{viewerjumpto "Syntax" "stqa_manifest##syntax"}{...}
{viewerjumpto "Description" "stqa_manifest##description"}{...}
{viewerjumpto "The manifest format" "stqa_manifest##format"}{...}
{viewerjumpto "Stored results" "stqa_manifest##results"}{...}
{title:Title}

{phang}
{bf:stqa_manifest} {hline 2} Bless and verify the data column of the certification record

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_manifest} {cmd:add} {cmd:using} {it:filename} [{cmd:,} {opt type(fixture|replay)}]

{p 8 17 2}
{cmd:stqa_manifest} {cmd:verify} [{cmd:using} {it:filename}] [{cmd:,} {opt q:uiet}]

{marker description}{...}
{title:Description}

{pstd}
One typed manifest, {cmd:qa/manifest.txt}, covers both halves of the chain of
custody: frozen inputs under {cmd:qa/fixtures/} and blessed replay pairs under
{cmd:qa/replay/}.  {cmd:add} blesses a file into the manifest; {cmd:verify}
recomputes every listed signature and compares.  Drift is a {cmd:FAIL:} with
the verdict-token contract, because a fixture that changed since blessing
invalidates every test that consumes it.

{pstd}
{cmd:add} on a {cmd:.dta} records the {help datasignature} {hline 2} a
signature over values, not bytes, so it survives platform differences and
re-saving.  Any other file records the {help checksum} (printed {cmd:%15.0f};
the default scientific-notation display loses precision and can let two
different files compare equal) together with the file length.  When
{opt type()} is omitted it is inferred: files under a {cmd:replay} directory
are {cmd:replay}, everything else {cmd:fixture}.

{pstd}
Blessing is a certify-side ceremony: {cmd:add} refuses inside a review-role
run (see {help stqa_run}).  A review run that could re-bless a fixture could
silently move the goalposts of the very test it is reviewing.  This is a
guardrail against accident, not access control {hline 2} a test file that
issues {cmd:clear all} drops the role global.

{pstd}
{cmd:verify} with {cmd:using} checks that one file; a file that is not listed
is itself a named failure, not a silent pass.  Without {cmd:using} it sweeps
every entry.  Tests normally reach verification through {help stqa_fixture}
(inputs) and {help stqa_replay} (output pairs) rather than calling
{cmd:verify} directly.

{marker format}{...}
{title:The manifest format}

{pstd}
One line per blessed file, six fields, space-separated, path last so it may
contain spaces:

{p 8 8 2}{it:type} {it:method} {it:value} {it:filelen} {it:stata} {it:path}

{pstd}
{it:type} is {cmd:fixture} or {cmd:replay}; {it:method} is {cmd:sig}
(datasignature) or {cmd:sum} (checksum); {it:filelen} and {it:stata} are
{cmd:.} where not applicable.  {it:stata} records {cmd:c(stata_version)} for
replay entries, because a blessed log is only comparable under the version
that blessed it.  The file is plain text and diffs cleanly in review.

{marker results}{...}
{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: {cmd:add} {hline 1} Macros}{p_end}
{synopt:{cmd:r(method)}}{cmd:sig} or {cmd:sum}{p_end}
{synopt:{cmd:r(value)}}the recorded signature or checksum{p_end}

{p2col 5 18 22 2: {cmd:verify} {hline 1} Scalars}{p_end}
{synopt:{cmd:r(n)}}number of entries checked{p_end}

{title:Also see}

{pstd}{help stqa_fixture}, {help stqa_replay}, {help stqa_run}, {help stataqa:stataqa hub}{p_end}
