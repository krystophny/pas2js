program Pas2jsReleaseCreator;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  LazUTF8, Classes, SysUtils, Types, CustApp, IniFiles, process, LazFileUtils,
  FileUtil, FindWriteln;

const
  DefaultCfgFilename = 'pas2jsrelease.ini';

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
    MakeFilename: string; // 'make' binary
    Pas2jsVersion: string;
    Simulate: boolean;
    SourceDir: string; // cloned git release
    Verbosity: integer;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    procedure ReadVersion;
    procedure CheckForgottenWriteln;
    procedure CleanSources;
    procedure CreateBuildSourceDir(const TargetOS, TargetCPU: string);
    procedure BuildPas2js(const TargetOS, TargetCPU: string);
    procedure RunTool(WorkDir, Exe: string; const ProcParams: TStringDynArray); overload;
    procedure RunTool(WorkDir, Exe: string; ProcParams: TStringList); overload;
    procedure ForceDir(Dir, DirTitle: string);
    function Quote(const s: string): string;
    function GetDefaultCfgFilename: string;
    function GetDefaultBuildDir: string;
    function GetDefaultLazBuild: string;
    function GetDefaultMake: string;
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
  TargetOS, TargetCPU: String;
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
  MakeFilename:=GetOption_Executable(' ','make',@GetDefaultMake);

  // write options
  if Verbosity>=0 then begin
    Log(etInfo,'BuildDir: "'+BuildDir+'"');
    Log(etInfo,'LazBuild: "'+LazBuildFilename+'"');
    Log(etInfo,'FPCRelease: "'+FPCReleaseFilename+'"');
    Log(etInfo,'FPCDevel: "'+FPCDevelFilename+'"');
    Log(etInfo,'Make: "'+MakeFilename+'"');
    Log(etInfo,'SourceDir: "'+SourceDir+'"');
  end;

  if HasOption('x','execute') then
    Simulate:=false
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
  CheckExecutable(MakeFilename,'make');

  ReadVersion;
  CheckForgottenWriteln;

  // build
  CleanSources;

  TargetOS:=lowercase({$i %FPCTargetOS%});
  TargetCPU:=lowercase({$i %FPCTargetCPU%});
  CreateBuildSourceDir(TargetOS,TargetCPU);
  BuildPas2js(TargetOS,TargetCPU);

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
  writeln('--make=<filename>: Path of gnu make executable.');
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

procedure TPas2jsReleaseCreator.CleanSources;

  procedure Clean(Dir: string);
  var
    Info: TRawByteSearchRec;
    Ext, Filename: String;
  begin
    Dir:=AppendPathDelim(Dir);
    if FindFirst(Dir+AllFilesMask,faAnyFile,Info)=0 then begin
      repeat
        if (Info.Name='') or (Info.Name='.') or (Info.Name='..') then continue;
        if (Info.Attr and faDirectory)>0 then begin
          Clean(Dir+Info.Name);
        end
        else begin
          Ext:=lowercase(ExtractFileExt(Info.Name));
          case Ext of
          '.ppu','.o','.rsj','.lib','.dylib':
            begin
              Filename:=Dir+Info.Name;
              if Simulate then begin
                if Verbosity>0 then
                  Log(etInfo,'Simulate Deleting "'+Filename+'"');
              end
              else begin
                if DeleteFile(Filename) then begin
                  if Verbosity>0 then
                    Log(etInfo,'Deleted "'+Filename+'"');
                end else begin
                  Err('Unable to delete "'+Filename+'"');
                end;
              end;
            end;
          end;
        end;
      until FindNext(Info)<>0;
    end;
    FindClose(Info);
  end;

begin
  // make clean
  RunTool(SourceDir,MakeFilename,['clean']);
  // delete files
  Clean(SourceDir);
end;

procedure TPas2jsReleaseCreator.CreateBuildSourceDir(const TargetOS,
  TargetCPU: string);
begin
  BuildSourceDir:=BuildDir+'pas2js-'+TargetOS+'-'+TargetCPU+'-'+Pas2jsVersion;
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
    Log(etInfo,'Created directory "'+BuildSourceDir+'"')
  end;
end;

procedure TPas2jsReleaseCreator.BuildPas2js(const TargetOS, TargetCPU: string);
var
  WorkDir, SrcCompilerDir, PkgSrcDir, UnitOutDir, BinOutDir: String;
  ProcParams: TStringList;
begin
  ProcParams:=TStringList.Create;
  try
    SrcCompilerDir:=SourceDir+'compiler'+PathDelim;

    WorkDir:=SrcCompilerDir+'utils'+PathDelim+'pas2js';

    PkgSrcDir:=SrcCompilerDir+'packages'+PathDelim;
    ProcParams.Add('-Fu'+PkgSrcDir+'fcl-js'+PathDelim+'src');
    ProcParams.Add('-Fu'+PkgSrcDir+'fcl-json'+PathDelim+'src');
    ProcParams.Add('-Fu'+PkgSrcDir+'fcl-passrc'+PathDelim+'src');
    ProcParams.Add('-Fu'+PkgSrcDir+'pastojs'+PathDelim+'src');

    ProcParams.Add('-B');
    ProcParams.Add('-MObjFPC');
    ProcParams.Add('-O1');
    ProcParams.Add('-Schi');
    ProcParams.Add('-vew');

    UnitOutDir:=SourceDir+'units'+PathDelim+TargetCPU+'-'+TargetOS;
    ForceDir(UnitOutDir,'unit output');
    ProcParams.Add('-FU'+UnitOutDir);

    BinOutDir:=SourceDir+'bin'+PathDelim+TargetCPU+'-'+TargetOS;
    ForceDir(BinOutDir,'binary output');
    ProcParams.Add('-FE'+BinOutDir);

    ProcParams.Add('pas2js.pp');

    RunTool(WorkDir,FPCReleaseFilename,ProcParams);
  finally
    ProcParams.Free;
  end;
end;

procedure TPas2jsReleaseCreator.RunTool(WorkDir, Exe: string;
  const ProcParams: TStringDynArray);
var
  sl: TStringList;
  i: Integer;
begin
  sl:=TStringList.Create;
  try
    for i:=0 to length(ProcParams)-1 do
      sl.Add(ProcParams[i]);
    RunTool(WorkDir,Exe,sl);
  finally
    sl.Free;
  end;
end;

procedure TPas2jsReleaseCreator.RunTool(WorkDir, Exe: string;
  ProcParams: TStringList);
var
  TheProcess: TProcess;
  i, OutLen, LineStart: Integer;
  OutputLine, buf, CmdLine: String;
begin
  if not FileIsExecutable(Exe) then
    Err('Not an executable: '+Exe);
  if DirectoryExists(Exe) then
    Err('Not an executable: '+Exe);
  if (not Simulate) and (not DirectoryExists(WorkDir)) then
    Err('Workdir missing: '+WorkDir);

  TheProcess:=TProcess.Create(nil);
  try
    TheProcess.Executable := Exe;
    TheProcess.Parameters := ProcParams;
    TheProcess.Options := [poUsePipes, poStdErrToOutput];
    TheProcess.ShowWindow := swoHide;
    TheProcess.CurrentDirectory := WorkDir;

    CmdLine:=Quote(Exe);
    for i:=0 to ProcParams.Count-1 do
      CmdLine+=' '+Quote(ProcParams[i]);
    if Simulate then begin
      Log(etInfo,'Simulate Running: WorkDir="'+WorkDir+'" Cmd: '+CmdLine);
      exit;
    end;
    Log(etInfo,'Running: WorkDir="'+WorkDir+'" Cmd: '+CmdLine);

    TheProcess.Execute;
    OutputLine:='';
    SetLength(buf{%H-},4096);
    repeat
      if (TheProcess.Output<>nil) then begin
        OutLen:=TheProcess.Output.Read(Buf[1],length(Buf));
      end else
        OutLen:=0;
      LineStart:=1;
      i:=1;
      while i<=OutLen do begin
        if Buf[i] in [#10,#13] then begin
          OutputLine:=OutputLine+copy(Buf,LineStart,i-LineStart);
          writeln(OutputLine);
          OutputLine:='';
          if (i<OutLen) and (Buf[i+1] in [#10,#13]) and (Buf[i]<>Buf[i+1]) then
            inc(i);
          LineStart:=i+1;
        end;
        inc(i);
      end;
      OutputLine:=OutputLine+copy(Buf,LineStart,OutLen-LineStart+1);
    until OutLen=0;
    if OutputLine<>'' then
      writeln(OutputLine);
    TheProcess.WaitOnExit;
    if TheProcess.ExitStatus<>0 then
      Err('ExitStatus: '+IntToStr(TheProcess.ExitStatus));
    if TheProcess.ExitCode<>0 then
      Err('ExitCode: '+IntToStr(TheProcess.ExitCode));
  finally
    TheProcess.Free;
  end;
end;

procedure TPas2jsReleaseCreator.ForceDir(Dir, DirTitle: string);
begin
  if DirectoryExists(Dir) then exit;
  if Simulate then exit;
  if ForceDirectories(Dir) then exit;
  Err('Unable to create '+DirTitle+' directory "'+Dir+'"');
end;

function TPas2jsReleaseCreator.Quote(const s: string): string;
begin
  Result:=s;
  if Pos(' ',Result)<1 then exit;
  Result:=QuotedStr(s);
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

function TPas2jsReleaseCreator.GetDefaultMake: string;
begin
  Result:='make';
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

