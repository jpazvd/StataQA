# qa/ — the package's own certification suite

Run from the repository root:

```stata
stataqa review qa     // executes; records nothing (run is an alias)
stataqa certify qa    // executes and appends the ledger stanza
```

Either role executes every `qa/test_*.do`, reads each file's verdict back out
of its log, and prints the per-family summary. Only `certify` appends a stanza
to the append-only ledger `qa/test_history.txt` (a `review` logs to scratch
and records nothing). Red and incomplete runs are recorded identically to
green ones.

## Check-ID discipline

Check IDs (`FAMILY-NN`) are immutable once they appear in a committed ledger
stanza. A retired ID is never reused; a renumbered check gets a fresh number.

### Retired IDs

| ID range | File | Retired | Why |
| --- | --- | --- | --- |
| INT-01..05 | `test_check_api.do` | 07aug2026 | `stqa_check_api` cut (strip-to-core) |
| INT-01..04 | `test_optional_deps.do` | 07aug2026 | `stqa_lint` / `stqa_repro` / `stqa_install_deps` cut; ids collided with `test_check_api.do` |
| META-01..03 | `test_check_meta.do` | 07aug2026 | `stqa_check_meta` cut; its note counter could never fire (`_note` vs `note0`) |
| DATA-01..04 | `test_check_pii.do` | 07aug2026 | `stqa_check_pii` cut; its email regex could never fire (`{2,}` under `regexm()`); ids collided with `test_harness.do` |
| DATA-11..15 | `test_check_sdmx.do` | 07aug2026 | `stqa_check_sdmx` cut |
| DATA-21..22 | `test_check_standards.do` | 07aug2026 | `stqa_check_standards` cut |
| REGR-01..02 | `test_check_stats.do` | 07aug2026 | `stqa_check_stats` cut |
| ENV-04..07, DISC-04..05 | `test_static.do` | 07aug2026 | `stqa_check_code` / `stqa_check_dependency` / `stqa_scan` / `stqa_check_requirements` cut |
| SMOKE-05 | `test_smoke.do` | 07aug2026 | the check modules it autoloaded were cut |
| SMOKE-01..02 (in `test_example.do`) | `test_example.do` | 07aug2026 | ids collided with `test_smoke.do`; renumbered to SMOKE-07..08 |

`DATA-01..02` and `INT-01..04` remain **live** in `test_harness.do` and
`test_pipeline.do` respectively — the collisions above were duplicate uses,
found by the 07aug2026 duplicate-id sweep, and the surviving files keep the ids.

The last stanza in which the retired ids appear as run checks is the
`GATE RED` stanza of 7 Aug 2026 (85 checks), in the development repository's
ledger. (Each repository keeps its own ledger; a public distribution clone
starts its record with the first certification run against it.)
