{smcl}
{* *! version 1.0.0  07dec2025}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "[D] cf" "help cf"}{...}
{vieweralsosee "[D] compare" "help compare"}{...}
{viewerjumpto "Syntax" "stqa_dta_equal##syntax"}{...}
{viewerjumpto "Description" "stqa_dta_equal##description"}{...}
{viewerjumpto "Options" "stqa_dta_equal##options"}{...}
{viewerjumpto "Examples" "stqa_dta_equal##examples"}{...}
{title:Title}

{phang}
{bf:stqa_dta_equal} {hline 2} Assert that dataset in memory matches a file on disk

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_dta_equal} {cmd:using} {it:filename} [{cmd:,} {opt msg(string)} {opt noi:sily}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_dta_equal} verifies that the dataset currently in memory is identical to the dataset stored in {it:filename}. It uses Stata's built-in {help cf} command to perform the comparison.

{pstd}
It checks all variables and observations. If any difference is found (values, variable names, or number of observations), the command exits with return code 9.

{marker options}{...}
{title:Options}

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails.

{phang}
{opt noi:sily} displays the output of the {cmd:cf} command, which details exactly which variables differ. By default, the comparison is quiet.

{marker examples}{...}
{title:Examples}

{pstd}Check if the current data matches the baseline:{p_end}
{phang2}. stqa_dta_equal using "tests/data/baseline.dta"{p_end}

{pstd}Show differences if they exist:{p_end}
{phang2}. stqa_dta_equal using "tests/data/baseline.dta", noisily{p_end}
