{smcl}
{* *! version 1.0.0  30dec2025}{...}
{title:stqa_vartype}

{pstd}{cmd:stqa_vartype} asserts that a variable has an expected storage type.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_vartype} {it:varname} {cmd:,} {opt type(string)} [{opt msg(string)}]{p_end}

{title:Description}
{pstd}Fails with exit code 9 if the variable's storage type does not match {opt type()}. Comparison is case-insensitive.{p_end}

{title:Options}
{p 8 8 2}{opt type(string)} Expected storage type (e.g., {cmd:strL}, {cmd:double}).{p_end}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_nomissing}, {help stataqa:stataqa hub}{p_end}
