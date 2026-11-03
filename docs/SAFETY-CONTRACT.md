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

## Current build

The current milestone only reads hardware, OS, graphics-driver, storage, active power-plan, and Secure Boot status. It writes report files under the current user's LocalAppData directory. It does not require administrator rights and does not alter the system.
