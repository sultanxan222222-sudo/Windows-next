# First installer release gate

This document records the validation requirements for the first Windows Next EXE. It does not claim that a binary has already passed them.

## Required automated checks

- Parse all PowerShell entry points and modules.
- Run Pester inventory, report, and fail-closed component-plan tests.
- Compile `installer/WindowsNext.iss` with Inno Setup 6 on a Windows runner.
- Confirm the EXE and its SHA-256 sidecar were uploaded as the workflow artifact.

## Required manual target-machine checks

- Install on the target Acer Aspire V3-772 and verify the Program Files location and Start Menu shortcut.
- Run the diagnostic entry point and confirm the report includes OS lifecycle warnings, graphics, storage, RAM, Wi-Fi, Ethernet, and Bluetooth.
- Verify installation does not modify drivers, Windows security, firmware, power settings, or thermal limits.
- Uninstall and confirm the tool removes its own installed files without deleting user reports.

## Release status

The first installer milestone is an installer for the Windows Next application itself. It is not yet an offline driver bundle or automatic system optimizer. Third-party driver installation remains disabled until exact package, signature, operating-system applicability, rollback, and target-hardware tests are approved.
