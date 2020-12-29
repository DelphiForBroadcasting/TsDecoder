program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Diagnostics,
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



function Usage(): string;
begin
  result := 'Usage: %s -i [MPEG-TS FILE] -dump [DUMP FILE] -pid [PID]';
end;

var
  lTsDecoder        : TTsDecoder;
  lArgI             : string;
  lArgPid           : string;
  LStreamDump       : TFileStream;
  lSourceStream     : TFileStream;
  lTsDecoderWatch   : TStopWatch;
  aData             : TArray<byte>;
  lReadBytes        : integer;
  lDumpPid          : integer;
begin
  try
    ReportMemoryLeaksOnShutdown := true;

    // -i
    if not FindCmdLineSwitch('i', lArgI, True) then
    begin
      writeln(format(Usage, [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
      exit;
    end;
    lArgI := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), lArgI));

    // -pid
    if not FindCmdLineSwitch('pid', lArgPid, True)then
    begin
      writeln(format(Usage, [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
      exit;
    end;
    lDumpPid := StrToIntDef(lArgPid, -1);


    lTsDecoder := TTsDecoder.Create;
    try
      lTsDecoder.OnParsePacket := procedure(Sender: TObject; TsPacket: TTsPacket)
        begin
          if (TsPacket.Pid = lDumpPid) then
          begin
            if TsPacket.PesHeader.StartCode > 0 then
            begin
              if TsPacket.PesHeader.Dts = 555 then
               writeln(Format('PTS: %d, PKT: %d',   [TsPacket.PesHeader.Pts, (Sender as TTsDecoder).PacketCounter.Packets]));
            end;
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
            //System.Writeln(Format('PMT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
            //System.Writeln((TsTable as TProgramMapTable).Dump);
          end else
          if TsTable is TProgramAssociationTable then
          begin
            //System.Writeln(Format('PAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
            //System.Writeln((TsTable as TProgramAssociationTable).Dump);
          end else
          if TsTable is TTimeDateTable then
          begin
            //System.Writeln(Format('%s', [FormatDateTime('YYYY-mm-dd hh:nn:ss', (TsTable as TTimeDateTable).DateTime)]));
          end else
          if TsTable is TServiceDescriptionTable then
          begin
            //System.Writeln(Format('PAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
            //System.Writeln((TsTable as TServiceDescriptionTable).Dump);
          end else
          if TsTable is TConditionalAccessTable then
          begin
            //System.Writeln(Format('CAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
            //System.Writeln((TsTable as TConditionalAccessTable).Dump);
          end else
            //System.Writeln(Format('TABLE: packet, %d PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
        end;

      SetLength(aData, 8192);
      lTsDecoderWatch := TStopWatch.StartNew();
      try
        lSourceStream := TFileStream.Create(lArgI, fmOpenRead);
        try
          while lSourceStream.Position < (lSourceStream.Size) do
          begin
            lReadBytes:= lSourceStream.ReadData(aData, 8192);
            if lReadBytes <> 8192 then
              SetLength(aData, lReadBytes);
            lTsDecoder.AddData(aData);
          end;
        finally
          FreeAndNil(lSourceStream);
        end;
      finally
        lTsDecoderWatch.Stop;
      end;


      System.Writeln(Format('lTsDecoderWatch: %d ms', [lTsDecoderWatch.ElapsedMilliseconds]));
      System.Writeln(Format('Processing Packets: %d', [lTsDecoder.PacketCounter.Packets]))

    finally
      FreeAndNil(lTsDecoder);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  System.Writeln;
  System.Write('Press Enter to exit...');
  System.Readln;
end.
