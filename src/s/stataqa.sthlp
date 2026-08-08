{smcl}
{* *! version 2.3.0  08aug2026}{...}
{vieweralsosee "stataqa run" "help stqa_run"}{...}
{vieweralsosee "stataqa init" "help stqa_init"}{...}
{vieweralsosee "stataqa report" "help stqa_report"}{...}
{vieweralsosee "stataqa assertions" "help stqa_assert"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{vieweralsosee "[P] cscript" "help cscript"}{...}
{viewerjumpto "Syntax" "stataqa##syntax"}{...}
{viewerjumpto "Description" "stataqa##description"}{...}
{viewerjumpto "Subcommands" "stataqa##subcommands"}{...}
{viewerjumpto "Author" "stataqa##author"}{...}
{title:Title}

{phang}
{bf:stataqa} {hline 2} A lightweight framework for automated testing and continuous integration

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stataqa} {it:subcommand} [{it:arguments}] [{cmd:,} {it:options}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stataqa} is a framework for automated testing of Stata code. It provides tools to discover and execute test scripts, verify results with assertions, and generate machine-readable reports (JUnit XML) for integration with Continuous Integration (CI) systems like GitHub Actions.

{pstd}
{cmd:stataqa} itself is only a dispatcher: it strips the leading subcommand and hands the
rest of the command line to the matching {cmd:stqa_}{it:name} command {bf:verbatim}, so a
quoted absolute path survives intact:

{phang2}. {stata `"stataqa run "c:/GitHub/my project/tests", pattern("test_*.do")"'}{p_end}

{pstd}
Every subcommand also lives in its own ado-file and can therefore be called directly
({cmd:stqa_run}, {cmd:stqa_init}, {cmd:stqa_report}, ...) without going through the
dispatcher.

{marker subcommands}{...}
{title:Subcommands}

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{help stqa_run:review}}Execute a test suite; record NOTHING (the default role){p_end}
{synopt :{help stqa_run:certify}}Execute a test suite and append the ledger stanza{p_end}
{synopt :{help stqa_validate:validate}}Judge the existing record against this tree; execute nothing{p_end}
{synopt :{help stqa_run:run}}Alias for {cmd:review}{p_end}
{synopt :{help stqa_init:init}}Initialize a new test suite{p_end}
{synopt :{help stqa_report:report}}Summarize a JUnit report, a run log, or the last run{p_end}
{synopt :{help stqa_scanlog:scanlog}}Read verdict tokens back out of a log{p_end}
{synopt :{help stqa_history:history}}Append and inspect run records{p_end}
{synopt :{help stqa_families:families}}List the failure-mode family vocabulary{p_end}
{synoptline}

{pstd}
The three role verbs split what a single runner used to conflate.
{cmd:review} answers ``does this tree pass?'' and is safe to point at a
repository you do not own: logs go to scratch, no stanza is appended.
{cmd:certify} is the deliberate act that enters the record {hline 2} it warns
when the working tree is dirty, and the stanza pins the branch, commit, and
dirty state of what actually ran.  {cmd:validate} reads the record without
running anything and fails when the record is red, self-inconsistent, or
certifies a different commit than the tree at hand.  A partial run
({opt test()} or {opt family()}) is never recorded under any role.

{pstd}
For details on writing tests, see the test block and assertion commands:

{synoptset 20 tabbed}{...}
{synopthdr :Test Blocks}
{synoptline}
{synopt :{help stqa_test:stqa_test}}Start a test case{p_end}
{synopt :{help stqa_endtest:stqa_endtest}}End a test case{p_end}
{synoptline}

{synoptset 20 tabbed}{...}
{synopthdr :Assertions}
{synoptline}
{synopt :{help stqa_assert:stqa_assert}}General assertions{p_end}
{synopt :{help stqa_approx:stqa_approx}}Numeric approximation checks{p_end}
{synopt :{help stqa_approx_all:stqa_approx_all}}All values within tolerance of target{p_end}
{synopt :{help stqa_dta_equal:stqa_dta_equal}}Dataset equality check{p_end}
{synopt :{help stqa_vartype:stqa_vartype}}Assert variable storage type{p_end}
{synopt :{help stqa_nomissing:stqa_nomissing}}Assert no missing values in a varlist{p_end}
{synopt :{help stqa_nobs_min:stqa_nobs_min}}Assert minimum number of observations{p_end}
{synopt :{help stqa_inrange:stqa_inrange}}Assert scalar within bounds{p_end}
{synopt :{help stqa_rc_zero:stqa_rc_zero}}Assert last return code is zero{p_end}
{synopt :{help stqa_file_exists:stqa_file_exists}}Assert file exists{p_end}
{synopt :{help stqa_dir_exists:stqa_dir_exists}}Assert directory exists (optionally create){p_end}
{synopt :{help stqa_iso3:stqa_iso3}}Assert ISO3 country codes are valid{p_end}
{synopt :{help stqa_hasvar:stqa_hasvar}}Assert variable existence{p_end}
{synopt :{help stqa_shape:stqa_shape}}Assert dataset dimensions{p_end}
{synopt :{help stqa_unique:stqa_unique}}Assert distinct-count matches expected{p_end}
{synopt :{help stqa_uniqueid:stqa_uniqueid}}Assert uniqueness via {cmd:isid}{p_end}
{synopt :{help stqa_svyset:stqa_svyset}}Assert survey design settings{p_end}
{synopt :{help stqa_rcof:stqa_rcof}}Return code verification{p_end}
{synopt :{help stqa_skip:stqa_skip}}Conditional test skipping{p_end}
{synopt :{help stqa_target:stqa_target}}Set, clear or show the single-test target{p_end}
{synopt :{help stqa_cmdline:stqa_cmdline}}Run one command line and book its verdict{p_end}
{synopt :{help stqa_examples:stqa_examples}}Harvest and run documented examples{p_end}
{synoptline}

{synoptset 20 tabbed}{...}
{synopthdr :Fixtures and golden masters}
{synoptline}
{synopt :{help stqa_manifest:stqa_manifest}}Bless and verify the data column of the record{p_end}
{synopt :{help stqa_fixture:stqa_fixture}}Verified access to a frozen input{p_end}
{synopt :{help stqa_replay:stqa_replay}}Re-run a blessed do-file and require the same output{p_end}
{synoptline}

{pstd}
The manifest is the chain of custody for test data: {cmd:stqa_fixture} will
not hand a test an input that drifted since blessing, and {cmd:stqa_replay}
will not accept output that differs from its golden master.  Blessing
({cmd:stqa_manifest add}, {cmd:stqa_replay, update}) is a certify-side
ceremony, refused inside a review-role run.

{marker author}{...}
{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
