program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  TsDecoder.Descriptor in '..\..\Source\TsDecoder.Descriptor.pas',
  TsDecoder.EsInfo in '..\..\Source\TsDecoder.EsInfo.pas',
  TsDecoder.PMT in '..\..\Source\TsDecoder.PMT.pas',
  TsDecoder.PAT in '..\..\Source\TsDecoder.PAT.pas',
  TsDecoder.SDT in '..\..\Source\TsDecoder.SDT.pas',
  TsDecoder.Packet in '..\..\Source\TsDecoder.Packet.pas',
  TsDecoder.Tables in '..\..\Source\TsDecoder.Tables.pas',
  TsDecoder.CC in '..\..\Source\TsDecoder.CC.pas',
  TsDecoder.CAT in '..\..\Source\TsDecoder.CAT.pas',
  TsDecoder.TDT in '..\..\Source\TsDecoder.TDT.pas',
  TsDecoder.TSDT in '..\..\Source\TsDecoder.TSDT.pas',
  TsDecoder in '..\..\Source\TsDecoder.pas';

{$REGION 'CONSOLE'}

const
  // Некоторые стандартные цвета
  YellowOnBlue = FOREGROUND_GREEN OR FOREGROUND_RED OR
                FOREGROUND_INTENSITY OR BACKGROUND_BLUE;
  WhiteOnBlue  = FOREGROUND_BLUE OR FOREGROUND_GREEN OR
                FOREGROUND_RED OR FOREGROUND_INTENSITY OR
                BACKGROUND_BLUE;
  RedOnWhite   = FOREGROUND_RED OR FOREGROUND_INTENSITY OR
                BACKGROUND_RED OR BACKGROUND_GREEN OR BACKGROUND_BLUE
                OR BACKGROUND_INTENSITY;
  WhiteOnRed   = BACKGROUND_RED OR BACKGROUND_INTENSITY OR
                FOREGROUND_RED OR FOREGROUND_GREEN OR FOREGROUND_BLUE
                OR FOREGROUND_INTENSITY;

// вывод покрашенного текста на консоль
procedure WriteColoredStr(AStr: String; AArgs: Array of const; AColor: Byte);
var
  hOut: THandle;
  BI: CONSOLE_SCREEN_BUFFER_INFO;
  OldAttr: Word;
  NewAttr: Word;
begin
  // назначить Handle, как буффер вывода
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);

  // запомнить текущие настройки консоли, чтобы после преобразований их снова восстанвоить
  GetConsoleScreenBufferInfo(hOut, BI);
  // взять цвет текста и цвет фона
  OldAttr := BI.wAttributes;

  // за цвет отвечает младший байт
  // биты 0-3 - цвет текста
  // биты 4-7 - цвет фона

  // преобразовать новую пееменную, в которой цвет фона будет предыдущий
  // а цвет текста установить который желает пользователь параметром AColor
  NewAttr := (AColor and $0F) or ((OldAttr shr 4) and $0F) shl 4;

  // установиить эти параметры, что были преобразованы
  SetConsoleTextAttribute(hOut, NewAttr);

  // выдать строку в консольное окно
  Write(Format(AStr, AArgs));

  // восстановиить прежние настройки
  SetConsoleTextAttribute(hOut, OldAttr);
end;

// вывод покрашенного текста на консоль на цветном фоне
procedure WriteColoredBkgStr(AStr: String; AArgs: Array of const; ABkgColor: Byte; AColor: Byte);
var
  hOut: THandle;
  NewAttr: Word;
  BI: CONSOLE_SCREEN_BUFFER_INFO;
  OldAttr: Word;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);

  GetConsoleScreenBufferInfo(hOut, BI);
  OldAttr := BI.wAttributes;

  // преобразовать биты ка ки в вышеописанной процедуре,
  // только сейчас нужно задать не предыдущий цвет фона,
  // а тот, который устанавливает пользователь
  NewAttr := (AColor and $0F) or (ABkgColor and $0F shl 4);

  SetConsoleTextAttribute(hOut, NewAttr);

  Write(Format(AStr, AArgs));

  SetConsoleTextAttribute(hOut, OldAttr);
end;

// установка позиции курсора в консольном окне
procedure SetCursorPos(AX, AY: Integer);
var
  P: TCoord;
  hOut: THandle;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);

  P.X := AX;
  P.Y := AY;
  SetConsoleCursorPosition(hOut, P);
end;

function GetCursorPos: TCoord;
var
  ScrBufInfo: TConsoleScreenBufferInfo;
  hOut: THandle;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo(hOut, ScrBufInfo);
  Result := ScrBufInfo.dwCursorPosition;
end;

// установить название окна
procedure SetTitle(ATitle: String);
begin
  SetConsoleTitle(PChar(ATitle));
end;

procedure SetAttributes(attr: word);
var
  hOut: THandle;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleTextAttribute(hOut, attr);
end;

function GetAttributes: word;
var
  ScrBufInfo: TConsoleScreenBufferInfo;
  hOut: THandle;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo(hOut, ScrBufInfo);
  Result := ScrBufInfo.wAttributes;
end;

procedure ClearConsole;
const
  UpperLeft: TCoord = (X:0; Y:0);
var
  fill: DWORD;
  ScrBufInfo: TConsoleScreenBufferInfo;
  hOut: THandle;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo(hOut, ScrBufInfo);
  fill := ScrBufInfo.dwSize.x * ScrBufInfo.dwSize.y;
  FillConsoleOutputCharacter(hOut, ' ', fill, UpperLeft, fill);
  FillConsoleOutputAttribute(hOut, ScrBufInfo.wAttributes, fill, UpperLeft, fill);
  SetConsoleCursorPosition(hOut, UpperLeft);
end;

function GetConsoleSize: TCoord;
var
  hOut: THandle;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  result := GetLargestConsoleWindowSize(hOut);
end;

procedure ShowCursor(Show : Bool);
var
  hOut   : THandle;
  CCI : TConsoleCursorInfo;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  CCI.bVisible := Show;
  SetConsoleCursorInfo(hOut, CCI);
end;

//---------------------------------------
//          рисуем строку статуса ("status line")
//---------------------------------------
procedure StatusLine(S : String);
var
  hOut              : THandle;
  NOAW              : DWORD;
  lStatusPosition   : TCoord;
  lScrBufInfo        : TConsoleScreenBufferInfo;
  lCursorPosition   : TCoord;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo(hOut,  lScrBufInfo);
  lCursorPosition := lScrBufInfo.dwCursorPosition;
  lStatusPosition.Y := lScrBufInfo.srWindow.Bottom;
  lStatusPosition.X := 0;
  SetConsoleCursorPosition(hOut, lStatusPosition);
  WriteConsoleOutputCharacter(hOut, PChar(S),   Length(S) + 1, lStatusPosition, NOAW);
  FillConsoleOutputAttribute (hOut, WhiteOnRed, Length(S),   lStatusPosition, NOAW);
  SetConsoleCursorPosition(hOut, lCursorPosition);
end;

//-----------------------------------------------------
// Обработчик консольных событий
//-----------------------------------------------------
function ConProc(CtrlType : DWord) : Bool; stdcall; far;
var
  S : String;
begin
  case CtrlType of
    CTRL_C_EVENT : S := 'CTRL_C_EVENT';
    CTRL_BREAK_EVENT : S := 'CTRL_BREAK_EVENT';
    CTRL_CLOSE_EVENT : S := 'CTRL_CLOSE_EVENT';
    CTRL_LOGOFF_EVENT : S := 'CTRL_LOGOFF_EVENT';
    CTRL_SHUTDOWN_EVENT : S := 'CTRL_SHUTDOWN_EVENT';
  else
    S := 'UNKNOWN_EVENT';
  end;
  Result := True;
end;

{$ENDREGION}

function Usage(): string;
begin
  result := 'Usage: %s -i [MPEG-TS FILE] -dump [DUMP FILE] -pid [PID]';
end;

 const
  lBuffSize  : integer = 1316;

var
  // ConsoleCtrlHandler
  IBuff             : TInputRecord;
  IEvent            : DWord;
  dwOutMode         : DWORD;
  dwInMode          : DWORD;

  lTsDecoder        : TTsDecoder;
  lArgI             : string;
  lArgDump          : string;
  lArgPid           : string;
  LStreamDump       : TFileStream;

  lDumpPid          : integer;

  lSourceStream     : TFileStream;
  lTsDecoderWatch   : TStopWatch;
  aRecvData         : TArray<byte>;
  lReadBytes        : integer;
begin
  try
    ReportMemoryLeaksOnShutdown := true;
    dwOutMode := 0;
    dwInMode := 0;
    GetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), &dwOutMode);
    GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), &dwInMode);
    SetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), dwOutMode);
    SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), dwInMode);
    ClearConsole;
    ShowCursor(false);

    // Устанавливаем обработчик событий
    SetConsoleCtrlHandler(@ConProc, True);
    try

        // -i
        if not FindCmdLineSwitch('i', lArgI, True) then
        begin
          writeln(format(Usage, [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
          exit;
        end;
        lArgI := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), lArgI));

        // -dump  filename
        // -pid
        if (FindCmdLineSwitch('dump', lArgDump, True) and (not FindCmdLineSwitch('pid', lArgPid, True))) then
        begin
          writeln(format(Usage, [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
          exit;
        end;
        if not lArgDump.IsEmpty then
        begin
          lArgDump := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), lArgDump));
          if System.IOUtils.TFile.Exists(lArgDump) then
            System.IOUtils.TFile.Delete(lArgDump);
        end;
        lDumpPid := StrToIntDef(lArgPid, -1);


        lTsDecoder := TTsDecoder.Create;
        try
          lTsDecoder.OnParsePacket := procedure(Sender: TObject; TsPacket: TTsPacket)
            begin
              if ((TsPacket.Pid = lDumpPid) and (not lArgDump.IsEmpty)) then
              begin

                LStreamDump := TFile.Open(lArgDump, TFileMode.fmAppend);
                try
                  LStreamDump.WriteBuffer(TsPacket.Payload, Length(TsPacket.Payload));
                finally
                  FreeAndNil(LStreamDump);
                end;

                {if assigned((Sender as TTsDecoder).ProgramAssociationTable) then
                  for i := 0 to (Sender as TTsDecoder).ProgramAssociationTable.Programs.Count - 1 do
                  begin
                    if assigned((Sender as TTsDecoder).ProgramAssociationTable.Programs[i].Pmt) then
                      if (Sender as TTsDecoder).ProgramAssociationTable.Programs[i].Pmt.EsList.TryGetByPid(lDumpPid, lEsInfo) then
                      begin
                        //Log.d('Elementary stream type=0x%02x(%s) pid=0x%04x(%d)', [lEsInfo.StreamType.asInt, lEsInfo.StreamType.asString,  lEsInfo.ElementaryPid, lEsInfo.ElementaryPid]);
                        break;
                      end;
                end;}
              end;
            end;

          lTsDecoder.OnContinutyError := procedure(const Sender:TObject; const Pid: Integer; const CC: Integer; const NewCC: Integer)
          begin
            System.Writeln(Format('ContinutyError: PID: %d, CC: %d, NewCC: %d', [Pid, CC, NewCC]));
          end;

          lTsDecoder.OnTableChange := procedure(Sender: TObject; TsTable: TTsTable)
            begin
              if TsTable is TProgramMapTable then
              begin
                System.Writeln(Format('PMT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
                System.Writeln((TsTable as TProgramMapTable).Dump);
              end else
              if TsTable is TProgramAssociationTable then
              begin
                System.Writeln(Format('PAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
                System.Writeln((TsTable as TProgramAssociationTable).Dump);
              end else
              if TsTable is TTimeDateTable then
              begin
                StatusLine(Format('%s', [FormatDateTime('YYYY-mm-dd hh:nn:ss', (TsTable as TTimeDateTable).DateTime)]));
              end else
              if TsTable is TServiceDescriptionTable then
              begin
                System.Writeln(Format('PAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
                System.Writeln((TsTable as TServiceDescriptionTable).Dump);
              end else
              if TsTable is TConditionalAccessTable then
              begin
                System.Writeln(Format('CAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
                System.Writeln((TsTable as TConditionalAccessTable).Dump);
              end else
                System.Writeln(Format('TABLE: packet, %d PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
            end;


          // read file thread
          SetLength(aRecvData, lBuffSize);
          lTsDecoderWatch := TStopWatch.StartNew();
          try
              lSourceStream := TFileStream.Create(lArgI, fmOpenRead);
              try
                while lSourceStream.Position < (lSourceStream.Size) do
                begin
                  lReadBytes:= lSourceStream.ReadData(aRecvData, lBuffSize);
                  if lReadBytes <> lBuffSize then
                    SetLength(aRecvData, lReadBytes);
                  lTsDecoder.AddData(aRecvData);
                end;
              finally
                FreeAndNil(lSourceStream);
              end;
          finally
              lTsDecoderWatch.Stop;
          end;

          System.Writeln(Format('lTsDecoderWatch: %d ms', [lTsDecoderWatch.ElapsedMilliseconds]));
          System.Writeln(Format('Processing Packets: %d', [lTsDecoder.PacketCounter.Packets]));


          System.Write('Press ESC to exit...');
          // ConsoleCtrlHandler
          while true do
          begin
            ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), IBuff, 1, IEvent);
            Case IBuff.EventType of
              KEY_EVENT   :
                begin
                  if ((IBuff.Event.KeyEvent.bKeyDown = True) and (IBuff.Event.KeyEvent.wVirtualKeyCode = VK_ESCAPE)) then
                    break;
                end;
            end;
          end;

        finally
          FreeAndNil(lTsDecoder);
        end;


    finally
      SetConsoleCtrlHandler(@ConProc, False);
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
