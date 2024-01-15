unit PRCUtils;

{$mode ObjFPC}{$H+}

interface

uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  Classes, SysUtils;

function GetCompiledTargetOS: string;
function GetCompiledTargetCPU: string;
function GetExeExt: string;
function GetLibExt(TargetOS: string = ''): string;

function AppendPathDelim(const Path: string): string;
function ChompPathDelim(const Path: string): string;
function FilenameIsAbsolute(const TheFilename: string):boolean;
function FileIsExecutable(const AFilename: string): boolean;
function FileSize(const Filename: string): int64; overload;
function FindDefaultExecutablePath(const Executable: string; const BaseDir: string = ''): string;

// file search
type
  TSearchFileInPathFlag = (
    sffDontSearchInBasePath, // do not search in BasePath, search only in SearchPath.
    sffSearchLoUpCase,
    sffFile, // must be file, not directory
    sffExecutable, // file must be executable
    sffDequoteSearchPath // ansi dequote
    );
  TSearchFileInPathFlags = set of TSearchFileInPathFlag;
const
  sffFindProgramInPath = [
    {$IFDEF Unix}sffDontSearchInBasePath,{$ENDIF}
    {$IFDEF Windows}sffDequoteSearchPath,{$ENDIF}
    sffFile,
    sffExecutable
    ];

function SearchFileInPath(const Filename, BasePath: string;
  SearchPath: string; const Delimiter: string;
  Flags: TSearchFileInPathFlags): string; overload;


function ForceDirectory(DirectoryName: string): boolean;
function DeleteDirectory(const DirectoryName: string; OnlyChildren: boolean): boolean;


type
  TCopyFileFlag = (
    cffOverwriteFile,
    cffCreateDestDirectory,
    cffPreserveTime,
    cffExceptionOnError
    );
  TCopyFileFlags = set of TCopyFileFlag;

function CopyFile(const SrcFilename, DestFilename: string;
                  Flags: TCopyFileFlags=[cffOverwriteFile]): boolean;
function CopyDirTree(SrcDir, DestDir: string; Flags: TCopyFileFlags): boolean;

implementation

function GetCompiledTargetOS: string;
begin
  Result:=lowerCase({$I %FPCTARGETOS%});
end;

function GetCompiledTargetCPU: string;
begin
  Result:=lowerCase({$I %FPCTARGETCPU%});
end;

function GetExeExt: string;
begin
  {$IFDEF WINDOWS}
  Result:='.exe';
  {$ELSE}
  Result:='';
  {$ENDIF}
end;

function GetLibExt(TargetOS: string): string;
begin
  if TargetOS='' then
    TargetOS:=GetCompiledTargetOS;
  TargetOS:=LowerCase(TargetOS);
  if copy(TargetOS,1,3)='win' then
    Result:='.dll'
  else
    case TargetOS of
      'darwin',
      'ios':
         Result:='.dylib';
      'linux',
      'android',
      'freebsd',
      'openbsd',
      'netbsd',
      'dragonfly',
      'haiku':
         Result:='.so';
      'browser',
      'nodejs',
      'electron',
      'module':
        Result:='.js';
    else
      Result:='';
    end;
end;

function AppendPathDelim(const Path: string): string;
begin
  if (Path<>'') and not (Path[length(Path)] in AllowDirectorySeparators) then
    Result:=Path+PathDelim
  else
    Result:=Path;
end;

function ChompPathDelim(const Path: string): string;
var
  Len, MinLen: Integer;
begin
  Result:=Path;
  if Path = '' then
    exit;
  Len:=length(Result);
  if (Result[1] in AllowDirectorySeparators) then begin
    MinLen := 1;
    {$IFDEF HasUNCPaths}
    if (Len >= 2) and (Result[2] in AllowDirectorySeparators) then
      MinLen := 2; // keep UNC '\\', chomp 'a\' to 'a'
    {$ENDIF}
  end
  else begin
    MinLen := 0;
    {$IFdef MSWindows}
    if (Len >= 3) and (Result[1] in ['a'..'z', 'A'..'Z'])  and
       (Result[2] = ':') and (Result[3] in AllowDirectorySeparators)
    then
      MinLen := 3;
    {$ENDIF}
  end;

  while (Len > MinLen) and (Result[Len] in AllowDirectorySeparators) do dec(Len);
  if Len<length(Result) then
    SetLength(Result,Len);
end;

function FilenameIsAbsolute(const TheFilename: string):boolean;
begin
  {$IFDEF Unix}
  Result:=(TheFilename<>'') and (TheFilename[1]='/');
  {$ELSE}
  Result:=((length(TheFilename)>=3) and
           (TheFilename[1] in ['A'..'Z','a'..'z']) and (TheFilename[2]=':')  and (TheFilename[3]in AllowDirectorySeparators))
      or ((length(TheFilename)>=2) and (TheFilename[1] in AllowDirectorySeparators) and (TheFilename[2] in AllowDirectorySeparators))
      ;
  {$ENDIF}
end;

function FileIsExecutable(const AFilename: string): boolean;
{$IFDEF Unix}
var
  Info : Stat;
{$ENDIF}
begin
  {$IFDEF Unix}
  // first check AFilename is not a directory and then check if executable
  Result:= (FpStat(AFilename,info{%H-})<>-1) and FPS_ISREG(info.st_mode) and
           (BaseUnix.FpAccess(AFilename,BaseUnix.X_OK)=0);
  {$ELSE}
  Result:=FileExists(AFilename);
  {$ENDIF}
end;

function FileSize(const Filename: string): int64;
{$IFDEF Windows}
var
  R: TSearchRec;
begin
  if SysUtils.FindFirst(FileName, faAnyFile, R) = 0 then
  begin
    Result := R.Size;
    SysUtils.FindClose(R);
  end
  else
    Result := -1;
end;
{$ELSE}
var
  st: baseunix.stat;
begin
  if not fpstat(pointer(FileName),st{%H-})>=0 then
    exit(-1);
  Result := st.st_size;
end;
{$ENDIF}

function FindDefaultExecutablePath(const Executable: string;
  const BaseDir: string): string;
var
  Env: string;
begin
  if FilenameIsAbsolute(Executable) then begin
    Result:=Executable;
    if FileExists(Result) then exit;
    {$IFDEF Windows}
    if ExtractFileExt(Result)='' then begin
      Result:=Result+'.exe';
      if FileExists(Result) then exit;
    end;
    {$ENDIF}
  end else begin
    Env:=GetEnvironmentVariable('PATH');
    Result:=SearchFileInPath(Executable, BaseDir, Env, PathSeparator, sffFindProgramInPath);
    if Result<>'' then exit;
    {$IFDEF Windows}
    if ExtractFileExt(Executable)='' then begin
      Result:=SearchFileInPath(Executable+'.exe', BaseDir, Env, PathSeparator, sffFindProgramInPath);
      if Result<>'' then exit;
    end;
    {$ENDIF}
  end;
  Result:='';
end;

function SearchFileInPath(const Filename, BasePath: string; SearchPath: string;
  const Delimiter: string; Flags: TSearchFileInPathFlags): string;
var
  p, StartPos, l, QuoteStart: integer;
  CurPath, Base: string;
begin
  if (Filename='') then begin
    Result:='';
    exit;
  end;
  // check if filename absolute
  if FilenameIsAbsolute(Filename) then begin
    if FileExists(Filename) then begin
      Result:=ExpandFilename(Filename);
      exit;
    end else begin
      Result:='';
      exit;
    end;
  end;
  Base:=AppendPathDelim(ExpandFileName(BasePath));
  // search in current directory
  if (not (sffDontSearchInBasePath in Flags)) then begin
    Result:=ExpandFilename(Base+Filename);
    if FileExists(Result) then
      exit;
  end;
  // search in search path
  StartPos:=1;
  l:=length(SearchPath);
  while StartPos<=l do begin
    p:=StartPos;
    while (p<=l) and (pos(SearchPath[p],Delimiter)<1) do
    begin
      if (SearchPath[p]='"') and (sffDequoteSearchPath in Flags) then
      begin
        // For example: Windows allows set path=C:\"a;b c"\d;%path%
        QuoteStart:=p;
        repeat
          inc(p);
        until (p>l) or (SearchPath[p]='"');
        if p<=l then
        begin
          system.delete(SearchPath,p,1);
          system.delete(SearchPath,QuoteStart,1);
          dec(l,2);
          dec(p,2);
        end;
      end;
      inc(p);
    end;
    CurPath:=copy(SearchPath,StartPos,p-StartPos);
    CurPath:=ExpandFileName(CurPath);
    StartPos:=p+1;
    if CurPath='' then continue;
    if not FilenameIsAbsolute(CurPath) then
      CurPath:=Base+CurPath;
    Result:=ExpandFilename(AppendPathDelim(CurPath)+Filename);
    if not FileExists(Result) then
      continue;
    if (sffFile in Flags) and DirectoryExists(Result) then
      continue;
    if (sffExecutable in Flags) and not FileIsExecutable(Result) then
      continue;
    exit;
  end;
  Result:='';
end;

function ForceDirectory(DirectoryName: string): boolean;
var
  i: integer;
  Dir: string;
begin
  DirectoryName:=AppendPathDelim(DirectoryName);
  i:=1;
  while i<=length(DirectoryName) do begin
    if DirectoryName[i] in AllowDirectorySeparators then begin
      // optimize paths like \foo\\bar\\foobar
      while (i<length(DirectoryName)) and (DirectoryName[i+1] in AllowDirectorySeparators) do
        Delete(DirectoryName,i+1,1);
      Dir:=copy(DirectoryName,1,i-1);
      if (Dir<>'') and not DirectoryExists(Dir) then begin
        Result:=CreateDir(Dir);
        if not Result then exit;
      end;
    end;
    inc(i);
  end;
  Result:=true;
end;

function DeleteDirectory(const DirectoryName: string; OnlyChildren: boolean): boolean;
const
  //Don't follow symlinks on *nix, just delete them
  DeleteMask = faAnyFile {$ifdef unix} or faSymLink{%H-} {$endif unix};
var
  FileInfo: TSearchRec;
  CurSrcDir: String;
  CurFilename: String;
begin
  Result:=false;
  CurSrcDir:=AppendPathDelim(ExpandFileName(DirectoryName));
  if FindFirst(CurSrcDir+AllFilesMask,DeleteMask,FileInfo)=0 then begin
    try
      repeat
        // check if special file
        if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='') then
          continue;
        CurFilename:=CurSrcDir+FileInfo.Name;
        if ((FileInfo.Attr and faDirectory)>0)
           {$ifdef unix} and ((FileInfo.Attr and faSymLink{%H-})=0) {$endif unix} then begin
          if not DeleteDirectory(CurFilename,false) then exit;
        end else begin
          if not DeleteFile(CurFilename) then exit;
        end;
      until FindNext(FileInfo)<>0;
    finally
      FindClose(FileInfo);
    end;
  end;
  if (not OnlyChildren) and (not RemoveDir(CurSrcDir)) then exit;
  Result:=true;
end;

function CopyFile(const SrcFilename, DestFilename: string; Flags: TCopyFileFlags
  ): boolean;
var
  SrcHandle: THandle;
  DestHandle: THandle;
  Buffer: array[1..4096] of byte;
  ReadCount, WriteCount, TryCount: LongInt;
begin
  Result := False;
  // check overwrite
  if (not (cffOverwriteFile in Flags)) and FileExists(DestFileName) then begin
    if cffExceptionOnError in Flags then
      raise EWriteError.Create('Destination file already exists: '+DestFilename);
    exit;
  end;
  // check directory
  if (cffCreateDestDirectory in Flags)
  and (not DirectoryExists(ExtractFilePath(DestFileName)))
  and (not ForceDirectories(ExtractFilePath(DestFileName))) then begin
    if cffExceptionOnError in Flags then
      raise EWriteError.Create('Unable to create directory: '+ExtractFilePath(DestFileName));
    exit;
  end;
  TryCount := 0;
  While TryCount <> 3 Do Begin
    SrcHandle := FileOpen(SrcFilename, fmOpenRead or fmShareDenyWrite);
    if SrcHandle = feInvalidHandle then Begin
      Inc(TryCount);
      Sleep(10);
    End
    Else Begin
      TryCount := 0;
      Break;
    End;
  End;
  If TryCount > 0 Then
  begin
    if cffExceptionOnError in Flags then
      raise EFOpenError.CreateFmt({SFOpenError}'Unable to open file "%s"', [SrcFilename])
    else
      exit;
  end;
  try
    DestHandle := FileCreate(DestFileName);
    if DestHandle = feInvalidHandle then
    begin
      if cffExceptionOnError in Flags then
        raise EFCreateError.CreateFmt({SFCreateError}'Unable to create file "%s"',[DestFileName])
      else
        Exit;
    end;
    try
      repeat
        ReadCount:=FileRead(SrcHandle,Buffer[1],High(Buffer));
        if ReadCount<=0 then break;
        WriteCount:=FileWrite(DestHandle,Buffer[1],ReadCount);
        if WriteCount<ReadCount then
        begin
          if cffExceptionOnError in Flags then
            raise EWriteError.CreateFmt({SFCreateError}'Unable to write to file "%s"',[DestFileName])
          else
            Exit;
        end;
      until false;
    finally
      FileClose(DestHandle);
    end;
    if (cffPreserveTime in Flags) then
      FileSetDate(DestFilename, FileGetDate(SrcHandle));
    Result := True;
  finally
    FileClose(SrcHandle);
  end;
end;

function CopyDirTree(SrcDir, DestDir: string; Flags: TCopyFileFlags): boolean;
var
  FileInfo: TRawByteSearchRec;
  SrcFilename, DestFilename: String;
begin
  Result:=false;
  if not DirectoryExists(SrcDir) then begin
    if cffExceptionOnError in Flags then
      raise EFOpenError.Create('Source directory not found: '+SrcDir);
    exit;
  end;
  if not DirectoryExists(DestDir) then begin
    if not (cffCreateDestDirectory in Flags) then begin
      if cffExceptionOnError in Flags then
        raise EFOpenError.Create('Destination directory not found: '+DestDir);
      exit;
    end;
    if not CreateDir(DestDir) then begin
      if cffExceptionOnError in Flags then
        raise EFOpenError.Create('Unable to create directory: '+DestDir);
      exit;
    end;
  end;
  SrcDir:=AppendPathDelim(SrcDir);
  DestDir:=AppendPathDelim(DestDir);
  if FindFirst(SrcDir+AllFilesMask,faAnyFile,FileInfo)=0 then begin
    try
      repeat
        // check if special file
        if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='') then
          continue;
        {$ifdef unix}
        if FileInfo.Attr and faSymLink{%H-}>0 then continue;
        {$endif unix}
        SrcFilename:=SrcDir+FileInfo.Name;
        DestFilename:=DestDir+FileInfo.Name;
        if FileInfo.Attr and faDirectory>0 then begin
          CopyDirTree(SrcFilename,DestFilename,Flags+[cffCreateDestDirectory]);
        end else begin
          if not CopyFile(SrcFilename, DestFilename, Flags) then
            exit;
        end;
      until FindNext(FileInfo)<>0;
    finally
      FindClose(FileInfo);
    end;
  end;
  Result:=true;
end;

initialization
  SetMultiByteConversionCodePage(CP_UTF8);
  // SetMultiByteFileSystemCodePage(CP_UTF8); not needed, this is the default under Windows
  SetMultiByteRTLFileSystemCodePage(CP_UTF8);

end.

