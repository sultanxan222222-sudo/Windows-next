# Windows Next

**One installable Windows maintenance package, tailored first for the Acer Aspire V3-772.**

The project is moving from a read-only inventory into a controlled, fail-closed maintenance application. Its target is one self-installing EXE that places the application on the computer, checks the hardware, selects only evidence-approved components, applies them in a controlled order, validates the result, and provides a recovery route.

## Current build: installable app + read-only compatibility planning

The current release candidate builds a single Inno Setup EXE. It installs the Windows Next application files and shortcuts, then can launch the diagnostic tool. The tool collects:

- Windows edition, version, build, and architecture.
- CPU and system model.
- Graphics adapters, device IDs, and driver metadata.
- Physical disks and reported health.
- Memory modules, speed, and memory-array information.
- Network and Bluetooth devices with driver metadata.
- Active power plan and Secure Boot status.

It then compares live hardware IDs with the component manifest. The component planner is **read-only** and fails closed.

### Build the installer

The GitHub Actions workflow `.github/workflows/build-installer.yml` runs the PowerShell tests, compiles `installer/WindowsNext.iss`, and publishes `WindowsNext-Setup-0.2.0.exe` as a downloadable workflow artifact.

For local builds, use Inno Setup 6:

```powershell
& "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe" .\installer\WindowsNext.iss
```

The output is placed in `dist\WindowsNext-Setup-0.2.0.exe`.

## Current hardware target

- Acer Aspire V3-772 / VA70 HW
- Intel Core i5-4200M
- Intel HD Graphics 4600
- NVIDIA GeForce GT 750M
- 8 GB Kingston DDR3L-1600
- Apacer AS340 120 GB SSD and Seagate 500 GB HDD
- Qualcomm Atheros AR5BWB222 Wi-Fi
- Broadcom NetLink Gigabit Ethernet
- Qualcomm Atheros Bluetooth module
- Windows 11 Pro x64, build 22000.2600

The detailed identifiers and installed driver versions are recorded in `manifest/profiles/acer-aspire-v3-772.json`.

## Driver installation status

**No driver is currently approved for unattended installation.** The graphics and network packages are being checked against exact device IDs, Windows 11 build support, vendor security notices, signatures, hashes, and rollback requirements. This is intentional: a driver with a higher version number is not automatically safer or more compatible.

The current installer installs Windows Next itself and runs read-only diagnostics. It does not yet install third-party drivers or apply system tweaks. Those operations remain disabled until validated packages and recovery tests are available.

## Safety contract

- No BIOS, UEFI, VBIOS, EC, or device firmware changes.
- No voltage, overclocking, thermal-limit, or fan-safety changes.
- No disabling Defender, Windows Update, Secure Boot, or driver-signature enforcement.
- No forced driver installation or opaque registry/debloat bundles.
- Changes must be backed up, applied one at a time, verified, logged, and recoverable.
- A failed validation stops the sequence.

See `docs/SAFETY-CONTRACT.md`, `docs/DRIVER-SELECTION.md`, and `docs/COMPATIBILITY-RESEARCH.md`.
