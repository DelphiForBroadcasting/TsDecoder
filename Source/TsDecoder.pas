unit TsDecoder;

interface

uses
  System.SysUtils, System.Generics.Collections,
  System.SyncObjs,
  TsDecoder.EsInfo,
  TsDecoder.PMT,
  TsDecoder.PAT,
  TsDecoder.SDT,
  TsDecoder.CAT,
  TsDecoder.CC,
  TsDecoder.TDT,
  TsDecoder.TSDT,
  TsDecoder.Packet,
  TsDecoder.Tables;

type
  TPacketCounter = record
  private
    FPackets          : int64;
    FErrorPackets     : int64;
    FPmtPackets       : int64;
    FPatPackets       : int64;
    FCatPackets       : int64;
    FSdtPackets       : int64;
    FEitPackets       : int64;
    FContinuityError  : int64;
    FNullPackets      : int64;
    procedure Increment();
    procedure IncContinuityError();
    procedure IncPat();
    procedure IncPmt();
    procedure IncError();
    procedure IncCat();
    procedure IncSdt();
    procedure IncEit();
    procedure IncNull();
  public
    class function Init(): TPacketCounter; static;
    procedure Reset();
    procedure AddPacket(const aTsPacket: TTsPacket);

    property Packets      : int64 read FPackets;
    property ErrorPackets : int64 read FErrorPackets;
    property PmtPackets   : int64 read FPmtPackets;
    property PatPackets   : int64 read FPatPackets;
    property CatPackets   : int64 read FCatPackets;
    property SdtPackets   : int64 read FSdtPackets;
    property EitPackets   : int64 read FEitPackets;
    property NullPackets   : int64 read FNullPackets;
  end;




  TTsDecoder = class
  type
    TOnParsePacket = reference to procedure(Sender: TObject; TsPacket: TTsPacket);
    TOnTableChange = reference to procedure(Sender: TObject; TsTable: TTsTable);
  private
    FPacketCounter            : TPacketCounter;
    FContinutyCounters        : TTsContinutyCounters;
    FProgramAssociationTable  : TProgramAssociationTable;
    FServiceDescriptionTable  : TServiceDescriptionTable;
    FConditionalAccessTable   : TConditionalAccessTable;
    FTsDescriptionTable       : TTsDescriptionTable;
    FProgramMapTables         : TProgramMapTables;

    FOnParsePacket            : TTsDecoder.TOnParsePacket;
    FOnTableChange            : TTsDecoder.TOnTableChange;
    FOnContinutyError         : TTsContinutyCounter.TContinutyError;

    FResidualData             : TArray<Byte>;

    function FindSync(aData: TArray<byte>; aOffset: integer; TsPacketSize: integer): integer;
    procedure AddPacket(const aTsPacket: TTsPacket);
    procedure CheckPmt(const aTsPacket: TTsPacket);
  public
    constructor Create();  overload;
    destructor Destroy; override;
    procedure AddData(const aData: array of System.Byte); overload;
    procedure AddData(const aData: TBytes); overload;

    property PacketCounter            : TPacketCounter read FPacketCounter;
    property ProgramAssociationTable  : TProgramAssociationTable read FProgramAssociationTable;
    property ProgramMapTables         : TProgramMapTables read FProgramMapTables;
    property ServiceDescriptionTable  : TServiceDescriptionTable read FServiceDescriptionTable;
    property ConditionalAccessTable   : TConditionalAccessTable read FConditionalAccessTable;

    property OnTableChange: TTsDecoder.TOnTableChange read FOnTableChange write FOnTableChange;
    property OnParsePacket: TTsDecoder.TOnParsePacket read FOnParsePacket write FOnParsePacket;
    property OnContinutyError: TTsContinutyCounter.TContinutyError read FOnContinutyError write FOnContinutyError;
  end;

implementation


class function TPacketCounter.Init(): TPacketCounter;
begin
  result.Reset();
end;

procedure TPacketCounter.Reset();
begin
  FPackets          := 0;
  FErrorPackets     := 0;
  FPmtPackets       := 0;
  FPatPackets       := 0;
  FCatPackets       := 0;
  FSdtPackets       := 0;
  FEitPackets       := 0;
  FContinuityError  := 0;
end;

procedure TPacketCounter.Increment();
begin
  TInterlocked.Increment(FPackets);
end;

procedure TPacketCounter.IncContinuityError();
begin
  TInterlocked.Increment(FContinuityError);
end;

procedure TPacketCounter.IncPat();
begin
  TInterlocked.Increment(FPatPackets);
end;

procedure TPacketCounter.IncPmt();
begin
  TInterlocked.Increment(FPmtPackets);
end;

procedure TPacketCounter.IncError();
begin
  TInterlocked.Increment(FErrorPackets);
end;

procedure TPacketCounter.IncCat();
begin
  TInterlocked.Increment(FCatPackets);
end;

procedure TPacketCounter.IncSdt();
begin
  TInterlocked.Increment(FSdtPackets);
end;

procedure TPacketCounter.IncEit();
begin
  TInterlocked.Increment(FEitPackets);
end;

procedure TPacketCounter.IncNull();
begin
  TInterlocked.Increment(FNullPackets);
end;

procedure TPacketCounter.AddPacket(const aTsPacket: TTsPacket);
begin
  if assigned(aTsPacket) then
  begin
    Self.Increment;
    if aTsPacket.TransportErrorIndicator then
      Self.IncError;

    case TPidType(aTsPacket.Pid) of
      TPidType.PAT_PID: //PAT
        begin
          IncPat;
        end;
      TPidType.CAT_PID:
        begin
          IncCat;
        end;
      TPidType.SDT_PID:
        begin
          IncSdt;
        end;
      TPidType.EIT_PID:
        begin
          IncEit;
        end;
      TPidType.NULL_PID:
        begin
          IncNull;
        end;
      else
        begin

        end;
      end;
    end;
end;

//
constructor TTsDecoder.Create();
begin
  inherited Create;
  FPacketCounter := TPacketCounter.Init();
  Self.FProgramMapTables := TProgramMapTables.Create;
  Self.FContinutyCounters := TTsContinutyCounters.Create;
  Self.FContinutyCounters.OnContinutyError :=  procedure(const Sender:TObject; const Pid: Integer; const CC: Integer; const NewCC: Integer)
  begin
    FPacketCounter.IncContinuityError;
    if assigned(Self.FOnContinutyError) then
      Self.FOnContinutyError(Self, Pid, CC, NewCC);
  end;
end;

destructor TTsDecoder.Destroy;
begin
  FreeAndNil(Self.FProgramMapTables);
  FreeAndNil(Self.FContinutyCounters);

  if assigned(Self.FProgramAssociationTable) then
    FreeAndNil(Self.FProgramAssociationTable);

  if assigned(Self.FServiceDescriptionTable) then
    FreeAndNil(Self.FServiceDescriptionTable);

  if assigned(Self.FConditionalAccessTable) then
    FreeAndNil(Self.FConditionalAccessTable);

  if assigned(Self.FTsDescriptionTable) then
    FreeAndNil(Self.FTsDescriptionTable);

  inherited Destroy;
end;


function TTsDecoder.FindSync(aData: TArray<byte>; aOffset: integer; TsPacketSize: integer): integer;
var
  i : integer;
begin
  result := -1;
  //not big enough to be any kind of single TS packet
  if (Length(aData) - aOffset < TTsPacket.PKT_SIZE) then
    exit;

  try
    for I := aOffset to Length(aData) - 1 do
    begin
      if aData[I] <> TTsPacket.TS_SYNC_BYTE then continue;
      if ((i + 1 * TsPacketSize < Length(aData)) and (aData[i + 1 * TsPacketSize] <> TTsPacket.TS_SYNC_BYTE)) then continue;
      if ((i + 2 * TsPacketSize < Length(aData)) and (aData[i + 2 * TsPacketSize] <> TTsPacket.TS_SYNC_BYTE)) then continue;
      if ((i + 3 * TsPacketSize < Length(aData)) and (aData[i + 3 * TsPacketSize] <> TTsPacket.TS_SYNC_BYTE)) then continue;
      if ((i + 4 * TsPacketSize < Length(aData)) and (aData[i + 4 * TsPacketSize] <> TTsPacket.TS_SYNC_BYTE)) then continue;
      result := I;
      break;
    end;
  except
    on E:Exception do
      ;
  end;
end;


procedure TTsDecoder.AddPacket(const aTsPacket: TTsPacket);
var
  lTDT : TTimeDateTable;
begin
  if not assigned(aTsPacket) then
    raise Exception.Create('Error TsPacket is nil.');

  // add packet counter
  FPacketCounter.AddPacket(aTsPacket);


  // Continuty Counter
  if ((not aTsPacket.isNull) and (aTsPacket.PayloadExists)) then
    Self.FContinutyCounters.AddOrSetCC(aTsPacket.Pid, aTsPacket.ContinuityCounter);

  // DoParsePacket
  try
    if Assigned(Self.FOnParsePacket) then
      Self.FOnParsePacket(Self, aTsPacket);
  except end;

  // Exit if TransportErrorIndicator
  if aTsPacket.TransportErrorIndicator then
  begin
    exit;
  end;

  // Processing packet
  case TPidType(aTsPacket.Pid) of
    TPidType.PAT_PID: //PAT
      begin
        if not assigned(FProgramAssociationTable) then
        begin
          Self.FProgramAssociationTable := TProgramAssociationTable.Create;
          Self.FProgramAssociationTable.OnChange := procedure(TsTable: TTsTable)
            begin
              Self.FOnTableChange(Self, TsTable);
            end;
        end;
        Self.FProgramAssociationTable.Deserialize(aTsPacket);
      end;
    TPidType.CAT_PID:
      begin
        if not assigned(FServiceDescriptionTable) then
        begin
          Self.FConditionalAccessTable := TConditionalAccessTable.Create;
          FConditionalAccessTable.OnChange := procedure(TsTable: TTsTable)
          begin
            Self.FOnTableChange(Self, TsTable);
          end;
        end;
        Self.FConditionalAccessTable.Deserialize(aTsPacket);
      end;
    TPidType.TSDT_PID:
      begin
        if not assigned(FTsDescriptionTable) then
        begin
          Self.FTsDescriptionTable := TTsDescriptionTable.Create;
          FTsDescriptionTable.OnChange := procedure(TsTable: TTsTable)
          begin
            Self.FOnTableChange(Self, TsTable);
          end;
        end;
        Self.FTsDescriptionTable.Deserialize(aTsPacket);
      end;
    TPidType.SDT_PID:
      begin
        if not assigned(FServiceDescriptionTable) then
        begin
          Self.FServiceDescriptionTable := TServiceDescriptionTable.Create;
          FServiceDescriptionTable.OnChange := procedure(TsTable: TTsTable)
          begin
            Self.FOnTableChange(Self, TsTable);
          end;
        end;
        Self.FServiceDescriptionTable.Deserialize(aTsPacket);
      end;
    TPidType.EIT_PID:
      begin

      end;
    TPidType.TDT_PID:
      begin
        lTDT := TTimeDateTable.Create();
        try
          lTDT.Deserialize(aTsPacket);
          if assigned(OnTableChange) then
            Self.FOnTableChange(Self, lTDT);
        finally
          FreeAndNil(lTDT);
        end;
      end;
    else
      begin
        CheckPmt(aTsPacket);
      end;
    end;
end;

procedure TTsDecoder.CheckPmt(const aTsPacket: TTsPacket);
var
  i : integer;
  lProgramMapTable : TProgramMapTable;
  lTsProgram       : TTsProgram;
begin
  lProgramMapTable := nil;

  if not assigned(Self.FProgramAssociationTable) then
    exit;

  if aTsPacket.Pid = integer(TPidType.NIT_PID) then
  begin
    exit;
  end;


  if Self.FProgramAssociationTable.Programs.TryGetByPmtPid(aTsPacket.Pid, lTsProgram) then
  begin
    for I := 0  to Self.FProgramMapTables.Count - 1 do
    begin
      if Self.FProgramMapTables[i].Pid = aTsPacket.Pid then
      begin
        lProgramMapTable := Self.FProgramMapTables[i];
        break;
      end;
    end;

    // Add PMT to PAT if not exist
    if not assigned(lProgramMapTable) then
    begin
      lProgramMapTable := TProgramMapTable.Create;
      lProgramMapTable.OnChange := procedure(TsTable: TTsTable)
        begin
          Self.OnTableChange(Self, TsTable);
        end;
      Self.FProgramMapTables.Add(lProgramMapTable);
    end;
    lProgramMapTable.Deserialize(aTsPacket);
    // reference PMT to PAT.Programs
    if not assigned(lTsProgram.Pmt) then
      lTsProgram.RefPmt(lProgramMapTable);
  end;
end;

procedure TTsDecoder.AddData(const aData: array of System.Byte);
var
  lData : TBytes;
begin
  SetLength(lData, Length(aData));
  Move(aData[0], lData[0], Length(aData));
  Self.AddData(lData);
end;

procedure TTsDecoder.AddData(const aData: TBytes);
var
  lStart          : integer;
  lTsPacket       : TTsPacket;
  lResidualBytes  : integer;
begin
  lStart := 0;
  lTsPacket := nil;
  // Residual Buffer bytes
  lResidualBytes := Length(Self.FResidualData);
  if lResidualBytes > 0 then
  begin
    SetLength(Self.FResidualData, TTsPacket.PKT_SIZE);
    move(aData[0], Self.FResidualData[lResidualBytes], TTsPacket.PKT_SIZE - lResidualBytes);

    if TTsPacket.ParsePacketFromData(Self.FResidualData, 0, lTsPacket) then
    begin
      try
        Self.AddPacket(lTsPacket);
      finally
        FreeAndNil(lTsPacket);
      end;
    end;
    lStart := lStart + TTsPacket.PKT_SIZE - lResidualBytes;
  end;
  //---

  while (Length(AData) - TTsPacket.PKT_SIZE) >= lStart  do
  begin
    lStart := FindSync(AData, lStart, TTsPacket.PKT_SIZE);
    if lStart >= 0 then
    begin
      if TTsPacket.ParsePacketFromData(aData, lStart, lTsPacket) then
      begin
        try
          Self.AddPacket(lTsPacket);
        finally
          FreeAndNil(lTsPacket);
        end;
      end;
      lStart := lStart + TTsPacket.PKT_SIZE ;
    end;
  end;

  // Residual Buffer bytes
  lResidualBytes :=  Length(AData) - lStart;
  SetLength(Self.FResidualData, lResidualBytes);
  Move(AData[lStart], Self.FResidualData[0], lResidualBytes);
  //---
end;

end.
