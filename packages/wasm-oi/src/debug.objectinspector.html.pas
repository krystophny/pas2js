{
    This file is part of the Pas2JS run time library.
    Copyright (c) 2024 by the Pas2JS development team.

    API to implement an object inspector in HTML
    
    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit debug.objectinspector.html;

{$mode ObjFPC}

interface

uses
  typinfo, Classes, SysUtils, Web, rtti;

Type
  EHTMLTreeBuilder = class(Exception);

  { THTMLTreeBuilder }
  TObjectSelectedEvent = procedure(Sender : TObject; aObjectId : Integer) of object;

  THTMLTreeBuilder = class(TObject)
  private
    FOnObjectSelect: TObjectSelectedEvent;
    FParentElement: TJSHTMLElement;
    FRootElement : TJSHTMLElement;
    FStartCollapsed: Boolean;
    procedure HandleItemCollapse(Event: TJSEvent);
    procedure HandleItemSelect(Event: TJSEvent);
    procedure SetParentElement(AValue: TJSHTMLElement);
  Public
    Function AddItem(aParent : TJSHTMLElement; aCaption : String; aID : Integer) : TJSHTMLElement;
    Function FindObjectItem(aID : Integer) : TJSHTMLElement;
    procedure Clear;
    Property ParentElement : TJSHTMLElement Read FParentElement Write SetParentElement;
    Property OnObjectSelected : TObjectSelectedEvent Read FOnObjectSelect Write FOnObjectSelect;
    Property StartCollapsed : Boolean Read FStartCollapsed Write FStartCollapsed;
  end;

  { THTMLObjectTree }
  TOTOption = (otShowCaption,otStartCollapsed);
  TOTOptions = set of TOTOption;

  THTMLObjectTree = class(TComponent)
  private
    FBuilder: THTMLTreeBuilder;
    FCaption: String;
    FOptions: TOTOptions;
    FParentElement,
    FCaptionElement : TJSHTMLElement;
    function GetOnObjectSelected: TObjectSelectedEvent;
    function GetParentElement: TJSHTMLElement;
    function GetParentElementID: String;
    procedure SetCaption(AValue: String);
    procedure SetOnObjectSelected(AValue: TObjectSelectedEvent);
    procedure SetOptions(AValue: TOTOptions);
    procedure SetParentElement(AValue: TJSHTMLElement);
    procedure SetParentElementID(AValue: String);
  Protected
    function BuildWrapper(aParent: TJSHTMLElement): TJSHTMLElement;
    procedure RenderCaption(aEl: TJSHTMLELement);
  Public
    Constructor Create(aOwner : TComponent); override;
    Destructor Destroy; override;
    Procedure AddObject(aID : integer; const aClassName,aCaption : String); overload;
    Procedure AddObject(AParentID,aID : integer; const aClassName,aCaption : String); overload;
    Procedure Clear;
    Property ParentElement : TJSHTMLElement Read GetParentElement Write SetParentElement;
  Published
    Property ParentElementID : String Read GetParentElementID Write SetParentElementID;
    Property OnObjectSelected : TObjectSelectedEvent Read GetOnObjectSelected Write SetOnObjectSelected;
    Property Caption : String Read FCaption Write SetCaption;
    Property Options : TOTOptions Read FOptions Write SetOptions;
  end;

  TPropDataFlag = (pdfNoValue,pdfError);
  TPropDataFlags = Set of TPropDataFlag;
  TOIPropData = record
    ObjectID : Longint;
    Index : Integer;
    Visibility : TMembervisibility;
    Kind : TTypeKind;
    Flags : TPropDataFlags;
    Name : String;
    Value : String;
    ValueObjectID : Longint;
  end;

  TOIColumn = (ocName,ocValue,ocKind,ocVisibility);
  TOIColumns = set of TOIColumn;

  TOIOption = (ooHidePropertiesWithoutValue,ooShowCaption);
  TOIOptions = set of TOIOption;

  { THTMLObjectInspector }

  TBeforeAddPropertyEvent = procedure (Sender : TObject; aData : TOIPropData; var aAllow : Boolean) of object;
  TAfterAddPropertyEvent = procedure (Sender : TObject; aData : TOIPropData) of object;

  THTMLObjectInspector = class(TComponent)
  private
    FAfterAddProperty: TAfterAddPropertyEvent;
    FBeforeAddProperty: TBeforeAddPropertyEvent;
    FBorder: Boolean;
    FCaption: String;
    FOnRefresh: TNotifyEvent;
    FOptions: TOIOptions;
    FVisibleColumns: TOIColumns;
    FObjectID: integer;
    FParentElement : TJSHTMLElement;
    FTableElement : TJSHTMLTableElement;
    FCaptionElement : TJSHTMLElement;
    function GetParentElement: TJSHTMLElement;
    function GetParentElementID: String;
    procedure RenderCaption(aEl: TJSHTMLElement);
    procedure SetBorder(AValue: Boolean);
    procedure SetCaption(AValue: String);
    procedure SetOptions(AValue: TOIOptions);
    procedure SetVisibleColumns(AValue: TOIColumns);
    procedure SetParentElementID(AValue: String);
  protected
    procedure DisplayChanged;
    procedure Refresh;
    function CreateTable(aParent : TJSHTMLElement) : TJSHTMLTableElement; virtual;
    procedure SetObjectID(AValue: integer); virtual;
    procedure SetParentElement(AValue: TJSHTMLElement);virtual;
    function CreateKindCell(aPropData: TOIPropData; const aKindName: String): TJSHTMLTableCellElement; virtual;
    function CreateNameCell(aPropData: TOIPropData): TJSHTMLTableCellElement; virtual;
    function CreateValueCell(aPropData: TOIPropData; const aKindName: string): TJSHTMLTableCellElement; virtual;
    function CreateVisibilityCell(aPropData: TOIPropData): TJSHTMLTableCellElement; virtual;
    procedure DoAddProperty(aPropData: TOIPropData); virtual;
  Public
    constructor Create(aOwner : TComponent); override;
    destructor destroy; override;
    procedure clear;
    procedure AddProperty(aIndex : Integer; aVisibility : TMemberVisibility; aKind : TTypeKind; aFlags : TPropDataFlags; const aName,aValue : String);
    procedure AddProperty(aPropData: TOIPropData);
    Property ParentElement : TJSHTMLElement Read GetParentElement Write SetParentElement;
  Published
    Property ObjectID : integer Read FObjectID Write SetObjectID;
    Property ParentElementID : String Read GetParentElementID Write SetParentElementID;
    Property Border : Boolean Read FBorder Write SetBorder;
    property VisibleColumns : TOIColumns read FVisibleColumns write SetVisibleColumns;
    Property Options : TOIOptions Read FOptions Write SetOptions;
    property BeforeAddProperty : TBeforeAddPropertyEvent Read FBeforeAddProperty Write FBeforeAddProperty;
    property AfterAddProperty : TAfterAddPropertyEvent Read FAfterAddProperty Write FAfterAddProperty;
    property OnRefresh : TNotifyEvent Read FOnRefresh write FOnRefresh;
    Property Caption : String Read FCaption Write SetCaption;
  end;


implementation

const
  VisibilityNames : Array[TMemberVisibility] of string = ('Private','Protected','Public','Published');


{ THTMLTreeBuilder }

procedure THTMLTreeBuilder.SetParentElement(AValue: TJSHTMLElement);
begin
  if FParentElement=AValue then Exit;
  FParentElement:=AValue;
  FParentElement.innerHTML:='';
  FRootElement:=nil;
end;

procedure THTMLTreeBuilder.HandleItemCollapse(Event : TJSEvent);

var
  El : TJSHTMLElement;

begin
  El:=TJSHTMLElement(event.targetElement.parentElement);
  El.classList.toggle('expanded');
  El.classList.toggle('collapsed');
end;

procedure THTMLTreeBuilder.HandleItemSelect(Event : TJSEvent);

var
  El : TJSHTMLElement;
  lList : TJSNodeList;
  lSelectID,I : integer;

begin
  // List element
  El:=TJSHTMLElement(event.targetElement.parentElement);
  lList:=FRootElement.querySelectorAll('li.selected');
  for I:=0 to lList.length-1 do
    if El<>lList.item(I) then
      TJSHtmlElement(lList.item(I)).classList.remove('selected');
  El.classList.add('selected');
  if Assigned(FOnObjectSelect) then
    begin
    lSelectID:=StrToIntDef(el.dataset['objectId'],-1);
    if (lSelectID<>-1) then
      FOnObjectSelect(Self,lSelectID);
    end;
end;



function THTMLTreeBuilder.AddItem(aParent: TJSHTMLElement; aCaption: String; aID: Integer): TJSHTMLElement;

var
  Span,Item,list : TJSHTMLELement;

begin
  if aParent=Nil then
    begin
    if FRootElement=Nil then
      begin
      FRootElement:=TJSHTMLElement(Document.createElement('ul'));
      FRootElement.className:='tree-nested';
      FParentElement.appendChild(FRootElement);
      end;
    aParent:=FParentElement;
    end
  else
    begin
    if Not SameText(aParent.tagName,'li') then
      Raise EHTMLTreeBuilder.CreateFmt('Invalid parent item type: %s',[aParent.tagName]);
    if Not StartCollapsed then
      begin
      aParent.ClassList.remove('collapsed');
      aParent.ClassList.add('expanded');
      end;
    end;
  List:=TJSHTMLELement(aParent.querySelector('ul.tree-nested'));
  if List=Nil then
    begin
    List:=TJSHTMLElement(Document.createElement('ul'));
    List.className:='tree-nested';
    aParent.appendChild(List);
    end;
  Item:=TJSHTMLElement(Document.createElement('li'));
  Item.className:='tree-item collapsed';
  Item.dataset['objectId']:=IntToStr(aID);
  Span:=TJSHTMLElement(Document.createElement('span'));
  Span.InnerText:=aCaption;
  Span.className:='tree-item-caption' ;
  Span.addEventListener('click',@HandleItemCollapse);
  Span.addEventListener('dblclick',@HandleItemSelect);
  Item.appendChild(Span);
  List.AppendChild(Item);
  Result:=Item;
end;

function THTMLTreeBuilder.FindObjectItem(aID: Integer): TJSHTMLElement;
begin
  Result:=TJSHTMLElement(ParentElement.querySelector('li[data-object-id="'+IntToStr(aID)+'"]'));
end;

procedure THTMLTreeBuilder.Clear;
begin
  if Assigned(FParentElement) then
    FParentElement.innerHTML:='';
  FRootElement:=Nil;
end;

{ THTMLObjectTree }

function THTMLObjectTree.GetParentElement: TJSHTMLElement;
begin
  Result:=FBuilder.ParentElement;
end;


function THTMLObjectTree.GetOnObjectSelected: TObjectSelectedEvent;
begin
  Result:=FBuilder.OnObjectSelected
end;

function THTMLObjectTree.GetParentElementID: String;
begin
  if Assigned(ParentElement) then
    Result:=ParentElement.id
  else
    Result:='';
end;

procedure THTMLObjectTree.SetCaption(AValue: String);
begin
  if FCaption=AValue then Exit;
  FCaption:=AValue;
  if Assigned(FCaption) then
    RenderCaption(FCaptionElement);
end;

procedure THTMLObjectTree.SetOnObjectSelected(AValue: TObjectSelectedEvent);
begin
  FBuilder.OnObjectSelected:=aValue;
end;

procedure THTMLObjectTree.SetOptions(AValue: TOTOptions);
begin
  if FOptions=AValue then Exit;
  FOptions:=AValue;
  FBuilder.StartCollapsed:=(otStartCollapsed in FOptions);
end;

procedure THTMLObjectTree.RenderCaption(aEl : TJSHTMLELement);

begin
  aEL.InnerText:=Caption;
end;

function THTMLObjectTree.BuildWrapper(aParent : TJSHTMLElement) : TJSHTMLElement;

var
  DW,DC,DT : TJSHTMLElement;

begin
  aParent.InnerHTML:='';
  DC:=TJSHTMLElement(document.createElement('div'));
  DC.className:='otCaption';
  aParent.AppendChild(DC);
  FCaptionElement:=DC;
  if Not (otShowCaption in Options) then
    DC.classList.Add('otHidden');
  RenderCaption(DC);
  DT:=TJSHTMLElement(document.createElement('div'));
  DT.className:='otTree';
  aParent.AppendChild(DT);
  Result:=DT;
end;

procedure THTMLObjectTree.SetParentElement(AValue: TJSHTMLElement);
begin
  FParentElement:=aValue;
  FBuilder.ParentElement:=BuildWrapper(FParentElement);
end;

procedure THTMLObjectTree.SetParentElementID(AValue: String);

var
  lParent : TJSHTMlelement;

begin
  lParent:=TJSHTMlelement(Document.getElementById(aValue));
  if lParent=Nil then
    Raise EHTMLTreeBuilder.CreateFmt('Unknown element id: "%s"',[aValue]);
  ParentElement:=lParent;
end;

constructor THTMLObjectTree.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FBuilder:=THTMLTreeBuilder.Create;
  FOptions:=[otShowCaption];
  FCaption:='Object Tree';
end;

destructor THTMLObjectTree.Destroy;
begin
  FreeAndNil(FBuilder);
  Inherited;
end;

procedure THTMLObjectTree.AddObject(aID: integer; const aClassName, aCaption: String);

begin
  AddObject(0,aID,aClassName,aCaption);
end;

procedure THTMLObjectTree.AddObject(AParentID, aID: integer; const aClassName, aCaption: String);

var
  lParent : TJSHTMLELement;

begin
  if aParentID<>0 then
    lParent:=FBuilder.FindObjectItem(aParentID)
  else
    lParent:=Nil;
  FBuilder.AddItem(lParent,aCaption,aID);
end;

procedure THTMLObjectTree.Clear;
begin
  FBuilder.Clear;
end;

{ THTMLObjectInspector }

function THTMLObjectInspector.GetParentElement: TJSHTMLElement;
begin
  Result:=FParentElement;
end;

function THTMLObjectInspector.GetParentElementID: String;
begin
  if Assigned(FParentElement) then
    Result:=FParentElement.ID
  else
    Result:='';
end;

procedure THTMLObjectInspector.SetBorder(AValue: Boolean);
begin
  if FBorder=AValue then Exit;
  FBorder:=AValue;
  if Assigned(FTableElement) then
    FTableElement.Border:=IntToStr(Ord(aValue));
end;

procedure THTMLObjectInspector.SetCaption(AValue: String);
begin
  if FCaption=AValue then Exit;
  FCaption:=AValue;
  if (ooShowCaption in Options) and Assigned(FCaptionElement) then
    RenderCaption(FCaptionElement);
end;

procedure THTMLObjectInspector.SetOptions(AValue: TOIOptions);
begin
  if FOptions=AValue then Exit;
  FOptions:=AValue;
  DisplayChanged;
end;

procedure THTMLObjectInspector.SetVisibleColumns(AValue: TOIColumns);
begin
  if FVisibleColumns=AValue then Exit;
  FVisibleColumns:=AValue;
  DisplayChanged;
end;

procedure THTMLObjectInspector.SetObjectID(AValue: integer);
begin
  if FObjectID=AValue then Exit;
  FObjectID:=AValue;
  DisplayChanged;
end;

procedure THTMLObjectInspector.SetParentElement(AValue: TJSHTMLElement);
begin
  FParentElement:=aValue;
  DisplayChanged;
end;

procedure THTMLObjectInspector.SetParentElementID(AValue: String);

var
  lParent : TJSHTMlelement;

begin
  lParent:=TJSHTMlelement(Document.getElementById(aValue));
  if lParent=Nil then
    Raise EHTMLTreeBuilder.CreateFmt('Unknown element id: "%s"',[aValue]);
  ParentElement:=lParent;
end;

procedure THTMLObjectInspector.DisplayChanged;
begin
  Clear;
  Refresh;
end;

procedure THTMLObjectInspector.Refresh;
begin
  if Assigned(FOnRefresh) then
    FonRefresh(Self);
end;

Procedure THTMLObjectInspector.RenderCaption(aEl : TJSHTMLElement);

begin
  aEl.innerText:=Caption;
end;

function THTMLObjectInspector.CreateTable(aParent : TJSHTMLElement): TJSHTMLTableElement;


var
  DP,DC,P,R,C : TJSHTMLElement;

  function AddHeader(aText,aClass : string) : TJSHTMLTableCellElement;
  begin
    Result:=TJSHTMLTableCellElement(Document.createElement('TH'));
    Result.InnerText:=aText;
    Result.className:=aClass;
    R.AppendChild(Result);
  end;

begin
  if (ooShowCaption in Options) and (Caption<>'') then
    begin
    DP:=TJSHTMLElement(Document.createElement('div'));
    DP.className:='oiWrapper';
    aParent.AppendChild(DP);
    DC:=TJSHTMLElement(Document.createElement('div'));
    DC.className:='oiCaption';
    RenderCaption(DC);
    DP.AppendChild(DC);
    FCaptionElement:=DC;
    end
  else
    begin
    FCaptionElement:=DC;
    DP:=aParent;
    end;
  Result:=TJSHTMLTableElement(Document.createElement('TABLE'));
  Result.ClassName:='objectInspectorTable';
  P:=TJSHTMLTableElement(Document.createElement('THEAD'));
  Result.appendChild(P);
  R:=TJSHTMLTableRowElement(Document.createElement('TR'));
  if ocName in VisibleColumns then
    addHeader('Property Name','oiPropertyName');
  if ocVisibility in VisibleColumns then
    addHeader('Visibility','oiPropertyVisibility');
  if ocKind in VisibleColumns then
    addHeader('Kind','oiPropertyKind');
  if ocValue in VisibleColumns then
    addHeader('Value','oiPropertyValue');
  P.appendChild(R);
  P:=TJSHTMLTableElement(Document.createElement('TBODY'));
  Result.border:=IntToStr(Ord(Border));
  Result.appendChild(P);
  DP.appendChild(Result);
end;

procedure THTMLObjectInspector.clear;
begin
  if not Assigned(FParentElement) then
    exit;
  FParentElement.innerHTML:='';
  FTableElement:=CreateTable(FParentElement);
end;


procedure THTMLObjectInspector.AddProperty(aIndex: Integer; aVisibility: TMemberVisibility; aKind: TTypeKind; aFlags: TPropDataFlags;
  const aName, aValue: String);

var
  aData : TOIPropData;

begin
  aData.Index:=aIndex;
  aData.Value:=aValue;
  aData.Name:=aName;
  aData.Kind:=aKind;
  aData.Flags:=aFlags;
  aData.Visibility:=aVisibility;
  AddProperty(aData);
end;

function THTMLObjectInspector.CreateNameCell(aPropData : TOIPropData) : TJSHTMLTableCellElement;

begin
  Result:=TJSHTMLTableCellElement(Document.createElement('TD'));
  Result.InnerText:=aPropData.Name;
  Result.className:='oiPropertyName';
end;

function THTMLObjectInspector.CreateKindCell(aPropData : TOIPropData; const aKindName: String) : TJSHTMLTableCellElement;

begin
  Result:=TJSHTMLTableCellElement(Document.createElement('TD'));
  Result.InnerText:=aKindName;
  Result.className:='oiPropertyKind';
end;

function THTMLObjectInspector.CreateVisibilityCell(aPropData : TOIPropData) : TJSHTMLTableCellElement;


begin
  Result:=TJSHTMLTableCellElement(Document.createElement('TD'));
  Result.InnerText:=VisibilityNames[aPropData.Visibility];
  Result.className:='oiPropertyVisibility';
end;

function THTMLObjectInspector.CreateValueCell(aPropData: TOIPropData; const aKindName : string): TJSHTMLTableCellElement;


begin
  Result:=TJSHTMLTableCellElement(Document.createElement('TD'));
  Result.InnerText:=aPropData.Value;
  Result.className:='oiPropertyValue '+aKindName;
end;


procedure THTMLObjectInspector.AddProperty(aPropData : TOIPropData);

var
  allow : Boolean;

begin
  if (ooHidePropertiesWithoutValue in Options) then
    allow:=Not (pdfNoValue in aPropdata.Flags)
  else
    allow:=True;
  if Assigned(BeforeAddProperty) then
    BeforeAddProperty(Self,aPropData,allow);
  if Allow then
    begin
    DoAddProperty(aPropData);
    if Assigned(AfterAddProperty) then
      AfterAddProperty(Self,aPropData);
    end;
end;

procedure THTMLObjectInspector.DoAddProperty(aPropData : TOIPropData);


var
  TN : String;
  PR,CN : TJSHTMLElement;

begin
  TN:=GetEnumName(TypeInfo(TTypeKind),Ord(aPropData.Kind));
  PR:=TJSHTMLTableRowElement(Document.createElement('TR'));
  PR.dataset['propertyIdx']:=IntToStr(aPropData.Index);
  PR.dataset['propertyName']:=aPropData.Name;
  PR.dataset['propertyKind']:=TN;
  PR.dataset['propertyKindOrd']:=IntToStr(Ord(aPropData.Kind));
  if ocName in VisibleColumns then
    begin
    cn:=CreateNameCell(aPropData);
    PR.AppendChild(CN);
    end;
  if ocVisibility in VisibleColumns then
    begin
    cn:=CreateVisibilityCell(aPropData);
    PR.AppendChild(CN);
    end;
  if ocKind in VisibleColumns then
    begin
    cn:=CreateKindCell(aPropData,TN);
    PR.AppendChild(CN);
    end;
  if ocValue in VisibleColumns then
    begin
    cn:=CreateValueCell(aPropData,TN);
    PR.AppendChild(CN);
    end;
  FTableElement.tBodies[0].AppendChild(PR);
end;

constructor THTMLObjectInspector.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  Caption:='Property inspector';
  Options:=[ooShowCaption,ooHidePropertiesWithoutValue];
  VisibleColumns:=[ocName,ocValue];
end;

destructor THTMLObjectInspector.destroy;
begin
  Clear;
  inherited destroy;
end;

end.

