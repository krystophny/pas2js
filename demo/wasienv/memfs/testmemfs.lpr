program testmemfs;

{$mode objfpc}
{$h+}

{
  Test program for TWASIMemFS - compiled with Free Pascal targeting WASM.
  Uses standard Pascal file handling routines (SysUtils) which internally
  call WASI syscalls routed to the TWASIMemFS implementation.

  Compile with: fpc -Twasi testmemfs.lpr
}

uses SysUtils;

var
  TestCount: Integer = 0;
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Check(const ATestName: string; ACondition: Boolean);
begin
  Inc(TestCount);
  if ACondition then
  begin
    Inc(PassCount);
    Writeln('  PASS: ', ATestName);
  end
  else
  begin
    Inc(FailCount);
    Writeln('  FAIL: ', ATestName);
  end;
end;

procedure TestSection(const ATitle: string);
begin
  Writeln;
  Writeln('=== ', ATitle, ' ===');
end;

// -------------------------------------------------------
// Test 1: CreateDir / DirectoryExists / RemoveDir
//   WASI ops: MkDirAt, StatAt, RmDirAt
// -------------------------------------------------------
procedure TestDirectoryOperations;
begin
  TestSection('Directory Operations (MkDirAt, StatAt, RmDirAt)');

  Check('Root directory exists', DirectoryExists('/'));

  // Create a directory
  Check('CreateDir /testdir succeeds', CreateDir('/testdir'));
  Check('DirectoryExists /testdir', DirectoryExists('/testdir'));

  // Create nested directory
  Check('CreateDir /testdir/sub succeeds', CreateDir('/testdir/sub'));
  Check('DirectoryExists /testdir/sub', DirectoryExists('/testdir/sub'));

  // Duplicate create should fail
  Check('CreateDir /testdir again fails', not CreateDir('/testdir'));

  // Remove empty subdirectory
  Check('RemoveDir /testdir/sub succeeds', RemoveDir('/testdir/sub'));
  Check('/testdir/sub no longer exists', not DirectoryExists('/testdir/sub'));

  // Remove non-empty directory should fail (we'll add a file first)
  Check('CreateDir /testdir/sub2 succeeds', CreateDir('/testdir/sub2'));
  Check('RemoveDir /testdir fails (not empty)', not RemoveDir('/testdir'));

  // Clean up
  Check('RemoveDir /testdir/sub2 succeeds', RemoveDir('/testdir/sub2'));
  Check('RemoveDir /testdir succeeds', RemoveDir('/testdir'));
  Check('/testdir no longer exists', not DirectoryExists('/testdir'));
end;

// -------------------------------------------------------
// Test 2: FileCreate / FileWrite / FileClose
//   WASI ops: OpenAt (CREAT|TRUNC), Write, Close
// -------------------------------------------------------
procedure TestFileCreateAndWrite;
var
  FD: Integer;
  S: UTF8String;
  Written: Integer;
begin
  TestSection('File Create and Write (OpenAt CREAT, Write, Close)');

  // Create directory for tests
  CreateDir('/files');

  // Create and write a file
  FD := FileCreate('/files/hello.txt');
  Check('FileCreate returns valid handle', FD >= 0);

  S := 'Hello, WebAssembly World!';
  Written := FileWrite(FD, S[1], Length(S));
  Check('FileWrite writes all bytes', Written = Length(S));

  FileClose(FD);
  Check('File exists after close', FileExists('/files/hello.txt'));
end;

// -------------------------------------------------------
// Test 3: FileOpen / FileRead / FileClose
//   WASI ops: OpenAt (read), Read, Close
// -------------------------------------------------------
procedure TestFileOpenAndRead;
var
  FD: Integer;
  S: UTF8String;
  BytesRead, FileSize: Integer;
begin
  TestSection('File Open and Read (OpenAt, Read, Close)');

  // Open the file we created
  FD := FileOpen('/files/hello.txt', fmOpenRead);
  Check('FileOpen returns valid handle', FD >= 0);

  // Get file size via seek to end
  FileSize := FileSeek(FD, 0, fsFromEnd);
  Check('File size is 25 bytes', FileSize = 25);

  // Seek back to beginning
  FileSeek(FD, 0, fsFromBeginning);

  // Read all content
  SetLength(S, FileSize);
  BytesRead := FileRead(FD, S[1], FileSize);
  Check('FileRead reads all bytes', BytesRead = FileSize);
  Check('Content matches', S = 'Hello, WebAssembly World!');

  FileClose(FD);
end;

// -------------------------------------------------------
// Test 4: FileSeek
//   WASI ops: Seek (swBeginning, swCurrent, swEnd)
// -------------------------------------------------------
procedure TestFileSeek;
var
  FD: Integer;
  Pos: Integer;
  Buf: array[0..4] of AnsiChar;
  BytesRead: Integer;
begin
  TestSection('File Seek (Seek swBeginning, swCurrent, swEnd)');

  FD := FileOpen('/files/hello.txt', fmOpenRead);
  Check('FileOpen succeeds', FD >= 0);

  // Seek from beginning
  Pos := FileSeek(FD, 7, fsFromBeginning);
  Check('Seek from beginning to 7', Pos = 7);

  // Read 'Web' from that position
  BytesRead := FileRead(FD, Buf[0], 3);
  Buf[3] := #0;
  Check('Read 3 bytes from pos 7', BytesRead = 3);
  Check('Content at pos 7 is "Web"', (Buf[0] = 'W') and (Buf[1] = 'e') and (Buf[2] = 'b'));

  // Seek from current (+8 from pos 10 = pos 18)
  Pos := FileSeek(FD, 8, fsFromCurrent);
  Check('Seek from current +8 gives 18', Pos = 18);

  // Seek from end (-6 on 25 byte file = pos 19)
  Pos := FileSeek(FD, -6, fsFromEnd);
  Check('Seek from end -6 gives 19', Pos = 19);

  // Read 'World' from pos 19
  BytesRead := FileRead(FD, Buf[0], 5);
  Check('Read 5 bytes from pos 19', BytesRead = 5);
  Check('Content is "World"',
    (Buf[0] = 'W') and (Buf[1] = 'o') and (Buf[2] = 'r') and
    (Buf[3] = 'l') and (Buf[4] = 'd'));

  FileClose(FD);
end;

// -------------------------------------------------------
// Test 5: File overwrite (truncate)
//   WASI ops: OpenAt (CREAT|TRUNC), Write, Read
// -------------------------------------------------------
procedure TestFileOverwrite;
var
  FD: Integer;
  S: UTF8String;
  Written, BytesRead, FileSize: Integer;
begin
  TestSection('File Overwrite/Truncate (OpenAt CREAT|TRUNC)');

  // Overwrite the existing file with shorter content
  FD := FileCreate('/files/hello.txt');
  Check('FileCreate for overwrite succeeds', FD >= 0);

  S := 'Short';
  Written := FileWrite(FD, S[1], Length(S));
  Check('Write shorter content', Written = 5);
  FileClose(FD);

  // Verify the file was truncated
  FD := FileOpen('/files/hello.txt', fmOpenRead);
  FileSize := FileSeek(FD, 0, fsFromEnd);
  Check('File size is now 5 (truncated)', FileSize = 5);

  FileSeek(FD, 0, fsFromBeginning);
  SetLength(S, FileSize);
  BytesRead := FileRead(FD, S[1], FileSize);
  Check('Read back 5 bytes', BytesRead = 5);
  Check('Content is "Short"', S = 'Short');
  FileClose(FD);
end;

// -------------------------------------------------------
// Test 6: RenameFile
//   WASI ops: RenameAt
// -------------------------------------------------------
procedure TestRenameFile;
begin
  TestSection('Rename File (RenameAt)');

  Check('Source exists before rename', FileExists('/files/hello.txt'));
  Check('RenameFile succeeds', RenameFile('/files/hello.txt', '/files/renamed.txt'));
  Check('Source no longer exists', not FileExists('/files/hello.txt'));
  Check('Target exists', FileExists('/files/renamed.txt'));
end;

// -------------------------------------------------------
// Test 7: DeleteFile
//   WASI ops: UnLinkAt
// -------------------------------------------------------
procedure TestDeleteFile;
begin
  TestSection('Delete File (UnLinkAt)');

  Check('File exists before delete', FileExists('/files/renamed.txt'));
  Check('DeleteFile succeeds', DeleteFile('/files/renamed.txt'));
  Check('File no longer exists', not FileExists('/files/renamed.txt'));

  // Deleting non-existent file should fail
  Check('Delete non-existent fails', not DeleteFile('/files/nope.txt'));
end;

// -------------------------------------------------------
// Test 8: FindFirst / FindNext (directory listing)
//   WASI ops: OpenAt (DIRECTORY), ReadDir, Close
// -------------------------------------------------------
procedure TestDirectoryListing;
var
  Info: TSearchRec;
  Count: Integer;
  FD: Integer;
  S: UTF8String;
  FoundA, FoundB, FoundSub: Boolean;
begin
  TestSection('Directory Listing (OpenAt DIRECTORY, ReadDir)');

  // Create some files and a subdirectory
  CreateDir('/listdir');
  CreateDir('/listdir/subdir');

  FD := FileCreate('/listdir/aaa.txt');
  S := 'File A';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  FD := FileCreate('/listdir/bbb.txt');
  S := 'File B content';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  // List directory
  Count := 0;
  FoundA := False;
  FoundB := False;
  FoundSub := False;
  if FindFirst('/listdir/*', faAnyFile, Info) = 0 then
  try
    repeat
      Inc(Count);
      if Info.Name = 'aaa.txt' then
        FoundA := True;
      if Info.Name = 'bbb.txt' then
        FoundB := True;
      if Info.Name = 'subdir' then
        FoundSub := True;
      Writeln('  Entry: ', Info.Name, ' size=', Info.Size,
        ' dir=', (Info.Attr and faDirectory) <> 0);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;

  Check('Found 3 entries', Count = 3);
  Check('Found aaa.txt', FoundA);
  Check('Found bbb.txt', FoundB);
  Check('Found subdir', FoundSub);

  // Clean up
  DeleteFile('/listdir/aaa.txt');
  DeleteFile('/listdir/bbb.txt');
  RemoveDir('/listdir/subdir');
  RemoveDir('/listdir');
end;

// -------------------------------------------------------
// Test 9: Large file write and read
//   WASI ops: Write (buffer growth), Read
// -------------------------------------------------------
procedure TestLargeFile;
var
  FD: Integer;
  WriteBuf, ReadBuf: array of Byte;
  I, Written, BytesRead, FileSize: Integer;
  Match: Boolean;
begin
  TestSection('Large File Write/Read (Write buffer growth, Read)');

  CreateDir('/large');

  // Create a 64KB file
  SetLength(WriteBuf, 65536);
  for I := 0 to 65535 do
    WriteBuf[I] := Byte(I and $FF);

  FD := FileCreate('/large/bigfile.bin');
  Check('FileCreate succeeds', FD >= 0);
  Written := FileWrite(FD, WriteBuf[0], 65536);
  Check('Wrote 64KB', Written = 65536);
  FileClose(FD);

  // Read it back
  FD := FileOpen('/large/bigfile.bin', fmOpenRead);
  FileSize := FileSeek(FD, 0, fsFromEnd);
  Check('File size is 64KB', FileSize = 65536);

  FileSeek(FD, 0, fsFromBeginning);
  SetLength(ReadBuf, FileSize);
  BytesRead := FileRead(FD, ReadBuf[0], FileSize);
  Check('Read back 64KB', BytesRead = 65536);

  // Verify content
  Match := True;
  for I := 0 to 65535 do
    if ReadBuf[I] <> Byte(I and $FF) then
    begin
      Match := False;
      Writeln('  Mismatch at byte ', I, ': expected ', I and $FF, ' got ', ReadBuf[I]);
      Break;
    end;
  Check('Content matches byte-for-byte', Match);

  FileClose(FD);
  DeleteFile('/large/bigfile.bin');
  RemoveDir('/large');
end;

// -------------------------------------------------------
// Test 10: Partial read and write at offsets
//   WASI ops: Seek, Write, Read at various positions
// -------------------------------------------------------
procedure TestPartialReadWrite;
var
  FD: Integer;
  S: UTF8String;
  Buf: array[0..9] of AnsiChar;
  Written, BytesRead, Pos: Integer;
begin
  TestSection('Partial Read/Write at Offsets (Seek + Write + Read)');

  CreateDir('/partial');

  // Write initial content
  FD := FileCreate('/partial/data.txt');
  S := 'AAAAAAAAAA'; // 10 A's
  Written := FileWrite(FD, S[1], Length(S));
  Check('Initial write 10 bytes', Written = 10);
  FileClose(FD);

  // Open for read/write, overwrite middle
  FD := FileOpen('/partial/data.txt', fmOpenReadWrite);
  Check('Open read/write succeeds', FD >= 0);

  Pos := FileSeek(FD, 3, fsFromBeginning);
  Check('Seek to position 3', Pos = 3);

  S := 'BBB';
  Written := FileWrite(FD, S[1], 3);
  Check('Overwrote 3 bytes at pos 3', Written = 3);

  // Read back entire file
  FileSeek(FD, 0, fsFromBeginning);
  BytesRead := FileRead(FD, Buf[0], 10);
  Check('Read back 10 bytes', BytesRead = 10);
  Check('Content is AAABBBAAAA',
    (Buf[0] = 'A') and (Buf[1] = 'A') and (Buf[2] = 'A') and
    (Buf[3] = 'B') and (Buf[4] = 'B') and (Buf[5] = 'B') and
    (Buf[6] = 'A') and (Buf[7] = 'A') and (Buf[8] = 'A') and
    (Buf[9] = 'A'));

  FileClose(FD);
  DeleteFile('/partial/data.txt');
  RemoveDir('/partial');
end;

// -------------------------------------------------------
// Test 11: FileExists on non-existent paths
//   WASI ops: StatAt returning ENOENT
// -------------------------------------------------------
procedure TestNonExistentPaths;
begin
  TestSection('Non-existent Path Checks (StatAt ENOENT)');

  Check('File does not exist', not FileExists('/nonexistent.txt'));
  Check('Directory does not exist', not DirectoryExists('/nonexistent'));
  Check('Nested path does not exist', not FileExists('/a/b/c/d.txt'));
end;

// -------------------------------------------------------
// Test 12: Multiple files in same directory
//   WASI ops: exercises interleaved OpenAt, Write, Close, ReadDir
// -------------------------------------------------------
procedure TestMultipleFiles;
var
  FD: Integer;
  S: UTF8String;
  Info: TSearchRec;
  Count: Integer;
begin
  TestSection('Multiple Files in Same Directory');

  CreateDir('/multi');

  // Create several files
  FD := FileCreate('/multi/one.txt');
  S := '1';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  FD := FileCreate('/multi/two.txt');
  S := '22';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  FD := FileCreate('/multi/three.txt');
  S := '333';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  // Verify all exist
  Check('/multi/one.txt exists', FileExists('/multi/one.txt'));
  Check('/multi/two.txt exists', FileExists('/multi/two.txt'));
  Check('/multi/three.txt exists', FileExists('/multi/three.txt'));

  // Count via directory listing
  Count := 0;
  if FindFirst('/multi/*', faAnyFile, Info) = 0 then
  try
    repeat
      Inc(Count);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;
  Check('Directory has 3 entries', Count = 3);

  // Delete one and verify
  DeleteFile('/multi/two.txt');
  Check('/multi/two.txt deleted', not FileExists('/multi/two.txt'));

  Count := 0;
  if FindFirst('/multi/*', faAnyFile, Info) = 0 then
  try
    repeat
      Inc(Count);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;
  Check('Directory now has 2 entries', Count = 2);

  // Clean up
  DeleteFile('/multi/one.txt');
  DeleteFile('/multi/three.txt');
  RemoveDir('/multi');
end;

// -------------------------------------------------------
// Test 13: Nested directory creation and file operations
//   WASI ops: MkDirAt (nested), OpenAt, StatAt
// -------------------------------------------------------
procedure TestNestedDirectories;
var
  FD: Integer;
  S: UTF8String;
begin
  TestSection('Nested Directory Operations');

  Check('Create /a', CreateDir('/a'));
  Check('Create /a/b', CreateDir('/a/b'));
  Check('Create /a/b/c', CreateDir('/a/b/c'));
  Check('/a/b/c exists', DirectoryExists('/a/b/c'));

  // Create file in deep directory
  FD := FileCreate('/a/b/c/deep.txt');
  S := 'Deep file';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  Check('Deep file exists', FileExists('/a/b/c/deep.txt'));

  // Cannot remove /a/b/c while it has a file
  Check('RemoveDir /a/b/c fails (not empty)', not RemoveDir('/a/b/c'));

  // Clean up in order
  DeleteFile('/a/b/c/deep.txt');
  Check('RemoveDir /a/b/c succeeds', RemoveDir('/a/b/c'));
  Check('RemoveDir /a/b succeeds', RemoveDir('/a/b'));
  Check('RemoveDir /a succeeds', RemoveDir('/a'));
end;

// -------------------------------------------------------
// Test 14: Empty file
//   WASI ops: OpenAt (CREAT|TRUNC), Close, StatAt, Read
// -------------------------------------------------------
procedure TestEmptyFile;
var
  FD: Integer;
  Buf: Byte;
  BytesRead, FileSize: Integer;
begin
  TestSection('Empty File Operations');

  CreateDir('/empty');
  FD := FileCreate('/empty/zero.txt');
  Check('Create empty file', FD >= 0);
  FileClose(FD);

  Check('Empty file exists', FileExists('/empty/zero.txt'));

  FD := FileOpen('/empty/zero.txt', fmOpenRead);
  FileSize := FileSeek(FD, 0, fsFromEnd);
  Check('Empty file size is 0', FileSize = 0);

  FileSeek(FD, 0, fsFromBeginning);
  BytesRead := FileRead(FD, Buf, 1);
  Check('Read from empty file returns 0 bytes', BytesRead = 0);

  FileClose(FD);

  DeleteFile('/empty/zero.txt');
  RemoveDir('/empty');
end;

// -------------------------------------------------------
// Test 15: Rename across directories
//   WASI ops: RenameAt with different source/target dirs
// -------------------------------------------------------
procedure TestRenameCrossDir;
var
  FD: Integer;
  S: UTF8String;
  BytesRead, FileSize: Integer;
begin
  TestSection('Rename Across Directories (RenameAt cross-dir)');

  CreateDir('/src');
  CreateDir('/dst');

  FD := FileCreate('/src/moveme.txt');
  S := 'Moving content';
  FileWrite(FD, S[1], Length(S));
  FileClose(FD);

  Check('Source exists', FileExists('/src/moveme.txt'));
  Check('RenameFile cross-dir', RenameFile('/src/moveme.txt', '/dst/moved.txt'));
  Check('Source gone', not FileExists('/src/moveme.txt'));
  Check('Target exists', FileExists('/dst/moved.txt'));

  // Verify content preserved
  FD := FileOpen('/dst/moved.txt', fmOpenRead);
  FileSize := FileSeek(FD, 0, fsFromEnd);
  Check('Size preserved after rename', FileSize = Length('Moving content'));
  FileSeek(FD, 0, fsFromBeginning);
  SetLength(S, FileSize);
  BytesRead := FileRead(FD, S[1], FileSize);
  Check('Content preserved', (BytesRead = FileSize) and (S = 'Moving content'));
  FileClose(FD);

  // Clean up
  DeleteFile('/dst/moved.txt');
  RemoveDir('/src');
  RemoveDir('/dst');
end;

// -------------------------------------------------------
// Test 16: localStorage persistence across page reloads
//
// On first run: creates /persist/ with files, does NOT
// delete them. Files are flushed to localStorage on Close.
//
// On second run (page reload): the in-memory tree starts
// empty, but OpenAt/StatAt should hydrate from localStorage.
// Verifies content survived the reload, then cleans up.
// -------------------------------------------------------
procedure TestPersistence;
var
  FD: Integer;
  S: UTF8String;
  BytesRead, FileSize: Integer;
  IsSecondRun: Boolean;
begin
  TestSection('localStorage Persistence (reload page to complete)');

  // Detect whether this is first or second run by checking
  // if the persistence marker file already exists
  IsSecondRun := FileExists('/persist/marker.txt');

  if not IsSecondRun then
  begin
    Writeln('  -- First run: creating persistent files --');

    // Create directory and files
    if not DirectoryExists('/persist') then
      Check('Create /persist', CreateDir('/persist'));

    FD := FileCreate('/persist/marker.txt');
    S := 'persistence-ok';
    FileWrite(FD, S[1], Length(S));
    FileClose(FD);
    Check('Created marker file', FileExists('/persist/marker.txt'));

    FD := FileCreate('/persist/data.bin');
    S := 'SecondFileContents!X';
    FileWrite(FD, S[1], Length(S));
    FileClose(FD);
    Check('Created data file', FileExists('/persist/data.bin'));

    Writeln('  -- Files written to localStorage. Reload page to verify. --');
  end
  else
  begin
    Writeln('  -- Second run: verifying files survived reload --');

    // marker.txt should be hydrated from localStorage
    Check('marker.txt exists after reload', FileExists('/persist/marker.txt'));

    FD := FileOpen('/persist/marker.txt', fmOpenRead);
    Check('Open marker.txt', FD >= 0);
    FileSize := FileSeek(FD, 0, fsFromEnd);
    Check('marker.txt size is 14', FileSize = 14);
    FileSeek(FD, 0, fsFromBeginning);
    SetLength(S, FileSize);
    BytesRead := FileRead(FD, S[1], FileSize);
    Check('Read marker content', BytesRead = 14);
    Check('Content is "persistence-ok"', S = 'persistence-ok');
    FileClose(FD);

    // data.bin should also survive
    Check('data.bin exists after reload', FileExists('/persist/data.bin'));

    FD := FileOpen('/persist/data.bin', fmOpenRead);
    Check('Open data.bin', FD >= 0);
    FileSize := FileSeek(FD, 0, fsFromEnd);
    Check('data.bin size is 20', FileSize = 20);
    FileClose(FD);

    // Clean up after verification
    DeleteFile('/persist/marker.txt');
    DeleteFile('/persist/data.bin');
    RemoveDir('/persist');
    Check('Cleaned up /persist', not DirectoryExists('/persist'));

    Writeln('  -- Persistence verified and cleaned up! --');
  end;
end;

// -------------------------------------------------------
// Main
// -------------------------------------------------------
begin
  Writeln('========================================');
  Writeln('  TWASIMemFS Test Suite');
  Writeln('========================================');

  TestDirectoryOperations;
  TestFileCreateAndWrite;
  TestFileOpenAndRead;
  TestFileSeek;
  TestFileOverwrite;
  TestRenameFile;
  TestDeleteFile;
  TestDirectoryListing;
  TestLargeFile;
  TestPartialReadWrite;
  TestNonExistentPaths;
  TestMultipleFiles;
  TestNestedDirectories;
  TestEmptyFile;
  TestRenameCrossDir;
  TestPersistence;

  Writeln;
  Writeln('========================================');
  Writeln('  Results: ', TestCount, ' tests, ',
    PassCount, ' passed, ', FailCount, ' failed');
  Writeln('========================================');

  if FailCount > 0 then
    Writeln('*** SOME TESTS FAILED ***')
  else
    Writeln('All tests passed!');
end.
