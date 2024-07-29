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
  TMemberVisibilities = Set of TMemberVisibility;

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

  TOIOption = (ooHidePropertiesWithoutValue,ooShowCaption,ooShowConfigPanel);
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
    FPropertyVisibilities: TMemberVisibilities;
    FSuffix: String;
    FVisibleColumns: TOIColumns;
    FObjectID: integer;
    FParentElement : TJSHTMLElement;
    FTableElement : TJSHTMLTableElement;
    FCaptionElement : TJSHTMLElement;
    FConfigPanel : TJSHTMLElement;
    function AppendEl(aParent: TJSHTMLElement; aTag: String; const aID: String; const aInnerText: String=''): TJSHTMLElement;
    function AppendSpan(aParent: TJSHTMLElement; const aInnerText: String=''): TJSHTMLElement;
    function CreateEl(aTag: String; const aID: String; const aInnerText: String=''): TJSHTMLElement;
    function GetParentElement: TJSHTMLElement;
    function GetParentElementID: String;
    procedure RenderCaption(aEl: TJSHTMLElement);
    procedure SetBorder(AValue: Boolean);
    procedure SetCaption(AValue: String);
    procedure SetOptions(AValue: TOIOptions);
    procedure SetPropertyVisibilities(AValue: TMemberVisibilities);
    procedure SetVisibleColumns(AValue: TOIColumns);
    procedure SetParentElementID(AValue: String);
    procedure ToggleConfig(aEvent: TJSEvent);
  protected
    procedure DisplayChanged;
    procedure Refresh;
    function CreateConfigPanel() : TJSHTMLElement; virtual;
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
    Property Suffix : String Read FSuffix Write FSuffix;
  Published
    Property ObjectID : integer Read FObjectID Write SetObjectID;
    Property ParentElementID : String Read GetParentElementID Write SetParentElementID;
    Property Border : Boolean Read FBorder Write SetBorder;
    property VisibleColumns : TOIColumns read FVisibleColumns write SetVisibleColumns;
    property PropertyVisibilities : TMemberVisibilities Read FPropertyVisibilities Write SetPropertyVisibilities;
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
  El.classList.toggle('ot-expanded');
  El.classList.toggle('ot-collapsed');
end;

procedure THTMLTreeBuilder.HandleItemSelect(Event : TJSEvent);

var
  El : TJSHTMLElement;
  lList : TJSNodeList;
  lSelectID,I : integer;

begin
  // List element
  El:=TJSHTMLElement(event.targetElement.parentElement);
  lList:=FRootElement.querySelectorAll('li.ot-selected');
  for I:=0 to lList.length-1 do
    if El<>lList.item(I) then
      TJSHtmlElement(lList.item(I)).classList.remove('ot-selected');
  El.classList.add('ot-selected');
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
      FRootElement.className:='ot-tree-nested';
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
      aParent.ClassList.remove('ot-collapsed');
      aParent.ClassList.add('ot-expanded');
      end;
    end;
  List:=TJSHTMLELement(aParent.querySelector('ul.ot-tree-nested'));
  if List=Nil then
    begin
    List:=TJSHTMLElement(Document.createElement('ul'));
    List.className:='ot-tree-nested';
    aParent.appendChild(List);
    end;
  Item:=TJSHTMLElement(Document.createElement('li'));
  Item.className:='ot-tree-item ot-collapsed';
  Item.dataset['objectId']:=IntToStr(aID);
  Span:=TJSHTMLElement(Document.createElement('span'));
  Span.InnerText:=aCaption;
  Span.className:='ot-tree-item-caption' ;
  Span.addEventListener('dblclick',@HandleItemCollapse);
  Span.addEventListener('click',@HandleItemSelect);
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
  DC.className:='ot-caption';
  aParent.AppendChild(DC);
  FCaptionElement:=DC;
  if Not (otShowCaption in Options) then
    DC.classList.Add('ot-hidden');
  RenderCaption(DC);
  DT:=TJSHTMLElement(document.createElement('div'));
  DT.className:='ot-tree';
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

procedure THTMLObjectInspector.SetPropertyVisibilities(AValue: TMemberVisibilities);
begin
  if FPropertyVisibilities=AValue then Exit;
  FPropertyVisibilities:=AValue;
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

function THTMLObjectInspector.AppendSpan(aParent: TJSHTMLElement; const aInnerText: String): TJSHTMLElement;
begin
  Result:=CreateEl('span','',aInnerText);
  aParent.AppendChild(Result);
end;

function THTMLObjectInspector.CreateEl(aTag: String; const aID: String; const aInnerText: String): TJSHTMLElement;

begin
  Result:=TJSHTMLElement(Document.CreateElement(aTag));
  if aID<>'' then
    Result.id:=aID;
  if aInnerText<>'' then
    Result.InnerText:=aInnerText;
end;

function THTMLObjectInspector.AppendEl(aParent: TJSHTMLElement; aTag: String; const aID: String; const aInnerText: String
  ): TJSHTMLElement;

begin
  Result:=CreateEl(aTag,aID,aInnerText);
  aParent.AppendChild(Result);
end;

function THTMLObjectInspector.CreateConfigPanel(): TJSHTMLElement;

  Function AppendCheckbox(aParent : TJSHTMLElement; aName,aLabel : String; aOrd : Integer; isChecked: Boolean) : TJSHTMLInputElement;

  var
    Tmp : TJSHTMLElement;

  begin
    Tmp:=AppendSpan(aParent,'');
    Tmp.ClassName:='oi-checkbox-row';
    Result:=TJSHTMLInputElement(AppendEl(Tmp,'input','cb'+aName+Suffix));
    Result.Checked:=isChecked;
    Result._type:='checkbox';
    Result.dataset['ord']:=IntToStr(aOrd);
    Tmp:=AppendEl(Tmp,'label','',aLabel);
    Tmp['for']:='cb'+aName;
  end;

var
  Tmp,CBDiv,CBhead,CBCol,cbRow : TJSHTMLElement;
  CB : TJSHTMLInputElement;
  Vis : TMemberVisibility;

begin
  Result:=CreateEl('div','oiConfig'+Suffix);
  Result.classList.add('oi-config-panel-closed');

  appendEl(Result,'h5','Use the checkboxes to show/hide fields in the table:');
  CBDiv:=appendEl(Result,'div','');
  CBDiv.ClassName:='oi-checkbox-div';
  // Col 1
  CBCol:=appendEl(CBDiv,'div','');
  CBCol.ClassName:='oi-checkbox-col';
  CBHead:=AppendEl(CBCol,'div','');
  CBHead.ClassName:='oi-checkbox-header';
  AppendSpan(CBHead,'Columns');
  AppendCheckBox(CBCol,'PropertyName','Property name',Ord(ocName),ocName in VisibleColumns);
  AppendCheckBox(CBCol,'PropertyVisibility','Visibility',Ord(ocVisibility),ocVisibility in VisibleColumns);
  AppendCheckBox(CBCol,'PropertyKind','Kind',Ord(ocKind),ocKind in VisibleColumns);
  AppendCheckBox(CBCol,'PropertyValue','Value',Ord(ocValue),ocValue in VisibleColumns);
  // Col 2
  CBCol:=appendEl(CBDiv,'div','');
  CBCol.ClassName:='oi-checkbox-col';
  CBHead:=AppendEl(CBCol,'div','');
  CBHead.ClassName:='oi-checkbox-header';
  AppendSpan(CBHead,'Visibilities');
  For Vis in TMemberVisibility do
    AppendCheckBox(CBCol,'PropVis'+VisibilityNames[Vis],VisibilityNames[Vis],Ord(Vis),Vis in PropertyVisibilities);
  Tmp:=AppendEl(Result,'div','');
  Tmp.classname:='oi-checkbox-last';
  AppendCheckBox(Tmp,'noShowNoValue','Hide properties without value',0,ooHidePropertiesWithoutValue in Options);


(*

    <div class="checkbox-last">
      <span class="width-300">
        <input
          type="checkbox"
          id="colPublishedCheckbox"
          name="cbxPublished"
          unchecked
        />
        <label for="cbxPublished">Hide properties without value</label>
      </span>
    </div>
  </div>

*)
end;

procedure THTMLObjectInspector.RenderCaption(aEl: TJSHTMLElement);

begin
  aEl.innerText:=Caption;
end;

procedure THTMLObjectInspector.ToggleConfig(aEvent : TJSEvent);

begin
  if not FConfigPanel.classList.toggle('oi-config-panel-open') then
    begin
    aEvent.TargetElement.innerHTML:='&#x2699;';
    FConfigPanel.classList.add('oi-config-panel-closed');
    end
  else
    begin
    aEvent.TargetElement.innerHTML:='&#x25b4;';
    FConfigPanel.classList.remove('oi-config-panel-closed');
    end
end;

function THTMLObjectInspector.CreateTable(aParent : TJSHTMLElement): TJSHTMLTableElement;


var
  CS,DP,DC,P,R,C : TJSHTMLElement;

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
    DP.className:='oi-wrapper';
    aParent.AppendChild(DP);
    DC:=TJSHTMLElement(Document.createElement('div'));
    DC.className:='oi-caption';
    CS:=TJSHTMLElement(Document.createElement('span'));
    DC.AppendChild(CS);
    RenderCaption(CS);
    DP.AppendChild(DC);
    FCaptionElement:=DC;
    FConfigPanel:=nil;
    if ooShowConfigPanel in Options then
      begin
      CS:=TJSHTMLElement(Document.createElement('span'));
      CS.innerHTML:='&#x2699;';
      CS.className:='oi-icon-btn';
      CS.addEventListener('click',@ToggleConfig);
      DC.AppendChild(CS);
      FConfigPanel:=CreateConfigPanel;
      DP.appendChild(FConfigPanel);
      end
    end
  else
    begin
    FConfigPanel:=nil;
    FCaptionElement:=DC;
    DP:=aParent;
    end;

  Result:=TJSHTMLTableElement(Document.createElement('TABLE'));
  Result.ClassName:='oi-table';
  P:=TJSHTMLTableElement(Document.createElement('THEAD'));
  Result.appendChild(P);
  R:=TJSHTMLTableRowElement(Document.createElement('TR'));
  if ocName in VisibleColumns then
    addHeader('Property Name','oi-property-name');
  if ocVisibility in VisibleColumns then
    addHeader('Visibility','oi-property-visibility');
  if ocKind in VisibleColumns then
    addHeader('Kind','oi-property-kind');
  if ocValue in VisibleColumns then
    addHeader('Value','oi-property-value');
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
  Options:=[ooShowCaption,ooShowConfigPanel,ooHidePropertiesWithoutValue];
  VisibleColumns:=[ocName,ocValue];
  PropertyVisibilities:=[Low(TMemberVisibility)..High(TMemberVisibility)];
end;

destructor THTMLObjectInspector.destroy;
begin
  Clear;
  inherited destroy;
end;

end.

