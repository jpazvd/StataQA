{smcl}
{* *! version 1.0.0  30dec2025}{...}
{title:stqa_dir_exists}

{pstd}{cmd:stqa_dir_exists} asserts that a directory exists, optionally creating it if absent.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_dir_exists} {it:dirpath} [{cmd:,} {opt create} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Confirms {it:dirpath} exists. If {opt create} is specified and the directory is missing, it attempts to create it. Fails with exit code 9 on creation failure or when missing without {opt create}.{p_end}

{title:Options}
{p 8 8 2}{opt create} Create the directory if it does not exist.{p_end}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_file_exists}, {help stataqa:stataqa hub}{p_end}
