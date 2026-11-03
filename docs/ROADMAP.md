# Development roadmap

## M0 — repository and read-only inventory
- [x] Create Windows Next repository and safety policy.
- [x] Add a read-only PowerShell inventory.
- [x] Collect exact display-device IDs and current driver metadata where Windows exposes them.
- [x] Produce JSON and readable TXT reports.
- [ ] Run the inventory on the target Acer and review the report.

## M1 — evidence-based compatibility research
- [ ] Confirm exact Acer model/revision, GPU PCI IDs, Windows build, and currently installed driver packages.
- [ ] Research official Intel/NVIDIA/Microsoft driver packages and published release notes.
- [ ] Record verified package hashes, signatures, supported IDs, and OS applicability.
- [ ] Decide whether a supported driver combination exists for each adapter.
- [ ] Document DirectX API support separately from runtime installation.

## M2 — controlled component engine
- [ ] Build package catalog validation and fail-closed selection.
- [ ] Add package signature and SHA-256 verification.
- [ ] Add driver export, recovery-point checks, and preflight validation.
- [ ] Implement one-component-at-a-time staging and post-install validation.
- [ ] Add rollback logic and fault-injection tests.

## M3 — single-package installer
- [ ] Build one signed or reproducibly packaged installer containing all approved components.
- [ ] Detect hardware and Windows automatically.
- [ ] Install components to their correct Windows-managed locations in a deterministic order.
- [ ] Produce one final report and clear success/failure status.
- [ ] Ensure no internet download is required during installation unless explicitly designed and approved.

## M4 — performance and stability
- [ ] Establish before/after measurements.
- [ ] Tune only reversible, evidence-backed Windows settings.
- [ ] Validate idle, sleep/wake, display switching, video playback, and representative application workloads.
- [ ] Publish a release only after target-hardware acceptance tests.

A milestone is not complete merely because source code exists. It is complete only when its tests and acceptance evidence exist.
