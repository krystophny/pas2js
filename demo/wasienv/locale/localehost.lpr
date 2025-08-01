program localehost;

{$mode objfpc}

uses
  BrowserConsole, BrowserApp, WASIHostApp, JS, Classes, SysUtils, Web, wasm.pas2js.locale;

type

  { TMyApplication }

  TMyApplication = class(TWASIHostApplication)
  protected
    FLocaleAPI : TWasmLocaleAPI;
    procedure DoRun; override;
  public
    destructor destroy;override;
  end;

procedure TMyApplication.DoRun;
begin
  FLocaleAPI:=TWasmLocaleAPI.Create(WasiEnvironment);
  WasiEnvironment.Environment.Values['TZ']:=FLocaleAPI.GetTimeZoneVar(TJSDate.New);
  StartWebAssembly('localedemo.wasm');
end;

destructor TMyApplication.destroy;
begin
  FLocaleAPI.Free;
  inherited destroy;
end;

var
  Application : TMyApplication;

begin
  Application:=TMyApplication.Create(nil);
  Application.Initialize;
  Application.Run;
end.
