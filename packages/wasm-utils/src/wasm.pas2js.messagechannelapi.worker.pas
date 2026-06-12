{
    This file is part of the Free Component Library

    Webassembly Message channel API - worker implementation
    Copyright (c) 2024 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit wasm.pas2js.messagechannelapi.worker;

{$mode ObjFPC}

interface

uses
  js, SysUtils, wasm.pas2js.messagechannelapi, wasm.messagechannel.shared, weborworker, webworker;

Type
  TWasmWorkerChannel = class(TWasmChannel)
  public
    constructor create(aID: TWasmMessageChannelID);
    procedure SendMessage(Msg: JSValue); override;
  end;

  { TWasmDirectChannel

    A broadcast channel whose name was registered as "direct": instead of a
    cross-tab BroadcastChannel it is backed by a private MessageChannel. We keep
    one port and hand the other to the parent (the page) so the consumer there
    binds it. Transparent to the wasm module, which still allocated a ctBroadcast
    channel and only uses send/listen by id. }
  TWasmDirectChannel = class(TWasmChannel)
  private
    FPort : TJSMessagePort;
  protected
    procedure StartListening; override;
  public
    constructor Create(aID: TWasmMessageChannelID; const aName: string); reintroduce;
    procedure SendMessage(Msg: JSValue); override;
  end;

  TWorkerMessageChannelAPI = Class(TMessageChannelAPI)
  private
    FDirectNames : TJSObject; // used as a string set: FDirectNames[name] = true
  Protected
    function CreateChannel(aType: TWasmChannelType; aID: TWasmMessageChannelID; aName: String): TWasmChannel; override;
  public
    // Register a (broadcast) channel name to be backed by a direct MessagePort.
    // Must be called before the wasm module allocates the channel.
    procedure RegisterDirectChannel(const aName : string);
  end;

implementation

{ TWasmWorkerChannel }

constructor TWasmWorkerChannel.create(aID: TWasmMessageChannelID);
begin
  inherited create(aID,ctWorker);
end;

procedure TWasmWorkerChannel.SendMessage(Msg: JSValue);
begin
  self_.postMessage(Msg);
end;

{ TWasmDirectChannel }

constructor TWasmDirectChannel.Create(aID: TWasmMessageChannelID; const aName: string);
var
  lChannel : TJSMessageChannel;
  lMsg : TJSObject;
begin
  // Logical type stays ctBroadcast: that is what the wasm module requested.
  inherited create(aID, ctBroadcast);
  lChannel := TJSMessageChannel.new;
  FPort := lChannel.port1;
  // Hand the far end up to the parent (the page), tagged with the channel name.
  lMsg := TJSObject.new;
  lMsg[MsgChannelDirectPortMarker] := True;
  lMsg[MsgChannelDirectPortName] := aName;
  lMsg[MsgChannelDirectPortPort] := lChannel.port2;
  self_.postMessage(lMsg, [ lChannel.port2 ]);
end;

procedure TWasmDirectChannel.StartListening;
begin
  FPort.addEventListener('message', @HandleMessage);
  FPort.start;
end;

procedure TWasmDirectChannel.SendMessage(Msg: JSValue);
begin
  FPort.postMessage(Msg);
end;

{ TWorkerMessageChannelAPI }

procedure TWorkerMessageChannelAPI.RegisterDirectChannel(const aName: string);
begin
  if FDirectNames = nil then
    FDirectNames := TJSObject.new;
  FDirectNames[aName] := True;
end;

function TWorkerMessageChannelAPI.CreateChannel(aType: TWasmChannelType; aID: TWasmMessageChannelID; aName: String): TWasmChannel;
begin
  if aType=ctWorker then
    Result:=TWasmWorkerChannel.Create(aID)
  else if (aType=ctBroadcast) and (FDirectNames<>nil) and FDirectNames.hasOwnProperty(aName) then
    Result:=TWasmDirectChannel.Create(aID, aName)
  else
    Result:=inherited CreateChannel(aType, aID, aName);
end;

end.

