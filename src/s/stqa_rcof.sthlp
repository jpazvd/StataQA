{smcl}
{* *! version 2.0.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{vieweralsosee "[P] capture" "help capture"}{...}
{viewerjumpto "Syntax" "stqa_rcof##syntax"}{...}
{viewerjumpto "Description" "stqa_rcof##description"}{...}
{viewerjumpto "Options" "stqa_rcof##options"}{...}
{viewerjumpto "Examples" "stqa_rcof##examples"}{...}
{title:Title}

{phang}
{bf:stqa_rcof} {hline 2} Assert that a command returns a specific error code

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_rcof} {cmd:"}{it:command}{cmd:"} {cmd:,} {opt rc(integer)} [{opt msg(string)}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_rcof} verifies that a command fails with a specific return code. This is used to test error handling logic (e.g., ensuring a command fails when given invalid input).

{pstd}
The command to be tested must be enclosed in double quotes. Only that outer pair of
quotes is removed, so quoted arguments inside the command survive: for example
{cmd:stqa_rcof "use "}{it:my file.dta}{cmd:", rc(601)} runs {cmd:use "my file.dta"}
exactly as typed.

{pstd}
If the observed return code differs from {opt rc()}, the command displays a {cmd:FAIL:}
line naming the current test id, followed by {cmd:Expected:} and {cmd:Got:} return-code
diagnostics and the command under test, and exits with return code 9.

{pstd}
Inside a skipped test block ({cmd:$stqa_skip_block} equal to {cmd:1}) the command is a
no-op and the command under test is not executed.

{marker options}{...}
{title:Options}

{phang}
{opt rc(integer)} specifies the expected return code. This is required.

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails. It replaces
the default description on the {cmd:FAIL:} line.

{marker examples}{...}
{title:Examples}

{pstd}Ensure a command fails when a required variable is missing (rc 111):{p_end}
{phang2}. stqa_rcof "regress price nonexistent_var", rc(111){p_end}

{pstd}Ensure a command fails with invalid options (rc 198):{p_end}
{phang2}. stqa_rcof "mycommand, badoption", rc(198){p_end}

{pstd}Quoted arguments inside the command are preserved (rc 601, file not found):{p_end}
{phang2}. stqa_rcof "use "no such file.dta"", rc(601){p_end}
