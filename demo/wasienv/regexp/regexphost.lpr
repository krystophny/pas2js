program regexphost;

{$mode objfpc}
{$modeswitch externalclass}

uses
  BrowserConsole, BrowserApp, WASIHostApp, JS, Classes, SysUtils, Web, wasm.pas2js.regexp;

type
  THostConfig = class external name 'Object' (TJSObject)
    wasmFilename : String;
    logRegExpAPI : Boolean;
    logWasiAPI : Boolean;
  end;

var
  HostConfig : THostConfig; external name 'hostConfig';

Type
  { TMyApplication }

  TMyApplication = class(TWASIHostApplication)
    cbLog:TJSHTMLInputElement;
    FRegexp : TWasmRegExpAPI;
  private
    procedure HandleLogClick(Event: TJSEvent);
  protected
    procedure DoRun; override;
  public
    Constructor Create(aOwner : TComponent); override;
  end;

procedure TMyApplication.DoRun;
begin
  StartWebAssembly('wasmregexpdemo.wasm');
end;

procedure TMyApplication.HandleLogClick(Event : TJSEvent);

begin
  FRegexp.LogAPICalls:=cbLog.Checked;
end;

constructor TMyApplication.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FRegexp:=TWasmRegExpAPI.Create(WasiEnvironment);
  if isDefined(hostConfig) and Assigned(hostConfig) then
     begin
     WasiEnvironment.LogAPI:=HostConfig.logWasiAPi;
     FRegexp.LogAPICalls:=HostConfig.logRegExpAPI;
     end;
  cbLog:=TJSHTMLInputElement(GetHTMLElement('cbLog'));
  cbLog.Checked:=FRegexp.LogAPICalls;
  cbLog.addEventListener('click',@HandleLogClick);
end;

var
  Application : TMyApplication;

begin
  Application:=TMyApplication.Create(nil);
  Application.Initialize;
  Application.Run;
end.
