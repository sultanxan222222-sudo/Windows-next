# Windows Next safety contract

The user requires a careful, evidence-led process. This document is a release constraint, not marketing language.

## Never do

- Flash, modify, or write BIOS/UEFI, VBIOS, embedded-controller firmware, or device firmware.
- Change CPU/GPU voltage, overclocking limits, thermal limits, fan safety controls, or hardware protection.
- Disable Windows Defender, Windows Update, Secure Boot, driver-signature enforcement, or other security controls.
- Force a driver onto a device whose exact hardware ID or OS target does not match.
- Remove an existing driver before a replacement has been staged and verified.
- Apply opaque registry tweaks, debloat bundles, or undocumented services.
- Continue to the next installation stage after any failed validation.

## Required behavior

- Default to read-only inspection.
- Record each proposed change and why it is needed.
- Back up affected configuration before changes.
- Check that a supported recovery route exists before driver mutation.
- Make changes in small, ordered transactions.
- Verify the resulting device state after every transaction.
- Stop safely on uncertainty, unsupported hardware, low disk space, missing power, signature errors, or failed checks.
- Keep a human-readable log and a machine-readable result.
- Do not promise zero risk. Engineering must minimize, detect, and contain risk.

## Changes currently permitted

- Current-user Run startup entries may be disabled only one-by-one or as explicitly selected by the user. Windows Next writes a backup containing the exact value and registry data type before deleting the entry. Restore refuses to overwrite an existing value. HKLM entries are view-only.
- Microsoft Visual C++ v14 x86/x64 may be installed from Microsoft's official stable aka.ms endpoints only after explicit confirmation and UAC.
- .NET Framework 3.5 may be enabled only as the built-in Windows optional feature through DISM `/Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart`, after explicit confirmation and UAC. It uses the configured Windows component source and never triggers an automatic reboot. The installer must have a valid Authenticode signature from Microsoft Corporation. SHA-256 is recorded in the operation log. An installed equal/newer version is never downgraded. Temporary setup files are removed.
- Built-in maintenance functions are limited to user Temp cleanup, Optimize-Volume, online NTFS scan, DISM/SFC health checks, and repair only after a successful restore-point operation and explicit confirmation.
- Driver inventory and export are allowed. Third-party driver bundles remain disabled. A separate Windows Update path may offer only driver-category updates from the machine's already-configured Windows Update service, and only when the update's Hardware ID exactly matches a live device and the package date is newer than the installed driver date. Only one update can be installed per operation. Before installation, Windows Next exports third-party drivers, creates a restore point, requires UAC and explicit confirmation, and never reboots automatically. Updates with missing metadata, compatible-ID-only matches, equal/older dates, or interactive installers are rejected.

## Current build evidence

The hosted CI checks parse PowerShell, run ScriptAnalyzer at Error severity, and run Pester tests. These checks do not replace first-launch, install/uninstall, sleep/wake, graphics-switching, audio, network, or game testing on the actual Acer Aspire V3-772. No release may claim hardware acceptance until that testing has been performed.
