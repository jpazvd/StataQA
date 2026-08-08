{smcl}
{* *! version 1.0.0  30dec2025}{...}
{viewerjumpto "Syntax" "stqa_uniqueid##syntax"}{...}
{viewerjumpto "Description" "stqa_uniqueid##description"}{...}
{viewerjumpto "Options" "stqa_uniqueid##options"}{...}
{viewerjumpto "Examples" "stqa_uniqueid##examples"}{...}
{title:Title}

{phang}
{bf:stqa_uniqueid} {hline 2} Assert that variables uniquely identify observations

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_uniqueid}
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
{cmd:stqa_uniqueid} verifies that the combination of variables in {it:varlist} uniquely identifies each observation in the dataset. It is a wrapper around {cmd:isid} that integrates with the stataqa framework.

{marker options}{...}
{title:Options}

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noisily} displays a confirmation message if the assertion passes.

{marker examples}{...}
{title:Examples}

{pstd}Check primary key{p_end}
{phang2}{cmd:. stqa_uniqueid id}{p_end}

{pstd}Check composite key{p_end}
{phang2}{cmd:. stqa_uniqueid country year}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
