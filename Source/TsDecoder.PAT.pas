unit TsDecoder.PAT;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Packet,
  TsDecoder.PMT,
  TsDecoder.Tables;

type
  TTsProgram = class
  private
    FNumber     : SmallInt;
    FPmtPid     : SmallInt;
    [weak] FPmt : TProgramMapTable;
  public
    constructor Create(); overload;
    constructor Create(const Number : SmallInt; Pid: SmallInt); overload;
    destructor Destroy; override;

    procedure RefPmt(Pmt: TProgramMapTable);

    property Number: SmallInt read FNumber write FNumber;
    property PmtPid: SmallInt read FPmtPid write FPmtPid;
    property Pmt: TProgramMapTable read FPmt write FPmt;
  end;

  TTsPrograms = class(TObjectList<TTsProgram>)
  private

  public
    constructor Create(); overload;
    destructor Destroy; override;

    // By Pmt Pid
    function ContainsPmtPid(const PmtPid: SmallInt): boolean;
    function IndexOfPmtPid(const PmtPid: SmallInt): integer;
    function TryGetByPmtPid(const PmtPid: SmallInt; var TsProgram: TTsProgram): boolean;
  end;

type
  TProgramAssociationTable = class(TTsTable)
  private
    FVersionNumber: byte;
    FTransportStreamId: SmallInt;
    FCurrentNextIndicator : boolean;
    FSectionNumber : byte;
    FLastSectionNumber: byte;
    FPrograms: TTsPrograms;
    FCrc: cardinal;
  public
    constructor Create(); overload;
    constructor Create(const aTsPacket : TTsPacket); overload;
    destructor Destroy; override;

    function Deserialize(const aTsPacket : TTsPacket): boolean; override;
    function Dump(): string;

    property VersionNumber: byte read FVersionNumber;
    property TransportStreamId: SmallInt read FTransportStreamId;
    property CurrentNextIndicator : boolean read FCurrentNextIndicator;
    property SectionNumber : byte read FSectionNumber;
    property LastSectionNumber: byte read FLastSectionNumber;
    property Programs: TTsPrograms read FPrograms;
    property Crc: cardinal read FCrc;
  end;

implementation

//
constructor TTsPrograms.Create();
begin
  inherited Create;
end;

destructor TTsPrograms.Destroy;
begin
  inherited Destroy;
end;

function TTsPrograms.ContainsPmtPid(const PmtPid: SmallInt): boolean;
var
  i  : integer;
begin
  result := false;
  for I := 0 to Self.Count - 1 do
  begin
    if Self.Items[i].PmtPid = PmtPid then
    begin
      result := true;
      break;
    end;
  end;
end;

function TTsPrograms.IndexOfPmtPid(const PmtPid: SmallInt): integer;
var
  i  : integer;
begin
  result := -1;
  for I := 0 to Self.Count - 1 do
  begin
    if Self.Items[i].PmtPid = PmtPid then
    begin
      result := i;
      break;
    end;
  end;
end;

function TTsPrograms.TryGetByPmtPid(const PmtPid: SmallInt; var TsProgram: TTsProgram): boolean;
var
  lIndex : integer;
begin
  result := false;
  TsProgram := nil;
  lIndex := Self.IndexOfPmtPid(PmtPid);
  if ((lIndex >= 0) and (lIndex < Self.Count)) then
  begin
    TsProgram := Self.Items[lIndex];
    result := true;
  end;
end;

//
constructor TTsProgram.Create();
begin
  inherited Create;
  Self.FNumber := -1;
  Self.FPmtPid := -1;
  Self.FPmt := nil;
end;

constructor TTsProgram.Create(const Number : SmallInt; Pid: SmallInt);
begin
  inherited Create();
  Self.FNumber := Number;
  Self.FPmtPid := Pid;
  Self.FPmt := nil;
end;

destructor TTsProgram.Destroy;
begin
  Self.FPmt := nil;
  inherited Destroy;
end;

procedure TTsProgram.RefPmt(Pmt: TProgramMapTable);
begin
  Self.FPmt := Pmt
end;

//
constructor TProgramAssociationTable.Create();
begin
  inherited Create;
  Self.FPrograms:= TTsPrograms.Create;
end;

constructor TProgramAssociationTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create();
  Self.FPrograms:= TTsPrograms.Create;

  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse PAT packet');
end;

destructor TProgramAssociationTable.Destroy;
begin
  FreeAndNil(Self.FPrograms);
  inherited Destroy;
end;

{$REGION 'DUMP'}
function TProgramAssociationTable.Dump(): string;
var
  i : integer;
begin
  result := Format('*** BEGIN - %s' + #13#10, [Self.Description]);
  for I := 0 to Self.FPrograms.Count - 1 do
  begin
    result := result + Format('       PAT program num=%u program_map_PID = 0x%04x (%d)', [Self.FPrograms[i].Number, Self.FPrograms[i].PmtPid, Self.FPrograms[i].PmtPid]) + #13#10;
    if assigned(Self.FPrograms[i].Pmt) then
      result := result + '              ' + Self.FPrograms[i].Pmt.Dump;
  end;
  result := result + Format('  CRC = 0x%08x', [Self.FCrc]) + #13#10;
  result := result + Format('*** END - %s', [Self.Description]);
end;
{$ENDREGION}

{$REGION 'Program association section'}
// Parse Program Association table
// PcktDump: 47 40 00     1A 00   00 B0 0D 00 01 C1 00 00 00 01 F0 00 2A B1 04 B2 FF FF FF FF FF FF FF FF FF FF FF .. FF
(*
  program_association_section() {
    table_id 8 uimsbf
    section_syntax_indicator 1 bslbf
    '0' 1 bslbf
    reserved 2 bslbf
    section_length 12 uimsbf
    transport_stream_id 16 uimsbf
    reserved 2 bslbf
    version_number 5 uimsbf
    current_next_indicator 1 bslbf
    section_number 8 uimsbf
    last_section_number 8 uimsbf
    for (i = 0; i < N; i++) {
      program_number 16 uimsbf
      reserved 3 bslbf
      if (program_number == '0') {
        network_PID 13 uimsbf
      }
      else {
        program_map_PID 13 uimsbf
      }
    }
    CRC_32 32 rpchof
  }

*)
{$ENDREGION}
function TProgramAssociationTable.Deserialize(const aTsPacket : TTsPacket): boolean;
var
  lCurPos       : integer;
  i             : integer;
  programStart  : integer;
begin
  result := false;
  if not inherited Deserialize(aTsPacket) then
    exit;

  lCurPos := 1;

  Self.FVersionNumber := byte((aTsPacket.Payload[lCurPos + 5] and $3E) shr 1);
  Self.FTransportStreamId := SmallInt((aTsPacket.Payload[lCurPos + 3] shl 8) + aTsPacket.Payload[lCurPos + 4]);

  Self.FCurrentNextIndicator := (aTsPacket.Payload[lCurPos + 5] and $01) <> 0;
  Self.FSectionNumber := aTsPacket.Payload[lCurPos + 6];
  Self.FLastSectionNumber := aTsPacket.Payload[lCurPos + 7];

  programStart := lCurPos + 8;
  lCurPos := programStart;
  for I := 0 to ((Self.SectionLength - 9) div 4) - 1 do
  begin
    Self.FPrograms.Add(TTsProgram.Create(SmallInt((aTsPacket.Payload[programStart + (i * 4)] shl 8) + aTsPacket.Payload[programStart + 1 + (i * 4)]), SmallInt(((aTsPacket.Payload[programStart + 2 + (i * 4)] and $1F) shl 8) + aTsPacket.Payload[programStart + 3 + (i * 4)])));
    inc(lCurPos, 4);
  end;

  Self.FCrc := cardinal((((aTsPacket.Payload[lCurPos]) shl 24) + (aTsPacket.Payload[lCurPos + 1] shl 16) + (aTsPacket.Payload[lCurPos + 2] shl 8) + (aTsPacket.Payload[lCurPos + 3])));

  result := true;

  if assigned(Self.OnChange) then
    Self.OnChange(Self);
end;


end.
