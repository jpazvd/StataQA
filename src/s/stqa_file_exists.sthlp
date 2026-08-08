{smcl}
{* *! version 2.1.0  06aug2026}{...}
{title:stqa_file_exists}

{pstd}{cmd:stqa_file_exists} asserts that a file exists at the given path.{p_end}

{title:Syntax}
{p 8 16 2}{cmd:stqa_file_exists} {it:filepath} [{cmd:,} {opt msg(string)}]{p_end}

{title:Description}
{pstd}Fails with exit code 9 if the file is not found, like every other StataQA assertion: it emits the line-initial {cmd:FAIL:} verdict token for the open test block, sets {cmd:$stqa_block_failed} and exits 9. The return code Stata itself raised, {cmd:601}, is reported in the {cmd:Got:} line so a missing file stays distinguishable from a failing comparison.{p_end}

{pstd}The assertion is a no-op when the block was skipped or targeted out ({cmd:$stqa_skip_block}).{p_end}

{title:Options}
{p 8 8 2}{opt msg(string)} Custom failure message.{p_end}

{title:See also}
{pstd}{help stqa_dir_exists}, {help stataqa:stataqa hub}{p_end}
