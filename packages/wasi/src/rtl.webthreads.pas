{
    This file is part of the Pas2JS run time library.
    Copyright (c) 2017-2020 by the Pas2JS development team.

    Threads API for Browser Window & Worker
    
    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$IFNDEF FPC_DOTTEDUNITS}
unit Rtl.WebThreads;
{$ENDIF}

{$mode ObjFPC}
{$modeswitch externalclass}

interface

uses
{$IFDEF FPC_DOTTEDUNITS}
  JSApi.JS, System.SysUtils, Wasi.Env, BrowserApi.WebAssembly;
{$ELSE}
  JS, SysUtils, wasienv, webassembly;
{$ENDIF}  

Const
  // Each thread starts spawning at 1000*IndexOfWorker
  ThreadIDInterval = 1000;
  // When the thread ID reaches this limit, then it requests a new block
  ThreadIDMargin = 2;

  // lowercase !!
  cmdConsole = 'console';
  cmdException = 'exception';
  cmdCleanup = 'cleanup';
  cmdCancel = 'cancel';
  cmdLoaded = 'loaded';
  cmdKill = 'kill';
  cmdNeedIdBlock = 'needidblock';
  cmdThreadIdRange = 'threadidrange';
  cmdSpawn = 'spawn';
  cmdLoad = 'load';
  cmdRun = 'run';
  cmdExecute = 'execute';
  cmdRPC = 'rpc';
  cmdRPCResult = 'rpcresult';

  channelConsole = 'console_output';

  DefaultThreadWorker = 'pas2jsthreadworker.js';
  DefaultThreadCount = 2;
  DefaultMaxWorkerCount = 100;

  // Default exported thread entry point. Must have signature TThreadEntryPointFunction
  DefaultThreadEntryPoint = 'wasi_thread_start';

  // Imports to wasi env.
  sThreadSpawn = 'thread-spawn';
  sThreadDetach = 'thread_detach';
  sThreadCancel = 'thread_cancel';
  sThreadSelf = 'thread_self';



Type
  // aRunProc and aArgs are pointers inside wasm.
  TThreadEntryPointFunction = Function(ThreadId: Integer; aArgs: Integer) : Integer;

  EWasmThreads = class(Exception);

  // Commands sent between thread workers and main program.

  { Basic TWorkerCommand. Command is the actual command }

  { we do not use Pascal classes for this, to avoid transferring unnecessary metadata present in the pascal class }

  TWorkerCommand = Class external name 'Object' (TJSObject)
    Command : String;
    ThreadID : Integer; // Meaning depends on actual command.
    TargetID : Integer; // Forward to thread ID
  end;
  TCommandNotifyEvent = Procedure (Sender : TObject; aCommand : TWorkerCommand) of object;

  { TWorkerCommandHelper }

  TWorkerCommandHelper = class helper for TWorkerCommand
    Class function NewWorker(const aCommand : string; aThreadID : Integer = -1) : TWorkerCommand; static;
  end;

  { TWorkerExceptionCommand }

  // When an unexpected error occurred.
  TWorkerExceptionCommand = class external name 'Object' (TWorkerCommand)
  public
    ExceptionClass: String;
    ExceptionMessage: String;
  end;

  { TWorkerExceptionCommandHelper }

  TWorkerExceptionCommandHelper = class helper for TWorkerExceptionCommand
    Class function CommandName : string; static;
    Class function CreateNew(const aExceptionClass,aExceptionMessage : string; aThreadID : Integer = -1) : TWorkerExceptionCommand; static;
  end;

  { TWorkerConsoleCommand }

  // Sent by worker to main: write message to console
  // Thread ID : sending console ID
  TWorkerConsoleCommand = class external name 'Object' (TWorkerCommand)
  public
    ConsoleMessage : String;
  end;

  { TWorkerConsoleCommandHelper }

  TWorkerConsoleCommandHelper = class helper for TWorkerConsoleCommand
    Class function CommandName : string; static;
    Class function Create(const aMessage : string; aThreadID : Integer = -1) : TWorkerConsoleCommand; static; reintroduce;
    Class function Create(const aMessage : array of JSValue; aThreadID : Integer = -1) : TWorkerConsoleCommand; static; reintroduce;
  end;

  // Cleanup thread info: put this worker into unusued workers
  TWorkerCleanupCommand = class external name 'Object' (TWorkerCommand)
  end;

  { TWorkerCleanupCommandHelper }

  TWorkerCleanupCommandHelper = class helper for TWorkerCleanupCommand
    Class function CommandName : string; static;
    Class function Create(aThreadID : Integer): TWorkerCleanupCommand; static;  reintroduce;
  end;


  { TWorkerKillCommand }
  // Kill thread (thread ID in ThreadID)
  TWorkerKillCommand = class external name 'Object' (TWorkerCommand)
  end;

  { TWorkerCleanupCommandHelper }

  TWorkerKillCommandHelper = class helper for TWorkerKillCommand
    Class function CommandName : string; static;
    Class function Create(aThreadID : Integer): TWorkerKillCommand; static;reintroduce;
  end;

  // Cancel thread (thread ID in ThreadID)
  TWorkerCancelCommand = class external name 'Object' (TWorkerCommand)
  end;

  { TWorkerCancelCommandHelper }

  TWorkerCancelCommandHelper = class helper for TWorkerCancelCommand
    Class function CommandName : string; static;
    Class function Create(aThreadID : Integer): TWorkerCancelCommand; static; reintroduce;
  end;

  // sent to notify main thread that the wasm module is loaded.
  TWorkerLoadedCommand = class external name 'Object' (TWorkerCommand)
  end;

  { TWorkerLoadedCommandHelper }

  TWorkerLoadedCommandHelper = class helper for TWorkerLoadedCommand
    Class function CommandName : string; static;
    Class function Create: TWorkerLoadedCommand; static; reintroduce;
  end;

  // Sent to notify main thread that a new range of IDs is needed.
  TWorkerNeedIdBlockCommand = class external name 'Object' (TWorkerCommand)
    Current : NativeInt;
  end;

  { TWorkerNeedIdBlockCommandHelper }

  TWorkerNeedIdBlockCommandHelper = class helper for TWorkerNeedIdBlockCommand
    Class function CommandName : string; static;
    Class function Create(aCurrent : NativeInt): TWorkerNeedIdBlockCommand; static; reintroduce;
  end;


  // Sent to notify main thread that a new thread must be started.
  // Worker cannot start new thread. It allocates the ID (threadId)
  // It sends RunFunction, Attributes and Arguments received by thread_spawn call.
  TWorkerSpawnThreadCommand = class external name 'Object' (TWorkerCommand)
    Arguments : Integer;
  end;

  { TWorkerSpawnThreadCommandHelper }

  TWorkerSpawnThreadCommandHelper = class helper for TWorkerSpawnThreadCommand
    Class function CommandName : string; static;
    class function Create(aThreadID: integer; aArgs: Integer): TWorkerSpawnThreadCommand; static; reintroduce;
  end;



  // Sent by main to worker: load wasm module
  TWorkerLoadCommand = class external name 'Object' (TWorkerCommand)
  public
    Memory : TJSWebAssemblyMemory;
    Module : TJSWebAssemblyModule;
    ThreadRangeStart : NativeInt;
  end;

  { TWorkerLoadCommandHelper }

  TWorkerLoadCommandHelper = class helper for TWorkerLoadCommand
    Class function CommandName : string; static;
    Class function Create(aStartThreadIdRange : integer; aModule : TJSWebAssemblyModule; aMemory : TJSWebAssemblyMemory): TWorkerLoadCommand; static;reintroduce;
  end;


  // Sent by main to worker: run thread procedure
  TWorkerRunCommand = class external name 'Object' (TWorkerCommand)
  public
    ThreadInfo : Integer;
    Attrs : Integer;
    Args : Integer;
  end;

  // Sent by main to thread controller worker: execute function
  TWorkerExecuteCommand = class external name 'Object' (TWorkerCommand)
  public
    Url : String;
    ExecuteFunc : string;
    Env : TJSObject;
  end;

  // Sent by main to thread controller worker: run function, return result
  TWorkerRpcCommand = class external name 'Object' (TWorkerCommand)
  public
    method : string;
    id : string;
    params : TJSArray;
    jsonrpc : string;
  end;

  TWorkerRPCError = class external name 'Object' (TJSObject)
    code : integer;
    message : string;
    data : JSValue;
  end;

  TWorkerRpcResultCommand = class external name 'Object' (TWorkerCommand)
  public
    method : string;
    result : jsValue;
    id : string;
    error : TWorkerRPCError;
    jsonrpc : string;
  end;


  { TWorkerRunCommandHelper }

  // Sent by main to thread controller worker: load and start a webassembly
  TWorkerRunCommandHelper = class helper for TWorkerRunCommand
    Class function CommandName : string; static;
    Class function Create(aThreadID, aArgs : Longint): TWorkerRunCommand; static; reintroduce;
  end;

  { TWorkerRpcCommandHelper }

  TWorkerRpcCommandHelper = class helper for TWorkerRpcCommand
    Class function CommandName : string; static;
    Class function Create(aID : String; aMethod : String; aParams : TJSArray): TWorkerRpcCommand; static; reintroduce;
  end;

  { TWorkerRpcResultCommandHelper }

  TWorkerRpcResultCommandHelper = class helper for TWorkerRpcResultCommand
    Class function CommandName : string; static;
    Class function Create(aID : String; aResult : JSValue): TWorkerRpcResultCommand; static; reintroduce;
    Class function CreateError(aID : String; aCode : Integer; aMessage : string): TWorkerRpcResultCommand; static; reintroduce;
    Class function CreateError(aID : String; aCode : Integer; aMessage : string; aData : JSValue): TWorkerRpcResultCommand; static; reintroduce;
  end;



  // Sent to worker with new range of thread IDs.
  TWorkerThreadIDRangeCommand = class external name 'Object' (TWorkerCommand)
    RangeStart : NativeInt;
  end;

  { TWorkerThreadIDRangeCommandHelper }

  TWorkerThreadIDRangeCommandHelper = class helper for TWorkerThreadIDRangeCommand
    Class function CommandName : string; static;
    class function Create(aRangeStart: NativeInt): TWorkerThreadIDRangeCommand;  static; reintroduce;
  end;



  TThreadinfo = record
    OriginThreadID : longint; // Numerical thread ID
    ThreadID : longint; // Numerical thread ID
    Arguments : longint;  // Arguments (pointer)
  end;

  // This basis object has the thread support that is needed by the WASM module.
  // It relies on descendents to implement the actual calls.

  { TWasmThreadSupport }

  TWasmPointer = Longint;
  TWasmThreadSupport = Class (TImportExtension)
  private
    FOnSendCommand: TCommandNotifyEvent;
  Protected

    // Proposed WASI standard, modeled after POSIX pthreads.
    function thread_spawn(start_arg : longint) : longint; virtual; abstract;
    Function thread_detach(thread_id : longint) : Integer; virtual; abstract;
    Function thread_cancel(thread_id : longint) : Integer; virtual; abstract;
    Function thread_self() : Integer; virtual; abstract;
  Public
    Function ImportName : String; override;
    procedure FillImportObject(aObject: TJSObject); override;
    Procedure HandleCommand(aCommand : TWorkerCommand); virtual;
    Procedure SendCommand(aCommand : TWorkerCommand); virtual;
    // Set this to actually send commands. Normally set by TWorkerWASIHostApplication
    Property OnSendCommand : TCommandNotifyEvent Read FOnSendCommand Write FOnSendCommand;


  end;


implementation

{ TWorkerRunCommandHelper }

class function TWorkerRunCommandHelper.CommandName: string;
begin
  Result:=cmdRun;
end;

class function TWorkerRunCommandHelper.Create(aThreadID, aArgs: integer): TWorkerRunCommand;
begin
  Result:=TWorkerRunCommand(TWorkerCommand.NewWorker(CommandName));
  Result.ThreadID:=aThreadID;
  Result.Args:=aArgs;
end;

{ TWorkerRpcCommandHelper }

class function TWorkerRpcCommandHelper.CommandName: string;
begin
  Result:=cmdRpc;
end;

class function TWorkerRpcCommandHelper.Create(aID: String; aMethod: String; aParams: TJSArray): TWorkerRpcCommand;
begin
  Result:=TWorkerRpcCommand(TWorkerCommand.NewWorker(CommandName));
  Result.id:=aID;
  Result.Method:=aMethod;
  Result.Params:=aParams;
end;

{ TWorkerRpcResultCommandHelper }

class function TWorkerRpcResultCommandHelper.CommandName: string;
begin
  result:=cmdRPCResult;
end;

class function TWorkerRpcResultCommandHelper.Create(aID: String; aResult: JSValue): TWorkerRpcResultCommand;
begin
  Result:=TWorkerRpcResultCommand(TWorkerCommand.NewWorker(CommandName));
  Result.id:=aID;
  Result.result:=aResult;
  Result.jsonrpc:='2.0';
end;

class function TWorkerRpcResultCommandHelper.CreateError(aID: String; aCode: Integer; aMessage: string): TWorkerRpcResultCommand;
begin
  Result:=TWorkerRpcResultCommand(TWorkerCommand.NewWorker(CommandName));
  Result.Id:=aID;
  Result.Error:=TWorkerRPCError.New;
  Result.Error.Code:=aCode;
  Result.Error.Message:=aMessage;
  Result.jsonrpc:='2.0';
end;

class function TWorkerRpcResultCommandHelper.CreateError(aID: String; aCode: Integer; aMessage: string; aData: JSValue
  ): TWorkerRpcResultCommand;
begin
  Result:=CreateError(aID,aCode,aMessage);
  Result.Error.Data:=aData;
end;

{ TWorkerLoadCommandHelper }

class function TWorkerLoadCommandHelper.CommandName: string;
begin
  Result:=cmdLoad;
end;

class function TWorkerLoadCommandHelper.Create(aStartThreadIdRange: integer;
  aModule: TJSWebAssemblyModule; aMemory: TJSWebAssemblyMemory
  ): TWorkerLoadCommand;
begin
  Result:=TWorkerLoadCommand(TWorkerCommand.NewWorker(CommandName));
  Result.ThreadRangeStart:=aStartThreadIdRange;
  Result.Memory:=aMemory;
  Result.Module:=aModule;
end;

{ TWorkerSpawnThreadCommandHelper }

class function TWorkerSpawnThreadCommandHelper.CommandName: string;
begin
  Result:=cmdSpawn
end;

class function TWorkerSpawnThreadCommandHelper.Create(aThreadID: integer; aArgs : Integer): TWorkerSpawnThreadCommand;
begin
  Result:=TWorkerSpawnThreadCommand(TWorkerCommand.NewWorker(CommandName,aThreadID));
  Result.Arguments:=aArgs;
end;

{ TWorkerThreadIDRangeCommandHelper }

class function TWorkerThreadIDRangeCommandHelper.CommandName: string;
begin
  Result:=cmdThreadIdRange;
end;

class function TWorkerThreadIDRangeCommandHelper.Create(aRangeStart: NativeInt
  ): TWorkerThreadIDRangeCommand;
begin
  Result:=TWorkerThreadIDRangeCommand(TWorkerCommand.NewWorker(CommandName));
  Result.RangeStart:=aRangeStart;
end;

{ TWorkerNeedIdBlockCommandHelper }

class function TWorkerNeedIdBlockCommandHelper.CommandName: string;
begin
  Result:=cmdNeedIdBlock;
end;

class function TWorkerNeedIdBlockCommandHelper.Create(aCurrent: NativeInt
  ): TWorkerNeedIdBlockCommand;
begin
  Result:=TWorkerNeedIdBlockCommand(TWorkerCommand.NewWorker(CommandName));
  Result.Current:=aCurrent;
end;


{ TWorkerLoadedCommandHelper }

class function TWorkerLoadedCommandHelper.CommandName: string;
begin
  Result:=cmdLoaded;
end;

class function TWorkerLoadedCommandHelper.Create: TWorkerLoadedCommand;
begin
  Result:=TWorkerLoadedCommand(TWorkerCommand.NewWorker(CommandName));
end;

{ TWorkerCancelCommandHelper }

class function TWorkerCancelCommandHelper.CommandName: string;
begin
  result:=cmdCancel;
end;

class function TWorkerCancelCommandHelper.Create(aThreadID: Integer
  ): TWorkerCancelCommand;
begin
  Result:=TWorkerCancelCommand(TWorkerCommand.NewWorker(CommandName,aThreadID));
end;

{ TWorkerKillCommandHelper }

class function TWorkerKillCommandHelper.CommandName: string;
begin
  Result:=cmdKill
end;

class function TWorkerKillCommandHelper.Create(aThreadID : Integer): TWorkerKillCommand;
begin
  Result:=TWorkerKillCommand(TWorkerCommand.NewWorker(CommandName,aThreadID));
end;

{ TWorkerCleanupCommandHelper }

class function TWorkerCleanupCommandHelper.CommandName: string;
begin
  Result:=cmdCleanup
end;

class function TWorkerCleanupCommandHelper.Create(aThreadID: Integer): TWorkerCleanupCommand;
begin
  Result:=TWorkerCleanupCommand(TWorkerCommand.NewWorker(CommandName,aThreadID));
end;

{ TWorkerConsoleCommandHelper }

class function TWorkerConsoleCommandHelper.CommandName: string;
begin
  Result:=cmdConsole;
end;

class function TWorkerConsoleCommandHelper.Create(
  const aMessage: string; aThreadID : Integer = -1): TWorkerConsoleCommand;
begin
  Result:=TWorkerConsoleCommand(TWorkerCommand.NewWorker(CommandName,aThreadID));
  Result.ConsoleMessage:=aMessage;
end;

class function TWorkerConsoleCommandHelper.Create(
  const aMessage: array of JSValue; aThreadID : Integer = -1): TWorkerConsoleCommand;
begin
  Result:=Create(TJSArray(aMessage).join(' '),aThreadID);
end;

{ TWorkerExceptionCommandHelper }

class function TWorkerExceptionCommandHelper.CommandName: string;
begin
  Result:=cmdException;
end;

class function TWorkerExceptionCommandHelper.CreateNew(const aExceptionClass,aExceptionMessage: string; aThreadID : Integer = -1  ): TWorkerExceptionCommand;
begin
  Result:=TWorkerExceptionCommand(TWorkerCommand.NewWorker(CommandName,aThreadID));
  Result.ExceptionClass:=aExceptionClass;
  Result.ExceptionMessage:=aExceptionMessage;
end;

{ TWorkerCommandHelper }

class function TWorkerCommandHelper.NewWorker(const aCommand : string; aThreadID : Integer = -1): TWorkerCommand;
begin
  Result:=TWorkerCommand.New;
  Result.Command:=LowerCase(aCommand);
  if aThreadID<>-1 then
    Result.ThreadID:=aThreadID;
end;


{ TWasmThreadSupport }

function TWasmThreadSupport.ImportName: String;
begin
  Result:='wasi';
end;

procedure TWasmThreadSupport.FillImportObject(aObject: TJSObject);
begin
  aObject[sThreadSpawn]:=@Thread_Spawn;
  aObject[sThreadDetach]:=@Thread_Detach;
  aObject[sThreadCancel]:=@Thread_Cancel;
  aObject[sThreadSelf]:=@Thread_Self;
end;


procedure TWasmThreadSupport.HandleCommand(aCommand: TWorkerCommand);

Var
  P : TWorkerExceptionCommand;

begin
  P:=TWorkerExceptionCommand.New;
  P.ExceptionClass:='ENotSupportedException';
  P.ExceptionMessage:='Unsupported command : '+TJSJSON.Stringify(aCommand);
  SendCommand(P);
end;

procedure TWasmThreadSupport.SendCommand(aCommand: TWorkerCommand);
begin
  if Assigned(FOnSendCommand) then
    FOnSendCommand(Self,aCommand);
end;


end.

