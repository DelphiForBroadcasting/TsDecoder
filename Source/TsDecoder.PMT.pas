unit TsDecoder.PMT;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Descriptor,
  TsDecoder.EsInfo,
  TsDecoder.Packet,
  TsDecoder.Tables;

{$REGION 'Program Map section'}
(*
TS_program_map_section() {
 table_id 8 uimsbf
 section_syntax_indicator 1 bslbf
 '0' 1 bslbf
 reserved 2 bslbf
 section_length 12 uimsbf
 program_number 16 uimsbf
 reserved 2 bslbf
 version_number 5 uimsbf
 current_next_indicator 1 bslbf
 section_number 8 uimsbf
 last_section_number 8 uimsbf
 reserved 3 bslbf
 PCR_PID 13 uimsbf
 reserved 4 bslbf
 program_info_length 12 uimsbf
 for (i = 0; i < N; i++) {
 descriptor()
 }
 for (i = 0; i < N1; i++) {
 stream_type 8 uimsbf
 reserved 3 bslbf
 elementary_PID 13 uimsbf

 reserved 4 bslbf
 ES_info_length 12 uimsbf
 for (i = 0; i < N2; i++) {
 descriptor()
 }
 }
 CRC_32 32 rpchof
}


(*
47 50 00 1A 00

table_id: 0x2 (program_map_section)
02

section_length: 23
B0 17

program_number: 1
00 01

version_number: 0
current_next: True
C1

section_number: 0
00

last_section_number: 0
00

PCR_PID: 256
E1 00

Program_descriptor_length: 0
F0 00

stream_type: 27
elementary_PID: 256
ES_descriptor_length: 0
1B E1 00 F0 00

stream_type: 15
elementary_PID: 257
ES_descriptor_length: 0
0F E1 01 F0 00

CRC
2F 44 B9 9B FF

*)


{$ENDREGION}
type
  TProgramMapTable = class(TTsTable)
  private
    FProgramNumber: word;
    FVersionNumber: byte;
    FCurrentNextIndicator: boolean;
    FSectionNumber: byte;
    FLastSectionNumber: byte;
    FPcrPid: word;
    FProgramDescriptorLength: word;
    FDescriptors : TDescriptors;
    FEsList : TEsInfoList;
    FCrc: cardinal;
  public
    constructor Create();  overload;
    constructor Create(const aTsPacket : TTsPacket); overload;
    destructor Destroy; override;

    function Deserialize(const aTsPacket : TTsPacket): boolean; override;
    function Dump(): string;

    property ProgramNumber: word read FProgramNumber;
    property VersionNumber: byte read FVersionNumber;
    property CurrentNextIndicator: boolean read FCurrentNextIndicator;
    property SectionNumber: byte read FSectionNumber;
    property LastSectionNumber: byte read FLastSectionNumber;
    property PcrPid: word read FPcrPid;
    property ProgramDescriptorLength: word read FProgramDescriptorLength;
    property Descriptors: TDescriptors read FDescriptors;
    property EsList: TEsInfoList read FEsList;
    property Crc: cardinal read FCrc;
  end;

  TProgramMapTables = class(TObjectList<TProgramMapTable>)
  private

  public
    constructor Create(); overload;
    destructor Destroy; override;

    // By Program
    function ContainsProgram(const aProgram: Word): boolean;
    function IndexOfProgram(const aProgram: Word): integer;
    function TryGetByProgram(const aProgram: Word; var ProgramMapTable: TProgramMapTable): boolean;
  end;

implementation

constructor TProgramMapTables.Create();
begin
  inherited Create;
end;

destructor TProgramMapTables.Destroy;
begin
  inherited Destroy;
end;

function TProgramMapTables.ContainsProgram(const aProgram: Word): boolean;
var
  i  : integer;
begin
  result := false;
  for I := 0 to Self.Count - 1 do
  begin
    if Self.Items[i].ProgramNumber = aProgram then
    begin
      result := true;
      break;
    end;
  end;
end;

function TProgramMapTables.IndexOfProgram(const aProgram: Word): integer;
var
  i  : integer;
begin
  result := -1;
  for I := 0 to Self.Count - 1 do
  begin
    if Self.Items[i].ProgramNumber = aProgram then
    begin
      result := i;
      break;
    end;
  end;
end;

function TProgramMapTables.TryGetByProgram(const aProgram: Word; var ProgramMapTable: TProgramMapTable): boolean;
var
  lIndex : integer;
begin
  result := false;
  ProgramMapTable := nil;
  lIndex := Self.IndexOfProgram(aProgram);
  if ((lIndex >= 0) and (lIndex < Self.Count)) then
  begin
    ProgramMapTable := Self.Items[lIndex];
    result := true;
  end;
end;

//
constructor TProgramMapTable.Create();
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;
  Self.FEsList := TEsInfoList.Create;
end;

constructor TProgramMapTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;
  Self.FEsList := TEsInfoList.Create;

  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse PMT packet');
end;

destructor TProgramMapTable.Destroy;
begin
  FreeAndNil(Self.FDescriptors);
  FreeAndNil(Self.FEsList);
  inherited Destroy;
end;

{$REGION 'DUMP'}
function TProgramMapTable.Dump(): string;
var
  i : integer;
begin
  result := Format('*** BEGIN - %s' + #13#10, [Self.Description]);
  result := result + Format('       PMT pcr_pid=0x%04x(%d)', [Self.FPcrPid, Self.FPcrPid]) + #13#10;
  for I := 0 to Self.FEsList.Count - 1 do
  begin
    result := result + Format('       PMT elementary stream type=0x%02x(%s) pid=0x%04x(%d)', [Self.FEsList[i].StreamType.asInt, Self.FEsList[i].StreamType.asString,  Self.FEsList[i].ElementaryPid, Self.FEsList[i].ElementaryPid]) + #13#10;
  end;
  result := result + Format('  CRC = 0x%08x', [Self.FCrc]) + #13#10;
  result := result + Format('*** END - %s', [Self.Description]);
end;
{$ENDREGION}

function TProgramMapTable.Deserialize(const aTsPacket : TTsPacket): boolean;
var
  lCurPos             : integer;
  startOfNextField    : integer;
  lCrcPos             : integer;
begin
  result := false;
  if not inherited Deserialize(aTsPacket) then
    exit;

  try
    lCurPos := 1;

    //dfgsdfgsdf
    //https://github.com/Cinegy/TsDecoder/blob/master/Cinegy.TsDecoder/Tables/TableFactory.cs

    Self.FProgramNumber := word((aTsPacket.Payload[lCurPos + 3] shl 8) + aTsPacket.Payload[lCurPos + 4]);
    Self.FCurrentNextIndicator := (aTsPacket.Payload[lCurPos + 5] and $01) <> 0;
    Self.FVersionNumber := byte((aTsPacket.Payload[lCurPos + 5] and $3E) shr 1);
    Self.FSectionNumber := aTsPacket.Payload[lCurPos + 6];
    Self.FLastSectionNumber := aTsPacket.Payload[lCurPos + 7];

    Self.FPcrPid := word(((aTsPacket.Payload[lCurPos + 8] and $1f) shl 8) + aTsPacket.Payload[lCurPos + 9]);
    Self.FProgramDescriptorLength := word(((aTsPacket.Payload[lCurPos + 10] and $03) shl 8) + aTsPacket.Payload[lCurPos + 11]);

    // Get descriptors
    startOfNextField := Self.FDescriptors.AddFromBuffer(aTsPacket.Payload, Self.FProgramDescriptorLength, lCurPos + 12);

    // read ES Info
    startOfNextField := Self.FEsList.AddFromBuffer(aTsPacket.Payload, Self.SectionLength, startOfNextField);

    // crc
    lCrcPos := (lCurPos + 3) + (Self.SectionLength - 4); // offset 3, aProgramMapTable.SectionLength - CRC(4byte)
    Self.FCrc := cardinal((((aTsPacket.Payload[lCrcPos]) shl 24) + (aTsPacket.Payload[lCrcPos + 1] shl 16) + (aTsPacket.Payload[lCrcPos + 2] shl 8) + (aTsPacket.Payload[lCrcPos + 3])));

    result := true;

    if assigned(Self.OnChange) then
      Self.OnChange(Self);
  except end;
end;



end.
