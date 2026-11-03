# Windows Next

**A single-package Windows maintenance and hardware-compatibility project.**

Windows Next is being developed first for the user-reported Acer Aspire V3-772 running Windows 11 x64. The long-term goal is one installer that identifies the machine, selects only verified compatible components, installs them in a controlled order, validates the result, and provides a recovery path.

## Current milestone: read-only inventory

The first implementation deliberately performs **no system changes**. It collects a privacy-conscious hardware and driver inventory so that later driver decisions are based on the machine's actual Plug-and-Play IDs and installed versions, not assumptions.

### Run the inventory

1. Download or clone this repository.
2. Double-click `Run-WindowsNext.cmd`.
3. The script writes JSON and readable TXT reports under:
   `%LOCALAPPDATA%\WindowsNext\Reports`
4. Share the report from the newest run for hardware-specific driver analysis.

It does not require administrator rights. It does not download drivers, change the registry, install or remove drivers, alter power settings, or touch BIOS/firmware.

## Initial target profile (must be confirmed by live inventory)

- Acer Aspire V3-772
- Intel Core i5-4200M
- Intel HD Graphics 4600
- NVIDIA GeForce GT 750M
- 8 GB RAM
- Windows 11 x64

This profile is a planning hint only. **It is not used as proof of device identity and cannot authorize a driver installation.**

## Safety model

- Fail closed: unknown or mismatched hardware means no installation.
- No BIOS, UEFI, VBIOS, firmware, voltage, overclocking, or thermal-limit changes.
- No disabling Windows security controls or driver-signature enforcement.
- Drivers must match the exact device IDs and OS target, have a traceable source, and pass signature/hash checks.
- Preserve the previous driver state and validate each stage before proceeding.
- A failed check stops the sequence; no later package is installed.

## Repository layout

- `src/` — Windows Next application and read-only inventory modules.
- `manifest/` — hardware planning profile and component approval state.
- `docs/` — engineering, driver-selection, and release-gate policies.
- `tests/` — PowerShell parsing and smoke tests.
- `.github/workflows/` — automated validation.

## Status

This is an engineering foundation, **not yet a driver installer**. No Intel or NVIDIA driver package is bundled or installed until the live inventory is reviewed and a specific package is verified for this exact machine and Windows build.
