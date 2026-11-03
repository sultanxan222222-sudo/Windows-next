# Windows Next

**Windows Next is a Windows maintenance and recovery suite, packaged as one installer.** The first target is the user's Acer Aspire V3-772 running Windows 11 x64.

## What the desktop app does

The application is a Russian-language Windows Forms desktop program with six areas: system overview, maintenance, driver inventory/backup, software libraries, user startup management, and logs.

- **Temporary-file cleanup:** removes only the current user's LocalAppData\Temp files older than 14 days. It does not clean Downloads, Documents, Windows folders, or recent files.
- **Drive optimization:** invokes Windows' own Optimize-Volume operation on any selected fixed local volume, so the SSD and HDD can be handled separately. Windows decides whether to issue SSD optimization/TRIM or an HDD optimization.
- **Drive scan:** runs the supported online scan for any selected NTFS volume and does not schedule an offline repair at reboot.
- **Windows health check:** runs DISM ScanHealth and SFC VerifyOnly without repairing files.
- **Windows repair:** asks for confirmation, requires a successful System Restore checkpoint, then runs DISM RestoreHealth and SFC Scannow.
- **Restore point:** creates a named Windows restore point when System Protection is available.
- **Driver backup:** exports third-party Windows driver packages to Documents\WindowsNext\DriverBackup, writes a CSV/JSON index, and calculates SHA-256 for each exported file.
- **Device view:** shows current display, network, and Bluetooth driver versions and hardware IDs.
- **Reports and logs:** keeps readable records under %LOCALAPPDATA%\WindowsNext.

System-level tasks ask for UAC elevation separately. The app stays responsive while the task runs and checks its result.

## Target machine

The initial inventory is recorded in `manifest/profiles/acer-aspire-v3-772.json`:

- Acer Aspire V3-772 / VA70 HW
- Intel Core i5-4200M
- Intel HD Graphics 4600 and NVIDIA GeForce GT 750M
- 8 GB Kingston DDR3L-1600
- Apacer AS340 120 GB SSD and Seagate ST500LT012 500 GB HDD
- Qualcomm Atheros AR5BWB222 Wi-Fi, Broadcom NetLink Gigabit Ethernet, Qualcomm Bluetooth
- Windows 11 Pro x64, build 22000.2600

## Driver and system upgrade policy

The component manifest is fail-closed. It currently contains **no approved unattended third-party driver packages** for this exact Windows 11 build. The application therefore inventories and backs up drivers but does not replace them. This is deliberate: driver names and newer version numbers alone are not sufficient proof of compatibility.

Windows 11 Pro 21H2 is out of servicing. A supported OS path is a separate engineering gate; Windows Next does not force an upgrade or bypass processor requirements. BIOS, UEFI, VBIOS, device firmware, voltage, clocks, fan controls, thermal limits, driver signature enforcement, Windows Defender, and Secure Boot are never modified.

## Build and package

The GitHub Actions workflow `/.github/workflows/build-installer.yml` runs PowerShell analysis and Pester tests, then compiles a single Inno Setup EXE and uploads its SHA-256 sidecar.

Current development version: **0.4.1**.

## Performance assessment

The dashboard includes a read-only assessment of memory modules, Windows-volume free space, common Run-key entries, and Windows build. The separate startup tab can disable only selected current-user Run entries after making a backup; machine-wide entries remain read-only. This can reduce the number of apps launched at sign-in, but the user must identify unnecessary items. The Visual C++ installer restores a common application prerequisite; it is not a benchmark and does not promise a frame-rate or speed increase.

For local compilation on Windows with Inno Setup 6:

```powershell
& "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe" .\installer\WindowsNext.iss
```

The build output is `dist\WindowsNext-Setup-<version>.exe`.

## Safety boundaries

- No BIOS, UEFI, VBIOS, EC, or device firmware changes.
- No voltage, overclocking, thermal-limit, or fan-safety changes.
- No disabling Defender, Windows Update, Secure Boot, or driver-signature enforcement.
- No forced installation of unknown drivers and no opaque registry/debloat bundles.
- Changes are user-confirmed and logged. Current exceptions to built-in maintenance are limited to the verified Microsoft Visual C++ v14 installer and the explicitly backed-up current-user Run entries.
- Do not claim zero risk. Repair functions can alter system files and must be explicitly confirmed.

## Development state

Current development includes the maintenance center, read-only hardware/performance assessment, reversible current-user startup controls, and a signature-checked Microsoft Visual C++ v14 installer. Device-driver installation remains disabled: no third-party driver package has passed exact hardware-ID and Windows-build validation for this laptop. The app has not yet passed install/use/uninstall acceptance testing on the physical Acer; CI success alone is not hardware acceptance.
