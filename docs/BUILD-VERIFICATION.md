# Windows Next 0.5.0 — build and acceptance record

## Automated release checks

The current CI workflow runs on a Windows GitHub Actions runner:

1. Installs PSScriptAnalyzer and Pester.
2. Parses and analyzes every PowerShell script and module, failing on analyzer errors.
3. Runs the Pester suite, including checks for:
   - source syntax and task entry points;
   - read-only performance and report functions;
   - fail-closed component manifest;
   - startup-entry backup, disable, and restore;
   - Visual C++ runtime source/signature safeguards;
   - .NET Framework 3.5 DISM feature setup and no forced reboot;
   - exact Hardware ID / newer driver-date rules;
   - post-install Device Manager verification guards;
   - Windows Update driver-category-only search.
4. Compiles the single Inno Setup EXE.
5. Creates a SHA-256 checksum and uploads both files as a workflow artifact.

The version and artifact filename are read from `installer/WindowsNext.iss`, avoiding a hard-coded version mismatch.

## Manual acceptance required on the Acer Aspire V3-772

The hosted CI runner is not the user's laptop. The following must be checked on the actual machine before claiming hardware acceptance:

- Install the one-file EXE, open Windows Next, close it, and uninstall it.
- Confirm all tabs open and Russian labels are readable.
- Check that driver inventory lists the expected Intel HD 4600, NVIDIA GT 750M, WLAN, Ethernet, and Bluetooth IDs.
- Run a read-only Windows Update driver search and confirm every result is exact-ID matched. A result list of zero is valid and safer than an unsupported driver.
- Do not test driver installation on the target unless a candidate is independently confirmed, a restore point is available, and the laptop is on AC power.
- Verify the startup backup/restore with a harmless nonessential user startup entry.
- Verify Visual C++ package signatures on the live machine; only install when a component is missing or older.
- Verify .NET Framework 3.5 state; enable it only when an older application actually needs it.
- Check SSD/HDD maintenance actions and Windows repair only after creating the required restore point.

## Current limitations

- No third-party driver bundle is approved for this exact Windows 11 21H2 laptop.
- Windows 11 Pro 21H2 is out of servicing and the i5-4200M is not an officially supported Windows 11 CPU. Windows Next does not bypass the CPU requirement or perform a feature upgrade.
- Intel HD 4600 and NVIDIA GT 750M are legacy graphics devices. The app will not downgrade the Intel driver to restore a DirectX feature or force an unsupported NVIDIA package.
- The installer currently has no trusted publisher code-signing certificate.
- CI success proves source checks and EXE compilation; it does not prove runtime behavior, driver update availability, or hardware acceptance on the physical Acer.
