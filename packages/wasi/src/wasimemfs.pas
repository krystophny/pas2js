unit wasimemfs;

{$mode ObjFPC}
{$INTERFACES CORBA}

interface

uses
  SysUtils, JS, types, Web, Wasitypes;

type

  { TMemFSNode }

  TMemFSNode = class
  private
    FName: string;
    FParent: TMemFSNode;
    FNodeType: TDirentType;
    FData: TJSUint8Array;
    FChildren: TJSMap;
    FCreatedAt: TJSDate;
    FModifiedAt: TJSDate;
    FSize: NativeInt;
  public
    constructor Create(const aName: string; aType: TDirentType; aParent: TMemFSNode);
    function GetAbsolutePath: string;
    property Name: string read FName write FName;
    property Parent: TMemFSNode read FParent write FParent;
    property NodeType: TDirentType read FNodeType;
    property Data: TJSUint8Array read FData write FData;
    property Children: TJSMap read FChildren;
    property CreatedAt: TJSDate read FCreatedAt;
    property ModifiedAt: TJSDate read FModifiedAt write FModifiedAt;
    property Size: NativeInt read FSize write FSize;
  end;

  { TOpenFileHandle }

  TOpenFileHandle = class
  public
    Node: TMemFSNode;
    Path: string;
    Position: Integer;
    CanRead: Boolean;
    CanWrite: Boolean;
    Modified: Boolean;
    IsDirectory: Boolean;
    IsAppend: Boolean;
    DirEntries: TStringDynArray;
  end;

  { TWASIMemFS }

  TWASIMemFS = class(TObject, IWASIFS)
  private
    FRoot: TMemFSNode;
    FHandles: TJSMap;
    FNextFD: Integer;
    FMaxFD: Integer;
    FMaxFileSize: NativeInt;
    FStorageKeyPrefix: string;
    FStorage: TJSStorage;
    procedure FlushFileToStorage(const aPath: string; aData: TJSUint8Array);
    function GetPathParts(const aPath: String): TStringDynArray;
    function IsPersistenceEnabled: Boolean;
    procedure RemoveFileFromStorage(const aPath: string);
    function TryHydrateFile(const aPath: string): TMemFSNode;
    procedure HydrateFromStorage;
    procedure HydrateDirFromStorage(const aDirPath: string; aNode: TMemFSNode);
    function ResolveFDPath(FD: Integer; const aPath: string): string;
    function FindNode(const aPath: string): TMemFSNode;
    function FindParentAndName(const aPath: string; out aName: string): TMemFSNode;
    function EnsureParentDirs(const aPath: string): TMemFSNode;
    function AllocateFD: Integer;
    function NormalizePath(const aPath: string): string;
    procedure SetStorageKeyPrefix(const aValue: string);
  public
    constructor Create;
    destructor Destroy; override;
    // IWASIFS methods
    function MkDirAt(FD: Integer; const aPath: String): NativeInt;
    function RmDirAt(FD: Integer; const aPath: String): NativeInt;
    function StatAt(FD: Integer; const aPath: String; var stat: TWasiFileStat): NativeInt;
    function StatFD(FD: Integer; var stat: TWasiFileStat): NativeInt;
    function UTimesAt(FD: Integer; aPath: String; aTime, MTime: TJSDate; UpdateLink: boolean): NativeInt;
    function UTimes(FD: Integer; aTime, MTime: TJSDate; Flags: TSetTimesFlags): NativeInt;
    function LinkAt(OldFD: Integer; OldPath: String; NewFD: Integer; NewPath: String): NativeInt;
    function SymLinkAt(FD: Integer; Path: String; Target: String): NativeInt;
    function RenameAt(OldFD: Integer; OldPath: String; NewFD: Integer; NewPath: String): NativeInt;
    function UnLinkAt(FD: Integer; const aPath: String): NativeInt;
    function OpenAt(FD: Integer; FDFlags: NativeInt; aPath: String; Flags, fsRightsBase, fsRightsInheriting, fsFlags: NativeInt; out OpenFD: Integer): NativeInt;
    function ReadLinkAt(FD: Integer; aPath: String; out aTarget: String): NativeInt;
    function Close(FD: Integer): NativeInt;
    function Write(FD: Integer; Data: TJSUint8Array; AtPos: Integer; out Written: Integer): NativeInt;
    function Sync(FD: Integer): NativeInt;
    function DataSync(FD: Integer): NativeInt;
    function Seek(FD: Integer; Offset: Integer; Whence: TSeekWhence; out NewPos: Integer): NativeInt;
    function Read(FD: Integer; Data: TJSUint8Array; AtPos: Integer; out BytesRead: Integer): NativeInt;
    function ReadDir(FD: Integer; Cookie: NativeInt; out DirEnt: TWasiFSDirent): NativeInt;
    function GetPrestat(FD: Integer): String;
    procedure PreLoadFile(aPath: String; aData: TJSDataView);
    // Convenience methods
    function GetFileContent(const aPath: string): TJSUint8Array;
    procedure SetFileContent(const aPath: string; aData: TJSUint8Array);
    function GetDirectoryContent(const aPath: string): TStringDynArray;
    function DumpTree(const aPrefix: string = ''): string;
    // Properties
    property MaxFD: Integer read FMaxFD write FMaxFD;
    property MaxFileSize: NativeInt read FMaxFileSize write FMaxFileSize;
    property StorageKeyPrefix: string read FStorageKeyPrefix write SetStorageKeyPrefix;
    property Storage: TJSStorage read FStorage write FStorage;
  end;

implementation

const
  ResOK = __WASI_ERRNO_SUCCESS;

{ Base64 helpers }

function ArrayToBase64(arr: TJSUint8Array): string;
begin
  asm
    var binary = '';
    var bytes = arr;
    var chunkSize = 8192;
    for (var i = 0; i < bytes.byteLength; i += chunkSize) {
      var chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.byteLength));
      binary += String.fromCharCode.apply(null, chunk);
    }
    Result = btoa(binary);
  end;
end;

function Base64ToArray(const s: string): TJSUint8Array;
begin
  asm
    var binary = atob(s);
    var len = binary.length;
    var bytes = new Uint8Array(len);
    for (var i = 0; i < len; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    Result = bytes;
  end;
end;

{ TMemFSNode }

constructor TMemFSNode.Create(const aName: string; aType: TDirentType; aParent: TMemFSNode);
begin
  inherited Create;
  FName := aName;
  FNodeType := aType;
  FParent := aParent;
  FCreatedAt := TJSDate.New;
  FModifiedAt := TJSDate.New;
  FSize := 0;
  if aType = dtDirectory then
    FChildren := TJSMap.New
  else
    FData := TJSUint8Array.New(0);
end;

function TMemFSNode.GetAbsolutePath: string;
var
  Node: TMemFSNode;
  Parts: TJSArray;
begin
  if FParent = nil then
    Exit('/');
  Parts := TJSArray.New;
  Node := Self;
  while (Node <> nil) and (Node.FParent <> nil) do
  begin
    Parts.unshift(Node.FName);
    Node := Node.FParent;
  end;
  Result := '/' + string(Parts.join('/'));
end;

{ TWASIMemFS }

constructor TWASIMemFS.Create;
var
  RootHandle: TOpenFileHandle;
begin
  inherited Create;
  FRoot := TMemFSNode.Create('/', dtDirectory, nil);
  FHandles := TJSMap.New;
  FNextFD := 4;
  FMaxFD := 1024;
  FMaxFileSize := 10 * 1024 * 1024;
  FStorageKeyPrefix := '';
  FStorage := nil;
  // Pre-register FD 3 as root directory handle
  RootHandle := TOpenFileHandle.Create;
  RootHandle.Node := FRoot;
  RootHandle.Path := '/';
  RootHandle.IsDirectory := True;
  RootHandle.CanRead := False;
  RootHandle.CanWrite := False;
  FHandles.&set(3, RootHandle);
end;

destructor TWASIMemFS.Destroy;
begin
  if IsPersistenceEnabled then
    FHandles.forEach(procedure(value: JSValue; key: JSValue)
    var
      Handle: TOpenFileHandle;
    begin
      Handle := TOpenFileHandle(value);
      if Handle.Modified and (not Handle.IsDirectory) then
        FlushFileToStorage(Handle.Path, Handle.Node.Data);
    end);
  inherited Destroy;
end;

function TWASIMemFS.IsPersistenceEnabled: Boolean;
begin
  Result := (FStorageKeyPrefix <> '') and Assigned(FStorage);
end;


procedure TWASIMemFS.SetStorageKeyPrefix(const aValue: string);
begin
  FStorageKeyPrefix := aValue;
  if (aValue <> '') and Assigned(FStorage) then
    HydrateFromStorage;
end;

function TWASIMemFS.GetPathParts(const aPath : String) : TStringDynArray;
begin
  Result := TJSString(StringReplace(aPath,'//','/',[rfReplaceAll])).split('/');
  if (Length(Result)>0) and (Result[0]='') then
    Result:=Copy(Result,1,Length(Result)-1);
end;

function TWASIMemFS.NormalizePath(const aPath: string): string;
var
  Normalized: TJSArray;
  Parts : TJSStringDynArray;
  I: Integer;
  Part: string;
begin
  if (aPath = '') or (aPath = '/') then
    Exit('/');
  Parts:=GetPathParts(aPath);
  Normalized := TJSArray.New;
  for I := 0 to Length(Parts) - 1 do
  begin
    Part :=Parts[I];
    if (Part = '') or (Part = '.') then
      continue
    else if Part = '..' then
    begin
      if Normalized.Length > 0 then
        Normalized.pop;
    end
    else
      Normalized.push(Part);
  end;
  if Normalized.Length = 0 then
    Result := '/'
  else
    Result := '/' + Normalized.join('/');
end;

function TWASIMemFS.ResolveFDPath(FD: Integer; const aPath: string): string;
var
  Handle: TOpenFileHandle;
  BasePath: string;
begin
  if FD = 3 then
  begin
    Result := aPath;
    if (Result <> '') and (Result[1] <> '/') then
      Result := '/' + Result;
  end
  else
  begin
    if FHandles.has(FD) then
    begin
      Handle := TOpenFileHandle(FHandles.get(FD));
      if not Handle.IsDirectory then
        Writeln('Warning: ResolveFDPath on non-directory FD ', FD);
      BasePath := Handle.Path;
      if (aPath <> '') and (aPath[1] = '/') then
        Result := aPath
      else
      begin
        if BasePath = '/' then
          Result := '/' + aPath
        else
          Result := BasePath + '/' + aPath;
      end;
    end
    else
    begin
      Writeln('Warning: ResolveFDPath unknown FD ', FD);
      Result := aPath;
      if (Result <> '') and (Result[1] <> '/') then
        Result := '/' + Result;
    end;
  end;
  Result := NormalizePath(Result);
end;

function TWASIMemFS.FindNode(const aPath: string): TMemFSNode;
var
  NPath: string;
  Parts: TStringDynArray;
  I: Integer;
  Current: TMemFSNode;
  Part: string;
  ChildVal: JSValue;
begin
  NPath := NormalizePath(aPath);
  if NPath = '/' then
    Exit(FRoot);

  Parts := GetPathParts(NPath);

  Current := FRoot;
  for I := 0 to Length(Parts) - 1 do
  begin
    Part := Parts[I];
    if (Current.NodeType <> dtDirectory) or (Current.Children = nil) then
      Exit(nil);
    if not Current.Children.has(Part) then
      Exit(nil);
    ChildVal := Current.Children.get(Part);
    Current := TMemFSNode(ChildVal);
  end;
  Result := Current;
end;

function TWASIMemFS.FindParentAndName(const aPath: string; out aName: string): TMemFSNode;
var
  NPath: string;
  LastSlash: Integer;
  ParentPath: string;
begin
  NPath := NormalizePath(aPath);
  if NPath = '/' then
  begin
    aName := '';
    Exit(nil);
  end;
  // Find last slash
  LastSlash :=TJSString(NPath).lastIndexOf('/');
  if LastSlash = 0 then
    ParentPath := '/'
  else
    ParentPath := Copy(NPath, 1, LastSlash);
  aName := Copy(NPath, LastSlash + 2, Length(NPath) - LastSlash - 1);
  Result := FindNode(ParentPath);
end;

function TWASIMemFS.EnsureParentDirs(const aPath: string): TMemFSNode;
var
  NPath: string;
  Parts: TStringDynArray;
  I: Integer;
  Current: TMemFSNode;
  Part: string;
  Child: TMemFSNode;
begin
  NPath := NormalizePath(aPath);
  Parts := GetPathParts(NPath);
  // We want the parent of the last component, so iterate all but last
  Current := FRoot;
  for I := 0 to Length(Parts) - 2 do
  begin
    Part := Parts[I];
    if Current.Children.has(Part) then
      Current := TMemFSNode(Current.Children.get(Part))
    else
    begin
      Child := TMemFSNode.Create(Part, dtDirectory, Current);
      Current.Children.&set(Part, Child);
      Current := Child;
    end;
  end;
  Result := Current;
end;

function TWASIMemFS.AllocateFD: Integer;
var
  StartFD: Integer;
begin
  StartFD := FNextFD;
  repeat
    if not FHandles.has(FNextFD) then
    begin
      Result := FNextFD;
      FNextFD := FNextFD + 1;
      if FNextFD >= FMaxFD then
        FNextFD := 4;
      Exit;
    end;
    FNextFD := FNextFD + 1;
    if FNextFD >= FMaxFD then
      FNextFD := 4;
  until FNextFD = StartFD;
  Result := -1;
end;

{ localStorage persistence helpers }

procedure TWASIMemFS.FlushFileToStorage(const aPath: string; aData: TJSUint8Array);
begin
  if not IsPersistenceEnabled then Exit;
  FStorage.setItem(FStorageKeyPrefix + aPath, ArrayToBase64(aData));
end;

procedure TWASIMemFS.RemoveFileFromStorage(const aPath: string);
begin
  if not IsPersistenceEnabled then Exit;
  FStorage.removeItem(FStorageKeyPrefix + aPath);
end;

function TWASIMemFS.TryHydrateFile(const aPath: string): TMemFSNode;
var
  RawValue: JSValue;
  StoredValue: string absolute rawvalue;
  FileData: TJSUint8Array;
  ParentNode: TMemFSNode;
  LeafName: string;
  NewNode: TMemFSNode;
  NPath: string;
begin
  Result := nil;
  if not IsPersistenceEnabled then Exit;
  NPath := NormalizePath(aPath);
  RawValue := JSValue(FStorage.getItem(FStorageKeyPrefix + NPath));
  if isNull(RawValue) or isUndefined(RawValue) then Exit;
  StoredValue := String(RawValue);
  FileData := Base64ToArray(StoredValue);
  ParentNode := EnsureParentDirs(NPath);
  LeafName:=ExtractFileName(NPath);
  if ParentNode.Children.has(LeafName) then
  begin
    NewNode := TMemFSNode(ParentNode.Children.get(LeafName));
    NewNode.Data := FileData;
    NewNode.Size := FileData.byteLength;
    Result := NewNode;
  end
  else
  begin
    NewNode := TMemFSNode.Create(LeafName, dtFile, ParentNode);
    NewNode.Data := FileData;
    NewNode.Size := FileData.byteLength;
    ParentNode.Children.&set(LeafName, NewNode);
    Result := NewNode;
  end;
end;

procedure TWASIMemFS.HydrateFromStorage;
var
  Keys: TStringDynArray;
  I, Len, Count: Integer;
  K: string;
  PrefixLen: Integer;
  FilePath: string;
begin
  if not IsPersistenceEnabled then Exit;
  PrefixLen := Length(FStorageKeyPrefix);
  Len := FStorage.length;
  Count := 0;
  SetLength(Keys, Len);
  for I := 0 to Len - 1 do
  begin
    K := FStorage.key(I);
    if Copy(K, 1, PrefixLen) = FStorageKeyPrefix then
    begin
      Keys[Count] := K;
      Inc(Count);
    end;
  end;
  SetLength(Keys, Count);
  for I := 0 to Count - 1 do
  begin
    FilePath := Copy(Keys[I], PrefixLen + 1, Length(Keys[I]) - PrefixLen);
    TryHydrateFile(FilePath);
  end;
end;

procedure TWASIMemFS.HydrateDirFromStorage(const aDirPath: string; aNode: TMemFSNode);
var
  I, Len: Integer;
  K, Prefix, FilePath, RelPath: string;
  PrefixLen: Integer;
begin
  if not IsPersistenceEnabled then Exit;
  if aNode = nil then Exit;
  Prefix := FStorageKeyPrefix + aDirPath;
  if Prefix[Length(Prefix)] <> '/' then
    Prefix := Prefix + '/';
  PrefixLen := Length(Prefix);
  Len := FStorage.length;
  for I := 0 to Len - 1 do
  begin
    K := FStorage.key(I);
    if Copy(K, 1, PrefixLen) <> Prefix then
      continue;
    RelPath := Copy(K, PrefixLen + 1, Length(K) - PrefixLen);
    // Only direct children (no further slashes)
    if Pos('/', RelPath) > 0 then
      continue;
    // Skip if already in tree
    if aNode.Children.has(RelPath) then
      continue;
    FilePath := Copy(K, Length(FStorageKeyPrefix) + 1, Length(K) - Length(FStorageKeyPrefix));
    TryHydrateFile(FilePath);
  end;
end;

{ IWASIFS: GetPrestat and PreLoadFile }

function TWASIMemFS.GetPrestat(FD: Integer): String;
begin
  if FD = 3 then
    Result := '/'
  else
    Result := '';
end;

procedure TWASIMemFS.PreLoadFile(aPath: String; aData: TJSDataView);
var
  FileData: TJSUint8Array;
  ParentNode: TMemFSNode;
  LeafName: string;
  Node: TMemFSNode;
  NPath: string;
begin
  FileData := TJSUint8Array.New(aData.buffer, aData.byteOffset, aData.byteLength);
  if FileData.byteLength > NativeUInt(FMaxFileSize) then
  begin
    Writeln('Warning: PreLoadFile skipping ', aPath, ' - exceeds MaxFileSize (', FileData.byteLength, ' > ', FMaxFileSize, ')');
    Exit;
  end;
  NPath := NormalizePath(aPath);
  ParentNode := EnsureParentDirs(NPath);
  LeafName:=ExtractFilePath(NPath);
  if ParentNode.Children.has(LeafName) then
  begin
    Node := TMemFSNode(ParentNode.Children.get(LeafName));
    Node.Data := FileData;
    Node.Size := FileData.byteLength;
    Node.ModifiedAt := TJSDate.New;
  end
  else
  begin
    Node := TMemFSNode.Create(LeafName, dtFile, ParentNode);
    Node.Data := FileData;
    Node.Size := FileData.byteLength;
    ParentNode.Children.&set(LeafName, Node);
  end;
  if IsPersistenceEnabled then
    FlushFileToStorage(NPath, FileData);
end;

{ IWASIFS: MkDirAt and RmDirAt }

function TWASIMemFS.MkDirAt(FD: Integer; const aPath: String): NativeInt;
var
  FullPath, LeafName: string;
  ParentNode: TMemFSNode;
  NewDir: TMemFSNode;
begin
  FullPath := ResolveFDPath(FD, aPath);
  ParentNode := FindParentAndName(FullPath, LeafName);
  if (ParentNode = nil) or (ParentNode.NodeType <> dtDirectory) then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  if ParentNode.Children.has(LeafName) then
  begin
    Result := WASI_EEXIST;
    Exit;
  end;
  NewDir := TMemFSNode.Create(LeafName, dtDirectory, ParentNode);
  ParentNode.Children.&set(LeafName, NewDir);
  Result := ResOK;
end;

function TWASIMemFS.RmDirAt(FD: Integer; const aPath: String): NativeInt;
var
  FullPath: string;
  Node: TMemFSNode;
  DirPrefix, SK: string;
  SLen, J: Integer;
begin
  FullPath := ResolveFDPath(FD, aPath);
  Node := FindNode(FullPath);
  if Node = nil then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  if Node.NodeType <> dtDirectory then
  begin
    Result := WASI_ENOTDIR;
    Exit;
  end;
  if Integer(Node.Children.size) > 0 then
  begin
    Result := WASI_ENOTEMPTY;
    Exit;
  end;
  if Node.Parent <> nil then
    Node.Parent.Children.delete(Node.Name);
  // Clean up localStorage entries under this directory
  if IsPersistenceEnabled then
  begin
    DirPrefix := FStorageKeyPrefix + FullPath + '/';
    SLen := FStorage.length;
    for J := SLen - 1 downto 0 do
    begin
      SK := FStorage.key(J);
      if Copy(SK, 1, Length(DirPrefix)) = DirPrefix then
        FStorage.removeItem(SK);
    end;
  end;
  Result := ResOK;
end;

{ IWASIFS: OpenAt }

function TWASIMemFS.OpenAt(FD: Integer; FDFlags: NativeInt; aPath: String;
  Flags, fsRightsBase, fsRightsInheriting, fsFlags: NativeInt;
  out OpenFD: Integer): NativeInt;
var
  FullPath: string;
  Node: TMemFSNode;
  Handle: TOpenFileHandle;
  NewFD: Integer;
  ParentNode: TMemFSNode;
  LeafName: string;
  Rights: NativeInt;
  CanReadF, CanWriteF: Boolean;
  ChildNames: TStringDynArray;

  function HasFlag(aFlag: Integer): Boolean;
  begin
    Result := (Flags and aFlag) <> 0;
  end;

  function HasRight(aRight: Integer): Boolean;
  begin
    if IsBigint(Rights) then
    begin
      asm
        Result = ((Rights & BigInt(aRight)) != 0n);
      end;
    end
    else
      Result := (Rights and aRight) <> 0;
  end;

var
  I : integer;

begin
  if (FDFlags <> 0) and (fsFlags <> 0) and (fsRightsInheriting <> 0) then ;
  FullPath := ResolveFDPath(FD, aPath);
  Rights := fsRightsBase;

  if HasFlag(__WASI_OFLAGS_DIRECTORY) then
  begin
    // Directory open
    Node := FindNode(FullPath);
    if Node = nil then
    begin
      Result := WASI_ENOENT;
      Exit;
    end;
    if Node.NodeType <> dtDirectory then
    begin
      Result := WASI_ENOTDIR;
      Exit;
    end;
    // Hydrate from storage
    if IsPersistenceEnabled then
      HydrateDirFromStorage(FullPath, Node);
    // Snapshot child names
    ChildNames := [];
    Node.Children.forEach(procedure(value: JSValue; key: JSValue)
    begin
      TJSArray(ChildNames).push(key);
    end);
    // Allocate FD
    NewFD := AllocateFD;
    if NewFD = -1 then
    begin
      Result := WASI_EMFILE;
      Exit;
    end;
    Handle := TOpenFileHandle.Create;
    Handle.Node := Node;
    Handle.Path := FullPath;
    Handle.IsDirectory := True;
    Handle.CanRead := False;
    Handle.CanWrite := False;
    SetLength(Handle.DirEntries, Length(ChildNames));
    for i:=0 to Length(ChildNames)-1 do
        Handle.DirEntries[i] := ChildNames[i];
    FHandles.&set(NewFD, Handle);
    OpenFD := NewFD;
    Result := ResOK;
  end
  else
  begin
    // File open
    CanReadF := HasRight(__WASI_RIGHTS_FD_READ);
    CanWriteF := HasFlag(__WASI_OFLAGS_CREAT) or HasRight(__WASI_RIGHTS_FD_WRITE);

    Node := FindNode(FullPath);
    // Try hydrate from storage
    if (Node = nil) and IsPersistenceEnabled then
      Node := TryHydrateFile(FullPath);

    if (Node <> nil) and HasFlag(__WASI_OFLAGS_EXCL) and HasFlag(__WASI_OFLAGS_CREAT) then
    begin
      Result := WASI_EEXIST;
      Exit;
    end;

    if Node = nil then
    begin
      if HasFlag(__WASI_OFLAGS_CREAT) then
      begin
        ParentNode := EnsureParentDirs(FullPath);
        LeafName:=ExtractFileName(FullPath);
        Node := TMemFSNode.Create(LeafName, dtFile, ParentNode);
        ParentNode.Children.&set(LeafName, Node);
      end
      else
      begin
        Result := WASI_ENOENT;
        Exit;
      end;
    end;

    if HasFlag(__WASI_OFLAGS_TRUNC) then
    begin
      Node.Data := TJSUint8Array.New(0);
      Node.Size := 0;
      Node.ModifiedAt := TJSDate.New;
    end;

    NewFD := AllocateFD;
    if NewFD = -1 then
    begin
      Result := WASI_EMFILE;
      Exit;
    end;

    Handle := TOpenFileHandle.Create;
    Handle.Node := Node;
    Handle.Path := FullPath;
    Handle.Position := 0;
    Handle.CanRead := CanReadF;
    Handle.CanWrite := CanWriteF;
    Handle.Modified := False;
    Handle.IsDirectory := False;
    Handle.IsAppend := (FDFlags and __WASI_FDFLAGS_APPEND) <> 0;
    FHandles.&set(NewFD, Handle);
    OpenFD := NewFD;
    Result := ResOK;
  end;
end;

{ IWASIFS: Read and Write }

function TWASIMemFS.Read(FD: Integer; Data: TJSUint8Array; AtPos: Integer;
  out BytesRead: Integer): NativeInt;
var
  Handle: TOpenFileHandle;
  Pos, Available, ToRead: Integer;
  SourceSlice: TJSUint8Array;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if Handle.IsDirectory or (not Handle.CanRead) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  if AtPos = -1 then
    Pos := Handle.Position
  else
    Pos := AtPos;
  Available := Handle.Node.Size;
  if Integer(Handle.Node.Data.byteLength) < Available then
    Available := Integer(Handle.Node.Data.byteLength);
  Available := Available - Pos;
  if Available < 0 then
    Available := 0;
  ToRead := Integer(Data.byteLength);
  if ToRead > Available then
    ToRead := Available;
  if ToRead > 0 then
  begin
    SourceSlice := Handle.Node.Data.subarray(Pos, Pos + ToRead);
    Data._set(SourceSlice);
  end;
  BytesRead := ToRead;
  if AtPos = -1 then
    Handle.Position := Pos + ToRead;
  Result := ResOK;
end;

function TWASIMemFS.Write(FD: Integer; Data: TJSUint8Array; AtPos: Integer;
  out Written: Integer): NativeInt;
var
  Handle: TOpenFileHandle;
  Pos, NewEndPos: Integer;
  NewBuf: TJSUint8Array;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if Handle.IsDirectory or (not Handle.CanWrite) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  if Handle.IsAppend then
    Pos := Handle.Node.Size
  else if AtPos = -1 then
    Pos := Handle.Position
  else
    Pos := AtPos;
  NewEndPos := Pos + Integer(Data.byteLength);
  if NewEndPos > FMaxFileSize then
  begin
    Result := WASI_EFBIG;
    Exit;
  end;
  if NewEndPos > Integer(Handle.Node.Data.byteLength) then
  begin
    NewBuf := TJSUint8Array.New(NewEndPos);
    NewBuf._set(Handle.Node.Data);
    Handle.Node.Data := NewBuf;
  end;
  Handle.Node.Data._set(Data, Pos);
  if NewEndPos > Handle.Node.Size then
    Handle.Node.Size := NewEndPos;
  if AtPos = -1 then
    Handle.Position := NewEndPos;
  Handle.Modified := True;
  Handle.Node.ModifiedAt := TJSDate.New;
  Written := Integer(Data.byteLength);
  Result := ResOK;
end;

{ IWASIFS: Seek, Close, Sync, DataSync }

function TWASIMemFS.Seek(FD: Integer; Offset: Integer; Whence: TSeekWhence;
  out NewPos: Integer): NativeInt;
var
  Handle: TOpenFileHandle;
  Pos: Integer;
  IntOffset: Integer;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if Handle.IsDirectory then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  IntOffset := AsIntNumber(Offset);
  case Whence of
    swBeginning: Pos := IntOffset;
    swCurrent: Pos := Handle.Position + IntOffset;
    swEnd: Pos := Handle.Node.Size + IntOffset;
  end;
  if Pos < 0 then
  begin
    Result := WASI_EINVAL;
    Exit;
  end;
  Handle.Position := Pos;
  NewPos := Pos;
  Result := ResOK;
end;

function TWASIMemFS.Close(FD: Integer): NativeInt;
var
  Handle: TOpenFileHandle;
begin
  if FD = 3 then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if Handle.Modified and (not Handle.IsDirectory) and IsPersistenceEnabled then
    FlushFileToStorage(Handle.Path, TJSUint8Array.New(Handle.Node.Data.buffer, 0, Handle.Node.Size));
  FHandles.delete(FD);
  Result := ResOK;
end;

function TWASIMemFS.Sync(FD: Integer): NativeInt;
var
  Handle: TOpenFileHandle;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if IsPersistenceEnabled and (not Handle.IsDirectory) then
    FlushFileToStorage(Handle.Path, TJSUint8Array.New(Handle.Node.Data.buffer, 0, Handle.Node.Size));
  Result := ResOK;
end;

function TWASIMemFS.DataSync(FD: Integer): NativeInt;
var
  Handle: TOpenFileHandle;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if IsPersistenceEnabled and (not Handle.IsDirectory) then
    FlushFileToStorage(Handle.Path, TJSUint8Array.New(Handle.Node.Data.buffer, 0, Handle.Node.Size));
  Result := ResOK;
end;

{ IWASIFS: StatAt, StatFD, ReadDir }

function TWASIMemFS.StatAt(FD: Integer; const aPath: String;
  var stat: TWasiFileStat): NativeInt;
var
  FullPath: string;
  Node: TMemFSNode;
  I, Len: Integer;
  K, CheckPrefix: string;
  Found: Boolean;
begin
  FullPath := ResolveFDPath(FD, aPath);
  Node := FindNode(FullPath);
  if (Node = nil) and IsPersistenceEnabled then
  begin
    Node := TryHydrateFile(FullPath);
    if Node = nil then
    begin
      // Check for implicit directory in localStorage
      CheckPrefix := FStorageKeyPrefix + FullPath + '/';
      Found := False;
      Len := FStorage.length;
      for I := 0 to Len - 1 do
      begin
        K := FStorage.key(I);
        if Copy(K, 1, Length(CheckPrefix)) = CheckPrefix then
        begin
          Found := True;
          Break;
        end;
      end;
      if Found then
      begin
        EnsureParentDirs(FullPath + '/dummy');
        Node := FindNode(FullPath);
      end;
    end;
  end;
  if Node = nil then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  stat.dev := 0;
  stat.ino := 0;
  stat.filetype := DirentMap[Node.NodeType];
  stat.nlink := 1;
  stat.size := Node.Size;
  stat.atim := NativeInt(Node.ModifiedAt.Time);
  stat.mtim := NativeInt(Node.ModifiedAt.Time);
  stat.ctim := NativeInt(Node.CreatedAt.Time);
  Result := ResOK;
end;

function TWASIMemFS.StatFD(FD: Integer; var stat: TWasiFileStat): NativeInt;
var
  Handle: TOpenFileHandle;
  Node: TMemFSNode;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  Node := Handle.Node;
  stat.dev := 0;
  stat.ino := 0;
  stat.filetype := DirentMap[Node.NodeType];
  stat.nlink := 1;
  stat.size := Node.Size;
  stat.atim := NativeInt(Node.ModifiedAt.Time);
  stat.mtim := NativeInt(Node.ModifiedAt.Time);
  stat.ctim := NativeInt(Node.CreatedAt.Time);
  Result := ResOK;
end;

function TWASIMemFS.ReadDir(FD: Integer; Cookie: NativeInt;
  out DirEnt: TWasiFSDirent): NativeInt;
var
  Handle: TOpenFileHandle;
  ChildName: string;
  ChildNode: TMemFSNode;
begin
  if not FHandles.has(FD) then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  Handle := TOpenFileHandle(FHandles.get(FD));
  if not Handle.IsDirectory then
  begin
    Result := WASI_EBADF;
    Exit;
  end;
  if (Cookie < 0) or (Cookie >= Length(Handle.DirEntries)) then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  ChildName := Handle.DirEntries[Cookie];
  DirEnt.name := ChildName;
  DirEnt.ino := 0;
  DirEnt.Next := Cookie + 1;
  // Look up child node for type
  if Handle.Node.Children.has(ChildName) then
  begin
    ChildNode := TMemFSNode(Handle.Node.Children.get(ChildName));
    DirEnt.EntryType := ChildNode.NodeType;
  end
  else
    DirEnt.EntryType := dtUnknown;
  Result := ResOK;
end;

{ IWASIFS: RenameAt and UnLinkAt }

function TWASIMemFS.RenameAt(OldFD: Integer; OldPath: String;
  NewFD: Integer; NewPath: String): NativeInt;
var
  OldFullPath, NewFullPath: string;
  Node: TMemFSNode;
  NewParent: TMemFSNode;
  NewLeaf: string;
  OldAbsPath, NewAbsPath: string;
  I, Len: Integer;
  K, OldStoragePrefix, NewStoragePrefix, StoredVal, NewKey: string;
begin
  OldFullPath := ResolveFDPath(OldFD, OldPath);
  NewFullPath := ResolveFDPath(NewFD, NewPath);
  Node := FindNode(OldFullPath);
  if Node = nil then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  NewParent := FindParentAndName(NewFullPath, NewLeaf);
  if NewParent = nil then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  // Remove from old parent
  if Node.Parent <> nil then
    Node.Parent.Children.delete(Node.Name);
  // Update node
  OldAbsPath := OldFullPath;
  NewAbsPath := NewFullPath;
  Node.Name := NewLeaf;
  Node.Parent := NewParent;
  NewParent.Children.&set(NewLeaf, Node);
  // Update open handles paths
  FHandles.forEach(procedure(value: JSValue; key: JSValue)
  var
    H: TOpenFileHandle;
    HPath: string;
  begin
    H := TOpenFileHandle(value);
    HPath := H.Path;
    if HPath = OldAbsPath then
      H.Path := NewAbsPath
    else
    begin
      len:=Length(OldAbsPath);
       if Copy(HPath,1,len + 1) = (OldAbsPath + '/') then
          H.Path := NewAbsPath + Copy(HPath,1, Len);
    end;
  end);
  // Update localStorage
  if IsPersistenceEnabled then
  begin
    if Node.NodeType = dtFile then
    begin
      RemoveFileFromStorage(OldAbsPath);
      FlushFileToStorage(NewAbsPath, Node.Data);
    end
    else
    begin
      // Directory rename: scan all localStorage keys
      OldStoragePrefix := FStorageKeyPrefix + OldAbsPath + '/';
      NewStoragePrefix := FStorageKeyPrefix + NewAbsPath + '/';
      // Collect keys to rename
      Len := FStorage.length;
      for I := Len - 1 downto 0 do
      begin
        K := FStorage.key(I);
        if Copy(K, 1, Length(OldStoragePrefix)) = OldStoragePrefix then
        begin
          StoredVal := FStorage.getItem(K);
          NewKey := NewStoragePrefix + Copy(K, Length(OldStoragePrefix) + 1, Length(K) - Length(OldStoragePrefix));
          FStorage.removeItem(K);
          FStorage.setItem(NewKey, StoredVal);
        end;
      end;
    end;
  end;
  Result := ResOK;
end;

function TWASIMemFS.UnLinkAt(FD: Integer; const aPath: String): NativeInt;
var
  FullPath: string;
  Node: TMemFSNode;
begin
  FullPath := ResolveFDPath(FD, aPath);
  Node := FindNode(FullPath);
  if Node = nil then
  begin
    Result := WASI_ENOENT;
    Exit;
  end;
  if Node.NodeType = dtDirectory then
  begin
    Result := WASI_EISDIR;
    Exit;
  end;
  if Node.Parent <> nil then
    Node.Parent.Children.delete(Node.Name);
  if IsPersistenceEnabled then
    RemoveFileFromStorage(FullPath);
  Result := ResOK;
end;

{ IWASIFS: Stub methods }

function TWASIMemFS.LinkAt(OldFD: Integer; OldPath: String;
  NewFD: Integer; NewPath: String): NativeInt;
begin
  if (OldFD <> 0) and (OldPath <> '') and (NewFD <> 0) and (NewPath <> '') then;
  Result := WASI_ENOSYS;
end;

function TWASIMemFS.SymLinkAt(FD: Integer; Path: String; Target: String): NativeInt;
begin
  if (FD <> 0) and (Path <> '') and (Target <> '') then;
  Result := WASI_ENOSYS;
end;

function TWASIMemFS.ReadLinkAt(FD: Integer; aPath: String; out aTarget: String): NativeInt;
begin
  if (FD <> 0) and (aPath <> '') then;
  aTarget := '';
  Result := WASI_ENOSYS;
end;

function TWASIMemFS.UTimesAt(FD: Integer; aPath: String; aTime, MTime: TJSDate;
  UpdateLink: boolean): NativeInt;
begin
  if (FD <> 0) and (aPath <> '') and Assigned(aTime) and Assigned(MTime) and UpdateLink then;
  Result := ResOK;
end;

function TWASIMemFS.UTimes(FD: Integer; aTime, MTime: TJSDate;
  Flags: TSetTimesFlags): NativeInt;
begin
  if (FD <> 0) and Assigned(aTime) and Assigned(MTime) and (Flags = []) then;
  Result := ResOK;
end;

{ Convenience methods }

function TWASIMemFS.GetFileContent(const aPath: string): TJSUint8Array;
var
  Node: TMemFSNode;
begin
  Node := FindNode(aPath);
  if (Node = nil) and IsPersistenceEnabled then
    Node := TryHydrateFile(aPath);
  if (Node = nil) or (Node.NodeType <> dtFile) then
    Exit(nil);
  Result := TJSUint8Array.New(Node.Data);
end;

procedure TWASIMemFS.SetFileContent(const aPath: string; aData: TJSUint8Array);
var
  NPath, LeafName: string;
  ParentNode: TMemFSNode;
  Node: TMemFSNode;
begin
  if Integer(aData.byteLength) > FMaxFileSize then
  begin
    Writeln('Warning: SetFileContent skipping ', aPath, ' - exceeds MaxFileSize');
    Exit;
  end;
  NPath := NormalizePath(aPath);
  ParentNode := EnsureParentDirs(NPath);
  LeafName:=ExtractFileName(NPath);
  if ParentNode.Children.has(LeafName) then
  begin
    Node := TMemFSNode(ParentNode.Children.get(LeafName));
    Node.Data := aData;
    Node.Size := aData.byteLength;
    Node.ModifiedAt := TJSDate.New;
  end
  else
  begin
    Node := TMemFSNode.Create(LeafName, dtFile, ParentNode);
    Node.Data := aData;
    Node.Size := aData.byteLength;
    ParentNode.Children.&set(LeafName, Node);
  end;
  if IsPersistenceEnabled then
    FlushFileToStorage(NPath, aData);
end;

function TWASIMemFS.GetDirectoryContent(const aPath: string): TStringDynArray;
var
  Node: TMemFSNode;
  NPath: string;
  Names: TJSArray;
  I, Len: Integer;
  K, CheckPrefix: string;
  Found: Boolean;
begin
  NPath := NormalizePath(aPath);
  Node := FindNode(NPath);
  if (Node = nil) and IsPersistenceEnabled then
  begin
    CheckPrefix := FStorageKeyPrefix + NPath + '/';
    Found := False;
    Len := FStorage.length;
    for I := 0 to Len - 1 do
    begin
      K := FStorage.key(I);
      if Copy(K, 1, Length(CheckPrefix)) = CheckPrefix then
      begin
        Found := True;
        Break;
      end;
    end;
    if Found then
    begin
      EnsureParentDirs(NPath + '/dummy');
      Node := FindNode(NPath);
    end;
  end;
  if (Node = nil) or (Node.NodeType <> dtDirectory) then
    Exit(nil);
  if IsPersistenceEnabled then
    HydrateDirFromStorage(NPath, Node);
  Names := TJSArray.New;
  Node.Children.forEach(procedure(value: JSValue; key: JSValue)
  begin
    Names.push(key);
  end);
  SetLength(Result, Integer(Names.Length));
  for I := 0 to Integer(Names.Length) - 1 do
    Result[I] := string(Names[I]);
end;

function TWASIMemFS.DumpTree(const aPrefix: string): string;
var
  Lines: TJSArray;

  procedure DumpNode(aNode: TMemFSNode; const aIndent: string);
  var
    ChildNames: TJSArray;
    I: Integer;
    ChildNode: TMemFSNode;
  begin
    if aNode.NodeType = dtDirectory then
    begin
      Lines.push(aIndent + aNode.Name + '/');
      ChildNames := TJSArray.New;
      aNode.Children.forEach(procedure(value: JSValue; key: JSValue)
      begin
        ChildNames.push(key);
      end);
      ChildNames.sort;
      for I := 0 to Integer(ChildNames.Length) - 1 do
      begin
        ChildNode := TMemFSNode(aNode.Children.get(string(ChildNames[I])));
        DumpNode(ChildNode, aIndent + '  ');
      end;
    end
    else
      Lines.push(aIndent + aNode.Name + ' (' + IntToStr(aNode.Size) + ' bytes)');
  end;

begin
  Lines := TJSArray.New;
  if aPrefix <> '' then
    Lines.push(aPrefix);
  DumpNode(FRoot, '');
  Result := string(Lines.join(#10));
end;

end.
