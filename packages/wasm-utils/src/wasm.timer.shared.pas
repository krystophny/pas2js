unit wasm.timer.shared;

{$mode ObjFPC}{$H+}

interface

Type
  TWasmTimerID = Longint;

const
  TimerExportName  = 'timer';
  TimerFN_Allocate = 'allocate';
  TimerFN_DeAllocate = 'deallocate';


implementation

end.

