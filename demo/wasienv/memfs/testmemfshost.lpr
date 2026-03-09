program testmemfshost;

{
  Host program (Pas2JS) for testmemfs.wasm.
  Uses TWASIMemFS instead of TWASIZenFS - no external JS dependencies.
}

{$mode objfpc}

uses
  BrowserConsole, BrowserApp, WASIHostApp, JS, Classes, SysUtils, Web, wasitypes, wasimemfs;

type
  TMyApplication = class(TWASIHostApplication)
  protected
    FS: TWASIMemFS;
    procedure DoRun; override;
  public
  end;

procedure TMyApplication.DoRun;
begin
  FS := TWASIMemFS.Create;
  FS.Storage := window.localStorage;
  FS.StorageKeyPrefix := 'memfs:';
  WasiEnvironment.FS := FS;
  StartWebAssembly('testmemfs.wasm');
end;

var
  Application: TMyApplication;

begin
  ConsoleStyle := DefaultCRTConsoleStyle;
  MaxConsoleLines:=50;
  HookConsole;
  Application := TMyApplication.Create(nil);
  Application.Initialize;
  Application.Run;
end.
