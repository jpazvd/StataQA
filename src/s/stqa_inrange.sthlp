{smcl}
{* *! version 1.0.0  30dec2025}{...}
{title:stqa_inrange}

{pstd}{cmd:stqa_inrange} asserts a scalar value lies within given bounds.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_inrange} {it:value} {it:min} {it:max} [{cmd:,} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Fails with exit code 9 if {it:value} is below {it:min} or above {it:max}.{p_end}

{title:Options}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_assert}, {help stqa_approx}, {help stqa_approx_all}, {help stataqa:stataqa hub}{p_end}
