unit wasizenfs;

{$mode ObjFPC}

interface

uses
  JS, libzenfs, Wasitypes;

Type

  { TWASIZenFS }

  TWASIZenFS = class (TObject,IWasiFS)
  private
    FRoot : TZenFSDir;
  protected
    function PrependFD(FD: Integer; aPath: String): string;
    class function ExceptToError(E : TJSObject) : Integer;
    class function ZenFSDateToWasiTimeStamp(aDate: TJSDate): Nativeint;
    class function ZenStatToWasiStat(ZSTat: TZenFSStats): TWasiFileStat;
  Public
    Function MkDirAt(FD : Integer; const aPath : String) : NativeInt;
    Function RmDirAt(FD : Integer; const aPath : String) : NativeInt;
    function StatAt(FD : Integer; const aPath : String; var stat: TWasiFileStat) : NativeInt;
    function StatFD(FD : Integer; var stat: TWasiFileStat) : NativeInt;
    Function UTimesAt(FD : Integer; aPath : String; aTime,MTime : TJSDate; UpdateLink : boolean) : NativeInt;
    Function UTimes(FD : Integer; aTime,MTime : TJSDate; Flags : TSetTimesFlags) : NativeInt;
    Function LinkAt(OldFD : Integer; OldPath : String; NewFD : Integer; NewPath : String) : NativeInt;
    Function RenameAt(OldFD : Integer; OldPath : String; NewFD : Integer; NewPath : String) : NativeInt;
    Function SymLinkAt(FD : Integer; Path : String; Target : String) : NativeInt;
    Function UnLinkAt(FD : Integer; const aPath : String) : NativeInt;
    function OpenAt(FD : Integer; FDFlags : NativeInt; aPath : String; Flags, fsRightsBase, fsRightsInheriting, fsFlags: NativeInt; out Openfd: Integer): NativeInt;
    function ReadLinkAt(FD : Integer; aPath : String; out aTarget : String): NativeInt;
    function Close(FD: Integer): NativeInt;
    function Write(FD : Integer; Data : TJSUint8Array; AtPos : Integer; out Written :Integer) : NativeInt;
    function Sync(FD : Integer) : NativeInt;
    function DataSync(FD : Integer) : NativeInt;
    function Seek(FD : integer; Offset : Integer; Whence : TSeekWhence; out NewPos : Integer) : NativeInt;
    Function Read(FD : Integer; Data : TJSUint8Array; AtPos : Integer; Out BytesRead : Integer) : NativeInt;
    Function GetPrestat(FD: Integer) : String;
  end;

implementation

const
  ResOK = __WASI_ERRNO_SUCCESS;

{ TWASIZenFS }

function TWASIZenFS.PrependFD(FD: Integer; aPath: String) : string;

begin
  if FD<>3 then
    Writeln('Warning, unknown CWD ID',FD);
  Result:='/'+aPath;
end;

class function TWASIZenFS.ExceptToError(E: TJSObject): Integer;
begin
  if Assigned(E) then;
  // For the moment.
  Result:=WASI_ENOSYS;
end;

function TWASIZenFS.MkDirAt(FD: Integer; const aPath: String): NativeInt;
begin
  try
    ZenFS.mkdirSync(PrependFD(FD,aPath),&777);
    Result:=ResOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.RmDirAt(FD: Integer; const aPath: String): NativeInt;
begin
  try
    ZenFS.rmdirSync(PrependFD(FD,aPath));
    Result:=ResOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

class function TWASIZenFS.ZenFSDateToWasiTimeStamp(aDate: TJSDate): Nativeint;
begin
  Result:=aDate.Time;
end;

class function TWASIZenFS.ZenStatToWasiStat(ZSTat: TZenFSStats): TWasiFileStat;

begin
  Result.dev:=0;
  Result.ino:=0;
  if ZStat.isDirectory then
    Result.filetype:=__WASI_FILETYPE_DIRECTORY
  else if ZSTat.isBlockDevice then
    Result.filetype:=__WASI_FILETYPE_BLOCK_DEVICE
  else if ZStat.isCharacterDevice then
    Result.filetype:=__WASI_FILETYPE_CHARACTER_DEVICE
  else if ZStat.isFile then
    Result.filetype:=__WASI_FILETYPE_REGULAR_FILE
  else if ZStat.isSocket() then
    Result.filetype:=__WASI_FILETYPE_SOCKET_DGRAM
  else if ZStat.isSymbolicLink() then
    Result.filetype:=__WASI_FILETYPE_SYMBOLIC_LINK
  else
    Result.filetype:=__WASI_FILETYPE_UNKNOWN;
  Result.nlink:=AsIntNumber(ZStat.nlink);
  Result.size:=AsIntNumber(ZStat.Size);
  Result.atim:=ZenFSDateToWasiTimeStamp(ZStat.aTime);
  Result.mtim:=ZenFSDateToWasiTimeStamp(ZStat.mTime);
  Result.ctim:=ZenFSDateToWasiTimeStamp(ZStat.cTime);
end;

function TWASIZenFS.StatAt(FD: Integer; const aPath: String;
  var stat: TWasiFileStat): NativeInt;

var
  ZStat : TZenFSStats;

begin
  try
    ZStat:=ZenFS.statSync(PrependFD(FD,aPath));
    Stat:=ZenStatToWasiStat(ZStat);
    Result:=ResOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.StatFD(FD: Integer; var stat: TWasiFileStat): NativeInt;
var
  ZStat : TZenFSStats;

begin
  try
    ZStat:=ZenFS.fstatSync(FD);
    Stat:=ZenStatToWasiStat(ZStat);
    Result:=ResOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.UTimesAt(FD : Integer; aPath: String; aTime, MTime: TJSDate; UpdateLink: boolean): NativeInt;

var
  lPath : String;

begin
  lPath:=PrependFD(FD,aPath);
  try
    if UpdateLink then
      ZenFS.lutimesSync(lPath,aTime,mTime)
    else
      ZenFS.utimesSync(lPath,aTime,mTime);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.UTimes(FD: Integer; aTime, MTime: TJSDate;
  Flags: TSetTimesFlags): NativeInt;
begin
  try
    ZenFS.futimes(fd,aTime,mTime);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.LinkAt(OldFD: Integer; OldPath: String; NewFD: Integer;
  NewPath: String): NativeInt;

var
  lOld,lNew : String;

begin
  lOld:=PrependFD(OldFD,OldPath);
  lNew:=PrependFD(NewFD,NewPath);
  try
    ZenFS.linkSync(lOld,lNew);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.RenameAt(OldFD: Integer; OldPath: String; NewFD: Integer;
  NewPath: String): NativeInt;
var
  lOld,lNew : String;

begin
  lOld:=PrependFD(OldFD,OldPath);
  lNew:=PrependFD(NewFD,NewPath);
  try
    ZenFS.renameSync(lOld,lNew);
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.SymLinkAt(FD: Integer; Path: String; Target: String
  ): NativeInt;
var
  lPath : String;

begin
  lPath:=PrependFD(FD,Path);
  try
    ZenFS.symLinkSync(Target,lPath);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.Close(FD : Integer): NativeInt;

begin
  try
    ZenFS.closeSync(fd);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.Write(FD: Integer; Data: TJSUint8Array; AtPos : Integer; out Written : Integer): NativeInt;

var
  DS : TJSDataView;

begin
  try
    DS:=TJSDataView.New(Data.buffer);
    if atPos<>-1 then
      Written:=ZenFS.writeSync(fd,DS,atPos)
    else
      Written:=ZenFS.writeSync(fd,DS,0,Data.byteLength);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.Sync(FD: Integer): NativeInt;
begin
  try
    ZenFS.fSyncSync(fd);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.DataSync(FD: Integer): NativeInt;
begin
  try
    ZenFS.fdatasyncSync(fd);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.Seek(FD: integer; Offset: Integer; Whence: TSeekWhence; out
  NewPos: Integer): NativeInt;

var
  aPos : Integer;
  F : TZenFSFile;
  Stat : TZenFSStats;

begin
  try
    case whence of
      swBeginning :
        aPos:=AsIntNumber(OffSet);
      swCurrent :
        begin
        // This is officially not supported...
        F:=fd2file(fd);
        if Assigned(F) then
          aPos:=AsintNumber(F.Position)+AsIntNumber(Offset)
        else
          Raise TZenFSErrnoError.new(TZenFSErrNo.EBADF);
        end;
      swEnd :
        begin
        Stat:=ZenFS.fstatSync(fd);
        aPos:=AsIntNumber(Stat.size)+AsIntNumber(Offset);
        end;
    end;
//    Buf:=TJSDataView.New(TJSUint8Array.New(0));
    ZenFS.readSync(fd,Nil,0,0,aPos);
    NewPos:=aPos;
    Result:=resOK;

  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.Read(FD: Integer; Data: TJSUint8Array; AtPos: Integer; out
  BytesRead: Integer): NativeInt;

Var
  V : TJSDataView;
  opts : TZenFSReadSyncOptions;

begin
  V:=TJSDataView.new(Data.buffer);
  try
    opts:=TZenFSReadSyncOptions.new;
    opts.offset:=0;
    opts.length:=Data.byteLength;
    if AtPos<>-1 then
      opts.position:=AtPos;
    BytesRead:=ZenFS.readSync(FD,V,Opts);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.GetPrestat(FD: Integer): String;
begin
  if (FD=3) then
    begin
    FRoot:=ZenFS.OpenDirSync('/');
    Result:='/';
    end;
end;

function TWASIZenFS.UnLinkAt(FD: Integer; const aPath: String): NativeInt;

var
  lPath : String;

begin
  lPath:=PrependFD(FD,aPath);
  try
    ZenFS.unlinkSync(lPath);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.OpenAt(FD : Integer; FDFlags : NativeInt; aPath : String; Flags, fsRightsBase, fsRightsInheriting, fsFlags: NativeInt; out Openfd: Integer): NativeInt;

var
  lPath : String;
  lFlags : String;
  Rights : NativeInt;
  Reading,Writing : Boolean;

  Function HasFlag(aFlag : Integer) : Boolean;
  begin
    Result:=(Flags and aFlag)<>0;
  end;

  Function HasRight(aRight : Integer) : Boolean;
  begin
    if IsBigint(Rights) then
      begin
      asm
        Result = ((Rights & BigInt(aRight)) != 0)
      end;
      end
    else
      Result:=(Rights and aRight)<>0;
  end;

begin
  if (fdFlags<>0) and (fsFlags<>0) then ;
  lPath:=PrependFD(FD,aPath);
  Rights:=AsIntNumber(fsRightsBase);
  Writing:=HasFlag(__WASI_OFLAGS_CREAT) or HasRight(__WASI_RIGHTS_FD_WRITE);
  Reading:=HasRight(__WASI_RIGHTS_FD_READ);
  if Writing then
    begin
    if HasFlag(__WASI_OFLAGS_TRUNC) then
      lFLags:='w'
    else
      lFLags:='a';
    if HasFlag(__WASI_OFLAGS_EXCL) then
      lFLags:=lFLags+'x';
    if Reading then
      lFLags:=lFLags+'+';
    end
  else
    begin
    lFlags:='r';
    end;
  try
    OpenFD:=ZenFS.openSync(lPath,lFlags);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

function TWASIZenFS.ReadLinkAt(FD: Integer; aPath: String; out aTarget: String): NativeInt;

var
  lPath : String;

begin
  lPath:=PrependFD(FD,aPath);
  try
    aTarget:=ZenFS.readlinkSync(lPath);
    Result:=resOK;
  except
    on E : TJSObject do
      Result:=ExceptToError(E);
  end;
end;

end.

