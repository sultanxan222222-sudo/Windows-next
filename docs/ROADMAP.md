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
- [x] Assess RAM layout, system-volume free space, Run startup count, and Windows build without modifying settings.
- [x] Add reversible backup/restore for selected current-user Run startup entries; keep machine Run keys view-only.
- [x] Add official Microsoft Visual C++ v14 x86/x64 setup with publisher signature check and post-install version verification.
- [x] Add opt-in .NET Framework 3.5 Windows optional feature enablement through DISM, with state check and no forced reboot.

## M3 — package and release
- [x] Build a single self-installing EXE with Inno Setup.
- [x] Install application files and Start Menu/Desktop shortcuts.
- [x] Include the complete application and its modules in the same installer.
- [x] Run PowerShell analysis and Pester tests in CI.
- [x] Validate the current build script, installer, checksum, and artifact in hosted CI (the CI build is not target-hardware acceptance).
- [ ] Test install, first launch, all tabs, each maintenance action, startup backup/restore, runtime installation, and uninstall on the target Acer.
- [ ] Provide a signed publisher certificate before any public consumer release.

## M4 — component deployment
- [ ] Build a package catalog with exact device IDs, OS build, signed catalog, SHA-256, and provenance.
- [ ] Research and test chipset, audio, USB, card reader, camera, touchpad, WLAN, Bluetooth, Ethernet, and graphics packages.
- [x] Add an opt-in Windows Update Agent driver path with exact live Hardware ID matching, newer-date check, one-at-a-time install, driver export, restore point, and no forced reboot.
- [ ] Test Windows Update discovery and installation against the exact Acer device set and verify Device Manager status after restart.
- [ ] Provide offline package payloads in the one EXE only after they have been approved.
- [ ] Never force-install a package or bypass driver signature checks.

## M5 — Windows servicing and performance
- [ ] Determine a supported OS servicing route for the unsupported i5-4200M, without BIOS or boot-policy changes.
- [ ] Add before/after measurements for boot, idle CPU/RAM, storage, and representative workloads.
- [ ] Add reversible performance profiles only when they preserve Windows security, sleep, thermal, and battery behavior.
- [ ] Test sleep/wake, display switching, video playback, Wi-Fi, audio, and games on the target Acer.

A release milestone is complete only after code, tests, and target-machine acceptance evidence exist. A successful CI build alone does not prove hardware acceptance.
