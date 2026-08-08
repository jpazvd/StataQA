{smcl}
{* *! version 1.0.0  08aug2026}{...}
{vieweralsosee "stataqa" "help stataqa"}{...}
{vieweralsosee "stqa_history" "help stqa_history"}{...}
{vieweralsosee "stqa_run" "help stqa_run"}{...}
{viewerjumpto "Syntax" "stqa_validate##syntax"}{...}
{viewerjumpto "Description" "stqa_validate##description"}{...}
{viewerjumpto "What is checked" "stqa_validate##checks"}{...}
{viewerjumpto "Stored results" "stqa_validate##results"}{...}
{title:Title}

{phang}
{bf:stqa_validate} {hline 2} Validate the certification record without executing anything

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stataqa validate} [{cmd:using} {it:ledgerfile}] [{cmd:,} {opt nofresh}]

{marker description}{...}
{title:Description}

{pstd}
The publisher role.  {cmd:stataqa validate} runs no tests, writes no files,
and appends nothing.  It reads the certification ledger's last stanza and
judges whether the {it:record} supports a release of {it:this} tree.  Every
check is a file read, which is what allows CI pattern~B to implement the same
contract in a shell script on a hosted runner that has no Stata license.

{marker checks}{...}
{title:What is checked}

{p 8 8 2}1. A stanza exists.  Nothing certified means nothing to release.{p_end}
{p 8 8 2}2. Its verdict is {cmd:GATE GREEN}.{p_end}
{p 8 8 2}3. Its own arithmetic reconciles ({cmd:Run} = {cmd:Passed} +
{cmd:Failed} + {cmd:Skipped}).  A record that disagrees with itself is not
evidence of anything.{p_end}
{p 8 8 2}4. {bf:Freshness}: the stanza's {cmd:Commit:} equals the commit of
the working tree being validated.  Without this, a run that forgot to certify
leaves the {it:previous} green stanza in place and a verdict-only validator
waves through a tree the record never saw {hline 2} two individually correct
behaviors composing into a false green.  Suppressed by {opt nofresh}; skipped
with a note when either side is not a git repository (an unzipped package,
for example).{p_end}

{pstd}
A certification made on a dirty tree ({cmd:Dirty: yes}) is flagged with a
note, not failed: the record says so honestly, and the reader decides.

{pstd}
Exit code 0 when everything holds; 9 otherwise, with each failure named.

{marker results}{...}
{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(ok)}}1 if validation passed{p_end}
{synopt:{cmd:r(green)}}1 if the verdict was GATE GREEN{p_end}
{synopt:{cmd:r(fresh)}}1 if the commit matched; 0 mismatch; . not checkable{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(commit)}}the stanza's recorded commit{p_end}
{synopt:{cmd:r(version)}}the stanza's recorded package version{p_end}

{title:Also see}

{pstd}{help stqa_history}, {help stqa_gitinfo}, {help stataqa:stataqa hub}{p_end}
