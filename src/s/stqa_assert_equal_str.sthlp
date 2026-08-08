{smcl}
{* *! version 1.0.0  07aug2026}{...}
{viewerjumpto "Syntax" "stqa_assert_equal_str##syntax"}{...}
{viewerjumpto "Description" "stqa_assert_equal_str##description"}{...}
{viewerjumpto "Examples" "stqa_assert_equal_str##examples"}{...}
{title:Title}

{phang}
{bf:stqa_assert_equal_str} {hline 2} Assert two strings are identical

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_assert_equal_str} {cmd:"}{it:str1}{cmd:"} {cmd:"}{it:str2}{cmd:"} [{cmd:,} {opt msg(string)}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_assert_equal_str} asserts that two strings are byte-identical.  On
failure it displays the {cmd:FAIL:} verdict token at column 1 naming the open
test block, shows both strings and the optional message, sets
{cmd:$stqa_block_failed}, and exits with return code 9.  It is a no-op when
the block is skipped or targeted out.

{pstd}
Quote each argument, including macro expansions, so that a value containing
blanks arrives as one token.  The comparison is case-sensitive and does not
trim: trailing blanks differ, which is usually the point of asserting on a
string a command returned.

{pstd}
{opt msg(string)} adds a diagnostic line to the failure report.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. quietly describe}{p_end}
{phang2}{cmd:. stqa_assert_equal_str "`c(filename)'" "auto.dta"}{p_end}

{phang2}{cmd:. stqa_assert_equal_str "`r(ids)'" "DET-03", msg("scanlog should collect exactly this id")}{p_end}

{title:Also see}

{pstd}{help stqa_assert_equal_num}, {help stqa_assert}, {help stataqa:stataqa hub}{p_end}
