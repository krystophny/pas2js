program wasmthreadcontroller;

{$mode objfpc}

uses
  Classes, WasiWorkerThreadHost;

type
  { TApplication }

  TApplication = class(TWorkerThreadControllerApplication)
  end;

{ TApplication }

var
  App: TApplication;

begin
  App:=TApplication.Create(nil);
  App.Run;
end.
