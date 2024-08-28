program BrowserDom10;

{$mode objfpc}

uses
  BrowserConsole, JS, Classes, SysUtils, Web, BrowserApp, libzenfs, libzenfsdom, wasizenfs,
  zenfsutils;

Type

  { TMyApplication }

  TMyApplication = class(TBrowserApplication)
  Private
    BtnDownload : TJSHTMLButtonElement;
    EdtFileName : TJSHTMLInputElement;
    DivDownloads : TJSHTMLElement;
    FTreeBuilder : THTMLZenFSTree;
    procedure CreateFiles;
    procedure DoSelectFile(Sender: TObject; aFileName: String; aType: TFileType);
    procedure SetupFS; async;
    procedure DoDownload(Event : TJSEvent);
    procedure SelectFile(Sender: TObject; aFileName: String; aType : TFileType);
  Public
    constructor Create(aOwner : TComponent); override;
    procedure DoRun; override;
  end;

{ TMyApplication }

constructor TMyApplication.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  // Allow to load file specified in hash: index.html#mywasmfile.wasm
  BtnDownload:=TJSHTMLButtonElement(GetHTMLElement('btnDownload'));
  BtnDownload.AddEVentListener('click',@DoDownload);
  EdtFileName:=TJSHTMLInputElement(GetHTMLElement('edtFilename'));
  DivDownloads:=GetHTMLElement('divDownloads');
  FTreeBuilder:=THTMLZenFSTree.Create(Self);
  FTreeBuilder.MaxHeight:='300px';
  FTreeBuilder.ParentElementID:='treeFiles';
  FTreeBuilder.OnFileSelected:=@SelectFile;
end;

procedure TMyApplication.DoRun;

begin
  SetupFS;
end;

procedure TMyApplication.CreateFiles;

  Procedure ForceDir(const aDir: string);

  var
    Stat : TZenFSStats;

  begin
    try
      Stat:=ZenFS.statSync(aDir);
    except
      Writeln('Directory "',aDir,'" does not exist, creating it.')
    end;
    if Not assigned(Stat) then
      begin
      try
        ZenFS.mkdirSync(aDir,&775)
      except
        Writeln('Failed to create directory "',aDir,'"');
        Raise;
      end;
      end
    else if Stat.isDirectory then
      Raise Exception.Create(aDir+' is not a directory');
  end;

  Procedure ForceFile(aFile : String);

  var
    S : String;
    I : Integer;

  begin
    Writeln('Creating file: ',aFile);
    S:='This is the content of file "'+aFile+'". Some random numbers:';
    For I:=1 to 10+Random(90) do
      S:=S+'Line '+IntToStr(i)+': '+IntToStr(1+Random(100))+sLineBreak;
    try
      ZenFS.writeFileSync(aFile,S);
    except
      Writeln('Failed to create file: ',aFile);
    end;
  end;

var
  FN : Integer;

begin
  ForceDir('/tmp');
  ForceFile('/tmp/file1.txt');
  ForceDir('/tmp/logs');
  For FN:=2 to 5+Random(5) do
    ForceFile(Format('/tmp/file_%d.txt',[FN]));
  For FN:=1 to 5+Random(5) do
    ForceFile(Format('/tmp/logs/file_%.6d.log',[FN]));
  ForceDir('/home');
  ForceDir('/home/user');
  For FN:=1 to 5+Random(5) do
    ForceFile(Format('/home/user/diary%d.log',[FN]));
  ForceDir('/home/user2');
  For FN:=1 to 1+Random(5) do
    ForceFile(Format('/home/user2/diary%d.log',[FN]));
end;

procedure TMyApplication.DoSelectFile(Sender: TObject; aFileName: String; aType: TFileType);

const
  filetypes : Array[TFileType] of string = ('Unknown','File','Directory','SymLink');

begin
  Writeln('You selected '+FileTypes[aType]+': '+aFileName);
  if aType=ftFile then
    EdtFileName.Value:=aFileName;
end;

procedure TMyApplication.SetupFS;

var
  Stat : TZenFSStats;

begin
  Terminate;
  // Set up filesystem
  aWait(TJSObject,ZenFS.configure(
    New([
     'mounts', New([
        '/',DomBackends.WebStorage
        ])
    ])));
  // Allow to load file specified in hash: index.html#mywasmfile.wasm
  try
    Stat:=ZenFS.statSync('/tmp/file1.txt');

  except
    Writeln('Directory structure does not exist, creating one');
  end;
  if Not assigned(Stat) then
    CreateFiles
  else
    Writeln('Directory structure already exists.');
  FTreeBuilder.ShowDir('/');
  FTreeBuilder.OnFileSelected:=@DoSelectFile;
end;

procedure TMyApplication.DoDownload(Event : TJSEvent);
var
  a : TJSHTMLAnchorElement;
begin
  a:=CreateDownLoadFromFile(edtFileName.value,'application/octet-stream',divDownloads,'file '+edtFileName.value);
  a.click;
end;

procedure TMyApplication.SelectFile(Sender: TObject; aFileName: String; aType : TFileType);
begin
  if aType=ftFile then
    EdtFileName.Value:=aFileName;
end;

var
  Application : TMyApplication;
begin
  Application:=TMyApplication.Create(nil);
  Application.Initialize;
  Application.Run;
end.
