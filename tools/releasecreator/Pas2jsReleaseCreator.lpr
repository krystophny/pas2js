program Pas2jsReleaseCreator;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  LazUTF8, Classes, SysUtils, CustApp, IniFiles, LazFileUtils, FileUtil,
  FindWriteln;

const
  DefaultCfgFilename = 'pas2jsrelease.ini';
  {$IFDEF Linux}
  BuildOS = 'linux';
  {$ENDIF}
  {$IFDEF Windows}
  BuildOS = 'windows';
  {$ENDIF}
  {$IFDEF MacOS}
  BuildOS = 'macos';
  {$ENDIF}

type
  TGetDefaultEvent = function(): string of object;

  { TPas2jsReleaseCreator }

  TPas2jsReleaseCreator = class(TCustomApplication)
  protected
    procedure DoLog(EventType: TEventType; const Msg: String); override;
    procedure DoRun; override;
    procedure Err(const Msg: string);
  public
    BuildDir: string;
    BuildSourceDir: string;
    CfgFilename: string;
    FPCReleaseFilename: string; // released compiler binary
    FPCDevelFilename: string; // development compiler binary
    Ini: TIniFile;
    LazBuildFilename: string; // lazbuild binary
    Pas2jsVersion: string;
    Simulate: boolean;
    SourceDir: string; // cloned git release
    Verbosity: integer;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    procedure ReadVersion;
    procedure CheckForgottenWriteln;
    procedure CreateBuildSourceDir;
    procedure BuildPas2js;
    function GetDefaultCfgFilename: string;
    function GetDefaultBuildDir: string;
    function GetDefaultLazBuild: string;
    function GetOption_String(ShortOption: char; const LongOption: string): string;
    function GetOption_Directory(ShortOption: char; const LongOption: string; const GetDefaultFunc: TGetDefaultEvent): string;
    function GetOption_Executable(ShortOption: char; const LongOption: string; const GetDefaultFunc: TGetDefaultEvent): string;
    procedure CheckExecutable(const Filename, ParamName: string);
  end;

{ TPas2jsReleaseCreator }

procedure TPas2jsReleaseCreator.DoLog(EventType: TEventType; const Msg: String);
begin
  case EventType of
    etInfo: write('Info: ');
    etWarning: write('Warning: ');
    etError: write('Error: ');
    etDebug: write('Debug: ');
  else
    write('Custom: ');
  end;
  writeln(Msg);
end;

procedure TPas2jsReleaseCreator.DoRun;
var
  ErrorMsg: String;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('hb:c:s:l:qvx', ['help', 'config:', 'lazbuild:',
    'builddir:', 'sourcedir:', 'quiet', 'verbose', 'execute',
    'fpcrelease:', 'fpcdevel:']);
  if ErrorMsg<>'' then
    Err(ErrorMsg);

  // parse basic parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  Simulate:=true;
  if HasOption('q','quiet') then
    dec(Verbosity);
  if HasOption('v','verbose') then
    inc(Verbosity);

  // read config file
  if HasOption('c','config') then begin
    CfgFilename:=ExpandFileName(GetOptionValue('c','config'));
    if not FileExists(CfgFilename) then
      Err('Config file not found: "'+CfgFilename+'"');
  end else begin
    CfgFilename:=GetDefaultCfgFilename;
  end;
  if FileExists(CfgFilename) then begin
    if Verbosity>=0 then
      Log(etInfo,'Reading config file "'+CfgFilename+'" ...');
    Ini:=TIniFile.Create(CfgFilename);
  end;

  BuildDir:=GetOption_Directory('b','builddir',@GetDefaultBuildDir);
  LazBuildFilename:=GetOption_Executable('l','lazbuild',@GetDefaultLazBuild);
  SourceDir:=GetOption_Directory('s','sourcedir',nil);
  if SourceDir='' then
    Err('missing source directory');
  FPCReleaseFilename:=GetOption_Executable(' ','fpcrelease',nil);
  FPCDevelFilename:=GetOption_Executable(' ','fpcdevel',nil);

  // write options
  if Verbosity>=0 then begin
    Log(etInfo,'BuildDir: "'+BuildDir+'"');
    Log(etInfo,'LazBuild: "'+LazBuildFilename+'"');
    Log(etInfo,'FPCRelease: "'+FPCReleaseFilename+'"');
    Log(etInfo,'FPCDevel: "'+FPCDevelFilename+'"');
    Log(etInfo,'SourceDir: "'+SourceDir+'"');
  end;

  if HasOption('x','execute') then
    Simulate:=true
  else
    Log(etInfo,'Simulating...');

  // preflight checks
  if not DirectoryExists(BuildDir) then
    Err('BuildDir missing: "'+BuildDir+'"');
  if not DirectoryExists(SourceDir) then
    Err('SourceDir missing: "'+SourceDir+'"');
  CheckExecutable(LazBuildFilename,'lazbuild');
  CheckExecutable(FPCReleaseFilename,'fpcrelease');
  CheckExecutable(FPCDevelFilename,'fpcdevel');

  ReadVersion;
  CheckForgottenWriteln;

  // build
  CreateBuildSourceDir;

  // stop program loop
  Terminate;
end;

procedure TPas2jsReleaseCreator.Err(const Msg: string);
begin
  Log(etError,Msg);
  Halt(1);
end;

constructor TPas2jsReleaseCreator.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TPas2jsReleaseCreator.Destroy;
begin
  FreeAndNil(Ini);
  inherited Destroy;
end;

procedure TPas2jsReleaseCreator.WriteHelp;
begin
  writeln('Usage: ', ExeName, ' -h');
  writeln;
  writeln('-h, --help: Write this help and exit');
  writeln('-q, --quiet: Less verbose');
  writeln('-v, --verbose: More verbose');
  writeln('-b <filename>, --builddir=<filename>: Output directory where to build the zip.');
  writeln('                Default: '+GetDefaultBuildDir);
  writeln('-c <filename>, --config=<filename>: Path of ini file with a Main section.');
  writeln('                Default: '+GetDefaultCfgFilename);
  writeln('--fpcrelease=<filename>: Path of released version fpc executable.');
  writeln('--fpcdevel=<filename>: Path of development version fpc executable.');
  writeln('-l <filename>, --lazbuild=<filename>: Path of lazbuild executable.');
  writeln('                Default: '+GetDefaultLazBuild);
  writeln('-s <filename>, --sourcedir=<filename>: git directory of the pas2js release');
  writeln('-x, --execute: Do not simulate, execute the commands');
end;

procedure TPas2jsReleaseCreator.ReadVersion;

  function CheckConstInt(const Line, Identifier: string; var aValue: integer): boolean;
  var
    s: String;
    p, StartP: SizeInt;
  begin
    Result:=false;
    s:='  '+Identifier+' = ';
    if not SameText(LeftStr(Line,length(s)),s) then exit;
    p:=length(s)+1;
    StartP:=p;
    aValue:=0;
    while (p<=length(Line)) and (Line[p] in ['0'..'9']) do begin
      aValue:=aValue*10+ord(Line[p])-ord('0');
      inc(p);
    end;
    Result:=p>StartP;
  end;

type
  TVersionPart = (vMajor,vMinor,vRelease);
const
  PartNames: array[TVersionPart] of string = ('VersionMajor','VersionMinor','VersionRelease');
var
  Filename, Line: String;
  sl: TStringList;
  i: Integer;
  Parts: array[TVersionPart] of integer;
  PartFound: array[TVersionPart] of boolean;
  p: TVersionPart;
begin
  Filename:=SourceDir+'compiler'+PathDelim+'packages'+PathDelim+'pastojs'+PathDelim+'src'+PathDelim+'pas2jscompiler.pp';
  if Verbosity>0 then
    Log(etInfo,'Reading version from "'+Filename+'" ...');
  if not FileExists(Filename) then
    Err('Missing source file: "'+Filename+'"');
  sl:=TStringList.Create;
  try
    sl.LoadFromFile(Filename);
    for p in TVersionPart do begin
      Parts[p]:=0;
      PartFound[p]:=false;
    end;
    for i:=0 to sl.Count-1 do begin
      Line:=sl[i];
      for p in TVersionPart do
        if not PartFound[p] then
          PartFound[p]:=CheckConstInt(Line,PartNames[p],Parts[p]);
      if PartFound[High(TVersionPart)] then begin
        if Verbosity>0 then
          Log(etInfo,'Found const '+PartNames[High(TVersionPart)]+' = '+IntToStr(Parts[High(TVersionPart)]));
        break;
      end;
    end;

    for p in TVersionPart do
      if not PartFound[p] then
        Err('Missing '+PartNames[p]+' in "'+Filename+'"');

    Pas2jsVersion:=IntToStr(Parts[vMajor])+'.'+IntToStr(Parts[vMinor])+'.'+IntToStr(Parts[vRelease]);
    if Verbosity>=0 then
      Log(etInfo,'Pas2js version is '+Pas2jsVersion);
  finally
    sl.Free;
  end;
end;

procedure TPas2jsReleaseCreator.CheckForgottenWriteln;

  procedure Check(const SrcDir: string);
  begin
    if not DirectoryExists(SrcDir) then
      Err('Missing dource directory: "'+SrcDir+'"');
    if Verbosity>=0 then
      Log(etInfo,'Checking for forgotten writeln: '+SrcDir+' ...');
    FindWritelnInDirectory(SrcDir,false,@DoLog);
  end;

begin
  Check(SourceDir+'compiler'+PathDelim+'packages'+PathDelim+'fcl-js'+PathDelim+'src');
  Check(SourceDir+'compiler'+PathDelim+'packages'+PathDelim+'fcl-json'+PathDelim+'src');
  Check(SourceDir+'compiler'+PathDelim+'packages'+PathDelim+'fcl-passrc'+PathDelim+'src');
  Check(SourceDir+'compiler'+PathDelim+'packages'+PathDelim+'pastojs'+PathDelim+'src');
  Check(SourceDir+'compiler'+PathDelim+'utils'+PathDelim+'pas2js');
end;

procedure TPas2jsReleaseCreator.CreateBuildSourceDir;
begin
  BuildSourceDir:=BuildDir+'pas2js-'+lowercase({$i %FPCTargetOS%})+'-'+lowercase({$i %FPCTargetCPU%})+'-'+Pas2jsVersion;
  if DirectoryExists(BuildSourceDir) then begin
    if Verbosity>=0 then
      Log(etInfo,'Deleting directory "'+BuildSourceDir+'"');
    if not Simulate then begin
      if not DeleteDirectory(BuildSourceDir,false) then
        Err('Unable to delete directory "'+BuildSourceDir+'"');
    end;
  end;
  if Simulate then begin
    Log(etInfo,'Simulate: create directory "'+BuildSourceDir+'"')
  end else begin
    if not ForceDirectory(BuildSourceDir) then
      Err('Unable to create directory "'+BuildSourceDir+'"');
  end;
end;

procedure TPas2jsReleaseCreator.BuildPas2js;
begin

end;

function TPas2jsReleaseCreator.GetDefaultCfgFilename: string;
begin
  Result:=ExpandFileName(DefaultCfgFilename);
end;

function TPas2jsReleaseCreator.GetDefaultBuildDir: string;
begin
  Result:=AppendPathDelim(ResolveDots(GetTempDir(false)));
end;

function TPas2jsReleaseCreator.GetDefaultLazBuild: string;
begin
  Result:='lazbuild';
end;

function TPas2jsReleaseCreator.GetOption_String(ShortOption: char;
  const LongOption: string): string;
begin
  if ShortOption<=' ' then begin
    if HasOption(LongOption) then begin
      Result:=GetOptionValue(LongOption);
      exit;
    end;
  end else begin
    if HasOption(ShortOption,LongOption) then begin
      Result:=GetOptionValue(ShortOption,LongOption);
      exit;
    end;
  end;
  if Ini<>nil then begin
    Result:=Ini.ReadString('Main',LongOption,'');
    exit;
  end;
  Result:='';
end;

function TPas2jsReleaseCreator.GetOption_Directory(ShortOption: char;
  const LongOption: string; const GetDefaultFunc: TGetDefaultEvent): string;
begin
  Result:=GetOption_String(ShortOption,LongOption);
  if (Result='') and Assigned(GetDefaultFunc) then
    Result:=GetDefaultFunc();
  if Result<>'' then
    Result:=AppendPathDelim(ExpandFileName(Result));
end;

function TPas2jsReleaseCreator.GetOption_Executable(ShortOption: char;
  const LongOption: string; const GetDefaultFunc: TGetDefaultEvent): string;
begin
  if ShortOption<=' ' then
    Result:=GetOption_String(ShortOption,LongOption)
  else
    Result:=GetOption_String(ShortOption,LongOption);
  if (Result='') and Assigned(GetDefaultFunc) then
    Result:=GetDefaultFunc();
  if Result='' then exit;
  if FilenameIsAbsolute(Result) then exit;
  if ExtractFilePath(Result)<>'' then
    Result:=ExpandFileName(Result)
  else
    Result:=FindDefaultExecutablePath(Result);
end;

procedure TPas2jsReleaseCreator.CheckExecutable(const Filename, ParamName: string);
begin
  if Filename='' then
    Err('Missing parameter '+ParamName);
  if not FileExists(Filename) then
    Err('File '+ParamName+' not found: "'+Filename+'"');
  if not FileIsExecutable(Filename) then
    Err('File '+ParamName+' not executable: "'+Filename+'"');
end;

var
  Application: TPas2jsReleaseCreator;
begin
  Application:=TPas2jsReleaseCreator.Create(nil);
  Application.Title:='Pas2js Release Creator';
  Application.Run;
  Application.Free;
end.

