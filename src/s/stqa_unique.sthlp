{smcl}
{* *! version 1.0.0  07dec2025}{...}
{viewerjumpto "Syntax" "stqa_unique##syntax"}{...}
{viewerjumpto "Description" "stqa_unique##description"}{...}
{viewerjumpto "Options" "stqa_unique##options"}{...}
{viewerjumpto "Examples" "stqa_unique##examples"}{...}
{title:Title}

{phang}
{bf:stqa_unique} {hline 2} Assert the number of unique values in a variable

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_unique}
{it:varname}
{cmd:,} {opt count(#)} [{it:comparison}] [{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt count(#)}}expected number used for comparison (required){p_end}
{synopt :{opt gt}}pass if unique count is greater than {it:count}; defaults to equal{p_end}
{synopt :{opt lt}}pass if unique count is less than {it:count}{p_end}
{synopt :{opt ge}}pass if unique count is greater than or equal to {it:count}{p_end}
{synopt :{opt le}}pass if unique count is less than or equal to {it:count}{p_end}
{synopt :{opt msg(string)}}custom error message to display on failure{p_end}
{synopt :{opt noi:sily}}display success message{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_unique} verifies the number of distinct nonmissing values in {it:varname} relative to a target count. By default it requires equality; comparison options allow greater-than, less-than, greater-or-equal, or less-or-equal tests.

{marker options}{...}
{title:Options}

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noisily} displays a confirmation message if the assertion passes.

{marker examples}{...}
{title:Examples}

{pstd}Require exactly 3 unique categories{p_end}
{phang2}{cmd:. stqa_unique region, count(3)}{p_end}

{pstd}Require more than 5 unique values{p_end}
{phang2}{cmd:. stqa_unique district, count(5) gt}{p_end}

{pstd}Require at most 2 unique flags{p_end}
{phang2}{cmd:. stqa_unique status, count(2) le}{p_end}

{title:Author}

{pstd}
João Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
