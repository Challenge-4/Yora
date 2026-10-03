#define AppName "Yora"
#define AppVersion "1.3.1"
#define AppPublisher "Yora"
#define AppExeName "yora.exe"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{FF4799FB-F3C5-4CF2-B71E-39AC788ADD6C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
PrivilegesRequired=admin
DefaultGroupName={#AppName}
OutputDir=output
OutputBaseFilename=YoraSetup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
AppMutex=Yora_SingleInstanceMutex
UsedUserAreasWarning=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "bundled\yt-dlp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "bundled\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "bundled\ffprobe.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "bundled\FFMPEG_LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "bundled\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installation du Visual C++ Redistributable..."; Check: VCRedistNeedsInstall; Flags: waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent shellexec

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Yora"

[Code]
function PrefsStringValue(const Key: String): String;
var
  Raw: AnsiString;
  Json, Marker: String;
  P, I: Integer;
begin
  Result := '';
  if not LoadStringFromFile(ExpandConstant('{userappdata}\yora_data\Yora\shared_preferences.json'), Raw) then Exit;
  Json := UTF8Decode(Raw);
  Marker := '"flutter.' + Key + '":"';
  P := Pos(Marker, Json);
  if P = 0 then Exit;
  I := P + Length(Marker);
  while I <= Length(Json) do
  begin
    if Json[I] = '"' then Exit;
    if (Json[I] = '\') and (I < Length(Json)) then I := I + 1;
    Result := Result + Json[I];
    I := I + 1;
  end;
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  CustomCacheDir: String;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  CustomCacheDir := PrefsStringValue('customCacheDir');
  if (CustomCacheDir <> '') and DirExists(AddBackslash(CustomCacheDir) + 'yora_online') then
    DelTree(AddBackslash(CustomCacheDir) + 'yora_online', True, True, True);
  RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#AppName}');
  RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', '{#AppName}');
end;

function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  Result := not (RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', Installed) and (Installed = 1));
end;
