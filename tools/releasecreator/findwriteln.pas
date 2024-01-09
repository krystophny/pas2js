unit FindWriteln;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TFindWritelnLog = procedure(EventType : TEventType; const Msg: string) of object;

function FindWritelnInDirectory(Dir: string; Recurse: boolean; const Log: TFindWritelnLog): integer;

implementation

function ReadNextToken(const Src: string; var SrcP: PChar; var Line: integer): string;
var
  p, TokenStart: PChar;
begin
  p:=SrcP;
  while p^ in [' ',#9] do inc(p);
  repeat
    case p^ of
    #0:
      if p-PChar(Src)=length(Src) then begin
        SrcP:=p;
        exit('');
      end
      else
        inc(p);
    #10,#13:
      begin
      inc(Line);
      if (p[1] in [#10,#13]) and (p^<>p[1]) then
        inc(p,2)
      else
        inc(p);
      end;
    ' ',#9:
      inc(p);
    else
      break;
    end;
  until false;
  TokenStart:=p;
  case p^ of
  'a'..'z','A'..'Z','_':
    while p^ in ['a'..'z','A'..'Z','_','0'..'9'] do inc(p);
  '0'..'9':
    while p^ in ['0'..'9'] do inc(p);
  '''':
    begin
    inc(p);
    repeat
      case p^ of
      #0,#10,#13: break;
      '''':
        begin
        inc(p);
        break;
        end;
      end;
      inc(p);
    until false;
    end;
  '/':
    if p[1]='/' then begin
      inc(p,2);
      while not (p^ in [#0,#10,#13]) do inc(p);
    end else
      inc(p);
  '{':
    begin
      inc(p);
      repeat
        case p^ of
        #0:
          if p-PChar(Src)=length(Src) then begin
            SrcP:=p;
            exit('');
          end;
        #10,#13:
          begin
          inc(Line);
          if (p[1] in [#10,#13]) and (p^<>p[1]) then
            inc(p);
          end;
        '}': break;
        end;
        inc(p);
      until false;
      inc(p);
    end;
  '(':
    if p[1]='*' then begin
      inc(p,2);
      repeat
        case p^ of
        #0:
          if p-PChar(Src)=length(Src) then begin
            SrcP:=p;
            exit('');
          end;
        #10,#13:
          begin
          inc(Line);
          if (p[1] in [#10,#13]) and (p^<>p[1]) then
            inc(p);
          end;
        '*':
          if p[1]=')' then break;
        end;
        inc(p);
      until false;
      inc(p,2);
    end else
      inc(p);
  else
    inc(p);
  end;
  SetLength(Result,p-TokenStart);
  Move(TokenStart^,Result[1],length(Result));
  SrcP:=P;
end;

procedure GetLineStartEndAtPosition(const Source:string; Position:integer;
   out LineStart,LineEnd:integer);
begin
  if Position<1 then begin
    LineStart:=0;
    LineEnd:=0;
    exit;
  end;
  if Position>length(Source)+1 then begin
    LineStart:=length(Source)+1;
    LineEnd:=LineStart;
    exit;
  end;
  LineStart:=Position;
  while (LineStart>1) and (not (Source[LineStart-1] in [#10,#13])) do
    dec(LineStart);
  LineEnd:=Position;
  while (LineEnd<=length(Source)) and (not (Source[LineEnd] in [#10,#13])) do
    inc(LineEnd);
end;

function GetLineInSrc(const Source: string; Position: integer): string;
var
  LineStart, LineEnd: integer;
begin
  GetLineStartEndAtPosition(Source,Position,LineStart,LineEnd);
  Result:=copy(Source,LineStart,LineEnd-LineStart);
end;

function CheckFile(Filename: string; const Log: TFindWritelnLog): integer;
var
  Token, LastToken, Src: String;
  ms: TMemoryStream;
  p: PChar;
  Line, LastIFDEF, AllowWriteln: Integer;
  Lvl, VerboseLvl: integer;
begin
  Result:=0;
  ms:=TMemoryStream.Create;
  try
    ms.LoadFromFile(Filename);
    if ms.Size=0 then exit;
    Src:='';
    SetLength(Src,ms.Size);
    Move(ms.Memory^,Src[1],length(Src));
    p:=PChar(Src);
    AllowWriteln:=0;
    Line:=1;
    LastIFDEF:=-1;
    Token:='';
    Lvl:=0;
    VerboseLvl:=-1;
    repeat
      LastToken:=Token;
      Token:=ReadNextToken(Src,p,Line);
      if Token='' then break;
      if Token[1]='{' then begin
        Token:=lowercase(Token);
        if Token='{allowwriteln}' then begin
          if AllowWriteln>0 then begin
            inc(Result);
            Log(etError,Filename+'('+IntToStr(Line)+'): writeln already allowed at '+IntToStr(AllowWriteln)+': '+GetLineInSrc(Src,p-PChar(Src)+1));
          end;
          AllowWriteln:=Line;
        end
        else if Token='{allowwriteln-}' then begin
          if AllowWriteln<1 then begin
            inc(Result);
            Log(etError,Filename+'('+IntToStr(Line)+'): writeln was not allowed: '+GetLineInSrc(Src,p-PChar(Src)+1));
          end;
          AllowWriteln:=0;
        end
        else if SameText(LeftStr(Token,4),'{$if') then begin
          inc(Lvl);
          LastIFDEF:=Line;
          if SameText(LeftStr(Token,15),'{$ifdef Verbose') then begin
            if VerboseLvl<0 then VerboseLvl:=Lvl;
          end;
        end else if SameText(LeftStr(Token,6),'{$else') then begin
          if Lvl=VerboseLvl then
            VerboseLvl:=-1;
          LastIFDEF:=Line;
        end else if SameText(LeftStr(Token,7),'{$endif') then begin
          if Lvl=VerboseLvl then begin
            VerboseLvl:=-1;
          end;
          dec(Lvl);
        end;
      end
      else begin
        if (CompareText(Token,'str')=0) and (LastToken<>'.') then begin
          if byte(Line-LastIFDEF) in [0,1] then begin
            // ignore writeln just behind IFDEF
            LastIFDEF:=Line;
          end;
        end;
        if (CompareText(Token,'writeln')=0)
            and (LastToken<>'.')
            and (LastToken<>':=')
            and (LastToken<>'=')
            and (LastToken<>'+')
            and not SameText(LastToken,'function')
            and not SameText(LastToken,'procedure') then begin
          if Lvl=VerboseLvl then begin
            // ignore writeln inside $IFDEF VerboseX
          end else if byte(Line-LastIFDEF) in [0,1] then begin
            // ignore writeln just behind IFDEF
            LastIFDEF:=Line;
          end else if AllowWriteln<1 then begin
            inc(Result);
            Log(etError,Filename+'('+IntToStr(Line)+'): '+GetLineInSrc(Src,p-PChar(Src)+1));
          end;
        end;
      end;
    until false;
  finally
    ms.Free;
  end;
end;

function FindWritelnInDirectory(Dir: string; Recurse: boolean; const Log: TFindWritelnLog): integer;
var
  Info: TRawByteSearchRec;
  Ext: String;
begin
  Result:=0;
  Dir:=IncludeTrailingPathDelimiter(Dir);
  if FindFirst(Dir+AllFilesMask,faAnyFile,Info)=0 then begin
    repeat
      if (Info.Name='') or (Info.Name='.') or (Info.Name='..') then continue;
      if (Info.Attr and faDirectory)>0 then begin
        if Recurse then
          Result+=FindWritelnInDirectory(Dir+Info.Name,true,Log);
      end
      else begin
        Ext:=lowercase(ExtractFileExt(Info.Name));
        case Ext of
        '.p','.pp','.pas','.inc': Result+=CheckFile(Dir+Info.Name,Log);
        end;
      end;
    until FindNext(Info)<>0;
  end;
end;

end.


