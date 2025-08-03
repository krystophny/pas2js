Unit libace;

{$MODE ObjFPC}
{$H+}
{$modeswitch externalclass}

interface

uses SysUtils, JS,web;

{$INTERFACES CORBA}
Type
  // Forward class definitions
  TDelta = Class;
  TEditorCommand = Class;
  TCommandMap = Class;
  TCommandManager = Class;
  TAnnotation = Class;
  TTokenInfo = Class;
  TPosition = Class;
  TKeyboardHandler = Class;
  TKeyBinding = Class;
  TTextMode = Class;
  TOptionProvider = Class;
  TAce = Class;
  TAnchor = Class;
  TBackgroundTokenizer = Class;
  TDocument = Class;
  TIEditSession = Class;
  TEditor = Class;
  TEditorChangeEvent = Class;
  TPlaceHolder = Class;
  TIRangeList = Class;
  TRange = Class;
  TRenderLoop = Class;
  TScrollBar = Class;
  TSearch = Class;
  TSelection = Class;
  TSplit = Class;
  TTokenIterator = Class;
  TTokenizer = Class;
  TUndoManager = Class;
  TVirtualRenderer = Class;
  TCompleter = Class;
  TCompletion = Class;
  // Forward class definitions
  TLayer = Class;

  TTexecEventHandler_obj_args = TJSArray;

  TTexecEventHandler_obj = class external name 'Object' (TJSObject)
  Public
    editor : TEditor;
    command : TEditorCommand;
    args : TTexecEventHandler_obj_args;
  end;


  TexecEventHandler = Procedure (obj : TTexecEventHandler_obj);
  TCommandLike = jsvalue; // EditorCommand |
  TNewLineMode = string; // Restricted values
  TCompletionCallback = Procedure (error : jsvalue; results : array of TCompletion);
  // Namespaces

  TLayer = class external name 'Layer' (TJSObject)
  Public
    Type
      // Forward class definitions
      TCursor = Class;

      TCursor = class external name 'Object' (TJSObject)
          Procedure hideCursor;
          Procedure setBlinking(blinking : boolean);
          Procedure setBlinkInterval(blinkInterval : Double);
          Procedure showCursor;
      end;


  end;

  TDelta_lines = array of string;
  TDelta = class external name 'Object' (TJSObject)
      action : jsvalue;
      start : TPosition;
      &end : TPosition;external name 'end';
      lines : TDelta_lines;
  end;

  TEditorCommand_exec = Procedure (editor : TEditor; args : JSValue);
  TEditorCommand = class external name 'Object' (TJSObject)
      name : jsvalue;
      bindKey : jsvalue;
      exec : TEditorCommand_exec;
      readOnly : jsvalue;
  end;

  TCommandMap = class external name 'Object' (TJSObject)
  end;

  TCommandManager_bindKeys_keys = class external name 'Object' (TJSObject)
  Public
  end;

  TCommandManager_parseKeys_Result = class external name 'Object' (TJSObject)
  Public
    key : string;
    hashId : Double;
  end;

  TCommandManager_handleKeyboard_data = class external name 'Object' (TJSObject)
  end;

  TCommandManager_getStatusText_data = class external name 'Object' (TJSObject)
  end;

  TCommandManager = class external name 'Object' (TJSObject)
      Function &on(name : String; callback : TexecEventHandler): TJSFunction; overload;
      Function &on(name : string; callback : TJSFunction; capturing : boolean): TJSFunction; overload;
      Function &on(name : string; callback : TJSFunction): TJSFunction; overload;
      Procedure addCommand(command : TEditorCommand);
      Procedure addCommands(commands : array of TEditorCommand);
      Procedure addEventListener(name : string; callback : TJSFunction; capturing : boolean); overload;
      Procedure addEventListener(name : string; callback : TJSFunction); overload;
      Procedure bindKey(key : jsvalue; command : TCommandLike; position : Double); overload;
      Procedure bindKey(key : jsvalue; command : TCommandLike); overload;
      Procedure bindKeys(keys : TCommandManager_bindKeys_keys);
      Function exec(command : string; editor : TEditor; args : JSValue): boolean;
      Function findKeyCommand(hashId : Double; keyString : string): jsvalue;
      Function getStatusText(editor : TEditor; data : TCommandManager_getStatusText_data): string;
      Function handleKeyboard(data : TCommandManager_handleKeyboard_data; hashId : Double; keyString : string; keyCode : jsvalue): jsvalue;
      Procedure off(name : string; callback : TJSFunction);
      Procedure once(name : string; callback : TJSFunction);
      Function parseKeys(keyPart : string): TCommandManager_parseKeys_Result;
      Procedure removeCommand(command : jsvalue; keepCommand : boolean); overload;
      Procedure removeCommand(command : jsvalue); overload;
      Procedure removeCommands(command : array of TEditorCommand);
      Procedure removeDefaultHandler(name : string; callback : TJSFunction);
      Procedure removeEventListener(name : string; callback : TJSFunction);
      Procedure removeListener(name : string; callback : TJSFunction);
      Procedure replay(editor : TEditor);
      Procedure setDefaultHandler(name : string; callback : TJSFunction);
      Procedure toggleRecording(editor : TEditor);
      byName : TCommandMap;
      commands : TCommandMap;
      platform : string;
  end;

  TAnnotation = class external name 'Object' (TJSObject)
      row : jsvalue;
      column : jsvalue;
      text : string;
      &type : string;external name 'type';
  end;

  TTokenInfo = class external name 'Object' (TJSObject)
      &type : string;external name 'type';
      value : string;
      index : jsvalue;
      start : jsvalue;
  end;

  TPosition = class external name 'Object' (TJSObject)
      row : Double;
      column : Double;
  end;

  TKeyboardHandler = class external name 'Object' (TJSObject)
      handleKeyboard : TJSFunction;
  end;

  TKeyBinding = class external name 'Object' (TJSObject)
      Procedure addKeyboardHandler(kb : TKeyboardHandler; pos : Double);
      Function getKeyboardHandler: TKeyboardHandler;
      Function onCommandKey(e : JSValue; hashId : Double; keyCode : Double): boolean;
      Function onTextInput(text : string): boolean;
      Function removeKeyboardHandler(kb : TKeyboardHandler): boolean;
      Procedure setDefaultHandler(kb : TKeyboardHandler);
      Procedure setKeyboardHandler(kb : TKeyboardHandler);
  end;

  TTextMode_createModeDelegates_mapping = class external name 'Object' (TJSObject)
  Public
  end;

  TTextMode_getKeywords_Result = array of JSValue;
  TTextMode_getCompletions_Result = array of TCompletion;
  TTextMode = class external name 'Object' (TJSObject)
      Procedure autoOutdent(state : JSValue; doc : TDocument; row : Double);
      Function checkOutdent(state : JSValue; line : string; input : string): boolean;
      Procedure createModeDelegates(mapping : TTextMode_createModeDelegates_mapping);
      Function createWorker(session : TIEditSession): JSValue;
      Function getCompletions(state : string; session : TIEditSession; pos : TPosition; prefix : string): TTextMode_getCompletions_Result;
      Function getKeywords(append : boolean): TTextMode_getKeywords_Result; overload;
      Function getKeywords: TTextMode_getKeywords_Result; overload;
      Function getNextLineIndent(state : JSValue; line : string; tab : string): string;
      Function getTokenizer: TTokenizer;
      Procedure toggleBlockComment(state : JSValue; session : TIEditSession; range : TRange; cursor : TPosition);
      Procedure toggleCommentLines(state : JSValue; session : TIEditSession; startRow : Double; endRow : Double);
      Function transformAction(state : string; action : string; editor : TEditor; session : TIEditSession; text : string): JSValue;
  end;

  TOptionProvider_setOptions_keyValueTuples = class external name 'Object' (TJSObject)
  Public
  end;

  TOptionProvider_getOptions_Result = class external name 'Object' (TJSObject)
  Public
  end;

  TOptionProvider = class external name 'Object' (TJSObject)
      Function getOption(name : string): JSValue;
      Function getOptions(optionNames : jsvalue): TOptionProvider_getOptions_Result; overload;
      Function getOptions: TOptionProvider_getOptions_Result; overload;
      Procedure setOption(optionName : string; optionValue : JSValue);
      Procedure setOptions(keyValueTuples : TOptionProvider_setOptions_keyValueTuples);
  end;

  TAce = class external name 'Object' (TJSObject)
      Function createEditSession(text : TDocument; mode : TTextMode): TIEditSession; overload;
      Function createEditSession(text : string; mode : TTextMode): TIEditSession; overload;
      Function edit(el : string): TEditor; overload;
      Function edit(el : TJSHTMLElement): TEditor; overload;
      Function require(moduleName : string): JSValue;
  end;

  TAnchor_on_fn = Function (e : JSValue): JSValue;
  TAnchor = class external name 'Object' (TJSObject)
      class Function &new(doc : TDocument; row : Double; column : Double): TAnchor;
      Procedure &on(event : string; fn : TAnchor_on_fn);
      Procedure attach(doc : TDocument);
      Procedure detach;
      Function getDocument: TDocument;
      Function getPosition: TPosition;
      Procedure onChange(e : JSValue);
      Procedure setPosition(row : Double; column : Double; noClip : boolean); overload;
      Procedure setPosition(row : Double; column : Double); overload;
  end;

  TBackgroundTokenizer_states = array of JSValue;
  TBackgroundTokenizer_getTokens_Result = array of TTokenInfo;
  TBackgroundTokenizer = class external name 'Object' (TJSObject)
      class Function &new(tokenizer : TTokenizer; editor : TEditor): TBackgroundTokenizer;
      Procedure fireUpdateEvent(firstRow : Double; lastRow : Double);
      Function getState(row : Double): string;
      Function getTokens(row : Double): TBackgroundTokenizer_getTokens_Result;
      Procedure setDocument(doc : TDocument);
      Procedure setTokenizer(tokenizer : TTokenizer);
      Procedure start(startRow : Double);
      Procedure stop;
      states : TBackgroundTokenizer_states;
  end;

  TDocument_on_fn = Function (e : JSValue): JSValue;
  TDocument_getLines_Result = array of string;
  TDocument_getAllLines_Result = array of string;
  TDocument_getLinesForRange_Result = array of string;
  TDocument_removeLines_Result = array of string;
  TDocument_removeFullLines_Result = array of string;
  TDocument = class external name 'Object' (TJSObject)
      class Function &new(text : string): TDocument; overload;
      class Function &new: TDocument; overload;
      class Function &new(text : array of string): TDocument; overload;
      Procedure &on(event : string; fn : TDocument_on_fn);
      Procedure applyDeltas(deltas : array of TDelta);
      Function clippedPos(row : Double; column : Double): TPosition;
      Function clonePos(pos : TPosition): TPosition;
      Procedure createAnchor(row : Double; column : Double);
      Function getAllLines: TDocument_getAllLines_Result;
      Function getLength: Double;
      Function getLine(row : Double): string;
      Function getLines(firstRow : Double; lastRow : Double): TDocument_getLines_Result;
      Function getLinesForRange(range : TRange): TDocument_getLinesForRange_Result;
      Function getNewLineCharacter: string;
      Function getNewLineMode: TNewLineMode;
      Function getTextRange(range : TRange): string;
      Function getValue: string;
      Function indexToPosition(index : Double; startRow : Double): TPosition;
      Function insert(position : TPosition; text : string): TPosition;
      Procedure insertFullLines(row : Double; lines : array of string);
      Function insertInLine(position : TPosition; text : string): TPosition;
      Function insertLines(row : Double; lines : array of string): TPosition;
      Function insertMergedLines(row : Double; lines : array of string): TPosition;
      Function insertNewLine(position : TPosition): TPosition;
      Function isNewLine(text : string): boolean;
      Function pos(row : Double; column : Double): TPosition;
      Function positionToIndex(pos : TPosition; startRow : Double): Double; overload;
      Function positionToIndex(pos : TPosition): Double; overload;
      Function remove(range : TRange): TPosition;
      Function removeFullLines(firstRow : Double; lastRow : Double): TDocument_removeFullLines_Result;
      Function removeInLine(row : Double; startColumn : Double; endColumn : Double): TPosition;
      Function removeLines(firstRow : Double; lastRow : Double): TDocument_removeLines_Result;
      Procedure removeNewLine(row : Double);
      Function replace(range : TRange; text : string): TPosition;
      Procedure revertDeltas(deltas : array of TDelta);
      Procedure setNewLineMode(newLineMode : TNewLineMode);
      Procedure setValue(text : string);
  end;
  TIEditSession_on_fn = Function (e : JSValue): JSValue;
  TIEditSession_getTokens_Result = array of TTokenInfo;
  TIEditSession_getBreakpoints_Result = array of Double;
  TIEditSession_getMarkers_Result = array of JSValue;
  TIEditSession_getLines_Result = array of string;
  TIEditSession_getStringScreenWidth_Result = array of Double;
  TIEditSession = class external name 'Object' (TJSObject)
      class Function &new(text : string; mode : TTextMode): TIEditSession; overload;
      class Function &new(text : string): TIEditSession; overload;
      class Function &new(content : string; mode : string): TIEditSession; overload;
      class Function &new(text : array of string; mode : string): TIEditSession; overload;
      class Function &new(text : array of string): TIEditSession; overload;
      Procedure _detectNewLine(text : string); external name '$detectNewLine';
      Procedure _getDisplayTokens(str : string; offset : Double); external name '$getDisplayTokens';
      Function _getStringScreenWidth(str : string; maxScreenColumn : Double; screenColumn : Double): TIEditSession_getStringScreenWidth_Result; external name '$getStringScreenWidth';
      Procedure _mode(mode : TTextMode); external name '$mode';
      Procedure _resetRowCache(row : Double); external name '$resetRowCache';
      Procedure &on(event : string; fn : TIEditSession_on_fn);
      Procedure addDynamicMarker(marker : JSValue; inFront : boolean);
      Procedure addFold(text : string; range : TRange);
      Procedure addGutterDecoration(row : Double; className : string);
      Function addMarker(range : TRange; clazz : string; &type : TJSFunction; inFront : boolean): Double; overload;
      Function addMarker(range : TRange; clazz : string; &type : string; inFront : boolean): Double; overload;
      Function adjustWrapLimit(desiredLimit : Double): boolean;
      Procedure clearAnnotations;
      Procedure clearBreakpoint(row : Double);
      Procedure clearBreakpoints;
      Function documentToScreenColumn(row : Double; docColumn : Double): Double;
      Function documentToScreenPosition(docRow : Double; docColumn : Double): JSValue;
      Procedure documentToScreenRow(docRow : Double; docColumn : Double);
      Function duplicateLines(firstRow : Double; lastRow : Double): Double;
      Procedure expandFold(arg : JSValue);
      Procedure findMatchingBracket(position : TPosition);
      Procedure foldAll(startRow : Double; endRow : Double; depth : Double); overload;
      Procedure foldAll; overload;
      Procedure foldAll(startRow : Double); overload;
      Procedure foldAll(startRow : Double; endRow : Double); overload;
      Function getAnnotations: JSValue;
      Function getAWordRange(row : Double; column : Double): JSValue;
      Function getBreakpoints: TIEditSession_getBreakpoints_Result;
      Function getDocument: TDocument;
      Function getDocumentLastRowColumn(docRow : Double; docColumn : Double): Double;
      Function getDocumentLastRowColumnPosition(docRow : Double; docColumn : Double): Double;
      Function getFoldAt(row : Double; column : Double): JSValue;
      Function getFoldDisplayLine(foldLine : JSValue; docRow : Double; docColumn : Double): JSValue;
      Function getFoldsInRange(range : TRange): JSValue;
      Function getLength: Double;
      Function getLine(row : Double): string;
      Function getLines(firstRow : Double; lastRow : Double): TIEditSession_getLines_Result;
      Function getMarkers(inFront : boolean): TIEditSession_getMarkers_Result;
      Function getMode: TTextMode;
      Function getNewLineMode: string;
      Function getOverwrite: boolean;
      Function getRowLength(row : Double): Double;
      Function getRowSplitData: string;
      Function getScreenLastRowColumn(screenRow : Double): Double;
      Function getScreenLength: Double;
      Function getScreenTabSize(screenColumn : Double): Double;
      Function getScreenWidth: Double;
      Function getScrollLeft: Double;
      Function getScrollTop: Double;
      Function getSelection: TSelection;
      Function getState(row : Double): string;
      Function getTabSize: Double;
      Function getTabString: string;
      Function getTextRange(range : TRange): string;
      Function getTokenAt(row : Double; column : Double): jsvalue;
      Function getTokens(row : Double): TIEditSession_getTokens_Result;
      Function getUndoManager: TUndoManager;
      Function getUseSoftTabs: boolean;
      Function getUseWorker: boolean;
      Function getUseWrapMode: boolean;
      Function getValue: string;
      Function getWordRange(row : Double; column : Double): TRange;
      Function getWrapLimit: Double;
      Function getWrapLimitRange: JSValue;
      Procedure highlight(text : string);
      Function highlightLines(startRow : Double; endRow : Double; clazz : string; inFront : boolean): TRange;
      Procedure indentRows(startRow : Double; endRow : Double; indentString : string);
      Function insert(position : TPosition; text : string): JSValue;
      Function isTabStop(position : JSValue): boolean;
      Function moveLinesDown(firstRow : Double; lastRow : Double): Double;
      Function moveLinesUp(firstRow : Double; lastRow : Double): Double;
      Function moveText(fromRange : TRange; toPosition : JSValue): TRange;
      Procedure onReloadTokenizer;
      Procedure outdentRows(range : TRange);
      Function redoChanges(deltas : array of JSValue; dontSelect : boolean): TRange;
      Function remove(range : TRange): JSValue;
      Procedure removeFold(arg : JSValue);
      Procedure removeGutterDecoration(row : Double; className : string);
      Procedure removeMarker(markerId : Double);
      Function replace(range : TRange; text : string): JSValue;
      Procedure screenToDocumentColumn(row : Double; column : Double);
      Function screenToDocumentPosition(screenRow : Double; screenColumn : Double): JSValue;
      Procedure setAnnotations(annotations : array of TAnnotation);
      Procedure setBreakpoint(row : Double; className : string);
      Procedure setBreakpoints(rows : array of JSValue);
      Procedure setDocument(doc : TDocument);
      Procedure setMode(mode : string);
      Procedure setNewLineMode(newLineMode : string);
      Procedure setOverwrite(overwrite : boolean);
      Procedure setScrollLeft(scrollLeft : Double);
      Procedure setScrollTop(scrollTop : Double);
      Procedure setTabSize(tabSize : Double);
      Procedure setUndoManager(undoManager : TUndoManager);
      Procedure setUndoSelect(enable : boolean);
      Procedure setUseSoftTabs(useSoftTabs : boolean);
      Procedure setUseWorker(useWorker : boolean);
      Procedure setUseWrapMode(useWrapMode : boolean);
      Procedure setValue(text : string);
      Procedure setWrapLimitRange(min : Double; max : Double);
      Procedure toggleOverwrite;
      Function undoChanges(deltas : array of JSValue; dontSelect : boolean): TRange;
      Procedure unfold(arg1 : JSValue; arg2 : boolean);
      selection : TSelection;
      bgTokenizer : TBackgroundTokenizer;
      doc : TDocument;
  end;

  TEditor_on_callback = Function (e : JSValue): JSValue;
  TEditor_addEventListener_callback = Function (ev : TEditorChangeEvent): JSValue;
  TEditor = class external name 'Object' (TOptionProvider)
      class  Function &new(renderer : TVirtualRenderer; session : TIEditSession): TEditor; overload;
      class  Function &new(renderer : TVirtualRenderer): TEditor; overload;
      Procedure &on(ev : string; callback : TEditor_on_callback);
      Procedure addEventListener(ev : String; callback : TEditor_addEventListener_callback); overload;
      Procedure addEventListener(ev : string; callback : TJSFunction); overload;
      Procedure blockIndent;
      Procedure blockOutdent(arg : string); overload;
      Procedure blockOutdent; overload;
      Procedure blur;
      Procedure centerSelection;
      Procedure clearSelection;
      Function copyLinesDown: Double;
      Function copyLinesUp: Double;
      Procedure destroy;
      Procedure execCommand(command : string; args : JSValue); overload;
      Procedure execCommand(command : string); overload;
      Procedure find(needle : string; options : JSValue; animate : boolean); overload;
      Procedure find(needle : string); overload;
      Procedure find(needle : string; options : JSValue); overload;
      Procedure findNext(options : JSValue; animate : boolean); overload;
      Procedure findNext; overload;
      Procedure findNext(options : JSValue); overload;
      Procedure findPrevious(options : JSValue; animate : boolean); overload;
      Procedure findPrevious; overload;
      Procedure findPrevious(options : JSValue); overload;
      Procedure focus;
      Function getBehavioursEnabled: boolean;
      Function getCopyText: string;
      Function getCursorPosition: TPosition;
      Function getCursorPositionScreen: Double;
      Function getDragDelay: Double;
      Function getFirstVisibleRow: Double;
      Function getHighlightActiveLine: boolean;
      Function getHighlightSelectedWord: boolean;
      Function getKeyboardHandler: string;
      Function getLastSearchOptions: JSValue;
      Function getLastVisibleRow: Double;
      Function getNumberAt: Double;
      Function getOverwrite: boolean;
      Function getPrintMarginColumn: Double;
      Function getReadOnly: boolean;
      Function getScrollSpeed: Double;
      Function getSelection: TSelection;
      Function getSelectionRange: TRange;
      Function getSelectionStyle: string;
      Function getSession: TIEditSession;
      Procedure getShowFoldWidgets;
      Function getShowInvisibles: boolean;
      Function getShowPrintMargin: boolean;
      Function getTheme: string;
      Function getValue: string;
      Procedure getWrapBehavioursEnabled;
      Procedure gotoLine(lineNumber : Double; column : Double; animate : boolean); overload;
      Procedure gotoLine(lineNumber : Double); overload;
      Procedure gotoLine(lineNumber : Double; column : Double); overload;
      Procedure gotoPageDown;
      Procedure gotoPageUp;
      Procedure indent;
      Procedure insert(text : string);
      Function isFocused: boolean;
      Function isRowFullyVisible(row : Double): boolean;
      Function isRowVisible(row : Double): boolean;
      Procedure jumpToMatching;
      Procedure modifyNumber(amount : Double);
      Procedure moveCursorTo(row : Double; column : Double; animate : boolean); overload;
      Procedure moveCursorTo(row : Double); overload;
      Procedure moveCursorTo(row : Double; column : Double); overload;
      Procedure moveCursorToPosition(position : TPosition);
      Function moveLinesDown: Double;
      Function moveLinesUp: Double;
      Function moveText(fromRange : TRange; toPosition : JSValue): TRange;
      Procedure navigateDown(times : Double); overload;
      Procedure navigateDown; overload;
      Procedure navigateFileEnd;
      Procedure navigateFileStart;
      Procedure navigateLeft(times : Double); overload;
      Procedure navigateLeft; overload;
      Procedure navigateLineEnd;
      Procedure navigateLineStart;
      Procedure navigateRight(times : Double);
      Procedure navigateTo(row : Double; column : Double);
      Procedure navigateUp(times : Double); overload;
      Procedure navigateUp; overload;
      Procedure navigateWordLeft;
      Procedure navigateWordRight;
      Procedure off(ev : string; callback : TJSFunction);
      Procedure onBlur;
      Procedure onChangeMode(e : JSValue); overload;
      Procedure onChangeMode; overload;
      Procedure onCommandKey(e : JSValue; hashId : Double; keyCode : Double);
      Procedure onCopy;
      Procedure onCursorChange;
      Procedure onCut;
      Procedure onDocumentChange(e : JSValue);
      Procedure onFocus;
      Procedure onPaste(text : string);
      Procedure onSelectionChange(e : JSValue);
      Procedure onTextInput(text : string);
      Procedure redo;
      Procedure remove(dir : string);
      Procedure removeEventListener(ev : string; callback : TJSFunction);
      Procedure removeLines;
      Procedure removeListener(ev : string; callback : TJSFunction);
      Procedure removeToLineEnd;
      Procedure removeToLineStart;
      Procedure removeWordLeft;
      Procedure removeWordRight;
      Procedure replace(replacement : string; options : JSValue); overload;
      Procedure replace(replacement : string); overload;
      Procedure replaceAll(replacement : string; options : JSValue); overload;
      Procedure replaceAll(replacement : string); overload;
      Procedure resize(force : boolean); overload;
      Procedure resize; overload;
      Procedure scrollPageDown;
      Procedure scrollPageUp;
      Procedure scrollToLine(line : Double; center : boolean; animate : boolean; callback : TJSFunction);
      Procedure scrollToRow;
      Procedure selectAll;
      Procedure selectMoreLines(n : Double);
      Procedure selectPageDown;
      Procedure selectPageUp;
      Procedure setBehavioursEnabled(enabled : boolean);
      Procedure setDragDelay(dragDelay : Double);
      Procedure setFontSize(size : string);
      Procedure setHighlightActiveLine(shouldHighlight : boolean);
      Procedure setHighlightSelectedWord(shouldHighlight : boolean);
      Procedure setKeyboardHandler(keyboardHandler : string);
      Procedure setOverwrite(overwrite : boolean);
      Procedure setPrintMarginColumn(showPrintMargin : Double);
      Procedure setReadOnly(readOnly : boolean);
      Procedure setScrollSpeed(speed : Double);
      Procedure setSelectionStyle(style : string);
      Procedure setSession(session : TIEditSession);
      Procedure setShowFoldWidgets(show : boolean);
      Procedure setShowInvisibles(showInvisibles : boolean);
      Procedure setShowPrintMargin(showPrintMargin : boolean);
      Procedure setStyle(style : string);
      Procedure setTheme(theme : string);
      Function setValue(val : string; cursorPos : Double): string; overload;
      Function setValue(val : string): string; overload;
      Procedure setWrapBehavioursEnabled(enabled : boolean);
      Procedure splitLine;
      Procedure toggleCommentLines;
      Procedure toggleOverwrite;
      Procedure toLowerCase;
      Procedure toUpperCase;
      Procedure transposeLetters;
      Procedure undo;
      Procedure unsetStyle;
      inMultiSelectMode : boolean;
      commands : TCommandManager;
      session : TIEditSession;
      selection : TSelection;
      renderer : TVirtualRenderer;
      keyBinding : TKeyBinding;
      container : TJSHTMLElement;
      _blockScrolling : Double; external name '$blockScrolling';
  end;

  TEditorChangeEvent_lines = array of JSValue;
  TEditorChangeEvent = class external name 'Object' (TJSObject)
      start : TPosition;
      &end : TPosition;external name 'end';
      action : string;
      lines : TEditorChangeEvent_lines;
  end;

  TPlaceHolder_on_fn = Function (e : JSValue): JSValue;
  TPlaceHolder = class external name 'Object' (TJSObject)
      class Function &new(session : TDocument; &length : Double; pos : Double; others : string; mainClass : string; othersClass : string): TPlaceHolder; overload;
      class Function &new(session : TIEditSession; &length : Double; pos : TPosition; positions : array of TPosition): TPlaceHolder; overload;
      Procedure &on(event : string; fn : TPlaceHolder_on_fn);
      Procedure cancel;
      Procedure detach;
      Procedure hideOtherMarkers;
      Procedure onCursorChange;
      Procedure onUpdate;
      Procedure setup;
      Procedure showOtherMarkers;
  end;

  TIRangeList_ranges = array of TRange;
  TIRangeList_merge_Result = array of TRange;
  TIRangeList = class external name 'Object' (TJSObject)
      class Function &new: TIRangeList;
      Procedure add(ranges : TRange);
      Procedure addList(ranges : array of TRange);
      Function merge: TIRangeList_merge_Result;
      Procedure pointIndex(pos : TPosition; startIndex : Double); overload;
      Procedure pointIndex(pos : TPosition); overload;
      Procedure substractPoint(pos : TPosition);
      ranges : TIRangeList_ranges;
  end;

  TRange = class external name 'Object' (TJSObject)
      class Function &new(startRow : Double; startColumn : Double; endRow : Double; endColumn : Double): TRange;
      class Function fromPoints(pos1 : TPosition; pos2 : TPosition): TRange;
      Function clipRows(firstRow : Double; lastRow : Double): TRange;
      Function clone: TRange;
      Function collapseRows: TRange;
      Function compare(row : Double; column : Double): Double;
      Function compareEnd(row : Double; column : Double): Double;
      Function compareInside(row : Double; column : Double): Double;
      Function comparePoint(p : TRange): Double;
      Function compareRange(range : TRange): Double;
      Function compareStart(row : Double; column : Double): Double;
      Function contains(row : Double; column : Double): boolean;
      Function containsRange(range : TRange): boolean;
      Function extend(row : Double; column : Double): TRange;
      Function fromPoints(start : TRange; &end : TRange): TRange;
      Function inside(row : Double; column : Double): boolean;
      Function insideEnd(row : Double; column : Double): boolean;
      Function insideStart(row : Double; column : Double): boolean;
      Function intersects(range : TRange): boolean;
      Function isEmpty: boolean;
      Function isEnd(row : Double; column : Double): boolean;
      Procedure isEqual(range : TRange);
      Function isMultiLine: boolean;
      Function isStart(row : Double; column : Double): boolean;
      Procedure setEnd(row : Double; column : Double);
      Procedure setStart(row : Double; column : Double);
      Function toScreenRange(session : TIEditSession): TRange;
      Procedure toString;
      startRow : Double;
      startColumn : Double;
      endRow : Double;
      endColumn : Double;
      start : TPosition;
      &end : TPosition;external name 'end';
  end;

  TRenderLoop = class external name 'Object' (TJSObject)
    class Function &new: TRenderLoop;
  end;

  TScrollBar = class external name 'Object' (TJSObject)
      class Function &new(parent : TJSHTMLElement): TScrollBar;
      Function getWidth: Double;
      Procedure onScroll(e : JSValue);
      Procedure setHeight(height : Double);
      Procedure setInnerHeight(height : Double);
      Procedure setScrollTop(scrollTop : Double);
  end;

  TSearch_findAll_Result = array of TRange;
  TSearch = class external name 'Object' (TJSObject)
      class Function &new: TSearch;
      Function &set(options : JSValue): TSearch;
      Function find(session : TIEditSession): TRange;
      Function findAll(session : TIEditSession): TSearch_findAll_Result;
      Function getOptions: JSValue;
      Function replace(input : string; replacement : string): string;
      Procedure setOptions(An : JSValue);
  end;

  TSelection_getAllRanges_Result = array of TRange;
  TSelection_on_fn = Function (e : JSValue): JSValue;
  TSelection = class external name 'Object' (TJSObject)
      class Function &new(session : TIEditSession): TSelection;
      Procedure &on(ev : string; callback : TJSFunction); overload;
      Procedure &on(event : string; fn : TSelection_on_fn); overload;
      Procedure addEventListener(ev : string; callback : TJSFunction);
      Procedure addRange(range : TRange);
      Procedure clearSelection;
      Procedure fromOrientedRange(range : TRange);
      Function getAllRanges: TSelection_getAllRanges_Result;
      Function getCursor: TPosition;
      Function getRange: TRange;
      Function getSelectionAnchor: JSValue;
      Function getSelectionLead: JSValue;
      Procedure getWordRange;
      Function isBackwards: boolean;
      Function isEmpty: boolean;
      Function isMultiLine: boolean;
      Procedure moveCursorBy(rows : Double; chars : Double);
      Procedure moveCursorDown;
      Procedure moveCursorFileEnd;
      Procedure moveCursorFileStart;
      Procedure moveCursorLeft;
      Procedure moveCursorLineEnd;
      Procedure moveCursorLineStart;
      Procedure moveCursorLongWordLeft;
      Procedure moveCursorLongWordRight;
      Procedure moveCursorRight;
      Procedure moveCursorTo(row : Double; column : Double; keepDesiredColumn : boolean); overload;
      Procedure moveCursorTo(row : Double; column : Double); overload;
      Procedure moveCursorToPosition(position : JSValue);
      Procedure moveCursorToScreen(row : Double; column : Double; keepDesiredColumn : boolean);
      Procedure moveCursorUp;
      Procedure moveCursorWordLeft;
      Procedure moveCursorWordRight;
      Procedure off(ev : string; callback : TJSFunction);
      Procedure removeEventListener(ev : string; callback : TJSFunction);
      Procedure removeListener(ev : string; callback : TJSFunction);
      Procedure selectAll;
      Procedure selectAWord;
      Procedure selectDown;
      Procedure selectFileEnd;
      Procedure selectFileStart;
      Procedure selectLeft;
      Procedure selectLine;
      Procedure selectLineEnd;
      Procedure selectLineStart;
      Procedure selectRight;
      Procedure selectTo(row : Double; column : Double);
      Procedure selectToPosition(pos : JSValue);
      Procedure selectUp;
      Procedure selectWord;
      Procedure selectWordLeft;
      Procedure selectWordRight;
      Procedure setRange(range : TRange; reverse : boolean);
      Procedure setSelectionAnchor(row : Double; column : Double);
      Procedure setSelectionRange(match : JSValue);
      Procedure shiftSelection(columns : Double);
  end;

  TSplit = class external name 'Object' (TJSObject)
      Procedure Split(container : TJSHTMLElement; theme : JSValue; splits : Double); overload;
      Procedure Split(container : TJSHTMLElement); overload;
      Procedure Split(container : TJSHTMLElement; theme : JSValue); overload;
      Procedure blur;
      Procedure focus;
      Procedure forEach(callback : TJSFunction; scope : string);
      Function getCurrentEditor: TEditor;
      Function getEditor(idx : Double): TEditor;
      Function getOrientation: Double;
      Function getSplits: Double;
      Procedure resize;
      Procedure setFontSize(size : Double);
      Procedure setKeyboardHandler(keybinding : string);
      Procedure setOrientation(orientation : Double);
      Procedure setSession(session : TIEditSession; idx : Double);
      Procedure setSplits(splits : Double); overload;
      Procedure setSplits; overload;
      Procedure setTheme(theme : string);
      BELOW : Double;
      BESIDE : Double;
  end;

  TTokenIterator_stepBackward_Result = array of string;
  TTokenIterator = class external name 'Object' (TJSObject)
      class Function &new(session : TIEditSession; initialRow : Double; initialColumn : Double): TTokenIterator;
      Function getCurrentToken: TTokenInfo;
      Function getCurrentTokenColumn: Double;
      Function getCurrentTokenRow: Double;
      Function stepBackward: TTokenIterator_stepBackward_Result;
      Function stepForward: string;
  end;

  TTokenizer_getLineTokens_Result = array of TTokenInfo;
  TTokenizer = class external name 'Object' (TJSObject)
      class Function &new(rules : JSValue; flag : string): TTokenizer;
      Function createSplitterRegexp(src : string; flag : string): TJSRegexp; overload;
      Function createSplitterRegexp(src : string): TJSRegexp; overload;
      Function getLineTokens(line : string; startState : jsvalue): TTokenizer_getLineTokens_Result;
      Function removeCapturingGroups(src : string): string;
  end;

  TUndoManager = class external name 'Object' (TJSObject)
      class Function &new: TUndoManager;
      Procedure bookmark(rev : Double); overload;
      Procedure bookmark; overload;
      Function canRedo: boolean;
      Function canUndo: boolean;
      Function hasRedo: boolean;
      Function hasUndo: boolean;
      Function isAtBookmark: boolean;
      Function isClean: boolean;
      Procedure markClean(rev : Double); overload;
      Procedure markClean; overload;
      Procedure redo(session : TIEditSession; dontSelect : boolean); overload;
      Procedure redo; overload;
      Procedure redo(session : TIEditSession); overload;
      Procedure reset;
      Function undo(session : TIEditSession; dontSelect : boolean): TRange; overload;
      Function undo: TRange; overload;
      Function undo(session : TIEditSession): TRange; overload;
  end;

  TVirtualRenderer = class external name 'Object' (TJSObject)
      class Function &new(container : TJSHTMLElement; theme : string): TVirtualRenderer; overload;
      class Function &new(container : TJSHTMLElement): TVirtualRenderer; overload;
      Procedure addGutterDecoration;
      Procedure adjustWrapLimit;
      Procedure destroy;
      Function getAnimatedScroll: boolean;
      Function getContainerElement: TJSHTMLElement;
      Function getFirstFullyVisibleRow: Double;
      Function getFirstVisibleRow: Double;
      Function getHScrollBarAlwaysVisible: boolean;
      Function getLastFullyVisibleRow: Double;
      Function getLastVisibleRow: Double;
      Function getMouseEventTarget: TJSHTMLElement;
      Function getPrintMarginColumn: boolean;
      Function getScrollBottomRow: Double;
      Function getScrollLeft: Double;
      Function getScrollTop: Double;
      Function getScrollTopRow: Double;
      Function getShowGutter: boolean;
      Function getShowInvisibles: boolean;
      Function getShowPrintMargin: boolean;
      Function getTextAreaContainer: TJSHTMLElement;
      Function getTheme: string;
      Procedure hideComposition;
      Procedure hideCursor;
      Function isScrollableBy(deltaX : Double; deltaY : Double): boolean;
      Procedure onResize(force : boolean; gutterWidth : Double; width : Double; height : Double);
      Procedure removeGutterDecoration;
      Procedure screenToTextCoordinates(left : Double; top : Double);
      Procedure scrollBy(deltaX : Double; deltaY : Double);
      Procedure scrollCursorIntoView;
      Procedure scrollToLine(line : Double; center : boolean; animate : boolean; callback : TJSFunction);
      Procedure scrollToRow(row : Double);
      Function scrollToX(scrollLeft : Double): Double;
      Function scrollToY(scrollTop : Double): Double;
      Procedure setAnimatedScroll(shouldAnimate : boolean);
      Procedure setAnnotations(annotations : array of JSValue);
      Procedure setCompositionText(text : string);
      Procedure setHScrollBarAlwaysVisible(alwaysVisible : boolean);
      Procedure setPadding(padding : Double);
      Procedure setPrintMarginColumn(showPrintMargin : boolean);
      Procedure setScrollMargin(top : Double; bottom : Double; left : Double; right : Double);
      Procedure setSession(session : TIEditSession);
      Procedure setShowGutter(show : boolean);
      Procedure setShowInvisibles(showInvisibles : boolean);
      Procedure setShowPrintMargin(showPrintMargin : boolean);
      Procedure setStyle(style : string);
      Procedure setTheme(theme : string);
      Procedure showComposition(position : Double);
      Procedure showCursor;
      Function textToScreenCoordinates(row : Double; column : Double): JSValue;
      Procedure unsetStyle(style : string);
      Procedure updateBackMarkers;
      Procedure updateBreakpoints;
      Procedure updateCursor;
      Procedure updateFontSize;
      Procedure updateFrontMarkers;
      Procedure updateFull(force : boolean);
      Procedure updateLines(firstRow : Double; lastRow : Double);
      Procedure updateText;
      Procedure visualizeBlur;
      Procedure visualizeFocus;
      scroller : JSValue;
      characterWidth : Double;
      lineHeight : Double;
      _cursorLayer : TLayer.TCursor; external name '$cursorLayer';
  end;

  TCompleter_getCompletions = Procedure (editor : TEditor; session : TIEditSession; pos : TPosition; prefix : string; callback : TCompletionCallback);
  TCompleter = class external name 'Object' (TJSObject)
      getCompletions : TCompleter_getCompletions;
      getDocTooltip : jsvalue;
  end;

  TCompletion = class external name 'Object' (TJSObject)
      value : string;
      meta : string;
      &type : jsvalue;external name 'type';
      caption : jsvalue;
      snippet : JSValue;
      score : jsvalue;
      exactMatch : jsvalue;
      docHTML : jsvalue;
  end;
      
    
Var
  Anchor : TAnchor; external name 'ace.Anchor';
  BackgroundTokenizer : TBackgroundTokenizer; external name 'BackgroundTokenizer';
//  Document : TDocument; external name 'Document';
  EditSession : TIEditSession; external name 'EditSession';
  Editor : TEditor; external name 'Editor';
  PlaceHolder : TPlaceHolder; external name 'PlaceHolder';
  Range : TRange; external name 'Range';
  RenderLoop : TRenderLoop; external name 'RenderLoop';
  ScrollBar : TScrollBar; external name 'ScrollBar';
  Search : TSearch; external name 'Search';
  Selection : TSelection; external name 'Selection';
  Split : TSplit; external name 'Split';
  TokenIterator : TTokenIterator; external name 'TokenIterator';
  Tokenizer : TTokenizer; external name 'Tokenizer';
  UndoManager : TUndoManager; external name 'UndoManager';
  VirtualRenderer : TVirtualRenderer; external name 'VirtualRenderer';

  ace : TAce; external name 'ace';

implementation
end.
