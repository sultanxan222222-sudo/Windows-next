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
- No package is downloaded or installed by the current inventory milestone.

## Installation sequence planned for a later milestone

1. Verify prerequisites, free disk space, power state, package hashes, and signatures.
2. Export the currently installed third-party driver packages and record their versions.
3. Create a restore point when System Protection is available; if the required recovery baseline cannot be made, stop.
4. Stage one approved driver package at a time.
5. Install only through supported Windows driver-installation mechanisms.
6. Re-enumerate the device and check its status, driver version, INF, and signature.
7. Run stability checks before permitting the next component.
8. On failure, stop the sequence and invoke the documented rollback path.

## DirectX

The application must distinguish the DirectX runtime installed in Windows from the feature levels and API capabilities exposed by each GPU/driver. It must not claim that installing a runtime can add hardware capabilities that the GPU or driver does not expose. No security setting or driver-signature enforcement may be weakened to obtain a graphics feature.
