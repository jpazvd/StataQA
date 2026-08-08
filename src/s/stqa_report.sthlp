{smcl}
{* *! version 2.0.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stataqa run" "help stqa_run"}{...}
{vieweralsosee "stqa_scanlog" "help stqa_scanlog"}{...}
{viewerjumpto "Syntax" "stqa_report##syntax"}{...}
{viewerjumpto "Description" "stqa_report##description"}{...}
{viewerjumpto "Remarks" "stqa_report##remarks"}{...}
{viewerjumpto "Stored results" "stqa_report##results"}{...}
{viewerjumpto "Examples" "stqa_report##examples"}{...}
{viewerjumpto "Author" "stqa_report##author"}{...}
{title:Title}

{phang}
{bf:stataqa report} {hline 2} Summarize a JUnit report, a run log, or the last run

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stataqa report} [{it:filename}]

{pstd}
The command may also be called directly as {cmd:stqa_report}. Quote {it:filename} if
it contains spaces.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stataqa report} prints a summary table for one of three sources, chosen by what
you give it:

{p 8 12 2}{it:filename}{cmd:.xml} - a JUnit report written by
{helpb stqa_run:stataqa run, junit()}. The {cmd:<testcase>}, {cmd:<failure>} and
{cmd:<skipped>} elements are counted.{p_end}
{p 8 12 2}any other {it:filename} - a run log. The log is handed to
{helpb stqa_scanlog}, so the verdict still comes out of the log rather than out of a
return code, and the presence or absence of the completion sentinel is reported.{p_end}
{p 8 12 2}nothing at all - the counters left behind by the last run in this session
({cmd:$stqa_n_pass}, {cmd:$stqa_n_fail}, {cmd:$stqa_n_skip}, {cmd:$stqa_n_total},
{cmd:$stqa_failed_ids}, {cmd:$stqa_skip_notes}).{p_end}

{marker remarks}{...}
{title:Remarks}

{pstd}
This command reports; it does not judge. It never sets an exit status of its own, so
it is safe to call at the end of a CI job. The gate belongs to
{helpb stqa_run:stataqa run}, which exits {cmd:9} on a red suite.

{pstd}
A log with no completion sentinel is called out explicitly. Such a log is {bf:not} a
green run however few failures it shows, because a suite that died before finishing
had no chance to write the failures it would have found.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:stataqa report} is {cmd:rclass} and stores

{synoptset 22 tabbed}{...}
{synopthdr :result}
{synoptline}
{synopt :{cmd:r(pass)}}checks or testcases passed{p_end}
{synopt :{cmd:r(fail)}}checks or testcases failed{p_end}
{synopt :{cmd:r(skip)}}checks or testcases skipped{p_end}
{synopt :{cmd:r(total)}}total{p_end}
{synopt :{cmd:r(done)}}log source only: 1 if the completion sentinel is present{p_end}
{synopt :{cmd:r(kind)}}{cmd:junit}, {cmd:log} or {cmd:globals}{p_end}
{synopt :{cmd:r(source)}}the file that was read{p_end}
{synopt :{cmd:r(failed_ids)}}ids of the failing checks, when known{p_end}
{synoptline}

{marker examples}{...}
{title:Examples}

{pstd}Summarize the run that just finished:{p_end}
{phang2}. {stata stataqa run}{p_end}
{phang2}. {stata stataqa report}{p_end}

{pstd}Summarize a JUnit report:{p_end}
{phang2}. {stata stataqa report "out.xml"}{p_end}

{pstd}Summarize one test's log:{p_end}
{phang2}. {stata stataqa report "tests/logs/test_example_stqa.log"}{p_end}

{marker author}{...}
{title:Author}

{pstd}
Joao Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
