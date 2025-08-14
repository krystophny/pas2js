{
    This file is part of the Pas2JS run time library.
    
    Provides a Webassembly module with locale querying functions.
    Copyright (c) 2025 by Michael Van Canneyt

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit wasm.pas2js.locale;

{$mode ObjFPC}

interface

uses
  weborworker, JS, SysUtils, wasienv, wasm.locale.shared;


Type
  TLocaleError = longint;

  { TWasmLocaleAPI }

  TWasmLocaleAPI = Class(TImportExtension)
    FLongMonthNames : Array[1..12] of string;
    FShortMonthNames : Array[1..12] of string;
    FLongDayNames : Array[1..7] of string;
    FShortDayNames : Array[1..7] of string;
    FTimeSeparator : String;
    FDateSeparator : String;
    FDecimalSeparator : String;
    FLocale : JSValue;
    FThousandSeparator : string;
    FCurrencySymbol : string;
  private
    // exported calls
    procedure SetWasmLocale(aLocale : TWasmPointer; aLocaleLen: Longint);
    function GetNameOfDay(aDay: Integer; aLong: Integer; aName: TWasmPointer; aNameLen: TWasmPointer): TLocaleError;
    function GetNameOfMonth(aMonth: Integer; aLong: Integer; aName: TWasmPointer; aNameLen: TWasmPointer): TLocaleError;
    function GetTimeSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
    function GetDateSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
    function GetDecimalSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
    function GetThousandSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
    function GetCurrencySymbol(aSymbol: TWasmPointer; aSymbolLen: TWasmPointer): TLocaleError;
    // Follows Javascript getTimezonOffset convention (UTC+3 is -180)
    function GetTimeZoneOffset : Integer;
    procedure InitAll;
    procedure InitTimeSeparator;
    procedure InitDateSeparator;
    procedure InitDecimalSeparator;
    procedure InitThousandSeparator;
    procedure InitCurrencySymbol;
    procedure InitMonthNames;
    procedure InitDayNames;
    function WriteToMem(const aValue: String; aData: TWasmPointer; aDataLen: TWasmPointer): TLocaleError;
  public
    constructor Create(aEnv: TPas2JSWASIEnvironment); override;
    procedure FillImportObject(aObject: TJSObject); override;
    function GetTimeZoneVar(aDate: TJSDate): string;
    function ImportName: String; override;
  end;


implementation


{ TWasmLocaleAPI }

(*
function getTimezoneOffsetString() {
  const offsetMinutes = new Date().getTimezoneOffset();
  const sign = offsetMinutes > 0 ? '-' : '+'; // Invert sign for display (e.g., UTC-5 means offsetMinutes is 300)
  const absOffsetMinutes = Math.abs(offsetMinutes);
  const hours = Math.floor(absOffsetMinutes / 60);
  const minutes = absOffsetMinutes % 60;

  const paddedHours = String(hours).padStart(2, '0');
  const paddedMinutes = String(minutes).padStart(2, '0');

  return `UTC${sign}${paddedHours}:${paddedMinutes}`;
}
*)

procedure TWasmLocaleAPI.InitMonthNames;
var
  lDate: TJSDate;
  lMonthName : string;
  lOptions : TJSDateLocaleOptions;
  I : integer;

begin
  // Create a DateFormatter for each month
  for i:=0 to 11 do
    begin
    ldate := TJSDate.New(2000, i, 1); // Use a fixed year and day, only month matters
    lOptions:=TJSDateLocaleOptions.New;
    lOptions.month:='long';
    lmonthName := TJSIntl.UndefinedDateTimeFormat(fLocale,lOptions).Format(ldate);
    FLongMonthNames[i+1]:=lmonthName;
    lOptions.month:='short';
    lmonthName := TJSIntl.UndefinedDateTimeFormat(fLocale,lOptions).Format(ldate);
    FShortMonthNames[i+1]:=lmonthName;
    end;
end;

constructor TWasmLocaleAPI.Create(aEnv: TPas2JSWASIEnvironment);
begin
  inherited Create(aEnv);
  FLocale:=Undefined;
  InitAll;
end;

function TWasmLocaleAPI.GetTimeZoneOffset: Integer;
begin
  Result:=-TJSDate.New.getTimezoneOffset();
end;

procedure TWasmLocaleAPI.InitAll;
begin
  InitTimeSeparator;
  InitDateSeparator;
  InitDecimalSeparator;
  InitThousandSeparator;
  InitCurrencySymbol;
  InitMonthNames;
  InitDayNames;
end;

procedure TWasmLocaleAPI.InitTimeSeparator;
var
  lFormatter : TJSIntlDateTimeFormat;
  lOptions : TJSDateLocaleOptions;
  lParts : TJSFormatDatePartArray;
  lPart : TJSFormatDatePart;
  S : String;

begin
  lOptions:=TJSDateLocaleOptions.New;
  lOptions.hour:='2-digit';
  lOptions.minute:='2-digit';
  lOptions.second:='2-digit';
  lOptions.hour12:=false; // Use 24-hour format to avoid AM/PM literals
  lformatter := TJSIntl.UndefinedDateTimeFormat(flocale,lOptions);
  lparts := lformatter.formatToParts(TJSDate.New(2023, 0, 15)); // Jan 15, 2023
  S:='';
  for lPart in lParts do
    if (lPart.type_='literal') and (S='') then
      S:=lPart.value;
  if S='' then
    S:=':';
  FTimeSeparator:=S;
end;

procedure TWasmLocaleAPI.InitDateSeparator;
var
  lFormatter : TJSIntlDateTimeFormat;
  lOptions : TJSDateLocaleOptions;
  lParts : TJSFormatDatePartArray;
  lPart : TJSFormatDatePart;
  S : String;

begin
  lOptions:=TJSDateLocaleOptions.New;
  lOptions.year := 'numeric';
  lOptions.Month := '2-digit';
  lOptions.Day := '2-digit';
  lformatter := TJSIntl.UndefinedDateTimeFormat(Flocale,lOptions);
  lparts := lformatter.formatToParts(TJSDate.New(2023, 0, 1, 13, 30, 45));
  S:='';
  for lPart in lParts do
    if (lPart.type_='literal') and (S='') then
      S:=lPart.value;
  if S='' then
    S:='/';
  FDateSeparator:=S;
end;

procedure TWasmLocaleAPI.InitDayNames;

var
  lDate : TJSDate;
  lOptions : TJSDateLocaleOptions;
  lDayName : string;
  I : integer;
begin
    // Create a Date object for each day of the week, starting from Sunday (0)
  for i := 1 to 7 do
    begin
    ldate :=TJSDate.New(2000, 0, 2 + i); // Jan 3, 2000 was a Monday.
    lOptions:=TJSDateLocaleOptions.New;
    lOptions.weekday:='long';
    ldayName:=TJSIntl.UndefinedDateTimeFormat(fLocale,lOptions).format(lDate);
    FLongDayNames[i]:=lDayName;
    lOptions:=TJSDateLocaleOptions.New;
    lOptions.weekday:='short';
    ldayName:=TJSIntl.UndefinedDateTimeFormat(fLocale,lOptions).format(lDate);
    FShortDayNames[i]:=lDayName;
    end;
end;

procedure TWasmLocaleAPI.InitDecimalSeparator;

var
  lformatter : TJSIntlNumberFormat;
  lParts : TJSIntlNumberPartArray;
  lPart : TJSIntlNumberPart;
  lSep : string;
begin
  // Format a number with a decimal point and then extract the decimal separator.
  lformatter:=TJSIntl.UndefinedNumberFormat(FLocale);
  lparts:=lformatter.formatToParts(1.1);
  lSep:='.';
  for lPart in lParts do
    if lPart.Type_='decimal' then
      lSep:=lPart.Value;
  FDecimalSeparator:=lSep;
end;

procedure TWasmLocaleAPI.InitThousandSeparator;
var
  lformatter : TJSIntlNumberFormat;
  lParts : TJSIntlNumberPartArray;
  lPart : TJSIntlNumberPart;
  lSep : string;
begin
  // Format a number with a decimal point and then extract the decimal separator.
  lformatter:=TJSIntl.UndefinedNumberFormat(FLocale);
  lparts:=lformatter.formatToParts(1000);
  lSep:='.';
  for lPart in lParts do
    if lPart.Type_='group' then
      lSep:=lPart.Value;
  FThousandSeparator:=lSep;
end;

procedure TWasmLocaleAPI.InitCurrencySymbol;

var
  lformatter : TJSIntlNumberFormat;
  lOptions : TJSNumberFormatOptions;
  lParts : TJSIntlNumberPartArray;
  lPart : TJSIntlNumberPart;
  lCurr : string;
begin
  try
    lOptions:=TJSNumberFormatOptions.New;
    lOptions.Style:='currency';
    lOptions.currency_:='currencyCode';
    lOptions.minimumFractionDigits:=0;
    lOptions.maximumFractionDigits:=0;
    lformatter:=TJSIntl.UndefinedNumberFormat(Flocale, lOptions);
    lparts:=lFormatter.formatToParts(0); // Format 0 to get just the symbol
    lCurr:='$';
    for lPart in lParts do
      if lPart.Type_='currency' then
        lCurr:=lPart.Value;
    FCurrencySymbol:=lCurr;
  except
    Console.Log('Unable to determine currency symbol');
  end;
end;

function TWasmLocaleAPI.WriteToMem(const aValue : String; aData : TWasmPointer; aDataLen : TWasmPointer) : TLocaleError;

var
  lRes : Integer;
  lLen : Integer;
begin
  lLen:=Env.GetMemInfoInt32(AdataLen);
  lRes:=Env.SetUTF8StringInMem(aData,lLen,aValue);
  if lRes<0 then
    begin
    Env.SetMemInfoInt32(aDataLen,lRes);
    Result:=ELocale_SIZETOOSMALL;
    end
  else
    begin
    Env.SetMemInfoInt32(aDataLen,lRes);
    Result:=ELocale_SUCCESS;
    end;
end;

// 1-based
function TWasmLocaleAPI.GetNameOfMonth(aMonth : Integer; aLong : Integer; aName : TWasmPointer; aNameLen : TWasmPointer) : TLocaleError;
var
  lName : string;
begin
  If (aMonth<1) or (aMonth>12) then
    exit(ELocale_INVALIDINDEX);
  if aLong<>0 then
    lName:=FLongMonthNames[aMonth]
  else
    lName:=FShortMonthNames[aMonth];
  Result:=WriteToMem(lName,aName,aNameLen);
end;

function TWasmLocaleAPI.GetTimeSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
begin
  Result:=WriteToMem(FTimeSeparator,aSeparator,aSeparatorLen);
end;

function TWasmLocaleAPI.GetDateSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
begin
  Result:=WriteToMem(FDateSeparator,aSeparator,aSeparatorLen);
end;

function TWasmLocaleAPI.GetDecimalSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
begin
  Result:=WriteToMem(FDecimalSeparator,aSeparator,aSeparatorLen);
end;

function TWasmLocaleAPI.GetThousandSeparator(aSeparator: TWasmPointer; aSeparatorLen: TWasmPointer): TLocaleError;
begin
  Result:=WriteToMem(FThousandSeparator,aSeparator,aSeparatorLen);
end;

function TWasmLocaleAPI.GetCurrencySymbol(aSymbol: TWasmPointer; aSymbolLen: TWasmPointer): TLocaleError;
begin
  Result:=WriteToMem(FCurrencySymbol,aSymbol,aSymbolLen);
end;

procedure TWasmLocaleAPI.SetWasmLocale(aLocale: TWasmPointer; aLocaleLen: Longint);

begin
  if (aLocaleLen=0) or (aLocale=0) then
    fLocale:=undefined
  else
    fLocale:=Env.GetUTF8StringFromMem(aLocale,aLocaleLen);
  InitAll;
end;

// ISO: 1 = Monday, 7=Sunday
function TWasmLocaleAPI.GetNameOfDay(aDay : Integer; aLong : Integer; aName : TWasmPointer; aNameLen : TWasmPointer) : TLocaleError;
var
  lName : string;
begin
  If (aDay<1) or (aDay>7) then
    exit(ELocale_INVALIDINDEX);
  if aLong<>0 then
    lName:=FLongDayNames[aDay]
  else
    lName:=FShortDayNames[aDay];
  Result:=WriteToMem(lName,aName,aNameLen);
end;


procedure TWasmLocaleAPI.FillImportObject(aObject: TJSObject);
begin
  aObject[HostLocale_FNSetWasmLocale]:=@SetWasmLocale;
  aObject[HostLocale_FNGetTimezoneOffset]:=@GetTimeZoneOffset;
  aObject[HostLocale_FNGetNameOfMonth]:=@GetNameOfMonth;
  aObject[HostLocale_FNGetNameOfDay]:=@GetNameOfDay;
  aObject[HostLocale_FNGetDecimalSeparator]:=@GetDecimalSeparator;
  aObject[HostLocale_FNGetThousandsSeparator]:=@GetThousandSeparator;
  aObject[HostLocale_FNGetCurrencyChar]:=@GetCurrencySymbol;
  aObject[HostLocale_FNGetDateSeparator]:=@GetDateSeparator;
  aObject[HostLocale_FNGetTimeSeparator]:=@GetTimeSeparator;
end;

function TWasmLocaleAPI.GetTimeZoneVar(aDate : TJSDate): string;
var
  posixOffsetString,
  stdAbbr : string;
  timezoneOffsetMinutes : Integer;
  absOffsetMinutes : Integer;
  offsetHours : integer;
  offsetMinutes : integer;
begin
  stdAbbr := 'UTC';
  timezoneOffsetMinutes := aDate.getTimezoneOffset();
  absOffsetMinutes :=abs(timezoneOffsetMinutes);
  offsetHours := trunc(absOffsetMinutes / 60);
  offsetMinutes := absOffsetMinutes mod 60;

  if (timezoneOffsetMinutes < 0) then
    posixOffsetString := '+'
  else
    posixOffsetString := '-';
  posixOffsetString := posixOffsetString + IntToStr(offsetHours);
  if (offsetMinutes > 0) then
    posixOffsetString := ':' + posixOffsetString +Format('%.2d',[offsetMinutes]);
  result:=stdAbbr+posixOffsetString;
end;

function TWasmLocaleAPI.ImportName: String;
begin
  Result:='hostlocale'
end;

end.

