{smcl}
{* *! version 2.1.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stataqa init" "help stqa_init"}{...}
{vieweralsosee "stataqa report" "help stqa_report"}{...}
{vieweralsosee "stqa_scanlog" "help stqa_scanlog"}{...}
{vieweralsosee "stqa_history" "help stqa_history"}{...}
{vieweralsosee "stqa_families" "help stqa_families"}{...}
{viewerjumpto "Syntax" "stqa_run##syntax"}{...}
{viewerjumpto "Description" "stqa_run##description"}{...}
{viewerjumpto "Options" "stqa_run##options"}{...}
{viewerjumpto "How a verdict is decided" "stqa_run##verdict"}{...}
{viewerjumpto "Test families" "stqa_run##families"}{...}
{viewerjumpto "Exit status and sentinel" "stqa_run##exit"}{...}
{viewerjumpto "Stored results" "stqa_run##results"}{...}
{viewerjumpto "Examples" "stqa_run##examples"}{...}
{viewerjumpto "Author" "stqa_run##author"}{...}
{title:Title}

{phang}
{bf:stataqa run} {hline 2} Discover and execute a test suite

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stataqa run} [{it:path}] [{it:testid}]
{cmd:,}
{opt pat:tern(string)}
{opt j:unit(filename)}
{opt tes:t(id)}
{opt fam:ily(codes)}
{opt log:dir(directory)}
{opt verb:ose}
{opt lis:t}
{opt allowempty}

{pstd}
The command may also be called directly as {cmd:stqa_run}. {it:path} defaults to
{it:tests}. Quote {it:path} whenever it contains spaces or a drive letter; the quotes
are preserved end to end.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stataqa run} discovers the test files under {it:path} that match {opt pattern()},
runs each one, and decides its verdict by {bf:reading the log the test wrote}, not by
trusting the return code. On Windows a batch Stata returns unusable exit codes and can
hang after finishing, so the log is the only reliable evidence of what happened.

{pstd}
The sequence for each run is:

{p 8 12 2}1. the log directory is created if it is missing, and is then judged by
whether it can be listed - not by the return code of {cmd:mkdir};{p_end}
{p 8 12 2}2. every per-test log that this run is about to write, and the JUnit file if
one was requested, is {bf:erased first}, so a stale artifact from an earlier run can
never masquerade as the current one;{p_end}
{p 8 12 2}3. each test file runs inside its own named log
({cmd:log using} {it:logdir}{cmd:/}{it:stub}{cmd:_stqa.log, name(stqa_case) replace text});{p_end}
{p 8 12 2}4. when - and only when - the do-file returns control, a completion sentinel
is appended to that log;{p_end}
{p 8 12 2}5. {helpb stqa_scanlog} reads the log back and reports how many verdict
tokens it carries;{p_end}
{p 8 12 2}6. live counters accumulate the scanner's numbers, and those same counters
are what the closing banner and the suite sentinel print, so the banner cannot drift
from what actually ran.{p_end}

{marker options}{...}
{title:Options}

{phang}
{opt pattern(string)} is the filename pattern used for discovery. The default is
{it:test*.do}.

{phang}
{opt junit(filename)} writes a JUnit XML report. One {cmd:<testcase>} is written per
test file. Every interpolated attribute is XML-escaped ({cmd:&}, {cmd:<}, {cmd:>},
{cmd:'} and {cmd:"}), and the {cmd:tests}, {cmd:failures}, {cmd:skipped},
{cmd:errors} and {cmd:time} attributes are written on both {cmd:<testsuites>} and
{cmd:<testsuite>}. If the file cannot be written the run is failed - the artifact,
not the return code, is what is checked.

{phang}
{opt test(id)} runs only the test whose id is {it:id} by setting the global
{cmd:stqa_target}. The same effect is obtained by giving {it:testid} as a second
positional argument. This is {bf:single-test mode}: a partial run is not a gate
record, so {helpb stqa_history} is {bf:not} called.

{phang}
{opt family(codes)} runs only the tests whose ids belong to one of the given
families, as in {cmd:family(DET)} or {cmd:family(DET ERR)}. A comma-separated
list is accepted too, and codes are matched in upper case, so
{cmd:family(det, err)} is the same request. It works through the same mechanism
as {opt test()} - the runner cannot skip do-file lines, so it sets the global
{cmd:stqa_target_family} and {helpb stqa_test} neutralises the blocks that do
not match - and it carries the same honest limitation: {bf:the body of a
filtered-out block still executes}, only the harness commands inside it are
switched off. The two filters are ANDed. This is a {bf:filtered run} and, like
single-test mode, it is not a gate record, so {helpb stqa_history} is {bf:not}
called.

{phang}
{opt logdir(directory)} is where per-test logs are written. The default is
{it:path}{cmd:/logs}.

{phang}
{opt verbose} sets the global {cmd:stqa_verbose} to {cmd:1} and turns
{cmd:set trace on} with {cmd:set tracedepth 4} on around each test body. Tracing is
switched off again after every file.

{phang}
{opt list} prints the catalog of discovered test files, together with any test ids
found by scanning them for {helpb stqa_test}, and then {bf:exits without running
anything}. The same ids are then printed again {bf:grouped by family}, each
family with its meaning as {helpb stqa_families} states it, because a family
prefix is the part of an id that says what the test is for.

{phang}
{opt allowempty} makes a suite that discovers no test files green instead of red.
Without it, finding nothing is a failure: a suite that discovered nothing has not
passed, it has simply not run.

{marker verdict}{...}
{title:How a verdict is decided}

{pstd}
After a test file has run, its log is scanned and the file is classified as:

{synoptset 18 tabbed}{...}
{synopthdr :verdict}
{synoptline}
{synopt :{bf:PASS}}a completion sentinel is present and no check failed{p_end}
{synopt :{bf:FAIL}}at least one line-initial {cmd:FAIL:} token was found{p_end}
{synopt :{bf:SKIP}}the file completed but executed no check, or only skips{p_end}
{synopt :{bf:not completed}}{bf:no} completion sentinel - recorded exactly like a
failure and never counted as green{p_end}
{synoptline}

{pstd}
A skipped test is never counted as passed and never as failed: skip is a first-class
outcome with its own counter.

{marker families}{...}
{title:Test families}

{pstd}
A test id has the form {it:FAMILY}{cmd:-}{it:NN}, as in {cmd:DET-01}; see
{helpb stqa_families} for the vocabulary and {helpb stqa_test} for the rule.
Three things in a run are organised by that family.

{pstd}
{bf:Filtering.} {opt family()} runs one or more families and nothing else.

{pstd}
{bf:The closing banner.} When more than one family was seen, the summary adds
one row per family under the {cmd:checks:} line, with these columns:

{p 8 8 2}{bf:family} {space 3}the family code, or {cmd:_auto} or {cmd:_other}{p_end}
{p 8 8 2}{bf:run} {space 6}checks recorded for that family{p_end}
{p 8 8 2}{bf:passed} {space 3}of those, how many passed{p_end}
{p 8 8 2}{bf:failed} {space 3}of those, how many failed{p_end}
{p 8 8 2}{bf:skipped} {space 2}of those, how many were skipped{p_end}
{p 8 8 2}{bf:meaning} {space 2}the family's meaning, as {helpb stqa_families} states it{p_end}

{pstd}
{cmd:_auto} and {cmd:_other} are not families: they are where auto ids
({cmd:T001}) and ids outside the taxonomy are collected, and they cannot
collide with a real code because a family code contains no underscore. The
breakdown is read back out of the {bf:case logs}, from the same line-initial
verdict tokens the scanner counts, and not out of a global - a test file is
free to issue {cmd:clear all}, which would drop any global the harness had
accumulated. A verdict line that cannot be parsed costs one row of attribution
and nothing else; the counts that decide the gate come from
{helpb stqa_scanlog}.

{pstd}
{bf:The ledger warning.} Immediately before the run would be appended to the
history ledger, a run that used auto-generated ids is warned about: auto ids
renumber when a test is inserted, so a record naming {cmd:T007} stops being
interpretable and a later single-test re-run targets a different test. This
{bf:warns; it does not refuse}, and it never affects the verdict or the exit
status.

{marker exit}{...}
{title:Exit status and sentinel}

{pstd}
The last line of a run is one of

{p 8 12 2}{cmd:ALL CHECKS PASSED (}{it:n}{cmd: checks)} - green, and the command
exits {cmd:0};{p_end}
{p 8 12 2}{cmd:STATAQA SUITE COMPLETE (}{it:n}{cmd: checks, }{it:f}{cmd: failed)} -
red, and the command exits {cmd:9}.{p_end}

{pstd}
Both lines mean the suite ran to completion; only the first means it is green. A CI
gate must require the sentinel {bf:and} zero line-initial {cmd:FAIL:} tokens - either
one alone is not sufficient, because a suite that died halfway leaves no sentinel and
a suite that never ran leaves no {cmd:FAIL:} either.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:stataqa run} leaves the suite counters in globals, which survive
{helpb clear:clear all} inside a test file:

{synoptset 22 tabbed}{...}
{synopthdr :global}
{synoptline}
{synopt :{cmd:$stqa_n_pass}}checks passed{p_end}
{synopt :{cmd:$stqa_n_fail}}checks failed, including files that did not complete{p_end}
{synopt :{cmd:$stqa_n_skip}}checks skipped{p_end}
{synopt :{cmd:$stqa_n_total}}checks in total{p_end}
{synopt :{cmd:$stqa_failed_ids}}space-separated ids of the failing test files{p_end}
{synopt :{cmd:$stqa_skip_notes}}pipe-separated {it:id: reason} entries{p_end}
{synopt :{cmd:$stqa_families_seen}}families of the blocks that ran{p_end}
{synopt :{cmd:$stqa_used_autoids}}{cmd:1} if a block that ran was given an auto id{p_end}
{synoptline}

{pstd}
{cmd:$stqa_target}, {cmd:$stqa_target_family} and {cmd:$stqa_verbose} are cleared
at the end of a run so that targeting and tracing cannot leak into the next one.
The taxonomy globals written by {helpb stqa_test} - {cmd:$stqa_families_seen},
{cmd:$stqa_used_autoids}, {cmd:$stqa_families_noted}, {cmd:$stqa_badid_noted}
and {cmd:$stqa_families_ok} - are reset at the {it:start} of a run, so that the
once-per-run notes fire again in the next one.

{marker examples}{...}
{title:Examples}

{pstd}Run every test in {it:tests}:{p_end}
{phang2}. {stata stataqa run}{p_end}

{pstd}Run a suite that lives under a quoted absolute path:{p_end}
{phang2}. {stata `"stataqa run "c:/GitHub/my project/tests", pattern("test_*.do") junit("out.xml")"'}{p_end}

{pstd}See what would run, without running it:{p_end}
{phang2}. {stata stataqa run, list}{p_end}

{pstd}Re-run one failing test with tracing on:{p_end}
{phang2}. {stata stataqa run, test(example_arith) verbose}{p_end}

{pstd}Run the deterministic and error-condition families only:{p_end}
{phang2}. {stata stataqa run, family(DET ERR)}{p_end}

{pstd}Allow an empty suite to be green (rarely what you want):{p_end}
{phang2}. {stata stataqa run, allowempty}{p_end}

{marker author}{...}
{title:Author}

{pstd}
Joao Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
