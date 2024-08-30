{$mode objfpc}{$H+}
program fpmake;

uses {$ifdef unix}cthreads,{$endif} sysutils, fpmkunit;

function FilenameIsAbsolute(const TheFilename: string):boolean;
begin
  {$IFDEF WINDOWS}
  // windows
  Result:=((length(TheFilename)>=2) and (TheFilename[1] in ['A'..'Z','a'..'z'])
           and (TheFilename[2]=':'))
     or ((length(TheFilename)>=2)
         and (TheFilename[1]='\') and (TheFilename[2]='\'));
  {$ELSE}
  // unix
  Result:=(TheFilename<>'') and (TheFilename[1]='/');
  {$ENDIF}
end;

Procedure CreateNamespacedConfigFile(CfgFile : string);

var
  F : Text;
  
  Procedure AddLn(S : String);

  begin
    Writeln(F,S);
  end;

begin
  if not ForceDirectories(ExtractFilePath(CfgFile)) then
    begin
    Writeln(StdErr,'Could not create destination directory ',ExtractFilePath(CfgFile));
    Halt(2);
    end;
  Assign(F,CfgFile);
  try
    Rewrite(F);
  except
    On E : exception do
      begin
      Writeln(StdErr,'Could not create config file ',CfgFile,' : ',E.Message);
      Halt(3);
      end;
  end;
  AddLn('-dUNICODERTL');
  Close(F);
end;

Procedure CreateConfigFile(CfgFile,BaseDir : String; rtl_js_dir: string = '');

Var
  F : Text;


  Procedure AddLn(S : String);

  begin
    Writeln(F,S);
  end;

  Procedure AddPath(const aPrefix,aDir,Suffix : String);
  
  var 
    aSubDir : String;
  
  begin
    aSubDir:=aDir;
    if Suffix<>'' then
      aSubDir:=aSubDir+Suffix;
    if not FilenameIsAbsolute(aDir) then
      aSubDir:='$CfgDir'+PathDelim+aSubDir;
    Addln(aPrefix+aSubDir);
  end;

begin
  if not ForceDirectories(ExtractFilePath(CfgFile)) then
    begin
    Writeln(StdErr,'Could not create destination directory ',ExtractFilePath(CfgFile));
    Halt(2);
    end;
  Assign(F,CfgFile);
  try
    Rewrite(F);
  except
    On E : exception do
      begin
      Writeln(StdErr,'Could not create config file ',CfgFile,' : ',E.Message);
      Halt(3);
      end;
  end;
  if (BaseDir<>'') then
    BaseDir:=IncludeTrailingPathDelimiter(BaseDir);

  Addln('#');
  Addln('# Minimal config file for pas2js compiler');
  Addln('#');
  Addln('# -d is the same as #DEFINE');
  Addln('# -u is the same as #UNDEF');
  Addln('#');
  Addln('# Write always a nice logo ;)');
  Addln('-l');
  Addln('');
  Addln('# Display Warnings, Notes and Hints');
  Addln('-vwnh');
  Addln('# If you don''t want so much verbosity use');
  Addln('#-vw');
  Addln('');
  Addln('# Allow C-operators');
  Addln('-Sc');
  Addln('');
  Addln('#IFDEF FPC_SUBTARGET_NAMESPACED');
  AddPath('-Fu',BaseDir,'*/namespaced');
  AddPath('-Fi',BaseDir,'*/src');
  AddLn('#else');
  AddPath('-Fu',BaseDir,'*/src');
  AddLn('#endif');
  if rtl_js_dir<>'' then
    AddPath('-Fu',rtl_js_dir,'');
  Addln('');
  Addln('#IFDEF nodejs');
  Addln('-Jirtl.js');
  Addln('#ENDIF');
  Addln('');
  Addln('# Put all generated JavaScript into one file');
  Addln('-Jc');
  Addln('');
  Addln('# end.');
  Close(F);
end;

Procedure AddInstallFiles(Files : TConditionalDestStrings; ADir,AllowedExt,APrefix : String);

Var
  Info : TSearchRec;
  ADestDir,E : String;
  P : Integer;

begin
  ADestDir:=ADir;
  P:=Pos(PathDelim,ADestDir);
  if (P>0) then
    Delete(ADestDir,1,P);
  ADir:=IncludeTrailingPathDelimiter(ADir);
  ADestDir:=IncludeTrailingPathDelimiter(ADestDir);
  if FindFirst(aDir+AllFilesMask,0,Info)=0 then
    try
      Repeat
      E:=LowerCase(ExtractFileExt(Info.Name));
      if pos(E,AllowedExt)>0 then
        Files.Add(ADir+Info.Name,aPrefix+ADestDir);
      until (FindNext(Info)<>0);
    finally
      FindClose(Info);
    end;
end;

Procedure AddPackageFiles(Files : TConditionalDestStrings; ADir,APrefix : String);

Const
  PackExt = '.pp.pas.inc.lpk';

begin
  AddInstallFiles(Files,'packages'+PathDelim+ADir+PathDelim+'src',packExt,aPrefix);
  AddInstallFiles(Files,'packages'+PathDelim+ADir+PathDelim+'namespaced',packExt,aPrefix);
end;


Procedure AddDemoFiles(Files : TConditionalDestStrings; ADir,APrefix : String);

Const
  DemoExt = '.pp.pas.inc.lpr.lpi.html.md.css';

begin
  AddInstallFiles(Files,'demo'+PathDelim+ADir,demoExt,APrefix);
end;

const 
  demos : Array of string = (
    'apiclient','asyncawait','atom','bootstrap','chartjs','css','dataabstract',
    'datamodule','datatables','debugcapture','design','dynload','electron',
    'errorhandler','extend_jsclass','fcldb','fpcunit','fpreport','fullcalendar',
    'hotreload','jitsimeet','jquery','jspdf','kurento','library','modules',
    'nodehttpserver','opentok','pacman','player','promise','pushjs','pwa',
    'regexp','resources','restbridge','router','rtl','scratch','templates',
    'testinsight','tetris','tinyeditor','translate','ts2pas','uselibpas2js',
    'vscode','wasienv','webcompiler','webgl','websockets','webwidget/designdemo',
    'webwidget/nativedesign', 'webwidget/widgets','xterm','zenfs' );

Var
  P : TPackage;
  aDemo, UnitDir,DemoDir,BD, TmpCfg, TmpCfg2: String;
  {$IF FPC_FULLVERSION>=30301}
  T: TTarget;
  {$ENDIF}
  FPCSrcDir, Pas2jsOFilename, RTLJSFilename: String;

begin
  FPCSrcDir:=GetEnvironmentVariable('FPCDIR');
  if FPCSrcDir<>'' then
    FPCSrcDir:=IncludeTrailingPathDelimiter(ExpandFileName(FPCSrcDir));
  if FPCSrcDir='' then
    FPCSrcDir:=IncludeTrailingPathDelimiter(GetCurrentDir)+'compiler'+PathDelim;

  With Installer do
    begin
    P:=AddPackage('pas2js');
    P.Author := 'Free Pascal Team';
    P.License := 'LGPL with modification';
    P.HomepageURL := 'www.freepascal.org';
    P.Description := 'Convert pascal sources to javascript.';
    P.Email := 'michael@freepascal.org';
    P.NeedLibC:= false;
    P.Version:='3.3.1';
    P.SourcePath.Add(FPCSrcDir+'utils/pas2js');
    P.UnitPath.Add(FPCSrcDir+'utils/pas2js');
    P.UnitPath.Add(FPCSrcDir+'packages/pastojs/src');
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-passrc/src');
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-js/src');
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-json/src');
    {$IF FPC_FULLVERSION>=30301}
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-base/src');
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-web/src/base');
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-net/src');
    P.IncludePath.Add(FPCSrcDir+'packages/fcl-net/src/unix',AllUnixOSes);
    P.IncludePath.Add(FPCSrcDir+'packages/fcl-net/src/win',AllWindowsOSes);
    P.IncludePath.Add(FPCSrcDir+'packages/fcl-net/src/os2',[EMX]);
    P.IncludePath.Add(FPCSrcDir+'packages/fcl-net/src/amiga',[morphos]);
    P.IncludePath.Add(FPCSrcDir+'packages/fcl-net/src/$(OS)',AllOSes-AllWindowsOSes-AllUnixOSes-[EMX]);
    P.UnitPath.Add(FPCSrcDir+'packages/fcl-base/src');
    P.IncludePath.Add(FPCSrcDir+'packages/fcl-base/src/dummy');
    P.UnitPath.Add(FPCSrcDir+'packages/webidl/src');
    {$ENDIF}
    P.IncludePath.Add(FPCSrcDir+'packages/pastojs/src');
    P.Dependencies.Clear;
    Defaults.Options.Add('-Sc');
    P.Targets.AddProgram('pas2js.pp');
    {$IF FPC_FULLVERSION>=30301}
    P.Targets.AddProgram('webidl2pas.pp');
    P.Targets.AddProgram('compileserver.pp');
    P.Targets.AddProgram('makestub.pp');
    T:=P.Targets.AddLibrary('pas2jslib.pp');
    if Defaults.OS=Linux then
      T.SetExeName('libpas2js.so');
    {$ENDIF}
    P.Targets.AddImplicitUnit('fpjson',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('fppas2js',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('fppjssrcmap',False);
    P.Targets.AddImplicitUnit('jsbase',False);
    P.Targets.AddImplicitUnit('jsonparser',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('jsonreader',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('jsonscanner',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('jssrcmap',False);
    P.Targets.AddImplicitUnit('jstoken',False);
    P.Targets.AddImplicitUnit('jstree',False);
    P.Targets.AddImplicitUnit('jswriter',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('pas2jscompiler',False);
    P.Targets.AddImplicitUnit('pas2jslogger',False);
    P.Targets.AddImplicitUnit('pas2jspparser',False);
    P.Targets.AddImplicitUnit('pas2jsuseanalyzer',False);
    P.Targets.AddImplicitUnit('pas2jsfs',False);
    P.Targets.AddImplicitUnit('pas2jsfilecache',False);
    P.Targets.AddImplicitUnit('pas2jsfileutils',False);
    P.Targets.AddImplicitUnit('pas2jslibcompiler',False);
    P.Targets.AddImplicitUnit('pas2jsfscompiler',False);
    P.Targets.AddImplicitUnit('pas2jscompilercfg',False);
    P.Targets.AddImplicitUnit('pas2jscompilerpp',False);
    P.Targets.AddImplicitUnit('pas2jsutils',False);
    P.Targets.AddImplicitUnit('pasresolveeval',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('pasresolver',False);
    P.Targets.AddImplicitUnit('pastree',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('pasuseanalyzer',False);
    P.Targets.AddImplicitUnit('pparser',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('pscanner',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('pascodegen.o',False);
    {$IF FPC_FULLVERSION>=30301}
    P.Targets.AddImplicitUnit('webidldefs',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('webidlscanner',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('webidlparser',False).ResourceStrings:=True;
    P.Targets.AddImplicitUnit('webidltopas',False).ResourceStrings:=True;
    {$ENDIF}
    P.Targets.AddImplicitUnit('stubcreator',False).ResourceStrings:=True;
    // Determine unit files location
    {$IF DECLARED(TCompileTarget)}
    BD:=IncludeTrailingPathDelimiter(P.GetBinOutputDir(Defaults.BuildTarget));
    {$ELSE} 
    BD:=IncludeTrailingPathDelimiter(P.GetBinOutputDir(Defaults.BuildCPU,Defaults.BuildOS));
    {$ENDIF}
    TmpCfg:=FPCSrcDir+'utils/pas2js/dist/pas2js.cfg';
    TmpCfg2:=FPCSrcDir+'utils/pas2js/dist/pas2js-namespaced.cfg';
    Case Installer.RunMode of
    rmCompile,rmBuild:
      begin
      RTLJSFilename:=SetDirSeparators(FPCSrcDir+'utils/pas2js/dist/');
      RTLJSFilename:=ExtractRelativePath(ExpandFileName(BD),RTLJSFilename);
      if not FileExists(BD+'pas2js.cfg') then
        CreateConfigFile(BD+'pas2js.cfg',SetDirSeparators('../../packages'),RTLJSFilename);
      if not FileExists(BD+'pas2js-namespaced.cfg') then
        CreateNameSpacedConfigFile(BD+'pas2js-namespaced.cfg');
      end;
    rmInstall,rmArchive,rmZipInstall:
      begin
      // UnitDir = some\path\units\i386-win32\..\..\..\pas2js\
      UnitDir:=ExcludeTrailingPathDelimiter(Defaults.UnitInstallDir);
      UnitDir:=ExcludeTrailingPathDelimiter(ExtractFilePath(UnitDir));
      UnitDir:=ExcludeTrailingPathDelimiter(ExtractFilePath(UnitDir));
      UnitDir:=ExtractFilePath(UnitDir);
      UnitDir:=UnitDir+'pas2js'+PathDelim;
      RTLJSFilename:=ExtractRelativePath(IncludeTrailingPathDelimiter(Defaults.BinInstallDir),
                            UnitDir+'rtl'+PathDelim);
      // Config file
      // Create config file
      CreateConfigFile(TmpCfg,
        ExtractRelativePath(IncludeTrailingPathDelimiter(Defaults.BinInstallDir),
                            UnitDir),RTLJSFilename);
      CreateNamespacedConfigFile(TmpCfg2);
      P.InstallFiles.Add(TmpCfg,Defaults.BinInstallDir);
      P.InstallFiles.Add(TmpCfg2,Defaults.BinInstallDir);
      P.InstallFiles.Add(FPCSrcDir+'utils/pas2js/dist/rtl.js',IncludeTrailingPathDelimiter(UnitDir)+'rtl');
      AddPackageFiles(P.InstallFiles,'chartjs',UnitDir);
      AddPackageFiles(P.InstallFiles,'dataabstract',UnitDir);
      AddPackageFiles(P.InstallFiles,'fcl-base',UnitDir);
      AddPackageFiles(P.InstallFiles,'fcl-db',UnitDir);
      AddPackageFiles(P.InstallFiles,'fcl-json',UnitDir);
      AddPackageFiles(P.InstallFiles,'fpcunit',UnitDir);
      AddPackageFiles(P.InstallFiles,'jspdf',UnitDir);
      AddPackageFiles(P.InstallFiles,'nodejs',UnitDir);
      AddPackageFiles(P.InstallFiles,'rtl',UnitDir);
      AddPackageFiles(P.InstallFiles,'atom',UnitDir);
      AddPackageFiles(P.InstallFiles,'job',UnitDir);
      AddPackageFiles(P.InstallFiles,'pushjs',UnitDir);
      AddPackageFiles(P.InstallFiles,'wasi',UnitDir);
      AddPackageFiles(P.InstallFiles,'bootstrap',UnitDir); 
      AddPackageFiles(P.InstallFiles,'fullcalendar',UnitDir);   
      AddPackageFiles(P.InstallFiles,'datatables',UnitDir);   
      AddPackageFiles(P.InstallFiles,'pdfjs',UnitDir);   
      AddPackageFiles(P.InstallFiles,'fcl-rpc',UnitDir);   
      AddPackageFiles(P.InstallFiles,'bulma',UnitDir);   
      AddPackageFiles(P.InstallFiles,'electron',UnitDir);   
      AddPackageFiles(P.InstallFiles,'htmlfragment',UnitDir);   
      AddPackageFiles(P.InstallFiles,'opentok',UnitDir);   
      AddPackageFiles(P.InstallFiles,'tinyeditor',UnitDir);   
      AddPackageFiles(P.InstallFiles,'xterm',UnitDir);   
      AddPackageFiles(P.InstallFiles,'flatpickr',UnitDir);   
      AddPackageFiles(P.InstallFiles,'jitsimeet',UnitDir);   
      AddPackageFiles(P.InstallFiles,'kurento',UnitDir);   
      AddPackageFiles(P.InstallFiles,'vscode',UnitDir);   
      AddPackageFiles(P.InstallFiles,'webwidget',UnitDir);   
      AddPackageFiles(P.InstallFiles,'zenfs',UnitDir);   
      AddPackageFiles(P.InstallFiles,'wasm-utils',UnitDir);   
      AddPackageFiles(P.InstallFiles,'wasm-oi',UnitDir);   
      // Demo files
      DemoDir:=IncludeTrailingPathDelimiter(Defaults.ExamplesInstallDir);
      For aDemo in Demos do
        AddDemoFiles(P.InstallFiles,aDemo,DemoDir);
      end;
    rmClean:
      begin
      P.CleanFiles.Add(TmpCfg);
      // workaround for fpc bug 40602: delete pas2js.o in FPCDIR
      Pas2jsOFilename:=FPCSrcDir+SetDirSeparators('utils/pas2js/units/'+Defaults.Target+'/pas2js.o');
      if FileExists(Pas2jsOFilename) then
        if not DeleteFile(Pas2jsOFilename) then
          begin
          writeln('Unable to delete "'+Pas2jsOFilename+'"');
          Halt(3);
          end;
      end;
    rmDistClean:
      if FileExists(BD+'pas2js.cfg') then
        P.CleanFiles.Add(BD+'pas2js.cfg');
    end;
    Run;
    end;
end.
