{$IFNDEF FPC_DOTTEDUNITS}
unit wasithreadedapp;
{$ENDIF}

{$mode ObjFPC}
{$modeswitch externalclass}
{$modeswitch typehelpers}

interface

uses
{$IFDEF FPC_DOTTEDUNITS}
  JSApi.JS, System.Classes, System.SysUtils, System.WebThreads, Wasi.Env, Fcl.App.Wasi.Host, Rtl.ThreadController
  BrowserApi.WebOrWorker;
{$ELSE} 
  JS, Classes, SysUtils, Rtl.WebThreads, wasienv, wasihostapp, weborworker, Rtl.ThreadController;
{$ENDIF}

Type
  TMainThreadSupport = class(TThreadController);

  { TBrowserWASIThreadedHostApplication }

  TBrowserWASIThreadedHostApplication = class(TBrowserWASIHostApplication)
  private
    FThreadSupport: TMainThreadSupport;
    FConsoleChannel : TJSBroadCastChannel;
    procedure HandleConsoleMessage(aEvent: TJSEvent);
  protected
    Function CreateThreadSupport(aEnv : TPas2JSWASIEnvironment) : TMainThreadSupport; virtual;
    Function CreateHost: TWASIHost; override;
  Public
    constructor Create(aOwner: TComponent); override;
    Destructor Destroy; override;
    Property ThreadSupport : TMainThreadSupport Read FThreadSupport;
  end;

  { ThreadAppWASIHost }

  ThreadAppWASIHost = class(TWASIHost)
  private
    FThreadSupport: TMainThreadSupport;
    procedure SetThreadSupport(AValue: TMainThreadSupport);
  Protected
    Procedure DoAfterInstantiate; override;
  Public
    Property ThreadSupport : TMainThreadSupport Read FThreadSupport Write SetThreadSupport;
  end;


implementation

{ ThreadAppWASIHost }

procedure ThreadAppWASIHost.SetThreadSupport(AValue: TMainThreadSupport);
begin
  if FThreadSupport=AValue then Exit;
  FThreadSupport:=AValue;
  FThreadSupport.Host:=Self;
end;

procedure ThreadAppWASIHost.DoAfterInstantiate;
begin
  inherited DoAfterInstantiate;
  If Assigned(FThreadSupport) then
    FThreadSupport.SendLoadCommands;
end;

{ TBrowserWASIThreadedHostApplication }

function TBrowserWASIThreadedHostApplication.CreateThreadSupport(
  aEnv: TPas2JSWASIEnvironment): TMainThreadSupport;
begin
  Result:=TMainThreadSupport.Create(aEnv);
end;

function TBrowserWASIThreadedHostApplication.CreateHost: TWASIHost;

Var
  Res : ThreadAppWASIHost;

begin
  Res:=ThreadAppWASIHost.Create(Self);
  Res.UseSharedMemory:=True;
  Res.ThreadSupport:=CreateThreadSupport(Res.WasiEnvironment);

  Result:=Res;
end;

procedure TBrowserWASIThreadedHostApplication.HandleConsoleMessage(aEvent : TJSEvent);

var
  E : TJSMessageEvent absolute aEvent;
  D : TWorkerCommand;

begin
  if not isObject(E.Data) then exit;
  D:=TWorkerCommand(E.Data);
  if D.Command=cmdConsole then
    Writeln(TWorkerConsoleCommand(d).ConsoleMessage);
end;

constructor TBrowserWASIThreadedHostApplication.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FConsoleChannel:=TJSBroadCastChannel.New(channelConsole);
  FConsoleChannel.addEventListener('message',@HandleConsoleMessage);
end;


destructor TBrowserWASIThreadedHostApplication.Destroy;
begin
  FConsoleChannel.Close;
  FConsoleChannel:=Nil;
  FreeAndNil(FThreadSupport);
  inherited Destroy;
end;


end.

