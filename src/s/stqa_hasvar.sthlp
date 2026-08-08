{smcl}
{* *! version 1.0.0  07dec2025}{...}
{viewerjumpto "Syntax" "stqa_hasvar##syntax"}{...}
{viewerjumpto "Description" "stqa_hasvar##description"}{...}
{viewerjumpto "Options" "stqa_hasvar##options"}{...}
{viewerjumpto "Examples" "stqa_hasvar##examples"}{...}
{title:Title}

{phang}
{bf:stqa_hasvar} {hline 2} Assert that variables exist in the dataset

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_hasvar}
{it:varlist}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt msg(string)}}custom error message to display on failure{p_end}
{synopt :{opt noi:sily}}display success message{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_hasvar} verifies that all variables specified in {it:varlist} exist in the current dataset.
If any variable is missing, the command fails with error code 9.

{marker options}{...}
{title:Options}

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noisily} displays a confirmation message if the assertion passes.

{marker examples}{...}
{title:Examples}

{pstd}Check for key identifiers{p_end}
{phang2}{cmd:. stqa_hasvar country year id}{p_end}

{pstd}Check for analysis variables{p_end}
{phang2}{cmd:. stqa_hasvar income education}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
