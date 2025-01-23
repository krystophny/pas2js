unit rtl.threadcontroller;

{$mode ObjFPC}
{$modeswitch externalclass}
{$modeswitch typehelpers}

interface

uses
  {$IFDEF FPC_DOTTEDUNITS}
    JSApi.JS, System.SysUtils, System.WebThreads, Wasi.Env, BrowserApi.WebOrWorker;
  {$ELSE}
    JS, SysUtils, Rtl.WebThreads, wasienv, weborworker;
  {$ENDIF}


Type
  { TWasmThread }
  TWasmThread = TJSWorker;

  { TWasmThreadHelper }

  TWasmThreadHelper = Class helper for TWasmThread
  private
    function GetLoaded: Boolean;
    function GetLoadSent: Boolean;
    function GetThreadID: Integer;
    function GetThreadIDRange: Integer;
    function GetThreadInfo: TThreadinfo;
    procedure SetLoaded(AValue: Boolean);
    procedure SetLoadSent(AValue: Boolean);
    procedure SetThreadID(AValue: Integer);
    procedure SetThreadIDRange(AValue: Integer);
    procedure SetThreadInfo(AValue: TThreadinfo);
  Public
    Class function Create(aScript : String) : TWasmThread; reintroduce; static;
    Procedure SendCommand(aCommand : TWorkerCommand);
    Property LoadSent : Boolean Read GetLoadSent Write SetLoadSent;
    Property Loaded : Boolean Read GetLoaded Write SetLoaded;
    Property ThreadInfo : TThreadinfo Read GetThreadInfo Write SetThreadInfo;
    Property ThreadID : Integer Read GetThreadID Write SetThreadID;
    Property ThreadIDRange : Integer Read GetThreadIDRange Write SetThreadIDRange;
  end;



  TThreadHash = class external name 'Object' (TJSObject)
  Private
    function GetThreadData(aIndex: NativeInt): TWasmThread; external name '[]';
    procedure SetThreadData(aIndex: NativeInt; const AValue: TWasmThread); external name '[]';
  Public
    Property ThreadData[aIndex : NativeInt] : TWasmThread Read GetThreadData Write SetThreadData; default;
  end;


  // This object has the thread support that is needed  by the 'main' program

  { TThreadController }

  TThreadController = class(TWasmThreadSupport)
  private
    FInitialWorkerCount: Integer;
    FMaxWorkerCount: Integer;
    FOnUnknownMessage: TJSRawEventHandler;
    FHost: TWASIHost;
    FWorkerScript: String;
    FNextIDRange : Integer;
    FNextThreadID : Integer;
    procedure SetWasiHost(AValue: TWASIHost);
  Protected
    procedure RunTimeOut(aInfo: TThreadInfo; aInterval: Integer); virtual;
    function thread_spawn(start_arg : longint) : longint; override;
    Function thread_detach(thread_id : longint) : Integer; override;
    Function thread_cancel(thread_id : longint) : Integer; override;
    Function thread_self() : Integer; override;
    function AllocateThreadID : Integer;
  Protected
    FIdleWorkers : Array of TWasmThread;
    FBusyWorkers : Array of TWasmThread;
    FThreads : TThreadHash; // ThreadID is key,
    // Allocate new thread ID range
    function GetNextThreadIDRange: Integer;
    // Handle worker messages. If it is a command, it is set to handlecommand.
    procedure DoWorkerMessage(aEvent: TJSEvent);
    // Create & set up new worker
    Function AllocateNewWorker(Const aWorkerScript : string) : TWasmThread;
    // Send a load command
    procedure SendLoadCommand(aThreadWorker: TWasmThread); virtual;
    // Get new worker from pool, create new if needed.
    Function GetNewWorker : TWasmThread;
    // Spawn & prepare to run a new thread.
    Function SpawnThread(aInfo : TThreadInfo) : Integer;
    // Actually send run command.
    Procedure SendRunCommand(aThreadWorker: TWasmThread);
    //
    // Handle Various commands sent from worker threads.
    //
    // Allocate a new worker for a thread and run the thread if the worker is loaded.
    procedure HandleSpawnCommand(aWorker: TWasmThread; aCommand: TWorkerSpawnThreadCommand); virtual;
    // Cancel command: stop the thread
    procedure HandleCancelCommand(aWorker: TWasmThread; aCommand: TWorkerCancelCommand); virtual;
    // Cleanup thread : after join (or stopped if detached), free worker.
    procedure HandleCleanupCommand(aWorker: TWasmThread; aCommand: TWorkerCleanupCommand); virtual;
    // forward KILL signal to thread.
    procedure HandleKillCommand(aWorker: TWasmThread; aCommand: TWorkerKillCommand); virtual;
    // Worker script is loaded, has loaded webassembly and is ready to run.
    procedure HandleLoadedCommand(aWorker: TWasmThread; aCommand: TWorkerLoadedCommand); overload;
    // Console output from worker.
    procedure HandleConsoleCommand(aWorker: TWasmThread;  aCommand: TWorkerConsoleCommand);
  Public
    Constructor Create(aEnv : TPas2JSWASIEnvironment); override;
    Constructor Create(aEnv : TPas2JSWASIEnvironment; aWorkerScript : String; aSpawnWorkerCount : integer); virtual; overload;
    Procedure HandleCommand(aWorker : TWasmThread; aCommand : TWorkerCommand); overload; virtual;
    // Send load commands to all workers that still need it.
    procedure SendLoadCommands;
    // Name of worker script
    Property WorkerScript : String Read FWorkerScript;
    // Initial number of threads, set by constructor
    Property InitialWorkerCount : Integer Read FInitialWorkerCount;
    // Maximum number of workers. If more workers are requested, the GetNewWorker will return Nil.
    Property MaxWorkerCount : Integer Read FMaxWorkerCount Write FMaxWorkerCount;
    Property OnUnknownMessage : TJSRawEventHandler Read FOnUnknownMessage Write FOnUnknownMessage;
    // The WASI host, used to run routines.
    Property Host : TWASIHost Read FHost Write SetWasiHost;
  end;


implementation

Resourcestring
  SErrMaxWorkersReached = 'Cannot create thread worker, Maximum number of workers (%d) reached.';

{ TWasmThread }


class function TWasmThreadHelper.Create(aScript: String): TWasmThread;
begin
  Result:=TJSWorker.new(aScript);
  Result.ThreadID:=-1;
  Result.Loaded:=False;
  Result.LoadSent:=False;
  Result.ThreadIDRange:=-1;
  Result.ThreadInfo:=Default(TThreadInfo);
end;

function TWasmThreadHelper.GetLoaded: Boolean;
Var
  S : JSValue;
begin
  S:=Properties['FLoaded'];
  if isBoolean(S) then
    Result:=Boolean(S)
  else
    Result:=False;
end;

function TWasmThreadHelper.GetLoadSent: Boolean;

Var
  S : JSValue;
begin
  S:=Properties['FLoadSent'];
  if isBoolean(S) then
    Result:=Boolean(S)
  else
    Result:=False;
end;

function TWasmThreadHelper.GetThreadID: Integer;
begin
  Result:=ThreadInfo.ThreadID;
end;

function TWasmThreadHelper.GetThreadIDRange: Integer;
Var
  S : JSValue;
begin
  S:=Properties['FThreadIDRange'];
  if isNumber(S) then
    Result:=Integer(S)
  else
    Result:=0;
end;

function TWasmThreadHelper.GetThreadInfo: TThreadinfo;
Var
  S : JSValue;
begin
  S:=Properties['FThreadInfo'];
  if isObject(S) then
    Result:=TThreadinfo(S)
  else
    Result:=Default(TThreadInfo);
end;

procedure TWasmThreadHelper.SetLoaded(AValue: Boolean);
begin
  Properties['FLoaded']:=aValue
end;

procedure TWasmThreadHelper.SetLoadSent(AValue: Boolean);
begin
  Properties['FLoadSent']:=aValue;
end;



procedure TWasmThreadHelper.SetThreadID(AValue: Integer);
begin
  ThreadInfo.ThreadID:=aValue;
end;

procedure TWasmThreadHelper.SetThreadIDRange(AValue: Integer);
begin
  Properties['FThreadIDRange']:=aValue
end;

procedure TWasmThreadHelper.SetThreadInfo(AValue: TThreadinfo);
begin
  Properties['FThreadInfo']:=aValue
end;


procedure TWasmThreadHelper.SendCommand(aCommand: TWorkerCommand);
begin
  // Writeln('Sending command '+TJSJSON.Stringify(aCommand));
  PostMessage(aCommand);
end;

procedure TThreadController.DoWorkerMessage(aEvent: TJSEvent);

Var
  aMessageEvent : TJSMessageEvent absolute aEvent;
  aData : TWorkerCommand;
  aWorker : TWasmThread;

begin
  // Writeln('Received worker message '+TJSJSON.Stringify(aMessageEvent.Data));
  if IsObject(aMessageEvent.Data) and TJSObject(aMessageEvent.Data).hasOwnProperty('Command') then
    begin
    aData:=TWorkerCommand(aMessageEvent.Data);
    aWorker:=TWasmThread(aMessageEvent.Target);
    HandleCommand(aWorker,aData);
    end
  else if Assigned(FOnUnknownMessage) then
    FOnUnknownMessage(aEvent)
  else
    Writeln('Unknown worker message : ',TJSJSON.stringify(aEvent));
end;

function TThreadController.GetNextThreadIDRange : Integer;

begin
  Inc(FNextIDRange,ThreadIDInterval);
  Result:=FNextIDRange;
end;

function TThreadController.AllocateNewWorker(const aWorkerScript: string): TWasmThread;

begin
  // Writeln('Allocating new worker for: '+aWorkerScript);
  Result:=TWasmThread.Create(aWorkerScript);
  Result.ThreadIDRange:=GetNextThreadIDRange;
  Result.addEventListener('message',@DoWorkerMessage);
  if Assigned(Host) and Host.StartDescriptorReady then
    SendLoadCommand(Result)
  else
    Writeln('Host not set, delaying sending load command.'+aWorkerScript);
end;

procedure TThreadController.SendLoadCommand(aThreadWorker: TWasmThread);

Var
  WLC: TWorkerLoadCommand;

begin
  WLC:=TWorkerLoadCommand.Create(aThreadWorker.ThreadIDRange, Host.PreparedStartDescriptor.Module, Host.PreparedStartDescriptor.Memory);
  aThreadWorker.SendCommand(WLC);
  aThreadWorker.LoadSent:=True;
end;

function TThreadController.GetNewWorker: TWasmThread;

Var
  WT : TWasmThread;

begin
  if Length(FIdleWorkers)=0 then
    begin
    // Writeln('No idle workers, creating new one');
    if Length(FBusyWorkers)<MaxWorkerCount then
      WT:=AllocateNewWorker(FWorkerScript)
    else
      Raise EWasmThreads.Create(SErrMaxWorkersReached);
    end
  else
    begin
    WT:=TWasmThread(TJSArray(FIdleWorkers).pop);
    end;
  TJSArray(FBusyWorkers).Push(WT);
  Result:=WT;
end;


procedure TThreadController.SendRunCommand(aThreadWorker: TWasmThread);

Var
  WRC : TWorkerRunCommand;

begin
  With aThreadWorker.ThreadInfo do
    WRC:=TWorkerRunCommand.Create(ThreadID,Arguments);
  aThreadWorker.SendCommand(Wrc);
end;

procedure TThreadController.SetWasiHost(AValue: TWASIHost);


begin
  // Writeln('Setting wasi host');
  if FHost=AValue then
    Exit;
  FHost:=AValue;
  If Assigned(FHost) and Host.StartDescriptorReady then
    SendLoadCommands;
end;

function TThreadController.thread_spawn(start_arg : longint) : longint;

var
  aInfo : TThreadInfo;

begin
  Writeln('In host thread_spawn');
  aInfo.ThreadID:=AllocateThreadID;
  aInfo.Arguments:=start_arg;
  aInfo.OriginThreadID:=0;
  Result:=SpawnThread(aInfo);
end;

function TThreadController.thread_detach(thread_id: longint): Integer;
begin
  if thread_id=-1 then;
  Result:=-1;
end;

function TThreadController.thread_cancel(thread_id: longint): Integer;
begin
  if thread_id=-1 then;
  Result:=-1;
end;

function TThreadController.thread_self: Integer;
begin
  Result:=-1;
end;

function TThreadController.AllocateThreadID: Integer;
begin
  Inc(FNextThreadID);
  Result:=FNextThreadID;
end;

procedure TThreadController.SendLoadCommands;

Var
  WT : TWasmThread;

begin
  // Writeln('Sending load command to all workers');
  For WT in FIdleWorkers do
    if not WT.LoadSent then
      SendLoadCommand(WT);
end;

procedure TThreadController.RunTimeOut(aInfo: TThreadInfo; aInterval: Integer);

var
  Msg : String;

begin
  Msg:=Format('Failed to run thread %d spawned from thread %d: load timed out after %d ms.',[aInfo.ThreadID,aInfo.OriginThreadID,aInterval]);
  Writeln(msg);
end;

function TThreadController.SpawnThread(aInfo: TThreadInfo): Integer;

Var
  WT : TWasmThread;


begin
  // Writeln('Enter TThreadController.SpawnThread for ID ',aInfo.ThreadID);
  WT:=GetNewWorker;
  if WT=nil then
    begin
    Writeln('Error: no worker !');
    exit(-1)
    end;
  WT.ThreadInfo:=aInfo;
  FThreads[aInfo.ThreadID]:=WT;
  SendRunCommand(WT);
  Result:=aInfo.ThreadID
 // Writeln('Exit: TThreadController.SpawnThread for ID ',WT.ThreadID);
end;


constructor TThreadController.Create(aEnv: TPas2JSWASIEnvironment);
begin
  Create(aEnv,DefaultThreadWorker,DefaultThreadCount)
end;

constructor TThreadController.Create(aEnv: TPas2JSWASIEnvironment;
  aWorkerScript: String; aSpawnWorkerCount: integer);

Var
  I : Integer;

begin
  Inherited Create(aEnv);
  FThreads:=TThreadHash.new;
  FWorkerScript:=aWorkerScript;
  FInitialWorkerCount:=aSpawnWorkerCount;
  FMaxWorkerCount:=DefaultMaxWorkerCount;
  For I:=1 to aSpawnWorkerCount do
    TJSArray(FIdleWorkers).Push(AllocateNewWorker(aWorkerScript));
end;

procedure TThreadController.HandleSpawnCommand(aWorker : TWasmThread; aCommand: TWorkerSpawnThreadCommand);

Var
  aInfo: TThreadInfo;

begin
  aInfo.OriginThreadID:=aWorker.ThreadID;
  aInfo.ThreadID:=aCommand.ThreadID;
  aInfo.Arguments:=aCommand.Arguments;
  SpawnThread(aInfo);
end;

procedure TThreadController.HandleKillCommand(aWorker : TWasmThread; aCommand: TWorkerKillCommand);

begin
  if (aWorker<>Nil) and (aCommand<>Nil) then ;
  // todo
end;

procedure TThreadController.HandleCancelCommand(aWorker : TWasmThread; aCommand: TWorkerCancelCommand);

begin
  if (aWorker<>Nil) and (aCommand<>Nil) then ;
  // todo
end;

procedure TThreadController.HandleLoadedCommand(aWorker : TWasmThread; aCommand: TWorkerLoadedCommand);

begin
  // Writeln('Host: Entering TThreadController.HandleLoadedCommand');
  aWorker.Loaded:=True;
  // if a thread is scheduled to run in this thread, run it.
  if aWorker.ThreadID>0 then
    SendRunCommand(aWorker);
  // Writeln('Host: exiting TThreadController.HandleLoadedCommand');
  if (aCommand<>Nil) then ;
end;

procedure TThreadController.HandleCleanupCommand(aWorker : TWasmThread; aCommand: TWorkerCleanupCommand);

Var
  Idx : Integer;

begin
  aWorker.ThreadInfo:=Default(TThreadInfo);
  Idx:=TJSarray(FBusyWorkers).indexOf(aWorker);
  if Idx<>-1 then
    Delete(FBusyWorkers,Idx,1);
  Idx:=TJSarray(FIdleWorkers).indexOf(aWorker);
  if Idx=-1 then
    FIdleWorkers:=Concat(FIdleWorkers,[aWorker]);
  if (aCommand<>Nil) then ;
end;

procedure TThreadController.HandleConsoleCommand(aWorker : TWasmThread; aCommand: TWorkerConsoleCommand);

Var
  Prefix : string;

begin
  Prefix:=Format('Wasm thread %d: ',[aWorker.ThreadID]);
  if Assigned(Host.OnConsoleWrite) then
    Host.OnConsoleWrite(Host,Prefix+aCommand.ConsoleMessage)
  else
    Writeln(Prefix+aCommand.ConsoleMessage);
end;

procedure TThreadController.HandleCommand(aWorker : TWasmThread; aCommand: TWorkerCommand);
begin
  Case aCommand.Command of
    cmdSpawn : HandleSpawnCommand(aWorker, TWorkerSpawnThreadCommand(aCommand));
    cmdCleanup : HandleCleanupCommand(aWorker, TWorkerCleanupCommand(aCommand));
    cmdKill : HandleKillCommand(aWorker, TWorkerKillCommand(aCommand));
    cmdCancel : HandleCancelCommand(aWorker, TWorkerCancelCommand(aCommand));
    cmdLoaded : HandleLoadedCommand(aWorker, TWorkerLoadedCommand(aCommand));
    cmdConsole : HandleConsoleCommand(aWorker, TWorkerConsoleCommand(aCommand));
  else
    HandleCommand(aCommand);
  end;
end;


end.

