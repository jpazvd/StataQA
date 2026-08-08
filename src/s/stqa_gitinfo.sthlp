{smcl}
{* *! version 1.0.0  08aug2026}{...}
{vieweralsosee "stqa_history" "help stqa_history"}{...}
{vieweralsosee "stqa_validate" "help stqa_validate"}{...}
{viewerjumpto "Syntax" "stqa_gitinfo##syntax"}{...}
{viewerjumpto "Description" "stqa_gitinfo##description"}{...}
{viewerjumpto "Stored results" "stqa_gitinfo##results"}{...}
{title:Title}

{phang}
{bf:stqa_gitinfo} {hline 2} Read git provenance for the working directory

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stqa_gitinfo} [{cmd:,} {opt nod:irty}]

{marker description}{...}
{title:Description}

{pstd}
A programmer's helper shared by {help stqa_history} (which records the fields
into the certification ledger) and {help stqa_validate} (which compares a
recorded stanza against the tree being validated).  Branch and commit are
read from {cmd:.git} directly {hline 2} {cmd:.git/HEAD}, the loose ref, or
{cmd:packed-refs} {hline 2} with no process spawn and no dependency on git
being installed, so it works where {cmd:shell} is refused.  Detached
{cmd:HEAD}, packed refs, and worktrees ({cmd:.git} as a file) are handled.

{pstd}
Dirty state is the one field that requires invoking git.  Because
{cmd:shell}'s return code proves nothing on Windows, the verdict is judged by
the artifact ({cmd:git status --porcelain} output captured to a file), and
any doubt degrades to missing with the state named {hline 2} never to a
clean-looking guess.  {opt nodirty} skips the probe entirely.

{pstd}
The command never errors: a missing repository is a reported state
({cmd:r(inrepo)} = 0, the string results say so in words), not a failure.

{marker results}{...}
{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(inrepo)}}1 inside a git repository, else 0{p_end}
{synopt:{cmd:r(dirty)}}1 dirty, 0 clean, . not determined{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(branch)}}branch name, or a parenthesized state{p_end}
{synopt:{cmd:r(commit)}}40-character commit SHA, or a parenthesized state{p_end}
{synopt:{cmd:r(dirtystate)}}{cmd:yes}, {cmd:no}, or a parenthesized state{p_end}

{title:Also see}

{pstd}{help stqa_history}, {help stqa_validate}, {help stataqa:stataqa hub}{p_end}
