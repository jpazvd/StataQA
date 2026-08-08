{smcl}
{* *! version 1.0.0  30dec2025}{...}
{title:stqa_nobs_min}

{pstd}{cmd:stqa_nobs_min} asserts that the dataset in memory has at least a minimum number of observations.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_nobs_min} {it:min_obs} [{cmd:,} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Fails with exit code 9 if {_N} is less than {it:min_obs}.{p_end}

{title:Options}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_nomissing}, {help stataqa:stataqa hub}{p_end}
