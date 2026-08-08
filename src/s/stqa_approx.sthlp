{smcl}
{* *! version 2.0.0  06aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{viewerjumpto "Syntax" "stqa_approx##syntax"}{...}
{viewerjumpto "Description" "stqa_approx##description"}{...}
{viewerjumpto "Options" "stqa_approx##options"}{...}
{viewerjumpto "Examples" "stqa_approx##examples"}{...}
{title:Title}

{phang}
{bf:stqa_approx} {hline 2} Assert numeric equality with tolerance

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_approx} {it:num1} {it:num2} [{cmd:,} {opt tol(real 1e-7)} {opt msg(string)}]

{p 8 17 2}
{cmd:stqa_approx} {it:num1} {cmd:==} {it:num2} [{cmd:,} {opt tol(real 1e-7)} {opt msg(string)}]

{pstd}
Both forms are equivalent. {opt tol()} and {opt tolerance()} are the same option.

{marker description}{...}
{title:Description}

{pstd}
{cmd:stqa_approx} verifies that two numbers are approximately equal, within a specified tolerance. This is essential for testing statistical results where floating-point arithmetic may cause minor differences.

{pstd}
If {it:abs(num1 - num2) > tol}, the command displays a {cmd:FAIL:} line naming the current test id, followed by {cmd:Expected:} and {cmd:Got:} diagnostics, and exits with return code 9.

{pstd}
Inside a skipped test block ({cmd:$stqa_skip_block} equal to {cmd:1}) the command is a no-op.

{marker options}{...}
{title:Options}

{phang}
{opt tol(real)} specifies the tolerance. The default is 1e-7. May also be spelled {opt tolerance()}.

{phang}
{opt msg(string)} specifies a custom message to display if the assertion fails. It replaces the default description on the {cmd:FAIL:} line.

{marker examples}{...}
{title:Examples}

{pstd}Check if a mean is approximately correct:{p_end}
{phang2}. summarize mpg{p_end}
{phang2}. stqa_approx r(mean) 21.2973, tol(1e-4){p_end}

{pstd}The same assertion written with {cmd:==}:{p_end}
{phang2}. regress price mpg weight{p_end}
{phang2}. stqa_approx _b[mpg] == -49.51, tol(0.1){p_end}
