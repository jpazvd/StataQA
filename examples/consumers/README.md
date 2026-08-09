# examples/consumers/ — StataQA suites for the maintainer's public packages

Each subdirectory is a **worked example**: a StataQA test suite exercising one
of the maintainer's published Stata packages (`yaml`, `unicefdata`,
`wbopendata`, `datalib`) as an ordinary user would install it.

## Why the suites live HERE and not in those repos

StataQA is not yet public. A `qa/` tree inside `yaml`'s repository that called
`stqa_*` would make a public package depend on a private one — unbuildable by
anyone but the maintainer, which is the opposite of what a test suite is for.
So, deliberately:

- **These suites are examples shipped with StataQA**, demonstrating how to test
  a real published package. They are part of this repo's documentation surface.
- **The consumer repos keep their own hand-rolled harnesses unchanged** until
  StataQA is publicly installable; migration in place is a decision for that
  day, not this one (`internal/DESIGN-ssc-and-rivals.md` §5, step 5 as
  amended).
- Each suite targets the package **as installed** (`ssc install` /
  `net install` from its public home), never a local working tree —
  a suite that quietly tested the working tree would certify code nobody else
  has (the `ENV-04` lesson from the yaml suite).

## Running one

```stata
net install stataqa, from("https://raw.githubusercontent.com/jpazvd/StataQA/main/src") replace
stataqa run examples/consumers/yaml
```

Every block starts by checking the package under test is installed and calls
`stqa_skip` if it is not, so the suite reports SKIP — not failure, and not
silence — on a machine without it.

These runs are **reviews, not certifications**: they exercise a package this
repo does not own, so their results are not appended to any ledger the package
could cite (see `internal/DESIGN-roles.md` — a record is trustworthy to the
degree that the certifying repo owns it).

| Suite | Package under test | Public home | Environmental skips |
| --- | --- | --- | --- |
| `yaml/` | `yaml` | github.com/jpazvd/yaml | package absent |
| `unicefdata/` | `unicefdata` | github.com/unicef-drp | package absent; API unreachable |
| `wbopendata/` | `wbopendata` | SSC | package absent; API unreachable |
| `datalib/` | `datalib` | github.com/jpazvd | package absent; library root not mounted |

A suite is **never red for environmental reasons**: absence of the package, the
network, or the mounted share reads as SKIP, reported with its reason. Red is
reserved for a package that is present and misbehaves.
