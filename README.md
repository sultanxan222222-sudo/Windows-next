# Windows Next

**Windows Next is a Windows maintenance and recovery suite, packaged as one installer.** The first target is the user's Acer Aspire V3-772 running Windows 11 x64.

## What the desktop app does

The application is a Russian-language Windows Forms desktop program with four areas: system overview, maintenance, driver inventory/backup, and logs.

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

Current product version: **0.3.0**.

For local compilation on Windows with Inno Setup 6:

```powershell
& "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe" .\installer\WindowsNext.iss
```

The build output is `dist\WindowsNext-Setup-0.3.0.exe`.

## Safety boundaries

- No BIOS, UEFI, VBIOS, EC, or device firmware changes.
- No voltage, overclocking, thermal-limit, or fan-safety changes.
- No disabling Defender, Windows Update, Secure Boot, or driver-signature enforcement.
- No forced installation of unknown drivers and no opaque registry/debloat bundles.
- Changes are user-confirmed, logged, and limited to built-in Windows maintenance commands.
- Do not claim zero risk. Repair functions can alter system files and must be explicitly confirmed.

## Development state

The desktop maintenance center is the first functional product milestone. The next work is controlled software/component deployment, supported OS servicing assessment, additional hardware modules (chipset, audio, USB, touchpad, camera), and before/after performance measurements. A feature is not considered complete until its operation and rollback behavior are tested on the target Acer.
