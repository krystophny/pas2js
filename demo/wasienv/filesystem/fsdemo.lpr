program fsdemo;

uses SysUtils;

Const
  {$ifdef cpuwasm32}
  OurDir = '/tmp';
  {$else}
  OurDir = '/tmp/something';
  {$Endif}
  OurFile = OurDir+'/test.txt';

var
  HasDir : Boolean;
  HasFile: Boolean;
  S : UTF8String;
  aSize,FD,byteCount : Integer;

begin
  S:='Hello, WebAssembly World!';
  HasDir:=DirectoryExists(OurDir);
  if HasDir then
    Writeln('Directory already exists: ',OurDir)
  else if CreateDir(OurDir) then
    Writeln('Created new directory: ',OurDir)
  else
    Writeln('Failed to create directory: ',OurDir);
  HasFile:=FileExists(OurFile);
  If HasFile then
    Writeln('File exists: ',OurFile)
  else
    begin
    Writeln('Creating file: ',OurFile);
    FD:=FileCreate(OurFile);
    if FD=-1 then
      Writeln('Failed to get fileHandle: ',FD)
    else
      begin
      Writeln('Got fileHandle: ',FD);
      ByteCount:=FileWrite(FD,S[1],Length(S));
      Writeln('Wrote ',byteCount,' bytes to file. Expected: ',Length(S));
      FileClose(FD);
      Writeln('Closed file');
      end;
    end;
  If FileExists(OurFile) then
    begin
    Writeln('Opening file: ',OurFile);
    FD:=FileOpen(OurFile,fmOpenRead);
    if FD=-1 then
      Writeln('Failed to get fileHandle: ',FD)
    else
      begin
      Writeln('Got fileHandle: ',FD);
      aSize:=FileSeek(FD,0,fsFromEnd);
      Writeln('Got file size: ',aSize);
      FileSeek(FD,0,fsFromBeginning);
      SetLength(S,aSize);
      if aSize>0 then
        ByteCount:=FileRead(FD,S[1],aSize);
      Writeln('Read ',byteCount,' bytes from file. Expected: ',aSize);
      Writeln('File contents: "',S,'"');
      FileClose(FD);
      Writeln('Closed file');
      end;
    end;
  if Not HasFile then
    Writeln('Deleting file ',DeleteFile(OurFile));
  if Not HasDir then
    Writeln('Deleting directory ',RemoveDir(OurDir));
  Writeln('All done!');
end.

