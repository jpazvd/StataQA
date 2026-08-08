{smcl}
{* *! version 1.0.0  07aug2026}{...}
{viewerjumpto "Syntax" "stqa_assert_equal_num##syntax"}{...}
{viewerjumpto "Description" "stqa_assert_equal_num##description"}{...}
{viewerjumpto "Examples" "stqa_assert_equal_num##examples"}{...}
{title:Title}

{phang}
{bf:stqa_assert_equal_num} {hline 2} Assert two numeric expressions are exactly equal

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_assert_equal_num} {it:exp1} {it:exp2} [{cmd:,} {opt msg(string)}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_assert_equal_num} asserts that two numeric expressions evaluate to
exactly the same value.  On failure it displays the {cmd:FAIL:} verdict token
at column 1 naming the open test block, shows both values and the optional
message, sets {cmd:$stqa_block_failed}, and exits with return code 9.  It is a
no-op when the block is skipped or targeted out.

{pstd}
Equality here is exact.  For values that are computed rather than copied ---
means, coefficients, anything that has been through floating-point
arithmetic --- use {help stqa_approx}, which compares within a tolerance;
an exact test on a computed value fails on representation noise.

{pstd}
{opt msg(string)} adds a diagnostic line to the failure report.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. quietly count}{p_end}
{phang2}{cmd:. stqa_assert_equal_num r(N) 74}{p_end}

{phang2}{cmd:. local n : word count `mylist'}{p_end}
{phang2}{cmd:. stqa_assert_equal_num `n' 3, msg("the list should carry three tokens")}{p_end}

{title:Also see}

{pstd}{help stqa_approx}, {help stqa_assert_equal_str}, {help stqa_assert}, {help stataqa:stataqa hub}{p_end}
