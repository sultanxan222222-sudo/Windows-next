# Driver selection and approval rules

A driver is not considered compatible because its marketing name resembles the GPU name. Windows Next must identify the exact device and target operating system first.

## Required matching evidence

1. Full live Plug-and-Play hardware IDs, including vendor, device, subsystem, and revision where present.
2. Exact Windows edition, version, build, architecture, and relevant servicing level.
3. The vendor's supported-product list and release notes for that package.
4. Driver package INF match entries and Windows ranking information.
5. A valid signature chain for the signed catalog/package. Windows' normal driver-signature enforcement must remain enabled.
6. SHA-256 hashes and provenance recorded in the repository release manifest.
7. A tested installation, validation, and rollback procedure for the exact hardware/OS combination.

A family name such as HD 4600 or GT 750M is not a sufficient match.

## Fail-closed selection

- If the device ID is incomplete, ambiguous, or not listed: stop.
- If the OS build is outside the package's documented support range: stop.
- If package provenance, signature, or hash cannot be verified: stop.
- If the INF does not match the exact device: stop; never force-install it.
- If two packages conflict or the preferred package is uncertain: stop and request engineering review.
- No third-party vendor pack is downloaded or installed by this catalog. A separate user-approved Windows Update Agent workflow can offer only the machine's configured Windows Update driver-category entries, after exact live Hardware ID and strictly newer driver-date checks.

## Windows Update driver workflow implemented in the app

1. Search only `IsInstalled=0 and Type='Driver' and IsHidden=0` through the Windows Update Agent service already configured on the computer.
2. Reject updates without driver metadata, an exact live hardware-ID match, a newer driver date, or a noninteractive installation behavior.
3. Ask the user to select exactly one candidate; install one driver per operation.
4. Require at least 2 GB of free space, export current third-party driver packages, and successfully create a restore point. Stop if either recovery step fails.
5. Accept the selected package's EULA only after the user's confirmation, download through Windows Update Agent, and install without a forced reboot.
6. Check the WUA installation result. If no reboot is required, re-enumerate device driver state; if reboot is required, defer final verification until after restart.
7. Stop after the one driver. The user must test device operation before selecting another update.
8. If a problem occurs, use the restore point or Device Manager's supported driver rollback. Windows Next does not bypass signature enforcement or force a driver package.

## DirectX

The application must distinguish the DirectX runtime installed in Windows from the feature levels and API capabilities exposed by each GPU/driver. It must not claim that installing a runtime can add hardware capabilities that the GPU or driver does not expose. No security setting or driver-signature enforcement may be weakened to obtain a graphics feature.
