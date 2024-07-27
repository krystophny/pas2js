{
    This file is part of the Pas2JS run time library.
    Copyright (c) 2024 by the Pas2JS development team.

    API to implement an object inspector for import in a WASM Module
    
    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit debug.objectinspector.wasm;

{$mode ObjFPC}

{ $DEFINE NOLOGAPICALLS} // Define this if you want to remove all API logging calls

interface

uses
  Classes, SysUtils, js, typinfo, debug.objectinspector.html, wasm.debuginspector.shared, wasienv;


type
  EWasmOI = Class(Exception);

  TWasmPointer = longint;

  { TWasmObjectInspectorApi }

  TWasmObjectInspectorApi = class(TImportExtension)
  private
    FHandleObjectSelection: Boolean;
    FInspector: THTMLObjectInspector;
    FLogAPICalls: Boolean;
    FObjectTree: THTMLObjectTree;
    procedure DoSelectObject(Sender: TObject; aObjectId: Integer);
    procedure RaiseOILastError(const aOperation: String);
    procedure SetHandleObjectSelection(AValue: Boolean);
    procedure SetInspector(AValue: THTMLObjectInspector);
    procedure SetLogAPICalls(AValue: Boolean);
    procedure SetObjectTree(AValue: THTMLObjectTree);
  protected
    procedure Logcall(Const aMsg : string);
    procedure LogCall(Const aFmt : string; aArgs : Array of const);
    // Inspector allocation/deallocation commands
    function InspectorAllocate(aID: TWasmPointer): TWasmOIResult;
    function InspectorDeAllocate(aID: TInspectorID): TWasmOIResult;
    // Property inspector commands
    function InspectorSetCaption(aInspectorID: TInspectorID; aCaption : TWasmPointer; aCaptionLen : Longint): TWasmOIResult;
    function InspectorAddProperty(aInspectorID: TInspectorID; PropertyData: TWasmPointer): TWasmOIResult;
    function InspectorClear(aInspectorID: TInspectorID): TWasmOIResult;
    // Object Tree commands
    function TreeSetCaption(aInspectorID: TInspectorID; aCaption : TWasmPointer; aCaptionLen : Longint): TWasmOIResult;
    function TreeAddObject(aInspectorID: TInspectorID; ObjectData : PObjectData): TWasmOIResult;
    function TreeClear(aInspectorID: TInspectorID) : TWasmOIResult;
    Procedure HookObjectTree;
    Procedure UnhookObjectTree;
    Function GetTree(aInspectorID : TInspectorID) : THTMLObjectTree;
    Function GetInspector(aInspectorID : TInspectorID) : THTMLObjectInspector;
  Public
    Constructor Create(aEnv : TPas2JSWASIEnvironment); override;
    Procedure FillImportObject(aObject : TJSObject); override;
    Function ImportName : String; override;
    Procedure GetObjectProperties(aObjectID : Integer);
    Property DefaultObjectTree : THTMLObjectTree Read FObjectTree Write SetObjectTree;
    property DefaultInspector : THTMLObjectInspector Read FInspector Write SetInspector;
    Property HandleObjectSelection : Boolean Read FHandleObjectSelection Write SetHandleObjectSelection;
    property LogAPICalls : Boolean read FLogAPICalls write SetLogAPICalls;
  end;

implementation

uses rtti;

type
  TGetObjectProperties = function(aInspectorID : TInspectorID; aObjectID : TObjectID; aFlags : Longint) : Longint;

{ TWasmObjectInspectorApi }

procedure TWasmObjectInspectorApi.SetInspector(AValue: THTMLObjectInspector);
begin
  if FInspector=AValue then Exit;
  FInspector:=AValue;
  if assigned(FInspector) then
    FInspector.Clear;
end;

procedure TWasmObjectInspectorApi.SetLogAPICalls(AValue: Boolean);
begin
  if FLogAPICalls=AValue then Exit;
  FLogAPICalls:=AValue;
end;

procedure TWasmObjectInspectorApi.SetObjectTree(AValue: THTMLObjectTree);
begin
  if FObjectTree=AValue then Exit;
  FObjectTree:=AValue;
  if assigned(FObjectTree) then
    FObjectTree.Clear;
  if FHandleObjectSelection then
    HookObjectTree;
end;

procedure TWasmObjectInspectorApi.Logcall(const aMsg: string);
begin
  {$IFNDEF NOLOGAPICALLS}
  Writeln(aMsg);
  {$ENDIF}
end;

procedure TWasmObjectInspectorApi.LogCall(const aFmt: string; aArgs: array of const);
begin
  {$IFNDEF NOLOGAPICALLS}
  Writeln(Format(aFmt,aArgs));
  {$ENDIF}
end;

function TWasmObjectInspectorApi.GetTree(aInspectorID: TInspectorID): THTMLObjectTree;
begin
  if aInspectorID=0 then
    Result:=DefaultObjectTree
  else
    Result:=nil;
end;

function TWasmObjectInspectorApi.GetInspector(aInspectorID: TInspectorID): THTMLObjectInspector;
begin
  if aInspectorID=0 then
    Result:=DefaultInspector
  else
    Result:=nil;
end;

procedure TWasmObjectInspectorApi.RaiseOILastError(const aOperation : String);

var
  S : String;

begin
  S:='Operation '+aOperation+' failed';
  // Todo, get error
  Raise EWasmOI.Create(S);
end;

procedure TWasmObjectInspectorApi.DoSelectObject(Sender: TObject; aObjectId: Integer);
begin
  GetObjectProperties(aObjectID);
end;

procedure TWasmObjectInspectorApi.SetHandleObjectSelection(AValue: Boolean);
begin
  if FHandleObjectSelection=AValue then Exit;
  FHandleObjectSelection:=AValue;
  if FHandleObjectSelection then
    HookObjectTree
  else
    UnhookObjectTree;
end;

procedure TWasmObjectInspectorApi.GetObjectProperties(aObjectID: Integer);

var
  Proc : TGetObjectProperties;
begin
  Proc:=TGetObjectProperties(InstanceExports['wasm_oi_get_object_properties']);
  if Not Assigned(Proc) then
    Raise EWasmOI.Create('No wasm_oi_get_object_properties entry point');
  if not Proc(0,aObjectID,WASM_SENDPROPERTYFLAG_ALLVISIBILITIES)=WASMOI_SUCCESS then
    RaiseOILastError('GetObjectProperties');
end;


constructor TWasmObjectInspectorApi.Create(aEnv: TPas2JSWASIEnvironment);
begin
  inherited Create(aEnv);
  FObjectTree:=Nil;
  FInspector:=Nil;
end;

function TWasmObjectInspectorApi.InspectorAllocate(aID: TWasmPointer): TWasmOIResult;

var
  v : TJSDataView;

begin
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.InspectorAllocate([%x])',[aID]);
    end;
  {$ENDIF}
   Result:=WASMOI_NOT_IMPLEMENTED;
{  v:=getModuleMemoryDataView;
  v.setInt32(aID,0,Env.IsLittleEndian);
  }
end;

function TWasmObjectInspectorApi.InspectorDeAllocate(aID: TInspectorID): TWasmOIResult;

var
  v : TJSDataView;

begin
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.InspectorDeAllocate(%d)',[aID]);
    end;
  {$ENDIF}
   Result:=WASMOI_NOT_IMPLEMENTED;
{  v:=getModuleMemoryDataView;
  v.setInt32(aID,0,Env.IsLittleEndian);
  }
end;

function TWasmObjectInspectorApi.InspectorSetCaption(aInspectorID: TInspectorID; aCaption: TWasmPointer; aCaptionLen: Longint
  ): TWasmOIResult;

var
  V : TJSDataView;
  OI : THTMLObjectInspector;
  lCaption : String;

begin
  V:=getModuleMemoryDataView;
  lCaption:=Env.GetUTF8StringFromMem(aCaption,aCaptionLen);
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.InspectorSetCaption(%d,"%s")',[aInspectorID,lCaption]);
    end;
  {$ENDIF}
  OI:=GetInspector(aInspectorID);
  if Not Assigned(OI) then
    Result:=WASMOI_NO_INSPECTOR
  else
    begin
    Result:=WASMOI_SUCCESS;
    OI.Caption:=lCaption;
    end;
end;



function TWasmObjectInspectorApi.TreeClear(aInspectorID: TInspectorID): TWasmOIResult;

var
  T : THTMLObjectTree;

begin
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.TreeClear(%d)',[aInspectorID]);
    end;
  {$ENDIF}
  T:=GetTree(aInspectorID);
  if T=Nil then
    Result:=WASMOI_NO_INSPECTOR
  else
    begin
    T.Clear;
    Result:=WASMOI_SUCCESS;
    end;
end;

procedure TWasmObjectInspectorApi.HookObjectTree;
begin
  if not Assigned(FObjectTree) then
    Exit;
  FObjectTree.OnObjectSelected:=@DoSelectObject;
end;

procedure TWasmObjectInspectorApi.UnhookObjectTree;
begin
  if not Assigned(FObjectTree) then
    Exit;
  FObjectTree.OnObjectSelected:=Nil;
end;

function TWasmObjectInspectorApi.InspectorClear(aInspectorID: TInspectorID): TWasmOIResult;

var
  OI : THTMLObjectInspector;


begin
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.InspectorClear(%d)',[aInspectorID]);
    end;
  {$ENDIF}
  OI:=GetInspector(aInspectorID);
  if Not Assigned(OI) then
    Result:=WASMOI_NO_INSPECTOR
  else
    begin
    Result:=WASMOI_SUCCESS;
    OI.Clear;
    end;
end;

function TWasmObjectInspectorApi.TreeSetCaption(aInspectorID: TInspectorID; aCaption: TWasmPointer; aCaptionLen: Longint
  ): TWasmOIResult;
var
  V : TJSDataView;
  T : THTMLObjectTree;
  lCaption : String;

begin
  V:=getModuleMemoryDataView;
  lCaption:=Env.GetUTF8StringFromMem(aCaption,aCaptionLen);
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.InspectorSetCaption(%d,"%s")',[aInspectorID,lCaption]);
    end;
  {$ENDIF}
  T:=GetTree(aInspectorID);
  if Not Assigned(T) then
    Result:=WASMOI_NO_INSPECTOR
  else
    begin
    Result:=WASMOI_SUCCESS;
    T.Caption:=lCaption;
    end;
end;

function TWasmObjectInspectorApi.InspectorAddProperty(aInspectorID: TInspectorID; PropertyData : TWasmPointer): TWasmOIResult;


  function GetElement(V : TJSDataView; aOffset : Longint) : Longint;
  begin
    Result:=V.getInt32(PropertyData+(aOffset*4),Env.IsLittleEndian);
  end;

  function GetString(V : TJSDataView; aNameOffset,aNameLenOffset : Longint) : string;

  var
    O,L : Longint;

  begin
    O:=GetElement(v,aNameOffset);
    L:=GetElement(v,aNameLenOffset);
    Result:=env.GetUTF8StringFromMem(O,L);
  end;


var
  PropertyKind : TNativeTypeKind;
  PropertyFlags : Longint;
  PropDataFlags : TPropDataFlags;
  V : TJSDataView;
  OI : THTMLObjectInspector;
  PropData : TOIPropData;

begin
  V:=getModuleMemoryDataView;

  PropData.ObjectID:=GetElement(V,WASM_PROPERTY_OBJECT_ID);
  PropertyKind:=TNativeTypeKind(GetElement(V,WASM_PROPERTY_KIND));
  PropertyFlags:=GetElement(V,WASM_PROPERTY_FLAGS);
  PropData.Index:=GetElement(V,WASM_PROPERTY_IDX);
  PropData.Visibility:=TMemberVisibility(GetElement(V,WASM_PROPERTY_VISIBILITY));
  PropData.Name:=GetString(V,WASM_PROPERTY_NAME,WASM_PROPERTY_NAME_LEN);
  PropData.Value:=GetString(V,WASM_PROPERTY_VALUE,WASM_PROPERTY_VALUE_LEN);
  PropData.ValueObjectID:=GetElement(V,WASM_PROPERTY_PROPERTYOBJECTID);
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.InspectorAddProperty(%d,%d,%d,%s,%s,"%s","%s",%d)',[
       aInspectorID,
       PropData.ObjectID,
       PropData.Index,
       GetEnumName(TypeInfo(TMemberVisibility),Ord(PropData.Visibility)),
       GetEnumName(TypeInfo(TNativeTypeKind),Ord(PropertyKind)),
       PropData.Name,
       PropData.Value,
       PropertyFlags]);
    end;
  {$ENDIF}
  OI:=GetInspector(aInspectorID);
  if Not Assigned(OI) then
    Result:=WASMOI_NO_INSPECTOR
  else
    begin
    Result:=WASMOI_SUCCESS;
    PropData.Flags:=[];
    if (PropertyFlags and WASM_PROPERTYFLAGS_NOVALUE)<>0 then
      Include(PropData.Flags,pdfNoValue);
    if (PropertyFlags and WASM_PROPERTYFLAGS_ERROR)<>0 then
      Include(PropData.Flags,pdfError);
    PropData.Kind:=GetPlatformTypeKind(PropertyKind);
    OI.ObjectID:=PropData.ObjectID;
    OI.AddProperty(Propdata);
    end;
end;

function TWasmObjectInspectorApi.TreeAddObject(aInspectorID: TInspectorID; ObjectData : PObjectData): TWasmOIResult;


  function GetElement(V : TJSDataView; aOffset : Longint) : Longint;
  begin
    Result:=V.getInt32(ObjectData+(aOffset*4),Env.IsLittleEndian);
  end;

  function GetString(V : TJSDataView; aNameOffset,aNameLenOffset : Longint) : string;

  var
    O,L : Longint;

  begin
    O:=GetElement(v,aNameOffset);
    L:=GetElement(v,aNameLenOffset);
    Result:=env.GetUTF8StringFromMem(O,L);
  end;

var
  T : THTMLObjectTree;
  lClassName,lCaption : String;
  lObjectID,
  lParentID : TObjectID;
  lFLags : Longint;
  V : TJSDataView;

begin
  V:=getModuleMemoryDataView;
  lParentID:=GetElement(V,WASM_OBJECT_PARENTID);
  lObjectID:=GetElement(V,WASM_OBJECT_ID);
  lFlags:=GetElement(V,WASM_OBJECT_ID);
  lClassName:=GetString(V,WASM_OBJECT_CLASSNAME,WASM_OBJECT_CLASSNAME_LEN);
  lCaption:=GetString(V,WASM_OBJECT_CAPTION,WASM_OBJECT_CAPTION_LEN);
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    begin
    LogCall('OI.TreeAddObject(%d,%d,%d,%d,"%s","%s")',[
       aInspectorID,
       lParentId,
       lObjectID,
       lFlags,
       lClassName,
       lCaption
    ]);
    end;
  {$ENDIF}
  T:=GetTree(aInspectorID);
  if T=Nil then
    Result:=WASMOI_NO_INSPECTOR
  else
    begin
    Result:=WASMOI_SUCCESS;
    T.AddObject(lParentID,lObjectID,lClassName,lCaption);
    end;
end;


procedure TWasmObjectInspectorApi.FillImportObject(aObject: TJSObject);
begin
  aObject[call_allocate]:=@InspectorAllocate;
  aObject[call_deallocate]:=@InspectorDeAllocate;
  aObject[call_tree_set_caption]:=@TreeSetCaption;
  aObject[call_tree_clear]:=@TreeClear;
  aObject[call_tree_add_object]:=@TreeAddObject;
  aObject[call_inspector_clear]:=@InspectorClear;
  aObject[call_inspector_add_property]:=@InspectorAddProperty;
  aObject[call_inspector_set_caption]:=@InspectorSetCaption;
end;

function TWasmObjectInspectorApi.ImportName: String;
begin
  Result:=InspectorModuleName;
end;

end.

