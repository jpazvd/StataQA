{smcl}
{* *! version 1.1.0  07aug2026}{...}
{title:stqa_nomissing}

{pstd}{cmd:stqa_nomissing} asserts that variables contain no missing values.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_nomissing} {it:varlist} [{cmd:,} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Fails with exit code 9 if any variable in {it:varlist} has missing values.{p_end}

{title:Options}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_vartype}, {help stqa_nobs_min}, {help stataqa:stataqa hub}{p_end}
