{
    This file is part of the Free Component Library

    Webassembly Websocket API - Provide the API to a webassembly module.
    Copyright (c) 2024 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit wasm.pas2js.websocketapi;

{$mode ObjFPC}

{ $DEFINE NOLOGAPICALLS}

interface

uses
  SysUtils, js, wasienv, web,weborworker, wasm.websocket.shared;

Type
  TWasmWebSocketAPI = Class;

  { TWasmWebsocket }

  TWasmWebsocket = class
  private
    FAPI : TWasmWebSocketAPI;
    FWebsocketID : TWasmWebsocketID;
    FWS : TJSWebSocket;
    FUserData: TWasmPointer;
  Public
    Constructor Create(aAPI : TWasmWebSocketAPI; aID : TWasmWebsocketID; aUserData : TWasmPointer;const aURL : String; const aProtocols : String = ''); virtual;
    destructor Destroy; override;
    Procedure Close(aCode : Integer; aReason : String);
    procedure SendText(aData: String); virtual;
    procedure SendBinary(aData: TJSArrayBuffer); virtual;
    procedure HandleClose(Event: TJSEvent); virtual;
    procedure HandleError(Event: TJSEvent); virtual;
    procedure HandleMessage(Event: TJSEvent); virtual;
    procedure HandleOpen(Event: TJSEvent); virtual;
    function ToString : String; override;
    Property UserData : TWasmPointer Read FUserData;
    Property WebsocketID : TWasmWebSocketID Read FWebSocketID;
  end;
  TWasmWebsocketClass = Class of TWasmWebsocket;

  { TWasmWebSocketAPI }
  TWasmWebSocketErrorHandler = Function (aWebsocketID : TWasmWebSocketID; aUserData : TWasmPointer) : TWebsocketCallBackResult;
  TWasmWebSocketMessageHandler = Function (aWebsocketID : TWasmWebSocketID; aUserData : TWasmPointer; aMessageType : TWasmWebSocketMessageType; aMessage : TWasmPointer; aMessageLen : Integer) : TWebsocketCallBackResult;
  TWasmWebSocketOpenHandler = Function (aWebsocketID : TWasmWebSocketID; aUserData : TWasmPointer) : TWebsocketCallBackResult;
  TWasmWebSocketCloseHandler = Function (aWebsocketID : TWasmWebSocketID; aUserData : TWasmPointer; aCode: Longint; aReason : PByte; aReasonLen : Longint; aClean : Longint) : TWebsocketCallBackResult;
  TWasmWebsocketAllocateBuffer = Function (aWebsocketID : TWasmWebSocketID; aUserData : TWasmPointer; aBufferLen : Longint) : TWasmPointer;

  TWasmWebSocketAPI = class(TImportExtension)
    FNextID : TWasmWebsocketID;
    FSockets : TJSObject;
    FEncoder : TJSTextEncoder;
    FDecoder : TJSTextDecoder;
  private
    FLogAPICalls: Boolean;
    function CheckCallbackRes(Res: TWebsocketCallBackResult; const aOperation: string): Boolean;
    procedure HandleSendMessage(aSocket: TWasmWebSocket; aMessage: TJSUInt8Array; aType: TWasmWebSocketMessageType);
  Protected
    procedure DoError(const Msg : String);
    Procedure DoError(Const Fmt : String; const Args : Array of const);
    Procedure LogCall(const Msg : String);
    Procedure LogCall(Const Fmt : String; const Args : Array of const);
    Function GetNextID : TWasmWebsocketID;
    Function GetWebsocket(aID : TWasmWebSocketID) : TWasmWebSocket;
    function GetWebSocketClass: TWasmWebsocketClass; virtual;
    Procedure HandleOpen(aSocket : TWasmWebSocket);
    Procedure HandleClose(aSocket : TWasmWebSocket; aCode : Integer; aReason : String; aWasClean : Boolean);
    Procedure HandleError(aSocket : TWasmWebSocket);
    Procedure HandleBinaryMessage(aSocket : TWasmWebSocket; aMessage : TJSArrayBuffer);
    Procedure HandleStringMessage(aSocket : TWasmWebSocket; aMessage : String);
    function WebsocketAllocate(aURL : PByte; aUrlLen : Longint; aProtocols : PByte; aProtocolLen : Longint; aUserData : TWasmPointer; aWebsocketID : PWasmWebSocketID) : TWasmWebsocketResult; virtual;
    function WebsocketDeAllocate(aWebsocketID : TWasmWebSocketID) : TWasmWebsocketResult; virtual;
    function WebsocketClose(aWebsocketID : TWasmWebSocketID; aCode : Longint; aReason : PByte; aReasonLen : Longint) : TWasmWebsocketResult; virtual;
    function WebsocketSend(aWebsocketID : TWasmWebSocketID; aData : PByte; aDataLen : Longint; aType : Longint) : TWasmWebsocketResult; virtual;
 public
    constructor Create(aEnv: TPas2JSWASIEnvironment); override;
    procedure FillImportObject(aObject: TJSObject); override;
    function AllocateBuffer(aSocket: TWasmWebSocket; aLen: Longint): TWasmPointer;
    function ImportName: String; override;
    property LogAPICalls : Boolean Read FLogAPICalls Write FLogAPICalls;
  end;

implementation

{ ---------------------------------------------------------------------
  TWasmWebSocketAPI
  ---------------------------------------------------------------------}

// Auxiliary calls

procedure TWasmWebSocketAPI.LogCall(const Msg: String);
begin
  {$IFNDEF NOLOGAPICALLS}
  If not LogAPICalls then exit;
  Writeln(Msg);
  {$ENDIF}
end;


procedure TWasmWebSocketAPI.LogCall(const Fmt: String; const Args: array of const);

begin
  {$IFNDEF NOLOGAPICALLS}
  If not LogAPICalls then exit;
  Writeln(Format(Fmt,Args));
  {$ENDIF}
end;


function TWasmWebSocketAPI.GetNextID: TWasmWebsocketID;
begin
  Inc(FNextID);
  Result:=FNextID;
end;


procedure TWasmWebSocketAPI.DoError(const Msg: String);
begin
  Console.Error(Msg);
end;


procedure TWasmWebSocketAPI.DoError(const Fmt: String; const Args: array of const);
begin
  Console.Error(Format(Fmt,Args));
end;


function TWasmWebSocketAPI.GetWebsocket(aID: TWasmWebSocketID): TWasmWebSocket;

var
  Value : JSValue;

begin
  Value:=FSockets[IntToStr(aID)];
  if isObject(Value) then
    Result:=TWasmWebSocket(Value)
  else
    Result:=Nil;
end;


function TWasmWebSocketAPI.GetWebSocketClass: TWasmWebsocketClass;
begin
  Result:=TWasmWebsocket;
end;


function TWasmWebSocketAPI.CheckCallbackRes(Res : TWebsocketCallBackResult; const aOperation : string) : Boolean;
begin
  Result:=(Res=WASMWS_CALLBACK_SUCCESS);
  if not Result then
    DoError('Error during %s call, exit status %d',[aOperation,Res]);
end;


// Callbacks for TWasmWebSocket, calls exported routines from webassembly module.

function TWasmWebSocketAPI.AllocateBuffer(aSocket: TWasmWebSocket; aLen : Longint) : TWasmPointer;

var
  aValue : JSValue;
  Callback : TWasmWebsocketAllocateBuffer absolute aValue;

begin
  aValue:=InstanceExports['__wasm_websocket_allocate_buffer'];
  if Assigned(CallBack) then
    With aSocket do
      Result:=CallBack(WebSocketID,UserData,aLen);
  if Result=0 then
    DoError('Socket %s: Failed to allocate buffer for ',[aSocket.ToString]);
end;


procedure TWasmWebSocketAPI.HandleOpen(aSocket: TWasmWebSocket);

var
  value : JSValue;
  callback : TWasmWebSocketOpenHandler absolute Value;
  Res : TWebsocketCallBackResult;

begin
  value:=InstanceExports['__wasm_websocket_on_open'];
  if not Assigned(CallBack) then
    exit;
  With aSocket do
    begin
    Res:=(CallBack)(WebSocketID,UserData);
    CheckCallbackRes(Res,'open');
    end;
end;


procedure TWasmWebSocketAPI.HandleClose(aSocket: TWasmWebSocket; aCode: Integer; aReason: String; aWasClean: Boolean);

var
  aValue : JSValue;
  Callback : TWasmWebSocketCloseHandler absolute aValue;
  StrBuf : TJSUint8Array;
  Buf : TWasmPointer;
  Res : TWebsocketCallBackResult;
  bufLen : Longint;

begin
  if aReason<>'' then
    begin
    StrBuf:=FEncoder.encode(aReason);
    if not Assigned(StrBuf) then
      begin
      Buf:=0;
      bufLen:=0;
      end
    else
      begin
      bufLen:=StrBuf.byteLength;
      Buf:=AllocateBuffer(aSocket,bufLen);
      if Buf=0 then
        begin
        DoError('Socket %d: Failed to allocate buffer for close reason: %s',[aSocket.WebsocketID,aReason]);
        exit;
        end;
      end;
    end
  else
    begin
    Buflen:=0;
    Buf:=0;
    end;
  aValue:=InstanceExports['__wasm_websocket_on_close'];
  if isFunction(aValue) then
    With aSocket do
      begin
      if BufLen<>0 then
        Env.SetUTF8StringInMem(Buf,Buflen,StrBuf);
      Res:=CallBack(WebSocketID,UserData,aCode,Buf,Buflen,Ord(aWasClean));
      CheckCallBackRes(Res,'close');
      end;
end;


procedure TWasmWebSocketAPI.HandleError(aSocket: TWasmWebSocket);
var
  Callback : JSValue;

begin
  CallBack:=InstanceExports['__wasm_websocket_on_error'];
  if Assigned(CallBack) then
    With aSocket do
      TWasmWebSocketErrorHandler(CallBack)(WebSocketID,UserData);
end;


procedure TWasmWebSocketAPI.HandleSendMessage(aSocket: TWasmWebSocket; aMessage: TJSUInt8Array; aType : TWasmWebSocketMessageType);

//begin
//  TWasmWebSocketMessageHandler = Function (aWebsocketID : TWasmWebSocketID; aUserData : Pointer; aMessageType : TWasmWebSocketMessageType; aMessage : Pointer; aMessageLen : Integer) : TWebsocketCallBackResult;

var
  Value: JSValue;
  CallBack : TWasmWebSocketMessageHandler absolute Value;
  lBuf : TWasmPointer;
  WasmMem: TJSUint8Array;
  lLen : Longint;
  Res : TWebsocketCallBackResult;

begin
  Value:=InstanceExports['__wasm_websocket_on_message'];
  if Not Assigned(Value) then
    begin
    DoError('Socket %s: Failed no export to handle message',[aSocket.ToString]);
    exit;
    end;
  lLen:=aMessage.byteLength;
  lBuf:=AllocateBuffer(aSocket,lLen);
  if Lbuf=0 then
    begin
    DoError('Socket %s: Failed to allocate buffer for message',[aSocket.ToString]);
    Exit;
    end;
  With aSocket do
    begin
    WasmMem:=TJSUint8Array.New(getModuleMemoryDataView.buffer,lBuf,lLen);
    WasmMem._set(aMessage);
    Res:=CallBack(WebSocketID,UserData,aType,lBuf,lLen);
    CheckCallbackRes(Res,'sendmessage');
    end;
end;


procedure TWasmWebSocketAPI.HandleBinaryMessage(aSocket: TWasmWebSocket; aMessage: TJSArrayBuffer);

var
  lMessage : TJSUint8array;

begin
  lMessage:=TJSUint8array.New(aMessage);
  HandleSendMessage(aSocket,lMessage,WASMWS_MESSAGE_TYPE_BINARY);
end;


procedure TWasmWebSocketAPI.HandleStringMessage(aSocket: TWasmWebSocket; aMessage: String);
var
  lMessage : TJSUint8array;

begin
  lMessage:=FEncoder.encode(aMessage);
  HandleSendMessage(aSocket,lMessage,WASMWS_MESSAGE_TYPE_TEXT);
end;

// API methods called from within webassembly

function TWasmWebSocketAPI.WebsocketAllocate(aURL: PByte; aUrlLen: Longint; aProtocols: PByte; aProtocolLen: Longint;
  aUserData: TWasmPointer; aWebsocketID: PWasmWebSocketID): TWasmWebsocketResult;

var
  lURL,lProtocols : String;
  lSocket : TWasmWebSocket;
  lID : TWasmWebsocketID;

begin
  lURL:=env.GetUTF8StringFromMem(aURL,aUrlLen);
  lProtocols:=env.GetUTF8StringFromMem(aProtocols,aProtocolLen);
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    LogCall('HTTP.WebSocketAllocate("%s","%s",%d,[%x])',[lURL,lProtocols,aUserData,aWebSocketID]);
  {$ENDIF}
  if (lUrl='') then
    Exit(WASMWS_RESULT_NO_URL);
  lID:=GetNextID;
  lSocket:=GetWebSocketClass.Create(Self,lID,aUserData,lURL,lProtocols);
  FSockets[IntToStr(lID)]:=lSocket;
  env.SetMemInfoInt32(aWebSocketID,lID);
  Result:=WASMWS_RESULT_SUCCESS;
{$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    LogCall('HTTP.WebSocketAllocate("%s","%s",%d,[%x]) => %d',[lURL,lProtocols,aUserData,aWebSocketID,lID]);
{$ENDIF}
end;


function TWasmWebSocketAPI.WebsocketDeAllocate(aWebsocketID: TWasmWebSocketID): TWasmWebsocketResult;

var
  lSocket : TWasmWebSocket;

begin
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    LogCall('HTTP.WebSocketDeAllocate(%d)',[aWebSocketID]);
  {$ENDIF}
  lSocket:=GetWebsocket(aWebSocketID);
  if lSocket=Nil then
    Exit(WASMWS_RESULT_INVALIDID);
  lSocket.Destroy;
  FSockets[IntToStr(aWebSocketID)]:=undefined;
  Result:=WASMWS_RESULT_SUCCESS;
end;


function TWasmWebSocketAPI.WebsocketClose(aWebsocketID: TWasmWebSocketID; aCode: Longint; aReason: PByte; aReasonLen: Longint): TWasmWebsocketResult;

var
  lSocket : TWasmWebSocket;
  lReason : String;

begin
  lReason:=Env.GetUTF8StringFromMem(aReason,aReasonLen);
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    LogCall('HTTP.WebSocketClose(%d,%d,"%s")',[aWebSocketID,aCode,aReason]);
  {$ENDIF}
  lSocket:=GetWebsocket(aWebSocketID);
  if lSocket=Nil then
    Exit(WASMWS_RESULT_INVALIDID);
  lSocket.Close(aCode,lReason);
  Result:=WASMWS_RESULT_SUCCESS;
end;


function TWasmWebSocketAPI.WebsocketSend(aWebsocketID: TWasmWebSocketID; aData: PByte; aDataLen: Longint; aType: Longint
  ): TWasmWebsocketResult;
var
  lSocket : TWasmWebSocket;
  lData : TJSArrayBuffer;
  lText : String;

begin
  {$IFNDEF NOLOGAPICALLS}
  If LogAPICalls then
    LogCall('HTTP.WebSocketSend(%d,[%x],%d,%d)',[aWebSocketID,aData,aDataLen,aType]);
  {$ENDIF}
  lSocket:=GetWebsocket(aWebSocketID);
  if lSocket=Nil then
    Exit(WASMWS_RESULT_INVALIDID);
  lData:=getModuleMemoryDataView.buffer.slice(aData,aData+aDatalen);
  if aType=WASMWS_MESSAGE_TYPE_BINARY then
    lSocket.SendBinary(lData)
  else
    begin
    lText:=FDecoder.Decode(lData);
    lSocket.SendText(lText);
    end;
  Result:=WASMWS_RESULT_SUCCESS;
end;


constructor TWasmWebSocketAPI.Create(aEnv: TPas2JSWASIEnvironment);
begin
  inherited Create(aEnv);
  FNextID:=0;
  FSockets:=TJSObject.New;
  FEncoder:=TJSTextEncoder.New;
  FDecoder:=TJSTextDecoder.New;
end;


procedure TWasmWebSocketAPI.FillImportObject(aObject: TJSObject);
begin
  aObject[websocketFN_Allocate]:=@WebsocketAllocate;
  aObject[websocketFN_DeAllocate]:=@WebsocketDeAllocate;
  aObject[websocketFN_Close]:=@WebsocketClose;
  aObject[websocketFN_Send]:=@WebsocketSend;
end;


function TWasmWebSocketAPI.ImportName: String;
begin
  Result:=websocketExportName;
end;

{ ---------------------------------------------------------------------
  TWasmWebsocket
  ---------------------------------------------------------------------}


procedure TWasmWebsocket.HandleOpen(Event : TJSEvent);

begin
  if not Assigned(FAPI) then
    exit;
  FAPI.HandleOpen(Self);
  if assigned(Event) then;
end;

function TWasmWebsocket.ToString: String;
begin
  Result:=Format('WebSocket %d: %s',[WebSocketID,FWS.url])
end;


procedure TWasmWebsocket.HandleClose(Event : TJSEvent);

var
  lEvent : TJSWebsocketCloseEvent absolute event;

begin
  if not Assigned(FAPI) then
    exit;
  FAPI.HandleClose(Self,lEvent.Code,lEvent.Reason,lEvent.WasClean);
end;


procedure TWasmWebsocket.HandleMessage(Event : TJSEvent);

var
  lEvent : TJSMessageEvent absolute event;

begin
  if Not Assigned(FAPI) then
    exit;
  if isString(lEvent.Data) then
    FAPI.HandleStringMessage(Self,String(lEvent.Data))
  else if isObject(lEvent.Data) then
    FAPI.HandleBinaryMessage(Self,TJSArrayBuffer(lEvent.Data))
  else
    FAPI.DoError('Received empty message');
end;


procedure TWasmWebsocket.HandleError(Event : TJSEvent);

begin
  if not Assigned(FAPI) then
    exit;
  FAPI.HandleError(Self);
  if assigned(Event) then;
end;


constructor TWasmWebsocket.Create(aAPI: TWasmWebSocketAPI; aID: TWasmWebsocketID; aUserData : TWasmPointer;const aURL: String; const aProtocols: String);
begin
  FAPI:=aAPI;
  FWebsocketID:=aID;
  FUserData:=aUserData;
  // We cannot pass an empty protocol string, it results in an error...
  if aProtocols<>'' then
    FWS:=TJSWebSocket.new(aUrl,aProtocols)
  else
    FWS:=TJSWebSocket.new(aUrl);
  FWS.binaryType:='arraybuffer';
  FWS.addEventListener('open',@HandleOpen);
  FWS.addEventListener('close',@HandleClose);
  FWS.addEventListener('error',@HandleError);
  FWS.addEventListener('message',@HandleMessage);
end;


destructor TWasmWebsocket.Destroy;
begin
  FAPI:=Nil;
  if FWS.readyState=TJSWebsocket.OPEN then
    FWS.close;
  inherited Destroy;
end;


procedure TWasmWebsocket.Close(aCode: Integer; aReason: String);
begin
  if (aReason<>'') then
    FWS.Close(aCode,aReason)
  else
    FWS.Close(aCode)
end;


procedure TWasmWebsocket.SendText(aData: String);

begin
  FWS.send(aData);
end;


procedure TWasmWebsocket.SendBinary(aData: TJSArrayBuffer);

begin
  FWS.send(aData);
end;

end.

