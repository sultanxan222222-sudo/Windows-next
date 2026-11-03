# Development roadmap

## M0 — hardware inventory
- [x] Create repository and safety policy.
- [x] Collect Windows, CPU, graphics IDs, storage, Secure Boot, and power plan.
- [x] Confirm live target inventory from the user's Acer.
- [x] Extend inventory to memory modules, memory-array information, network, and Bluetooth.
- [x] Produce JSON and readable TXT reports.

## M1 — compatibility research
- [x] Record exact Acer identifiers and installed driver versions.
- [x] Review Intel's legacy graphics security and DirectX notes.
- [x] Review NVIDIA's mobile Kepler end-of-support statement.
- [x] Check the Microsoft Update Catalog for the exact Atheros subsystem ID.
- [x] Keep every unverified driver blocked in the component manifest.
- [ ] Finish independent review of storage, audio, chipset, USB, card-reader, touchpad, and camera devices.

## M2 — one-file installer foundation
- [x] Add Inno Setup definition for a single self-installing EXE.
- [x] Install the application and shortcuts under Program Files.
- [x] Add CI workflow to test source and compile the installer.
- [x] Add read-only, fail-closed component planning.
- [ ] Verify the first CI build and download artifact.
- [ ] Test install, launch, uninstall, and reinstall on the target Acer.

## M3 — controlled component engine
- [ ] Add a verified package catalog with exact IDs, OS build rules, SHA-256, and signature requirements.
- [ ] Add driver export, restore-point checks, and preflight validation.
- [ ] Implement one-component-at-a-time staging, supported installation, and post-install verification.
- [ ] Add rollback and fault-injection tests.
- [ ] Do not enable this milestone until a specific driver package passes all gates.

## M4 — single-package component bundle
- [ ] Bundle only approved offline payloads into the single EXE.
- [ ] Detect the computer and select compatible packages automatically.
- [ ] Install approved components in deterministic order with logs and recovery.
- [ ] Produce one final success/failure report.
- [ ] Verify no internet connection is required for offline installation.

## M5 — performance and stability
- [ ] Establish before/after measurements.
- [ ] Tune only reversible, evidence-backed Windows settings.
- [ ] Validate idle, sleep/wake, display switching, video, and representative games.
- [ ] Publish only after target-hardware acceptance tests.

A milestone is complete only when its tests and target-hardware acceptance evidence exist.
