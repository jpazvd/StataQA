{smcl}
{* *! version 1.0.0  07dec2025}{...}
{viewerjumpto "Syntax" "stqa_svyset##syntax"}{...}
{viewerjumpto "Description" "stqa_svyset##description"}{...}
{viewerjumpto "Options" "stqa_svyset##options"}{...}
{viewerjumpto "Examples" "stqa_svyset##examples"}{...}
{title:Title}

{phang}
{bf:stqa_svyset} {hline 2} Assert survey design settings

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_svyset}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt psu(varname)}}expected primary sampling unit variable{p_end}
{synopt :{opt str:ata(varname)}}expected strata variable{p_end}
{synopt :{opt w:eight(varname)}}expected weight variable{p_end}
{synopt :{opt msg(string)}}custom error message to display on failure{p_end}
{synopt :{opt noi:sily}}display success message{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_svyset} verifies that the dataset is currently {cmd:svyset} with the expected parameters.
This is crucial for ensuring that survey data analysis pipelines are correctly configured before running estimation commands.

{marker options}{...}
{title:Options}

{phang}
{opt psu(varname)} specifies the expected variable for the Primary Sampling Unit (PSU).

{phang}
{opt strata(varname)} specifies the expected variable for stratification.

{phang}
{opt weight(varname)} specifies the expected variable for sampling weights.

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noisily} displays a confirmation message if the assertion passes.

{marker examples}{...}
{title:Examples}

{pstd}Check full survey design{p_end}
{phang2}{cmd:. stqa_svyset, psu(clusterid) strata(region) weight(pweight)}{p_end}

{pstd}Check only weights{p_end}
{phang2}{cmd:. stqa_svyset, weight(wgt)}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
