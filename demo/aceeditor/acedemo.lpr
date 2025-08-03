program acedemo;

{$mode objfpc}
{$modeswitch multilinestrings}

uses
  JS, Classes, SysUtils, Web, libace;

var
  editor : TEditor;
  btn : TJSHTMLButtonElement;

procedure HandleDownload(event : TJSEvent);
var
  blob : TJSBlob;
  url : string;
  a : TJSHTMLAnchorElement;
  aInit : TJSBlobInit;

begin
  aInit:=TJSBlobInit.New;
  aInit.type_:='text/plain;charset=utf-8';
  blob:=TJSBlob.new([editor.getValue],aInit);
  url:=TJSURL.createObjectURL(blob);
  a:=TJSHTMLAnchorElement(document.createElement('a'));
  a.href:=url;
  a.download:='hello.pp'; // Set the download attribute to specify the filename
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  TJSURL.revokeObjectURL(url);
end;


begin
  editor:=ace.edit('editor');
  editor.setTheme('ace/theme/solarized_light');
  editor.session.setMode('ace/mode/pascal');
  editor.setOption('fontSize',14);
  editor.setValue(`program hello;
begin
  Writeln('Hello, world!');
end.
`);
  btn:=TJSHTMLButtonElement(document.getElementById('btnDownload'));
  btn.addEventListener('click',@HandleDownload);
  // Create a Blob from the text data
end.
