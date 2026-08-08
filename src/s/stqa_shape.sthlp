{smcl}
{* *! version 2.1.0  06aug2026}{...}
{viewerjumpto "Syntax" "stqa_shape##syntax"}{...}
{viewerjumpto "Description" "stqa_shape##description"}{...}
{viewerjumpto "Options" "stqa_shape##options"}{...}
{viewerjumpto "Examples" "stqa_shape##examples"}{...}
{title:Title}

{phang}
{bf:stqa_shape} {hline 2} Assert dataset dimensions (observations and variables)

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_shape}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt nobs(integer)}}expected number of observations{p_end}
{synopt :{opt vars(integer)}}expected number of variables{p_end}
{synopt :{opt msg(string)}}custom error message to display on failure{p_end}
{synopt :{opt noi:sily}}display success message{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_shape} verifies that the current dataset has the expected number of observations and/or variables.
This is useful for ensuring that merges, appends, or collapses produced the expected output dimensions.

{marker options}{...}
{title:Options}

{phang}
{opt nobs(integer)} specifies the exact number of observations expected.

{phang}
{opt vars(integer)} specifies the exact number of variables expected.

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noisily} displays a confirmation message if the assertion passes.

{marker examples}{...}
{title:Examples}

{pstd}Check exact dimensions{p_end}
{phang2}{cmd:. stqa_shape, nobs(74) vars(12)}{p_end}

{pstd}Check only observation count{p_end}
{phang2}{cmd:. stqa_shape, nobs(1000)}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
