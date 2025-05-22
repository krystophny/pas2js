unit wasm.pas2js.storage;

{$mode ObjFPC}

// Uncomment this if you want to remove all logging calls
{ $DEFINE NOLOGAPICALLS}
interface

uses
  js, web, wasienv, wasm.storage.shared;

Type
  
  { TStorageAPI }

  TStorageAPI = Class(TImportExtension)
  Protected
    function GetStorageName(aKind: Longint): string; virtual;
    function GetStorage(aKind: Longint): TJSStorage; virtual;
    function HandleClear(aStorageKind: Longint): longint; virtual;
    function HandleKey(aStorageKind: Longint; aKey: integer; aResult, aResultLen: TWasmPointer): longint; virtual;
    function HandleGetItem(aStorageKind: Longint; aKey: TWasmPointer; aKeyLen: Integer; aResult, aResultLen: TWasmPointer): longint; virtual;
    function HandleLength(aStorageKind: Longint; aResult: TWasmPointer): longint; virtual;
    function HandleRemoveItem(aStorageKind: Longint; aKey: TWasmPointer; aKeyLen: Integer): longint; virtual;
    function HandleSetItem(aStorageKind: Longint; aKey: TWasmPointer; aKeyLen: Integer; aValue: TWasmPointer; aValueLen: Integer): longint; virtual;
  public
    procedure FillImportObject(aObject: TJSObject); override;
    function ImportName : String; override;
    property LogAPI;
  end;

implementation

{ TLocalStorageAPI }

function TStorageAPI.GetStorageName(aKind: Longint): string;
begin
  Case aKind of
    STORAGE_LOCAL : Result:='localStorage';
    STORAGE_SESSION : Result:='sessionStorage';
  else
    Result:='unknown';
  end;
end;

function TStorageAPI.GetStorage(aKind: Longint): TJSStorage;

begin
  Case aKind of
    STORAGE_LOCAL : Result:=window.localStorage;
    STORAGE_SESSION : Result:=window.sessionStorage;
  else
    Result:=Nil;
  end;
end;

function TStorageAPI.HandleKey(aStorageKind: Longint; aKey: integer; aResult, aResultLen: TWasmPointer): longint;
var
  lStorage : TJSStorage;
  lValue : string;
  lLen,lLoc : integer;
begin
  {$IFNDEF NOLOGAPICALLS}
  if LogAPI then
    DoLog('Key(%s,%d)',[GetStorageName(aStorageKind),aKey]);
  {$ENDIF}
  lStorage:=GetStorage(aStorageKind);
  if lStorage=Nil then
    exit(ESTORAGE_INVALIDKIND);
  lValue:=lStorage.key(aKey);
  if isnull(lValue) or (Length(lValue)=0) then
    begin
    Env.SetMemInfoInt32(aResult,0);
    Env.SetMemInfoInt32(aResultLen,0);
    end
  else
    begin
    lLen:=Length(lValue)*4;
    lLoc:=InstanceExports.AllocMem(lLen);
    lLen:=env.SetUTF8StringInMem(lLoc,lLen,lValue);
    Env.SetMemInfoInt32(aResult,lLoc);
    Env.SetMemInfoInt32(aResultLen,lLen);
    end;
  Result:=ESTORAGE_SUCCESS;
end;

function TStorageAPI.HandleGetItem(aStorageKind: Longint; aKey: TWasmPointer; aKeyLen: Integer; aResult, aResultLen: TWasmPointer
  ): longint;
var
  lStorage : TJSStorage;
  lKey : String;
  lValue : String;
  lLen,lLoc : Integer;
begin
  lStorage:=GetStorage(aStorageKind);
  lKey:=env.GetUTF8StringFromMem(aKey,aKeyLen);
  {$IFNDEF NOLOGAPICALLS}
  if LogAPI then
    DoLog('GetItem(%s,"%s")',[GetStorageName(aStorageKind),lKey]);
  {$ENDIF}
  if lStorage=Nil then
    exit(ESTORAGE_INVALIDKIND);
  lValue:=lStorage.getItem(lKey);
  if isnull(lValue) or (Length(lValue)=0) then
    begin
    Env.SetMemInfoInt32(aResult,0);
    Env.SetMemInfoInt32(aResultLen,0);
    end
  else
    begin
    lLen:=Length(lValue)*4;
    lLoc:=InstanceExports.AllocMem(lLen);
    lLen:=env.SetUTF8StringInMem(lLoc,lLen,lValue);
    Env.SetMemInfoInt32(aResult,lLoc);
    Env.SetMemInfoInt32(aResultLen,lLen);
    end;
  Result:=ESTORAGE_SUCCESS;
end;

function TStorageAPI.HandleLength(aStorageKind: Longint; aResult: TWasmPointer): longint;
var
  lStorage : TJSStorage;
begin
  {$IFNDEF NOLOGAPICALLS}
  if LogAPI then
    DoLog('Length(%s)',[GetStorageName(aStorageKind)]);
  {$ENDIF}
  lStorage:=GetStorage(aStorageKind);
  if lStorage=Nil then
    exit(ESTORAGE_INVALIDKIND);
  env.SetMemInfoInt32(aResult,lStorage.Length);
  Result:=ESTORAGE_SUCCESS
end;

function TStorageAPI.HandleSetItem(aStorageKind: Longint; aKey: TWasmPointer; aKeyLen: Integer; aValue: TWasmPointer;
  aValueLen: Integer): longint;

var
  lStorage : TJSStorage;
  lKey : String;
  lValue : String;
begin
  lKey:=env.GetUTF8StringFromMem(aKey,aKeyLen);
  lValue:=env.GetUTF8StringFromMem(aValue,aValueLen);
  {$IFNDEF NOLOGAPICALLS}
  if LogAPI then
    DoLog('SetItem(%s,"%s","%s")',[GetStorageName(aStorageKind),lKey,lValue]);
  {$ENDIF}
  lStorage:=GetStorage(aStorageKind);
  if lStorage=Nil then
    exit(ESTORAGE_INVALIDKIND);
  lKey:=env.GetUTF8StringFromMem(aKey,aKeyLen);
  lValue:=env.GetUTF8StringFromMem(aValue,aValueLen);
  lStorage.setItem(lKey,lValue);
  Result:=ESTORAGE_SUCCESS;
end;

function TStorageAPI.HandleRemoveItem(aStorageKind: Longint; aKey: TWasmPointer; aKeyLen: Integer): longint;

var
  lStorage : TJSStorage;
  lKey : string;
begin
  lKey:=env.GetUTF8StringFromMem(aKey,aKeyLen);
  {$IFNDEF NOLOGAPICALLS}
  if LogAPI then
    DoLog('RemoveItem(%s,"%s")',[GetStorageName(aStorageKind),lKey]);
  {$ENDIF}
  lStorage:=GetStorage(aStorageKind);
  if lStorage=Nil then
    exit(ESTORAGE_INVALIDKIND);
  lStorage.removeItem(lKey);
  Result:=ESTORAGE_SUCCESS;
end;

function TStorageAPI.HandleClear(aStorageKind: Longint): longint;

var
  lStorage : TJSStorage;
begin
  {$IFNDEF NOLOGAPICALLS}
  if LogAPI then
    DoLog('Clear(%s)',[GetStorageName(aStorageKind)]);
  {$ENDIF}
  lStorage:=GetStorage(aStorageKind);
  if lStorage=Nil then
    exit(ESTORAGE_INVALIDKIND);
  lStorage.Clear;
end;

procedure TStorageAPI.FillImportObject(aObject: TJSObject);
begin
  aObject[storageFN_GetItem]:=@HandleGetItem;
  aObject[storageFN_Key]:=@HandleKey;
  aObject[storageFN_length]:=@HandleLength;
  aObject[storageFN_SetItem]:=@HandleSetItem;
  aObject[storageFN_RemoveItem]:=@HandleRemoveItem;
  aObject[storageFN_Clear]:=@HandleRemoveItem;
end;

function TStorageAPI.ImportName: String;
begin
  result:=storageExportName
end;

end.

