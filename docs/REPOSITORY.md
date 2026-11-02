# Standalone repository and local research

Git contains the standalone ScalpingBot source, profiles, documentation, offline tests, native fixture sources and current EA binary. The working project may also remain inside a larger trading-robot workspace. CapitalGuard and parent-workspace files are not part of this import.

The compact records in artifacts/daily-lock-v1 describe the last locally tested EA build. Full native logs, simulated inputs, HTML/PNG reports, account/trade data, source-workspace preservation baselines and historical release archives remain local. Their paths mentioned in historical reports are provenance references, not promised files in a fresh clone. The `preserved_files` counts document checks against that original local workspace.

For a clean clone, run tests/verify_project.ps1, tests/test_rules.ps1, tests/test_risk_execution.ps1 and the Python unittest command in README. The project verifier automatically selects standalone checks if the original protected-file snapshot is absent. The current release fingerprint can be checked with tests/verify_repository.ps1 -VerifyReleaseSnapshot. Historical report snapshots remain immutable; future code changes require a new build/validation record rather than assuming the old one proves the new source.

To compile native tests, use compile.ps1 -MetaEditor <your editor> -Source tests/<Fixture>.mq5. Native fixtures refuse ordinary non-tester initialization. This repository does not bundle MT5 terminal executables or account credentials.

The existing prepare_*_backtests.ps1, prepare_daily_risk_tests.ps1, run_backtests.ps1 and historical report/package/preservation tools were developed against the original workstation. Some have explicit installation/cache/server/login parameters; some require local snapshots or archives from previous phases and a local Python installation. Inspect and configure their parameters/paths before using them. They are not part of the portable CI contract and are retained as local research tooling. Reconstruct missing baseline evidence from a retained local archive rather than inventing it.

Use a dedicated portable tester for simulations. Keep its files beneath artifacts/test-terminal; .gitignore excludes them. Do not commit Config/accounts.dat, servers.dat, common.ini, password fields, raw logs or downloaded history. No publication step deploys the EA or changes a running terminal.

The all-five execution profile deliberately disables daily-baseline/daily-loss entry enforcement and both signal-only switches. Its real-account block and unverified broker-time defaults remain active. Preserve or explicitly configure the desired broker-time inputs when applying it; publishing this profile does not verify any broker's historical UTC/DST policy.
