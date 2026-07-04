; Coriander Player Inno Setup 安装脚本
; 使用 Inno Setup 6.x 编译: iscc CorianderPlayer.iss

#define MyAppName "Coriander Player"
#define MyAppVersion "1.5.2"
#define MyAppPublisher "dj2733721464-cyber"
#define MyAppURL "https://github.com/dj2733721464-cyber/player"
#define MyAppExeName "coriander_player.exe"

[Setup]
AppId={{B8F0C8E0-3E5A-4A1C-8B7E-9F2D1E4C6A8B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=.\output
OutputBaseFilename=CorianderPlayer_v{#MyAppVersion}_Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=admin
CloseApplications=force

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："; Flags: checkedonce

[Files]
; 主程序文件
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; BASS 音频库
Source: "..\build\windows\x64\runner\Release\BASS\*"; DestDir: "{app}\BASS"; Flags: ignoreversion recursesubdirs createallsubdirs

; 桌面歌词组件
Source: "..\build\windows\x64\runner\Release\desktop_lyric\*"; DestDir: "{app}\desktop_lyric"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 Coriander Player"; Flags: postinstall nowait skipifsilent unchecked
