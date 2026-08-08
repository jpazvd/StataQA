{smcl}
{* *! version 2.0.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stataqa run" "help stqa_run"}{...}
{viewerjumpto "Syntax" "stqa_init##syntax"}{...}
{viewerjumpto "Description" "stqa_init##description"}{...}
{viewerjumpto "Remarks" "stqa_init##remarks"}{...}
{viewerjumpto "Examples" "stqa_init##examples"}{...}
{viewerjumpto "Author" "stqa_init##author"}{...}
{title:Title}

{phang}
{bf:stataqa init} {hline 2} Initialize a new test suite

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stataqa init} [{it:directory}]

{pstd}
The command may also be called directly as {cmd:stqa_init}. {it:directory} defaults to
{it:tests} and should be quoted if it contains spaces.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stataqa init} creates the directory structure a {cmd:stataqa} suite needs:

{p 8 12 2}{it:directory}{cmd:/} - where test files live;{p_end}
{p 8 12 2}{it:directory}{cmd:/logs/} - where {helpb stqa_run} writes one log per test
file, and where it reads the verdicts back from;{p_end}
{p 8 12 2}{it:directory}{cmd:/test_example.do} - a sample test file.{p_end}

{marker remarks}{...}
{title:Remarks}

{pstd}
Both directories are judged by whether they can be listed afterwards, not by the
return code of {cmd:mkdir}, so re-running {cmd:stataqa init} on an existing suite is
safe.

{pstd}
An existing {it:test_example.do} is never overwritten - the command reports that it
was left untouched and stops.

{marker examples}{...}
{title:Examples}

{pstd}Initialize in the default {it:tests} directory:{p_end}
{phang2}. {stata stataqa init}{p_end}

{pstd}Initialize in a custom directory:{p_end}
{phang2}. {stata stataqa init "my_tests"}{p_end}

{pstd}Then run it:{p_end}
{phang2}. {stata stataqa run "my_tests"}{p_end}

{marker author}{...}
{title:Author}

{pstd}
Joao Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
