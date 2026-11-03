# Windows Next single-file installer

The Inno Setup definition in this directory builds one self-installing EXE:

`WindowsNext-Setup-0.2.0.exe`

It installs the Windows Next application files under Program Files, creates Start Menu shortcuts, and can launch the read-only inventory after setup.

## Build

Use Inno Setup 6 on Windows:

```powershell
& "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe" .\installer\WindowsNext.iss
```

The output is written to `dist\WindowsNext-Setup-0.2.0.exe`.

## Important current scope

This is the first installable application package, not yet a driver bundle. The detected Acer hardware has no driver package approved for unattended installation at this stage. The installer does not change drivers, registry settings, power plans, Windows security, BIOS/UEFI, firmware, voltage, clocks, or thermal controls.

Future driver payloads must be placed in the repository only after exact hardware-ID, Windows-build, signature, hash, installation, and recovery checks are complete. The component manifest remains fail-closed until that evidence is recorded.
