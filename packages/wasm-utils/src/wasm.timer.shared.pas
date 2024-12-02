unit wasm.timer.shared;

{$mode ObjFPC}{$H+}

interface

Type
  TWasmTimerID = Longint;

const
  TimerExportName  = 'timer';
  TimerFN_Allocate = 'allocate_timer';
  TimerFN_DeAllocate = 'deallocate_timer';


implementation

end.

