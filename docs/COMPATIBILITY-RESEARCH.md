# Acer Aspire V3-772 — compatibility research

Research snapshot: 2026-11-03. This document is a decision record, not permission to install a driver.

## Confirmed target inventory

- System: Acer Aspire V3-772, SKU Aspire V3-772_0781_1.12.
- OS: Windows 11 Pro x64, version 10.0, build 22000.2600.
- CPU: Intel Core i5-4200M (2 cores / 4 logical processors).
- Integrated GPU: Intel HD Graphics 4600, PCI\VEN_8086&DEV_0416&SUBSYS_07811025.
- Discrete GPU: NVIDIA GeForce GT 750M, PCI\VEN_10DE&DEV_0FE4&SUBSYS_07811025.
- RAM: Kingston KVR16LS11/8, 8 GB, DDR3L-1600 as reported by Windows; CIM reports four memory devices and 32 GB array maximum. That report is not proof that a 32 GB configuration is valid with this exact CPU/board combination.
- SSD: Apacer AS340 120 GB.
- HDD: Seagate ST500LT012-9WS142, approximately 500 GB.
- Wi-Fi: Qualcomm Atheros AR5BWB222, PCI\VEN_168C&DEV_0034&SUBSYS_E052105B.
- Ethernet: Broadcom NetLink Gigabit, PCI\VEN_14E4&DEV_1692&SUBSYS_07811025.
- Bluetooth USB module: USB\VID_0489&PID_E04E.

## Operating system servicing

The confirmed Windows 11 Pro build 22000.2600 belongs to version 21H2. Microsoft ended servicing for Windows 11 Home and Pro 21H2 on 2023-10-10; that release no longer receives security updates. This is a material security issue for the target machine.

Windows Next must include a separate OS servicing assessment before any system-maintenance release. It must not silently perform a feature upgrade, bypass CPU support requirements, or rewrite boot/firmware configuration. The correct upgrade path must be checked against the exact CPU, device drivers, user files, and supported Windows release before it is offered.

Source:
- https://learn.microsoft.com/ru-ru/lifecycle/announcements/windows-11-21h2-end-of-servicing

## Graphics driver decisions

### Intel HD Graphics 4600

Installed Windows driver: 10.18.15.4248 (2015-08-04).

Intel documents that graphics driver 15.40.44.5107 and later deprecates DirectX 12 capability on 4th-generation Intel graphics as a mitigation for security advisory SA-00315. Intel's 15.40 branch is Windows 10-only for 4th-generation graphics and is no longer receiving functional or security updates; Intel recommends discontinuing its use. The current installed version must not be blindly downgraded to restore a DirectX capability. No Intel package is approved for unattended installation on this Windows 11 build.

Sources:
- https://www.intel.com/content/www/us/en/support/articles/000057520.html
- https://www.intel.com/content/www/us/en/download/18369/intel-graphics-driver-for-windows-15-40.html
- https://www.intel.com/content/www/us/en/security-center/advisory/intel-sa-01191.html

### NVIDIA GeForce GT 750M

Installed Windows driver: 21.21.13.7654 (2016-12-29).

NVIDIA's 425.31 reference package lists the GT 750M among supported notebook GPUs, but states that Game Ready support for mobile Kepler GPUs ended after the final Release 418 driver on 2019-04-11 and critical security updates were available only through 2020-04. The 425.31 package page targets Windows 10 64-bit, not the user's Windows 11 build. Later 2026 GeForce security-update packages target newer architectures and do not list the GT 750M. Do not substitute them.

Decision: keep the currently installed OEM driver unless a specifically validated Acer/Windows Update package is found. Do not force-install a desktop Kepler package on this mobile GPU.

Source:
- https://www.nvidia.com/Download/driverResults.aspx/145874/en-us/

## Network and Bluetooth

The installed Qualcomm Atheros WLAN driver is 10.0.0.352 (2017-06-19). Microsoft Update Catalog contains an AR5BWB222 package version 10.0.3.456 and its supported-hardware list includes the reported subsystem ID E052105B. However, the catalog result is described for Windows 10 servicing branches. This is not sufficient evidence for unattended installation on Windows 11 build 22000.2600. Keep current driver pending Windows 11-specific validation.

Source:
- https://catalog.update.microsoft.com/Search.aspx?q=Qualcomm+Atheros+AR5BWB222

The current Broadcom Ethernet and Qualcomm Bluetooth packages remain unchanged until an exact, signed, OS-applicable package is validated.

## Memory and storage

- The system inventory reports a 120 GB Apacer AS340 SSD and a 500 GB Seagate hard disk. Windows Next may report health and free space but must not change firmware or perform destructive disk operations.
- The CIM memory array reports 4 slots / 32 GB maximum. Do not treat this as a guarantee of 32 GB support. Check Acer service documentation and the exact board/CPU memory topology before purchasing RAM.

## Release decision

As of this research snapshot, there are **zero approved unattended driver packages** for the current Acer / Windows 11 target. The single-file installer therefore installs Windows Next itself and runs read-only diagnostics. Driver installation stays disabled until evidence and rollback tests are complete.
