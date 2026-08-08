{smcl}
{* *! version 1.0.0  30dec2025}{...}
{viewerjumpto "Syntax" "stqa_iso3##syntax"}{...}
{viewerjumpto "Description" "stqa_iso3##description"}{...}
{viewerjumpto "Options" "stqa_iso3##options"}{...}
{viewerjumpto "Examples" "stqa_iso3##examples"}{...}
{title:Title}

{phang}
{bf:stqa_iso3} {hline 2} Assert that a variable contains only ISO3 country codes

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_iso3} {it:varname} [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt allowmissing}}allow missing values (otherwise missing triggers failure){p_end}
{synopt :{opt msg(string)}}custom error message to display on failure{p_end}
{synopt :{opt noi:sily}}display success message{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_iso3} checks that the distinct nonmissing values of {it:varname} are valid ISO 3166-1 alpha-3 country codes. A built-in whitelist covers standard countries and territories. Missing values fail the check unless {opt allowmissing} is specified.

{marker options}{...}
{title:Options}

{phang}
{opt allowmissing} permits missing values without failing the assertion.

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noisily} displays a confirmation message if the assertion passes.

{marker examples}{...}
{title:Examples}

{pstd}Require all codes to be valid ISO3{p_end}
{phang2}{cmd:. stqa_iso3 iso3}{p_end}

{pstd}Allow missing codes{p_end}
{phang2}{cmd:. stqa_iso3 iso3, allowmissing}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
