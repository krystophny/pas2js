{$IFNDEF FPC_DOTTEDUNITS}
unit wasithreadedapp;
{$ENDIF}

{$mode ObjFPC}
{$modeswitch externalclass}
{$modeswitch typehelpers}

interface

uses
{$IFDEF FPC_DOTTEDUNITS}
  JSApi.JS, System.Classes, System.SysUtils, System.WebThreads, Wasi.Env, Fcl.App.Wasi.Host, Rtl.WorkerCommands, Rtl.ThreadController
  BrowserApi.WebOrWorker;
{$ELSE} 
  JS, Classes, SysUtils, Rtl.WebThreads, wasienv, wasihostapp, Rtl.WorkerCommands, Rtl.ThreadController;
{$ENDIF}

Type
  { TBrowserWASIThreadedHostApplication }

  TBrowserWASIThreadedHostApplication = TBrowserWASIHostApplication;

  { ThreadAppWASIHost }

  ThreadAppWASIHost = class(TWASIHost)
  private
  Protected
    class function NeedSharedMemory: Boolean; override;
    function GetThreadSupport: TThreadController; virtual;
    Procedure DoAfterInstantiate; override;
    Function CreateWasiEnvironment : TPas2JSWASIEnvironment; override;
  Public
    Property ThreadSupport : TThreadController Read GetThreadSupport;
  end;

  { TThreadConsoleOutput }

  TThreadConsoleOutputEvent = reference to procedure(const Msg : string);
  TThreadConsoleOutput = Class (TObject)
  private
    class var _Instance : TThreadConsoleOutput;
  private
    FEnabled: boolean;
    FOnOutput: TThreadConsoleOutputEvent;
    class function GetInstance: TThreadConsoleOutput; static;
    procedure HandleConsoleMessage(aCommand: TCustomWorkerCommand); virtual;
  Public
    class constructor done;
    constructor Create; virtual;
    class property Instance : TThreadConsoleOutput Read _Instance;
    property Enabled : boolean Read FEnabled Write FEnabled;
    property OnOutput : TThreadConsoleOutputEvent Read FOnOutput Write FOnOutput;
  end;

implementation

class function ThreadAppWASIHost.NeedSharedMemory: Boolean;
begin
  Result:=True;
end;

function ThreadAppWASIHost.GetThreadSupport: TThreadController;
begin
  Result:=TThreadController.Instance as TThreadController;
end;

procedure ThreadAppWASIHost.DoAfterInstantiate;
begin
  inherited DoAfterInstantiate;
  If Assigned(ThreadSupport) then
    // Will send load commands
    ThreadSupport.SetWasmModuleAndMemory(PreparedStartDescriptor.Module,PreparedStartDescriptor.Memory);
end;

function ThreadAppWASIHost.CreateWasiEnvironment: TPas2JSWASIEnvironment;
begin
  Result:=inherited CreateWasiEnvironment;
  TWasmThreadSupportApi.Create(Result);
end;

{ TThreadConsoleOutput }

class function TThreadConsoleOutput.GetInstance: TThreadConsoleOutput; static;
begin
  if _instance=Nil then
    _Instance:=TThreadConsoleOutput.Create;
  Result:=_instance;
end;

procedure TThreadConsoleOutput.HandleConsoleMessage(aCommand : TCustomWorkerCommand);
var
  D : TWorkerConsoleCommand absolute aCommand;
  Msg : String;

begin
  Msg:=D.ConsoleMessage;
  if D.SenderID<>'' then
    Msg:='['+D.SenderID+'] '+Msg;
  if assigned(OnOutput) then
    OnOutPut(Msg)
  else
    Writeln(Msg);
end;

class constructor TThreadConsoleOutput.done;
begin
  FreeAndNil(_Instance);
end;

constructor TThreadConsoleOutput.Create;
begin
  TCommandDispatcher.Instance.RegisterCommandHandler(cmdConsole,@HandleConsoleMessage);
  FEnabled:=True;
end;

initialization
  TCommandDispatcher.Instance.DefaultSenderID:='HTML page thread';
  TThreadConsoleOutput._Instance:=TThreadConsoleOutput.Create;
  TWASIHostApplication.SetWasiHostClass(ThreadAppWASIHost);
end.

