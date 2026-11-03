#define ProductName "Windows Next"
#define ProductVersion "0.2.0"
#define ProductPublisher "Windows Next Project"

[Setup]
AppId={{A8172AC9-DC8B-46B1-9F8A-5D932F8E5E28}
AppName={#ProductName}
AppVersion={#ProductVersion}
AppPublisher={#ProductPublisher}
DefaultDirName={autopf}\Windows Next
DefaultGroupName={#ProductName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=WindowsNext-Setup-{#ProductVersion}
UninstallDisplayName={#ProductName}
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
UsePreviousAppDir=yes
RestartApplications=no
SetupLogging=yes
VersionInfoVersion=0.2.0.0
VersionInfoCompany={#ProductPublisher}
VersionInfoDescription=Windows Next safe hardware inventory and maintenance foundation
VersionInfoProductName={#ProductName}
VersionInfoProductVersion={#ProductVersion}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Dirs]
Name: "{app}\src"
Name: "{app}\manifest"
Name: "{app}\docs"

[Files]
Source: "..\Run-WindowsNext.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\*"; DestDir: "{app}\src"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\manifest\*"; DestDir: "{app}\manifest"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Windows Next — диагностика"; Filename: "{app}\Run-WindowsNext.cmd"; WorkingDir: "{app}"
Name: "{autodesktop}\Windows Next — диагностика"; Filename: "{app}\Run-WindowsNext.cmd"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{group}\Удалить Windows Next"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\Run-WindowsNext.cmd"; Description: "Запустить Windows Next и проверить компьютер"; Flags: postinstall nowait skipifsilent runasoriginaluser

