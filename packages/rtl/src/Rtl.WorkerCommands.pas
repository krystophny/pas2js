unit Rtl.WorkerCommands;

{$mode ObjFPC}
{$modeswitch externalclass}

interface

uses
  SysUtils, JS, WebOrWorker;

Type
  EWorkerCommand = Class(Exception);
  TCustomWorkerCommand = class external name 'Object' (TJSObject)
  private
    FCanceled : Boolean; external name 'canceled';
    FCommand : string; external name 'command';
  Public
    property Command : string read FCommand;
    property Canceled : Boolean read FCanceled;
  end;

  { TCustomWorkerCommandHelper }

  TCustomWorkerCommandHelper = class helper for TCustomWorkerCommand
    Procedure Cancel;
    class function createCommand(aCommand : string) : TCustomWorkerCommand; static;
  end;

  TForwardCommand = class external name 'Object' (TCustomWorkerCommand)
    DestinationWorker : string;
    Payload : TCustomWorkerCommand;
  end;

  { TWorwardCommandHelper }

  TWorwardCommandHelper = class helper (TCustomWorkerCommandHelper) for TForwardCommand
    class function create(const aDestinationWorker : string; aCommand :TCustomWorkerCommand) : TForwardCommand; static;
  end;


  TCommandDispatcher = class;
  TCommandDispatcherClass = class of TCommandDispatcher;

  TCommandHandler = Reference to procedure(aCommand : TCustomWorkerCommand);
  TCommandHandlerArray = array of TCommandHandler;

  { TCommandDispatcher }

  TCommandDispatcher = class(TObject)
  private
    Type
       TJSWorkerReg = record
         Worker : TJSWorker;
         Name : string;
       end;
    class var _Instance : TCommandDispatcher;
    class var _DispatcherClass : TCommandDispatcherClass;
    class function GetInstance: TCommandDispatcher; static;
  private
    FMap : TJSMap; // Key is command. Value is TCommandHandlerArray.
    FWorkers : Array of TJSWorkerReg;
  protected
    class function IsCommandEvent(aEvent: TJSEvent): Boolean;
    function IndexOfWorker(aWorker: TJSWorker): Integer;
    function IndexOfWorker(const aName: String): Integer;
    Procedure HandleIncomingMessage(aEvent : TJSEvent);
    procedure HandleCommand(aCommand: TCustomWorkerCommand); virtual;
  Public
    constructor create; virtual;
    // Send command to worker
    procedure SendCommand(aWorker : TJSWorker; aCommand : TCustomWorkerCommand); virtual;
    // Send command to worker
    procedure SendCommand(const aName : string; aCommand : TCustomWorkerCommand);
    // Send command to thread that started this worker. Cannot be used in main thread
    procedure SendCommand(aCommand : TCustomWorkerCommand); virtual;
    // Send command to all registered workers
    procedure BroadcastCommand(aCommand : TCustomWorkerCommand);
    // Register a command handler for command aCommand
    Procedure RegisterCommandHandler(const aCommand : string; aHandler : TCommandHandler);
    // Remove the given command handler for command aCommand
    Procedure UnRegisterCommandHandler(const aCommand : string; aHandler : TCommandHandler);
    // Register a worker for broadcast
    Procedure RegisterWorker(aWorker : TJSWorker; const aName : string);
    // Remove a worker from broadcast list
    Procedure UnRegisterWorker(aWorker : TJSWorker);
    Procedure UnRegisterWorker(const aName : string);
    Class function SetDispatcherClass(aClass : TCommandDispatcherClass) : TCommandDispatcherClass;
    Class property instance : TCommandDispatcher read GetInstance;
  end;

function CommandDispatcher : TCommandDispatcher;

implementation

function CommandDispatcher : TCommandDispatcher;
begin
  Result:=TCommandDispatcher.Instance;
end;

{ TCustomWorkerCommandHelper }

procedure TCustomWorkerCommandHelper.Cancel;
begin
  FCanceled:=True;
end;

class function TCustomWorkerCommandHelper.createCommand(aCommand: string): TCustomWorkerCommand;
begin
  Result:=TCustomWorkerCommand.New;
  Result.FCanceled:=False;
  Result.FCommand:=aCommand;
end;

{ TWorwardCommandHelper }

class function TWorwardCommandHelper.create(const aDestinationWorker: string; aCommand: TCustomWorkerCommand
  ): TForwardCommand;
begin
  Result:=TForwardCommand(CreateCommand('_forward'));
  Result.DestinationWorker:=aDestinationWorker;
  Result.Payload:=aCommand;
end;

{ TCommandDispatcher }

class function TCommandDispatcher.GetInstance: TCommandDispatcher; static;
var
  C : TCommandDispatcherClass;
begin
  if Not Assigned(_Instance) then
    begin
    C:=_DispatcherClass;
    if (C=Nil) then
      C:=TCommandDispatcher;
    _Instance:=C.Create;
    end;
  Result:=_Instance;

end;

class function TCommandDispatcher.IsCommandEvent(aEvent: TJSEvent): Boolean;
var
  lMessageEvent : TJSMessageEvent absolute aEvent;
  Obj : TJSObject;
begin
  Result:=assigned(aEvent) and isObject(lMessageEvent.Data);
  if Result then
    begin
    Obj:=TJSObject(lMessageEvent.Data);
    Result:=Obj.hasOwnProperty('command') and isString(Obj['command']);
    end;
end;

procedure TCommandDispatcher.HandleCommand(aCommand : TCustomWorkerCommand);
var
  lCmd : String;
  lValue : JSValue;
  lHandlers : TCommandHandlerArray absolute lValue;
  lHandler : TCommandHandler;

begin
  lCmd:=aCommand.Command;
  lValue:=FMap.get(lCmd);
  if assigned(lValue) then
    For lHandler in lHandlers do
      begin
      LHandler(aCommand);
      if aCommand.Canceled then
        break;
      end;
end;

procedure TCommandDispatcher.HandleIncomingMessage(aEvent: TJSEvent);
var
  lMessageEvent : TJSMessageEvent absolute aEvent;
begin
  if IsCommandEvent(aEvent) then
    HandleCommand(TCustomWorkerCommand(lMessageEvent.data))
end;

constructor TCommandDispatcher.create;
begin
  FMap:=TJSMap.new();
  if not isMainBrowserThread then
    Self_.addEventListener('message',@HandleIncomingMessage);
end;

procedure TCommandDispatcher.SendCommand(aWorker: TJSWorker; aCommand: TCustomWorkerCommand);
begin
  aWorker.postMessage(aCommand);
end;

procedure TCommandDispatcher.SendCommand(const aName: string; aCommand: TCustomWorkerCommand);
var
  Idx : integer;
begin
  Idx:=IndexOfWorker(aName);
  if Idx<0 then
    begin
    // let the main dispatcher forward it.
    if (isWebWorker or IsServiceWorker) then
      SendCommand(TForwardCommand.create(aName,aCommand))
    else
      Raise EWorkerCommand.CreateFmt('Unknown worker: %s',[aName]);
    end;
  SendCommand(FWorkers[Idx].Worker,aCommand);
end;

procedure TCommandDispatcher.SendCommand(aCommand: TCustomWorkerCommand);
begin
  if not (isWebWorker or IsServiceWorker) then
    Raise EWorkerCommand.Create('Cannot send to starting thread from main page');
  asm
  self.postMessage(aCommand);
  end;
end;

procedure TCommandDispatcher.BroadcastCommand(aCommand: TCustomWorkerCommand);
var
  lWorker : TJSWorkerReg;
begin
  For lWorker in FWorkers do
    SendCommand(lWorker.Worker,aCommand);
end;

procedure TCommandDispatcher.RegisterCommandHandler(const aCommand: string; aHandler: TCommandHandler);
var
  lValue : JSValue;
  lHandlers : TCommandHandlerArray absolute lValue;
begin
  lValue:=FMap.get(aCommand);
  if Assigned(lValue) then
    TJSArray(LHandlers).push(aHandler)
  else
    begin
    LHandlers:=[aHandler];
    FMap.&set(aCommand,LHandlers);
    end;
end;

procedure TCommandDispatcher.UnRegisterCommandHandler(const aCommand: string; aHandler: TCommandHandler);
var
  lValue : JSValue;
  lHandlers : TCommandHandlerArray absolute lValue;
  Idx : integer;
begin
  lValue:=FMap.get(aCommand);
  if Assigned(lValue) then
    begin
    Idx:=TJSArray(LHandlers).IndexOf(aHandler);
    if Idx>=0 then
      Delete(LHandlers,Idx,1);
    end;
end;

procedure TCommandDispatcher.RegisterWorker(aWorker: TJSWorker; const aName: string);
var
  lReg : TJSWorkerReg;
begin
  if IndexOfWorker(aName)>=0 then
    Raise EWorkerCommand.CreateFmt('Duplicate worker name: %s',[aName]);
  if IndexOfWorker(aWorker)>=0 then
    Raise EWorkerCommand.Create('Duplicate worker instance');
  lReg.Worker:=aWorker;
  lReg.Name:=aName;
  FWorkers:=Concat(FWorkers,[lReg]);
  aWorker.addEventListener('message',@HandleIncomingMessage);
end;

function TCommandDispatcher.IndexOfWorker(aWorker: TJSWorker) : Integer;

begin
  Result:=Length(FWorkers)-1;
  While (Result>=0) and (FWorkers[Result].Worker<>aWorker) do
    Dec(Result);
end;
function TCommandDispatcher.IndexOfWorker(const aName : String) : Integer;

begin
  Result:=Length(FWorkers)-1;
  While (Result>=0) and (FWorkers[Result].Name<>aName) do
    Dec(Result);
end;

procedure TCommandDispatcher.UnRegisterWorker(aWorker: TJSWorker);
var
  Idx : Integer;
begin
  Idx:=IndexOfWorker(aWorker);
  if Idx>=0 then
    Delete(FWorkers,Idx,1);
end;

procedure TCommandDispatcher.UnRegisterWorker(const aName: string);
var
  Idx : Integer;
begin
  Idx:=IndexOfWorker(aName);
  if Idx>=0 then
    Delete(FWorkers,Idx,1);
end;

class function TCommandDispatcher.SetDispatcherClass(aClass: TCommandDispatcherClass): TCommandDispatcherClass;
begin
  Result:=_DispatcherClass;
  _DispatcherClass:=aClass;
end;

end.

