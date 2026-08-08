# stataqa — Local certification and quality assurance for Stata

`stataqa` is a framework for **local certification**, **automated testing**, and **license-aware continuous integration (CI)** in Stata. It provides a suite of tools to write robust tests, validate datasets, and generate machine-readable reports (JUnit XML) for integration with CI systems like GitHub Actions.

> **Lineage:** this project supersedes `stataci` (jpazvd/stataci, frozen as an archive at its final state, 2026-01). The package was renamed at import — `stataci`→`stataqa`, `stci_*`→`stqa_*` — because to a statistics audience "CI" reads as *confidence interval* (Stata itself ships `ci` and `stci`). A companion article is under review at the Stata Journal.

## Features

- **Test Runner**: Discover and execute test scripts (`.do` files) automatically.
- **CI Integration**: Generate JUnit XML reports compatible with GitHub Actions, Jenkins, etc.
- **Certification record**: a `certify` run appends a stanza to the append-only
  ledger `qa/test_history.txt`, pinning branch, commit, and dirty state; the
  verdict is read out of the log (`stqa_scanlog`), never from the batch exit
  code. `review` executes without recording; `validate` judges the record
  without executing.
- **Chain of custody for test data**: `stqa_manifest` blesses frozen inputs and
  golden-master output pairs into a typed manifest; `stqa_fixture` refuses to
  hand a test an input that drifted since blessing; `stqa_replay` re-runs a
  blessed do-file and requires the same output.
- **Assertions**: beyond simple `assert` — dataset equality (`stqa_dta_equal`),
  numeric tolerance (`stqa_approx`), structure, identifiers, survey design, and
  return-code expectations. All run with base Stata only.
- **Docs as tests**: `stqa_examples` harvests and runs the clickable examples in a
  help file or an examples gallery; `stqa_cmdline` books any single command line.
- **Test Blocks**: Define granular test cases within a single file using `stqa_test` and `stqa_endtest`.

## Why stataqa

Stata has had test *assertions* for decades (`assert`, `cscript`), and two
community unit-test packages exist on GitHub — `stata_unit_test` (Skinner 2019)
and `adotest` (Dutey 2024–26). What none of them produces is a **trustworthy,
auditable record** of what was verified. The comparison below is from a
line-level review of both packages with the load-bearing behaviours executed
on Stata 17 (07aug2026):

| | stata_unit_test | adotest | **stataqa** |
| --- | --- | --- | --- |
| Installable (`net install`) | no — do-file `include` only | yes | yes |
| Survives `clear all` | no (do-defined programs vanish) | yes | yes |
| Exit code on a red suite | **0** | **0** | 9, from the log-sentinel rule |
| Suite summary | none at all | banner reads **observation 1 only** — can miss red | counts that reconcile, per family |
| Run artifact | none | per-run CSV+log: counts and timestamps only | append-only ledger: verdict rule, counts, failed ids, Stata flavour, package version, **git commit** |
| Verdict source | human reads the screen | class counters **the code under test can rewrite** | line-initial tokens read back out of the log |
| Vacuous (zero-obs) assertions | pass silently | `null` guard on assert only | `null` guard on `stqa_assert` + hard zero-obs failures in the data assertions |
| Help files | none | none | one per command |
| Licence | none (all rights reserved) | GPL-3 | MIT (`LICENSE` at the repository root; every command carries a `License: MIT` header) |

The one mechanism a rival had that stataqa lacked — adotest's vacuity guard —
was adopted (as `stqa_assert, null`, StataCorp's own `assert` option) and is
credited in its help file. Everything else this package declines from the
rivals, it declines for cause: console-snapshot hashing breaks on locale and
version banners; certutil-via-.bat hashing is Windows-only; class-counter
verdicts are writable by the code they judge.

## Installation

Install from this repository:

```stata
net install stataqa, from("https://raw.githubusercontent.com/jpazvd/StataQA/main/src") replace
```

Install from a local clone (no internet required):

```stata
net install stataqa, from("path/to/StataQA/src") replace
```

This repository is the distribution home for `stataqa`. Each release published
here is a tagged snapshot, certified by running the shipped suite
(`stataqa certify qa`) against the tag — the resulting stanza in
`qa/test_history.txt` pins the exact commit that was verified. The package
matches the version described in the companion Stata Journal article.

## Quick Start

1. **Initialize a test suite**:
   ```stata
   stataqa init tests
   ```

2. **Write a test file** (e.g., `tests/test_analysis.do`):
   ```stata
   stqa_test "Data Load"
       sysuse auto, clear
       assert _N == 74
   stqa_endtest

   stqa_test "Regression Model"
       reg price mpg weight
       stqa_approx _b[mpg] == -49.51, tol(0.1)
   stqa_endtest
   ```

3. **Review, then certify**:
   ```stata
   stataqa review tests    // executes; records nothing (the default role)
   stataqa certify tests   // executes and appends the ledger stanza
   stataqa validate        // no execution: is the record green, coherent,
                           // and pinned to THIS commit?
   ```
   `run` is an alias for `review`: entering the certification record
   requires saying so.

## Command Reference

### Core Commands
- `stataqa review [path]`: Execute tests; record nothing (default role; `run` is an alias).
- `stataqa certify [path]`: Execute tests and append the certification stanza (warns on a dirty tree).
- `stataqa validate`: Judge the existing record against this tree; executes nothing.
- `stataqa init [path]`: Create a new test directory with a sample test.

### Fixtures and golden masters
- `stqa_manifest`: Bless and verify the data column of the record (`qa/manifest.txt`).
- `stqa_fixture`: Verified access to a frozen input — exists, listed, unchanged, then loaded or resolved.
- `stqa_replay`: Re-run a blessed do-file and require the same output as its golden-master log.

### Assertions & Checks (core)
- `stqa_assert`: General assertion wrapper.
- `stqa_approx`: Check if two numbers are approximately equal.
- `stqa_approx_all`: Ensure all values in a variable are within tolerance of a target.
- `stqa_rcof`: Verify that a command returns a specific error code.
- `stqa_rc_zero`: Assert last return code is zero.
- `stqa_dta_equal`: Assert that the dataset in memory matches a file on disk.
- `stqa_inrange`: Assert value lies within bounds.
- `stqa_iso3`: Assert a variable’s distinct values are valid ISO3 country codes.
- `stqa_unique`: Assert the count of distinct values in a variable (supports `count()`, `gt/lt/ge/le`).
- `stqa_uniqueid`: Assert that one or more variables uniquely identify observations.
- `stqa_hasvar`: Assert that a variable exists in the dataset.
- `stqa_shape`: Assert dataset shape (optionally check nobs and vars).
- `stqa_nomissing`: Assert no missing values in a varlist.
- `stqa_nobs_min`: Assert a minimum number of observations in memory.
- `stqa_vartype`: Assert a variable has an expected storage type.
- `stqa_file_exists`: Assert a file exists.
- `stqa_dir_exists`: Assert a directory exists (optionally create with `, create`).

> The domain checkers (`stqa_check_*`), the dependency scanner and the
> `stata_linter`/`repkit` wrappers were parked on 07aug2026 — the package now
> owns everything downstream of "the environment is ready", and nothing
> upstream of it.

### Flow Control
- `stqa_test "Name"`: Begin a test block.
- `stqa_endtest`: End a test block.
- `stqa_skip "Reason"`: Skip the current test block.

## Repository Structure

```text
.
├─ src/
│  ├─ stataqa.pkg         # net-install manifest
│  ├─ stata.toc
│  └─ s/                  # one command per ado-file, one help file per command
├─ qa/                    # the package's own certification suite
│  ├─ test_*.do
│  ├─ fixtures/           # frozen inputs, incl. captured ledger dialects
│  ├─ test_history.txt    # this repository's append-only certification ledger
│  └─ README.md           # check-id discipline and retirements
├─ LICENSE
└─ README.md
```

## Author

**João Pedro Azevedo**  
UNICEF  
jpazevedo@unicef.org
