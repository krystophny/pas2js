{
    This file is part of the Pas2JS run time library.
    
    Constants for the a Webassembly module with locale querying functions.
    Copyright (c) 2025 by Michael Van Canneyt

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit wasm.locale.shared;

{$mode ObjFPC}

interface

const
  modHostLocale = 'hostlocale';

  HostLocale_FNSetWasmLocale = 'hostlocale_setwasmlocale';
  HostLocale_FNGetTimezoneOffset = 'hostlocale_gettimezoneoffset';
  HostLocale_FNGetNameOfMonth = 'hostlocale_getnameofmonth';
  HostLocale_FNGetNameOfDay = 'hostlocale_getnameofday';
  HostLocale_FNGetTimeSeparator = 'hostlocale_gettimeseparator';
  HostLocale_FNGetDateSeparator = 'hostlocale_getdateseparator';
  HostLocale_FNGetDecimalSeparator = 'hostlocale_getdecimalseparator';
  HostLocale_FNGetThousandsSeparator = 'hostlocale_getthousandsseparator';
  HostLocale_FNGetCurrencyFormat = 'hostlocale_getcurrencyformat';
  HostLocale_FNGetCurrencyChar = 'hostlocale_getcurrencyChar';

  ELocale_SUCCESS = 0;
  ELocale_INVALIDINDEX = -1;
  ELocale_SIZETOOSMALL = -2;

implementation

end.

