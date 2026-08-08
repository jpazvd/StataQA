{smcl}
{* *! version 1.0.0  30dec2025}{...}
{title:stqa_rc_zero}

{pstd}{cmd:stqa_rc_zero} asserts the last return code is zero.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_rc_zero} [{cmd:,} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Fails with exit code 9 if {_rc} is non-zero. Useful after commands run under {help capture}.{p_end}

{title:Options}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_rcof}, {help stqa_assert}, {help stataqa:stataqa hub}{p_end}
