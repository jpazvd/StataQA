{smcl}
{* *! version 1.0.0  30dec2025}{...}
{title:stqa_approx_all}

{pstd}{cmd:stqa_approx_all} asserts all values of a variable are within a tolerance of a target value.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_approx_all} {it:varname} [{cmd:,} {opt target(real 0)} {opt tol(real 1e-6)} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Computes the maximum absolute deviation from {it:target} and fails if it exceeds {it:tol}.{p_end}

{title:Options}
{p 8 8 2}{opt target(real)} Target value (default 0).{p_end}
{p 8 8 2}{opt tol(real)} Tolerance (default 1e-6).{p_end}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_approx}, {help stqa_assert}, {help stqa_inrange}, {help stataqa:stataqa hub}{p_end}
