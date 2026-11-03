# Windows Next development roadmap

## M0 — hardware profile
- [x] Collect target machine and Windows inventory.
- [x] Record exact GPU and network hardware identifiers.
- [x] Record storage and memory module identities.
- [x] Record driver provenance, installed versions, and compatibility decisions.

## M1 — desktop product foundation
- [x] Replace diagnostic-only startup with the Windows Next desktop maintenance center.
- [x] Add a Russian-language interface and separate feature areas.
- [x] Add task execution with independent result files, operation logs, and UAC elevation where needed.
- [x] Preserve the inventory utility as a separate diagnostic tool.

## M2 — working maintenance modules
- [x] Clean only current-user temporary files older than 14 days.
- [x] Use Windows Optimize-Volume on the system volume, letting Windows select SSD/HDD behavior.
- [x] Run a non-offline NTFS volume scan.
- [x] Run DISM ScanHealth and SFC VerifyOnly.
- [x] Run DISM RestoreHealth and SFC Scannow only after a restore point is successfully created and the user confirms.
- [x] Create a named restore point on request.
- [x] Export third-party drivers with CSV/JSON index and per-file SHA-256 hashes.
- [x] Display existing GPU/network/Bluetooth drivers and IDs.

## M3 — package and release
- [x] Build a single self-installing EXE with Inno Setup.
- [x] Install application files and Start Menu/Desktop shortcuts.
- [x] Include the complete application and its modules in the same installer.
- [x] Run PowerShell analysis and Pester tests in CI.
- [ ] Validate the updated 0.3.0 app build and artifact.
- [ ] Test install, first launch, each maintenance action, and uninstall on the target Acer.
- [ ] Provide a signed publisher certificate before any public consumer release.

## M4 — component deployment
- [ ] Build a package catalog with exact device IDs, OS build, signed catalog, SHA-256, and provenance.
- [ ] Research and test chipset, audio, USB, card reader, camera, touchpad, WLAN, Bluetooth, Ethernet, and graphics packages.
- [ ] Add driver installation only after package signature, INF match, and recovery tests pass.
- [ ] Provide offline package payloads in the one EXE only after they have been approved.
- [ ] Never force-install a package or bypass driver signature checks.

## M5 — Windows servicing and performance
- [ ] Determine a supported OS servicing route for the unsupported i5-4200M, without BIOS or boot-policy changes.
- [ ] Add before/after measurements for boot, idle CPU/RAM, storage, and representative workloads.
- [ ] Add reversible performance profiles only when they preserve Windows security, sleep, thermal, and battery behavior.
- [ ] Test sleep/wake, display switching, video playback, Wi-Fi, audio, and games on the target Acer.

A release milestone is complete only after code, tests, and target-machine acceptance evidence exist. A successful CI build alone does not prove hardware acceptance.
