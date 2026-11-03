# Windows Next 0.3.0 target-machine acceptance

This checklist verifies the actual desktop maintenance product, not only its inventory code.

## CI gates
- [ ] All PowerShell files parse without syntax errors.
- [ ] PSScriptAnalyzer reports no errors.
- [ ] Pester passes.
- [ ] Inno Setup compiles the one-file installer.
- [ ] Installer and SHA-256 sidecar are uploaded as a build artifact.

## Target Acer checks
- [ ] Install and launch the Windows Next Maintenance Center.
- [ ] Confirm the overview identifies the Acer Aspire V3-772 and both GPUs.
- [ ] Confirm the driver page displays graphics/network devices and their existing versions.
- [ ] Verify temporary cleanup only targets current-user LocalAppData Temp files older than 14 days.
- [ ] Verify SSD/HDD optimization uses Windows Optimize-Volume.
- [ ] Verify NTFS online scan does not schedule an offline boot-time repair.
- [ ] Verify DISM/SFC health check runs verification-only.
- [ ] Verify repair requires successful restore-point creation and explicit confirmation.
- [ ] Verify driver export creates a CSV/JSON index and SHA-256 manifest.
- [ ] Verify each action writes a log and cancellation of UAC does not start the action.
- [ ] Verify uninstall removes only the application installation and leaves reports/backups.

## Deliberately disabled in 0.3.0
- Third-party driver auto-installation.
- Forced graphics-driver replacement.
- Windows feature upgrades or TPM/CPU requirement bypass.
- BIOS/UEFI/VBIOS/firmware writes, overclocking, voltage, fan or thermal-limit changes.
- Defender, Secure Boot, Windows Update, or driver-signature enforcement changes.

CI success is not a substitute for running this checklist on the target Acer.
