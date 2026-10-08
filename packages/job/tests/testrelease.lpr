{ Browser regression for JOB object ID release.
  Distributed under the JOB package's modified LGPL terms; see the
  repository LICENSE and COPYING.txt. }

program testrelease;

{$mode objfpc}

uses SysUtils, JS, Web, WebAssembly, WasiEnv, JOB_Browser, JOB_Shared;

type
  TTestBridge = class(TJSObjectBridge)
    function ReleaseLocalObject(ID: TJOBObjectID): TJOBResult;
  end;

function TTestBridge.ReleaseLocalObject(ID: TJOBObjectID): TJOBResult;
begin
  Result := ReleaseObject(ID);
end;

procedure Check(Condition: Boolean; const Message: string);
begin
  if not Condition then
    raise Exception.Create(Message);
end;

var
  Environment: TPas2JSWASIEnvironment;
  Bridge: TTestBridge;
  Instance: TJSWebAssemblyInstance;
  ExportFixture: TJSObject;
  Released: TJSArray;
  ID, PreviousID, I: TJOBObjectID;
  MissingExportRejected: Boolean;

procedure RunTest;
begin
  // A WASM export fixture with an independently observable free list.
  // It deliberately supplies both exports so selecting the allocator is observable.
  asm
    $mod.ExportFixture = {
      memory: new WebAssembly.Memory({ initial: 1 }),
      allocationCalls: 0,
      nextID: 1,
      freeIDs: [],
      releasedIDs: [],
      AllocateJobObjectID: function() {
        this.allocationCalls++;
        return this.freeIDs.length ? this.freeIDs.pop() : this.nextID++;
      },
      ReleaseJobObjectID: function(id) {
        this.releasedIDs.push(id);
        this.freeIDs.push(id);
      },
      JOBCallback: function() { return 0; }
    };
    // Exported WASM functions do not depend on their JavaScript receiver.
    $mod.ExportFixture.AllocateJobObjectID = $mod.ExportFixture.AllocateJobObjectID.bind($mod.ExportFixture);
    $mod.ExportFixture.ReleaseJobObjectID = $mod.ExportFixture.ReleaseJobObjectID.bind($mod.ExportFixture);
    $mod.Instance = { exports: $mod.ExportFixture };
  end;
  Environment := TPas2JSWASIEnvironment.Create;
  Bridge := TTestBridge.Create(Environment);
  Environment.Instance := Instance;
  Environment.SetExports(TWASIExports(Instance.exports_));
  Released := TJSArray(ExportFixture['releasedIDs']);
  PreviousID := 0;
  for I := 1 to 20 do
  begin
    ID := Bridge.RegisterLocalObject(TJSObject.New);
    Check(Bridge.FindObject(ID) <> nil, 'registered object must be findable');
    if I > 1 then
      Check(ID = PreviousID, 'released ID must be reusable by the WASM allocator');
    Check(Bridge.ReleaseLocalObject(ID) = JOBResult_Success, 'release must succeed');
    Check(Bridge.FindObject(ID) = nil, 'released object must no longer be findable');
    Check(Released.length = I, 'each release must invoke the WASM release export once');
    Check(NativeInt(Released[I - 1]) = ID, 'release must pass the original object ID');
    Check(NativeInt(ExportFixture['allocationCalls']) = I, 'release must not allocate another ID');
    PreviousID := ID;
  end;

  // The allocator being present must not mask a missing release export.
  ID := Bridge.RegisterLocalObject(TJSObject.New);
  asm
    delete $mod.ExportFixture.ReleaseJobObjectID;
  end;
  MissingExportRejected := False;
  try
    Bridge.ReleaseLocalObject(ID);
  except
    on E: EJOBBridge do
      MissingExportRejected := True;
  end;
  Check(MissingExportRejected, 'missing WASM release export must be rejected');
  Check(NativeInt(ExportFixture['allocationCalls']) = 21, 'missing release must not call the allocator');
  document.body.textContent := 'PASS: 20 release/reuse cycles and missing release export';
end;

begin
  try
    RunTest;
  except
    on E: Exception do
      document.body.textContent := 'FAIL: ' + E.Message;
  end;
end.
