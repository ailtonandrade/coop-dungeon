; Instalador do Corrumpted para Windows (Inno Setup 6: https://jrsoftware.org/isdl.php).
; Antes: exporte o jogo (tools/exportar_windows.bat ou Projeto > Exportar > Windows),
; que gera ..\..\export\windows\Corrumpted.exe e Corrumpted.pck.
; Depois: abra este arquivo no Inno Setup e clique em Compilar (ou rode o .bat, que faz tudo).
; O instalador sai em ..\..\export\instalador\Corrumpted-Setup.exe

#define AppName "Corrumpted"
#define AppVersion "0.10"
#define ExportDir "..\..\export\windows"

[Setup]
AppId={{6E3C1B52-6D3A-4C8E-9C1E-5A1F0C9B2D7A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=..\..\export\instalador
OutputBaseFilename=Corrumpted-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Languages]
Name: "pt"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"

[Files]
Source: "{#ExportDir}\Corrumpted.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ExportDir}\Corrumpted.pck"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\Corrumpted.exe"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\Corrumpted.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Corrumpted.exe"; Description: "Jogar agora"; Flags: nowait postinstall skipifsilent
