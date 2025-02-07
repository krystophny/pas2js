{$IFNDEF FPC_DOTTEDUNITS}
unit wasiworkerthreadhost;
{$ENDIF}

{$mode ObjFPC}
{$modeswitch externalclass}
{ $define NOLOGAPICALLS}

interface

uses
{$IFDEF FPC_DOTTEDUNITS}
  System.Classes, System.SysUtils, JSApi.JS, Fcl.CustApp, BrowserApi.WebOrWorker, 
  BrowserApi.Worker, BrowserApi.WebAssembly, Wasi.Env, System.WebThreads,
  Rtl.ThreadController;
{$ELSE} 
  Classes, SysUtils, JS, custapp, weborworker, webworker, webassembly, wasienv,
  Rtl.WebThreads, Rtl.ThreadController;
{$ENDIF}

const
  ThreadRunnerScript = 'wasm_worker_runner.js';
  ThreadCount = 4;

Type
  TWorkerThreadSupport = Class;
  { TWASIThreadHost }

  TWASIThreadHost = class(TWASIHost)
  private
    FSendOutputToBrowserWindow: Boolean;
    FThreadEntryPoint: String;
    FThreadSupport: TWorkerThreadSupport;
    procedure PrepareWebAssemblyThread(aDescr: TWebAssemblyStartDescriptor);
    procedure SetThreadSupport(AValue: TWorkerThreadSupport);
  Protected
    Procedure RunWebAssemblyThread(aProc : TRunWebassemblyProc); virtual;
    procedure DoStdWrite(Sender: TObject; const aOutput: String); override;
  Public
    constructor Create(aOwner: TComponent); override;
    // Thread entry point name for the WASI Host.
    Property ThreadEntryPoint : String Read FThreadEntryPoint Write FThreadEntryPoint;
    // Send output to main window
    Property SendOutputToBrowserWindow : Boolean Read FSendOutputToBrowserWindow Write FSendOutputToBrowserWindow;
    // our thread
    Property ThreadSupport : TWorkerThreadSupport Read FThreadSupport Write SetThreadSupport;
  end;


  // This object has the thread support that is needed by the worker that runs a thread.

  { TWorkerThreadSupport }

  TWorkerThreadSupport = class(TWasmThreadSupport)
  Private
    Type
      TWorkerState = (wsNeutral, wsLoading, wsLoaded, wsRunWaiting, wsRunning);
    procedure DoRunThread(aExports: TWASIExports);
  Private
    FState: TWorkerState;
    FCurrentThreadInfo : TThreadinfo;
    FModule : TJSWebAssemblyModule;
    FMemory : TJSWebAssemblyMemory;
    FWasiHost: TWASIThreadHost;
  Protected
    // Incoming messages
    procedure LoadWasmModule(aCommand: TWorkerLoadCommand); virtual;
    procedure RunWasmModule(aCommand: TWorkerRunCommand); virtual;
    procedure CancelWasmModule(aCommand: TWorkerCancelCommand); virtual;
    procedure SendLoaded; virtual;
    Procedure SendConsoleMessage(aMessage : String); overload;
    Procedure SendConsoleMessage(aFmt : String; const aArgs : array of const); overload;
    Procedure SendConsoleMessage(const aArgs : array of JSValue); overload;
    procedure SendException(aError: Exception); overload;
    procedure SendException(aError: TJSError); overload;
  Protected
    function thread_spawn(start_arg : longint) : longint; override;
    Function thread_detach(thread_id : Integer) : Integer; override;
    Function thread_cancel(thread_id : Integer) : Integer; override;
    Function thread_self() : Integer; override;
  Public
    // Handle incoming command
    Procedure HandleCommand(aCommand : TWorkerCommand); override;
    // Current thread info.
    Property CurrentThreadInfo : TThreadInfo Read FCurrentThreadInfo;
    // The WASI host, used to run routines.
    Property Host : TWASIThreadHost Read FWasiHost Write FWasiHost;
  end;

  { TWorkerWASIHostApplication }

  TWorkerWASIHostApplication = class(TCustomApplication)
  private
    FHost : TWASIHost;
    FSendOutputToBrowser: Boolean;
    FConsoleChannel: TJSBroadcastChannel;
    function GetAfterStart: TAfterStartEvent;
    function GetBeforeStart: TBeforeStartEvent;
    function GetcPredefinedConsoleInput: TStrings;
    function GetEnv: TPas2JSWASIEnvironment;
    function GetExported: TWASIExports;
    function GetOnConsoleRead: TConsoleReadEvent;
    function GetOnConsoleWrite: TConsoleWriteEvent;
    function GetRunEntryFunction: String;
    procedure SetAfterStart(AValue: TAfterStartEvent);
    procedure SetBeforeStart(AValue: TBeforeStartEvent);
    procedure SetOnConsoleRead(AValue: TConsoleReadEvent);
    procedure SetOnConsoleWrite(AValue: TConsoleWriteEvent);
    procedure SetPredefinedConsoleInput(AValue: TStrings);
    procedure SetRunEntryFunction(AValue: String);
  protected
    procedure HandleMessage(aEvent: TJSEvent); virtual; abstract;
    procedure DoOnSendCommand(Sender : TObject; aCommand : TWorkerCommand);
    function CreateHost: TWASIHost; virtual; abstract;
    procedure DoRun; override;
    procedure DoLog(EventType: TEventType; const Msg: String); override;
    function GetConsoleApplication: boolean; override;
    function GetLocation: String; override;
    property ConsoleChannel : TJSBroadCastChannel Read FConsoleChannel;
    Property Host : TWASIHost Read FHost;
  public
    Constructor Create(aOwner : TComponent); override;
    Destructor Destroy; override;
    // Send a command to the process that started the worker.
    procedure SendCommand(aCommand: TWorkerCommand); virtual;
    // Get the list of environment variables.
    procedure GetEnvironmentList(List: TStrings; NamesOnly: Boolean); override;
    // Load and start webassembly. If DoRun is true, then Webassembly entry point is called.
    // If aBeforeStart is specified, then it is called prior to calling run, and can disable running.
    // If aAfterStart is specified, then it is called after calling run. It is not called is running was disabled.
    Procedure StartWebAssembly(aPath: string; DoRun : Boolean = True;  aBeforeStart : TBeforeStartCallback = Nil; aAfterStart : TAfterStartCallback = Nil);
    // Environment to be used
    Property WasiEnvironment : TPas2JSWASIEnvironment Read GetEnv;
    // Exported functions. Also available in start descriptor.
    Property Exported : TWASIExports Read GetExported;
    // Name of function to run, if empty default _start symbol is used.
    Property RunEntryFunction : String Read GetRunEntryFunction Write SetRunEntryFunction;
    // Called after webassembly start was run. Not called if webassembly was not run.
    Property AfterStart : TAfterStartEvent Read GetAfterStart Write SetAfterStart;
    // Called before running webassembly. If aAllowRun is false, running is disabled
    Property BeforeStart : TBeforeStartEvent Read GetBeforeStart Write SetBeforeStart;
    // Send output to browser window process?
    Property SendOutputToBrowser : Boolean Read FSendOutputToBrowser Write FSendOutputToBrowser;
    // Default console input
    Property PredefinedConsoleInput : TStrings Read GetcPredefinedConsoleInput Write SetPredefinedConsoleInput;
    // Called when reading from console (stdin). If not set, PredefinedConsoleinput is used.
    property OnConsoleRead : TConsoleReadEvent Read GetOnConsoleRead Write SetOnConsoleRead;
    // Called when writing to console (stdout). If not set, console.log is used.
    property OnConsoleWrite : TConsoleWriteEvent Read GetOnConsoleWrite Write SetOnConsoleWrite;
  end;

  { TWorkerThreadRunnerApplication }

  TWorkerThreadRunnerApplication = class(TWorkerWASIHostApplication)
  Private
    FThreadSupport : TWorkerThreadSupport;
  Protected
    procedure HandleConsoleWrite(Sender: TObject; aOutput: string);
    function HandleCustomCommand(aData: TWorkerCommand): Boolean; virtual;
    function CreateHost: TWASIHost; override;
    function CreateWorkerThreadSupport(aEnv: TPas2JSWasiEnvironment): TWorkerThreadSupport; virtual;
    procedure HandleMessage(aEvent: TJSEvent); override;
  Public
    procedure ShowException(aError: Exception); override;
    // Our thread support object
    Property ThreadSupport : TWorkerThreadSupport Read FThreadSupport Write FThreadSupport;
  end;

  { TWASIThreadHost }

  { TWASIThreadControllerHost }

  TWASIThreadControllerHost = class(TWASIHost)
  private
    FSendOutputToBrowserWindow: Boolean;
    FThreadSupport: TThreadController;
    procedure SetThreadSupport(AValue: TThreadController);
  Protected
    procedure DoAfterInstantiate; override;
  Public
    constructor Create(aOwner: TComponent); override;
    // Send output to main window
    Property SendOutputToBrowserWindow : Boolean Read FSendOutputToBrowserWindow Write FSendOutputToBrowserWindow;
    // our thread
    Property ThreadSupport : TThreadController Read FThreadSupport Write SetThreadSupport;
  end;

  { TWorkerThreadControllerApplication }

  TWorkerThreadControllerApplication = class(TWorkerWASIHostApplication)
  Private
    FThreadSupport : TThreadController;
  Protected
    function CreateThreadSupport(aEnv: TPas2JSWASIEnvironment): TThreadController; virtual;
    procedure HandleConsoleWrite(Sender: TObject; aOutput: string); virtual;
    procedure HandleExecuteCommand(aCmd: TWorkerExecuteCommand); virtual;
    procedure HandleRpcCommand(aCmd: TWorkerRpcCommand); virtual;
    function HandleCustomCommand(aData: TWorkerCommand): Boolean; virtual;
    procedure HandleMessage(aEvent: TJSEvent); override;
    function CreateHost: TWASIHost; override;
  Public
    procedure ShowException(aError: Exception); override;
    property ThreadSupport : TThreadController Read FThreadSupport;
  end;

function GetJSClassName(aObj : TJSObject) : string;

var
  Self_ : TJSDedicatedWorkerGlobalScope; external name 'self';

implementation

uses 
{$IFDEF FPC_DOTTEDUNITS}
  System.Types, System.TypInfo;
{$ELSE} 
  TypInfo, Types;
{$ENDIF}

var
  EnvNames: TJSObject;

procedure ReloadEnvironmentStrings;

var
  I : Integer;
  S,N : String;
  A,P : TStringDynArray;

begin
  if Assigned(EnvNames) then
    FreeAndNil(EnvNames);
  EnvNames:=TJSObject.new;
  S:=self_.Location.search;
  S:=Copy(S,2,Length(S)-1);
  A:=TJSString(S).split('&');
  for I:=0 to Length(A)-1 do
    begin
    P:=TJSString(A[i]).split('=');
    N:=LowerCase(decodeURIComponent(P[0]));
    if Length(P)=2 then
      EnvNames[N]:=decodeURIComponent(P[1])
    else if Length(P)=1 then
      EnvNames[N]:=''
    end;
end;

function MyGetEnvironmentVariable(Const EnvVar: String): String;

Var
  aName : String;

begin
  aName:=Lowercase(EnvVar);
  if EnvNames.hasOwnProperty(aName) then
    Result:=String(EnvNames[aName])
  else
    Result:='';
end;

function MyGetEnvironmentVariableCount: Integer;
begin
  Result:=length(TJSOBject.getOwnPropertyNames(envNames));
end;

function MyGetEnvironmentString(Index: Integer): String;
begin
  Result:=String(EnvNames[TJSOBject.getOwnPropertyNames(envNames)[Index]]);
end;


{ TWASIThreadHost }

procedure TWASIThreadHost.SetThreadSupport(AValue: TWorkerThreadSupport);
begin
  if FThreadSupport=AValue then Exit;
  if Assigned(FThreadSupport) then
    FThreadSupport.Host:=Nil;
  FThreadSupport:=AValue;
  if Assigned(FThreadSupport) then
    FThreadSupport.Host:=Self;
end;

procedure TWASIThreadHost.RunWebAssemblyThread(aProc : TRunWebassemblyProc);
begin
//  Writeln('TWASIThreadHost.Entering RunWebAssemblyThread ');
  RunWebAssemblyInstance(Nil,Nil,aProc);
end;

procedure TWASIThreadHost.PrepareWebAssemblyThread( aDescr: TWebAssemblyStartDescriptor);

begin
  PrepareWebAssemblyInstance(aDescr);
end;

procedure TWASIThreadHost.DoStdWrite(Sender: TObject; const aOutput: String);
begin
  inherited DoStdWrite(Sender, aOutput);
  if FSendOutputToBrowserWindow and assigned(FThreadSupport) then
    FThreadSupport.SendConsoleMessage(aOutput);
end;

constructor TWASIThreadHost.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FThreadEntryPoint:=DefaultThreadEntryPoint;
  FSendOutputToBrowserWindow:=True;
end;

{ TWorkerThreadSupport }

function TWorkerThreadSupport.thread_spawn(start_arg: longint): longint;

Var
  P : TWorkerSpawnThreadCommand;

begin
  P:=TWorkerSpawnThreadCommand.Create(start_arg,start_arg);
  SendCommand(P);
  Result:=start_arg;
end;

function TWorkerThreadSupport.thread_detach(thread_id: Integer): Integer;
begin
  Result:=0;
  if thread_id=0 then ;
end;

function TWorkerThreadSupport.thread_cancel(thread_id: Integer): Integer;
begin
  Result:=0;
  if thread_id=0 then ;
end;

function TWorkerThreadSupport.thread_self: Integer;
begin
  Result:=0;
end;

procedure TWorkerThreadSupport.SendLoaded;

Var
  L : TWorkerLoadedCommand;

begin
  L:=TWorkerLoadedCommand.Create();
  SendCommand(L);
end;

procedure TWorkerThreadSupport.SendConsoleMessage(aMessage: String);

Var
  L : TWorkerConsoleCommand;

begin
  L:=TWorkerConsoleCommand.Create(aMessage,FCurrentThreadInfo.ThreadId);
  SendCommand(L);
end;

procedure TWorkerThreadSupport.SendConsoleMessage(aFmt: String;
  const aArgs: array of const);
begin
  SendConsoleMessage(Format(aFmt,aArgs));
end;

procedure TWorkerThreadSupport.SendConsoleMessage(const aArgs: array of JSValue);

Var
  L : TWorkerConsoleCommand;

begin
  L:=TWorkerConsoleCommand.Create(aArgs,FCurrentThreadInfo.ThreadId);
  SendCommand(L);
end;

procedure TWorkerThreadSupport.CancelWasmModule(aCommand : TWorkerCancelCommand);

begin
  if (aCommand<>Nil) then ;
  // todo
end;


procedure TWorkerThreadSupport.SendException(aError : Exception);

Var
  E : TWorkerExceptionCommand;

begin
  E:=TWorkerExceptionCommand.CreateNew(aError.ClassName,aError.Message,FCurrentThreadInfo.ThreadId);
  SendCommand(E);
end;

procedure TWorkerThreadSupport.SendException(aError: TJSError);

Var
  aMessage,aClass : String;
  E : TWorkerExceptionCommand;

begin
  aClass:='Error';
  aMessage:=aError.Message;
  E:=TWorkerExceptionCommand.CreateNew(aClass,aMessage,FCurrentThreadInfo.ThreadId);
  SendCommand(E);
end;

Procedure TWorkerThreadSupport.DoRunThread(aExports : TWASIExports);

Var
  aResult : Integer;

begin
  try
    FState:=wsRunning;
    // Writeln('About to run webassembly entry point (',Host.ThreadEntryPoint,') for thread ID ',aCommand.ThreadID);
    aResult:=TThreadEntryPointFunction(aExports[Host.ThreadEntryPoint])(FCurrentThreadInfo.ThreadID,FCurrentThreadInfo.Arguments);
    FState:=wsLoaded;
    if aResult>0 then
      SendConsoleMessage('Thread run function result= %d ',[aResult]);
  except
    on E : Exception do
      SendException(E);
    on JE : TJSError do
      SendException(JE);
    on JE : TJSError do
      SendException(JE)
  end;
end;


procedure TWorkerThreadSupport.RunWasmModule(aCommand : TWorkerRunCommand);

begin
  if (FState=wsNeutral) then
    begin
    {$IFNDEF NOLOGAPICALLS}
    DoLog('No webassembly loaded');
    {$ENDIF}
    exit; // Todo: send error back
    end;
  if (FState in [wsRunning,wsRunWaiting]) then
    begin
    {$IFNDEF NOLOGAPICALLS}
    DoLog('Webassembly already running');
    {$ENDIF}
    exit; // Todo: send error back
    end;
  // Writeln('Entering TWorkerThreadSupport.RunWasmModule '+TJSJSON.Stringify(aCommand));
  // initialize current thread info
  FCurrentThreadInfo.ThreadID:=aCommand.ThreadID;
  FCurrentThreadInfo.Arguments:=aCommand.Args;
  if FState=wsLoaded then
    Host.RunWebAssemblyThread(@DoRunThread)
  else
    FState:=wsRunWaiting;
end;

procedure TWorkerThreadSupport.LoadWasmModule(aCommand: TWorkerLoadCommand);


Var
  WASD : TWebAssemblyStartDescriptor;
  aTable : TJSWebAssemblyTable;

  function doOK(aValue: JSValue): JSValue;
  // We are using the overload that takes a compiled module.
  // In that case the promise resolves to a WebAssembly.Instance, not to a InstantiateResult !
  Var
    aInstance : TJSWebAssemblyInstance absolute aValue;

  begin
    Result:=True;
    WASD.Instance:=aInstance;
    WASD.Exported:=TWASIExports(TJSObject(aInstance.exports_));
    WASD.CallRun:=Nil;
    Host.PrepareWebAssemblyThread(WASD);
    SendLoaded;
    if FState=wsRunWaiting then
      Host.RunWebAssemblyThread(@DoRunThread)
    else
      FState:=wsLoaded;
  end;

  function DoFail(aValue: JSValue): JSValue;

  var
    E: Exception;

  begin
    FState:=wsNeutral;
    Result:=True;
    E:=Exception.Create('Failed to create webassembly. Reason: '+TJSJSON.Stringify(aValue));
    SendException(E);
    E.Free;
  end;


begin
  FState:=wsLoading;
  FMemory:=aCommand.Memory;
  FModule:=aCommand.Module;
  try
    aTable:=TJSWebAssemblyTable.New(Host.TableDescriptor);
    WASD:=Host.InitStartDescriptor(FMemory,aTable,Nil);
    TJSWebAssembly.Instantiate(FModule,WASD.Imports)._then(@DoOK,@DoFail).Catch(@DoFail);
  except
    on E : Exception do
      SendException(E);
    on JE : TJSError do
      SendException(JE);
  end;
end;

procedure TWorkerThreadSupport.HandleCommand(aCommand: TWorkerCommand);

begin
  case aCommand.Command of
    cmdload : LoadWasmModule(TWorkerLoadCommand(aCommand));
    cmdRun : RunWasmModule(TWorkerRunCommand(aCommand));
    cmdCancel : CancelWasmModule(TWorkerCancelCommand(aCommand));
  end;
end;



{ TWorkerWASIHostApplication }

function TWorkerWASIHostApplication.GetAfterStart: TAfterStartEvent;
begin
  Result:=FHost.AfterStart;
end;

function TWorkerWASIHostApplication.GetBeforeStart: TBeforeStartEvent;
begin
  Result:=FHost.BeforeStart;
end;

function TWorkerWASIHostApplication.GetcPredefinedConsoleInput: TStrings;
begin
  Result:=FHost.PredefinedConsoleInput;
end;

function TWorkerWASIHostApplication.GetEnv: TPas2JSWASIEnvironment;
begin
  Result:=FHost.WasiEnvironment;
end;

function TWorkerWASIHostApplication.GetExported: TWASIExports;
begin
  Result:=FHost.Exported;
end;


function TWorkerWASIHostApplication.GetOnConsoleRead: TConsoleReadEvent;
begin
  Result:=FHost.OnConsoleRead;
end;

function TWorkerWASIHostApplication.GetOnConsoleWrite: TConsoleWriteEvent;
begin
  Result:=FHost.OnConsoleWrite;
end;

function TWorkerWASIHostApplication.GetRunEntryFunction: String;
begin
  Result:=FHost.RunEntryFunction;
end;


procedure TWorkerWASIHostApplication.SetAfterStart(AValue: TAfterStartEvent);
begin
  FHost.AfterStart:=aValue;
end;

procedure TWorkerWASIHostApplication.SetBeforeStart(AValue: TBeforeStartEvent);
begin
  FHost.BeforeStart:=aValue;
end;

procedure TWorkerWASIHostApplication.SetOnConsoleRead(AValue: TConsoleReadEvent
  );
begin
  FHost.OnConsoleRead:=aValue;
end;

procedure TWorkerWASIHostApplication.SetOnConsoleWrite(
  AValue: TConsoleWriteEvent);
begin
    FHost.OnConsoleWrite:=aValue;
end;

procedure TWorkerWASIHostApplication.SetPredefinedConsoleInput(AValue: TStrings);
begin
  FHost.PredefinedConsoleInput:=aValue;
end;

procedure TWorkerWASIHostApplication.SetRunEntryFunction(AValue: String);
begin
  FHost.RunEntryFunction:=aValue;
end;


procedure TWorkerWASIHostApplication.DoRun;
begin
  Self_.addEventListener('message',@HandleMessage);
end;

procedure TWorkerWASIHostApplication.DoLog(EventType: TEventType; const Msg: String);
var
  S : String;
begin
  S:=GetEnumName(TypeInfo(TEventType),Ord(EventType));
  ConsoleChannel.PostMessage(TWorkerConsoleCommand.Create(Format('[%s] %s',[S,Msg])));
end;


procedure TWorkerWASIHostApplication.DoOnSendCommand(Sender: TObject;
  aCommand: TWorkerCommand);
begin
  SendCommand(aCommand);
end;

procedure TWorkerWASIHostApplication.SendCommand(aCommand: TWorkerCommand);
begin
  Self_.PostMessage(aCommand);
end;

function TWorkerWASIHostApplication.GetConsoleApplication: boolean;
begin
  Result:=true;
end;

function TWorkerWASIHostApplication.GetLocation: String;
begin
  Result:={$IFDEF FPC_DOTTEDUNITS}BrowserApi.Worker.{$ELSE}WebWorker.{$ENDIF}Location.pathname;
end;

constructor TWorkerWASIHostApplication.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FHost:=CreateHost;
  FConsoleChannel:=TJSBroadcastChannel.new(channelConsole);
end;

destructor TWorkerWASIHostApplication.Destroy;
begin
  FConsoleChannel.Close;
  FreeAndNil(FHost);
  inherited Destroy;
end;

procedure TWorkerWASIHostApplication.GetEnvironmentList(List: TStrings;
  NamesOnly: Boolean);
var
  Names: TStringDynArray;
  i: Integer;
begin
  Names:=TJSObject.getOwnPropertyNames(EnvNames);
  for i:=0 to length(Names)-1 do
  begin
    if NamesOnly then
      List.Add(Names[i])
    else
      List.Add(Names[i]+'='+String(EnvNames[Names[i]]));
  end;
end;


procedure TWorkerWASIHostApplication.StartWebAssembly(aPath: string; DoRun: Boolean;
  aBeforeStart: TBeforeStartCallback = nil; aAfterStart: TAfterStartCallback = nil);

begin
  FHost.StartWebAssembly(aPath,DoRun,aBeforeStart,aAfterStart);
end;

{ TWorkerThreadRunnerApplication }

procedure TWorkerThreadRunnerApplication.HandleConsoleWrite(Sender: TObject; aOutput: string);
begin
  ConsoleChannel.postMessage(TWorkerConsoleCommand.Create(aOutput));
end;

function TWorkerThreadRunnerApplication.CreateWorkerThreadSupport(aEnv : TPas2JSWasiEnvironment) : TWorkerThreadSupport;

begin
  Result:=TWorkerThreadSupport.Create(aEnv);
end;

function TWorkerThreadRunnerApplication.CreateHost: TWASIHost;

var
  TH : TWasiThreadHost;

begin
  TH:=TWASIThreadHost.Create(Self);
  TH.OnConsoleWrite:=@HandleConsoleWrite;
  FThreadSupport:=CreateWorkerThreadSupport(TH.WasiEnvironment);
  FThreadSupport.OnSendCommand:=@DoOnSendCommand;
  TH.ThreadSupport:=FThreadSupport; // Sets FThreadSupport.host
  Result:=TH;
end;

procedure TWorkerThreadRunnerApplication.ShowException(aError: Exception);

Var
  Ex : TWorkerExceptionCommand;

begin
  Ex:=TWorkerExceptionCommand.CreateNew(aError.ClassName,aError.Message);
  SendCommand(Ex);
end;


function TWorkerThreadRunnerApplication.HandleCustomCommand(aData : TWorkerCommand) : Boolean;

begin
  if aData<>Nil then;
  Result:=False;
end;

procedure TWorkerThreadRunnerApplication.HandleMessage(aEvent: TJSEvent);

Var
  aMessageEvent : TJSMessageEvent absolute aEvent;
  aData : TWorkerCommand;

begin
  {$IFNDEF NOLOGAPICALLS}
  DoLog(etDebug,'Message received in worker');
  {$ENDIF}
  if IsObject(aMessageEvent.Data) and TJSObject(aMessageEvent.Data).hasOwnProperty('Command') then
    begin
    aData:=TWorkerCommand(aMessageEvent.Data);
    {$IFNDEF NOLOGAPICALLS}
    DoLog(etDebug,'Command Message received in worker: '+TJSJSON.Stringify(aData));
    {$ENDIF}
    if not HandleCustomCommand(aData) then
      FThreadSupport.HandleCommand(aData);
    end
  else
    FThreadSupport.SendConsoleMessage('Unknown message received: '+TJSJSON.Stringify(aMessageEvent.Data));
end;

{ TWASIThreadControllerHost }

procedure TWASIThreadControllerHost.SetThreadSupport(AValue: TThreadController);
begin
  if Assigned(FThreadSupport) then
    FThreadSupport.Host:=Nil;
  FThreadSupport:=AValue;
  if Assigned(FThreadSupport) then
    FThreadSupport.Host:=Self;
end;

procedure TWASIThreadControllerHost.DoAfterInstantiate;
begin
  inherited DoAfterInstantiate;
  If Assigned(FThreadSupport) then
    FThreadSupport.SendLoadCommands;
end;

constructor TWASIThreadControllerHost.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
end;


{ TWorkerThreadControllerApplication }

procedure TWorkerThreadControllerApplication.ShowException(aError: Exception);
Var
  Ex : TWorkerExceptionCommand;

begin
  Ex:=TWorkerExceptionCommand.CreateNew(aError.ClassName,aError.Message);
  SendCommand(Ex);
end;

procedure TWorkerThreadControllerApplication.HandleExecuteCommand(aCmd : TWorkerExecuteCommand);

(*
Function DoPrepare(Sender : TObject; aDescriptor : TWebAssemblyStartDescriptor) : Boolean;

  begin
//    aDescriptor.
    Result:=True;
  end;
*)

begin
  if isObject(aCmd.Env) then
    EnvNames:=aCmd.Env;
  if isString(aCmd.executeFunc) then
    FHost.RunEntryFunction:=aCmd.executeFunc;
  StartWebAssembly(aCmd.Url,True,Nil {@DoPrepare}, Nil)
end;

function GetJSClassName(aObj : TJSObject) : string;

begin
  Result:='';
  if aObj=Nil then
    exit;
  asm
    return aObj.constructor.name;
  end;
end;

procedure TWorkerThreadControllerApplication.HandleRpcCommand(aCmd: TWorkerRpcCommand);

var
  res : TWorkerRpcResultCommand;
  data : JSValue;
  errClass : String;
  errMessage : String;

begin
  if aCmd.Id='' then
    Res:=TWorkerRpcResultCommand.CreateError(aCmd.id,-32600,'Invalid request: No json-rpc ID')
  else if aCmd.jsonrpc<>'2.0' then
    Res:=TWorkerRpcResultCommand.CreateError(aCmd.id,-32600,'Invalid request: no jsonrpc version')
  else if Not Assigned(Exported.functions[aCmd.method]) then
    Res:=TWorkerRpcResultCommand.CreateError(aCmd.id,-32601,'Method "'+aCmd.method+'" not found')
  else
    begin
    try
      if isArray(aCmd.Params) then
        data:=Exported.functions[aCmd.method].Apply(nil,TJSValueDynArray(aCmd.Params))
      else
        data:=Exported.functions[aCmd.method].call(nil);
      Res:=TWorkerRpcResultCommand.Create(aCmd.id,Data);
    except
      on JE : TJSError do
        begin
        errClass:=GetJSClassName(JE);
        errMessage:=JE.message;
        end;
      on E : Exception do
        begin
        errClass:=E.ClassName;
        errMessage:=E.Message;
        end;
    end;
    if not assigned(Res) then
      Res:=TWorkerRpcResultCommand.CreateError(aCmd.id,-32603,'Exception '+ErrClass+' while executing "'+aCmd.method+'" : '+ErrMessage);
    end;
  Self_.postMessage(Res);
end;

procedure TWorkerThreadControllerApplication.HandleConsoleWrite(Sender: TObject; aOutput: string);
begin
  FConsoleChannel.postMessage(TWorkerConsoleCommand.Create(aOutput,0));
end;

function TWorkerThreadControllerApplication.HandleCustomCommand(aData : TWorkerCommand) : Boolean;

begin
  if not Assigned(aData) then
    Exit(True);
  Result:=False;
end;

procedure TWorkerThreadControllerApplication.HandleMessage(aEvent: TJSEvent);

var
  aMessageEvent : TJSMessageEvent absolute aEvent;
  aData: TWorkerCommand;

begin
  Writeln('Thread Message received');
  if IsObject(aMessageEvent.Data) and TJSObject(aMessageEvent.Data).hasOwnProperty('Command') then
    begin
    aData:=TWorkerCommand(aMessageEvent.Data);
    Writeln('Command message received: '+TJSJSON.Stringify(aData));
    case aData.Command of
      cmdExecute : HandleExecuteCommand(TWorkerExecuteCommand(aData));
      cmdRpc : HandleRPCCommand(TWorkerRpcCommand(aData));
    else
      if not HandleCustomCommand(aData) then
        FThreadSupport.HandleCommand(aData);
    end;
    end;
end;

function TWorkerThreadControllerApplication.CreateThreadSupport(aEnv : TPas2JSWASIEnvironment) : TThreadController;

begin
  Result:=TThreadController.Create(aEnv,ThreadRunnerScript,20);
end;

function TWorkerThreadControllerApplication.CreateHost: TWASIHost;
var
  TH : TWASIThreadControllerHost;
  Mem : TJSWebAssemblyMemoryDescriptor;
begin
  TH:=TWASIThreadControllerHost.Create(Self);
  TH.OnConsoleWrite:=@HandleConsoleWrite;
  FThreadSupport:=CreateThreadSupport(TH.WasiEnvironment);
  Mem.Initial:=256;
  Mem.maximum:=1024;
  Mem.shared:=True;
  TH.MemoryDescriptor:=Mem;
  FThreadSupport.OnSendCommand:=@DoOnSendCommand;
  TH.ThreadSupport:=FThreadSupport; // Sets FThreadSupport.host
  Result:=TH;
//  TThreadController

end;

Initialization
  ReloadEnvironmentStrings;
  OnGetEnvironmentVariable:=@MyGetEnvironmentVariable;
  OnGetEnvironmentVariableCount:=@MyGetEnvironmentVariableCount;
  OnGetEnvironmentString:=@MyGetEnvironmentString;
end.

