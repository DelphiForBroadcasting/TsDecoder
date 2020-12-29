unit TsDecoder.Packet;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.EsInfo;

type
  EPesSyntax = Exception;
  ETsPacket = Exception;

  TPidType =
  (
        PAT_PID = $0000,
        CAT_PID = $0001,
        TSDT_PID = $0002,
        NIT_PID = $0010,
        SDT_PID = $0011,
        EIT_PID = $0012,
        TDT_PID = $0014,
        NULL_PID = $1FFF
  );

  TPesHeader = record
  public
    StartCode           : cardinal;
    StreamId            : TStreamType;
    PacketLength        : word;
    ScramblingControl   : integer;
    Priority            : integer;
    Alignment           : boolean;
    Copyright           : boolean;
    Original            : boolean;
    Copy                : boolean;
    ESCR                : boolean;
    EsRate              : boolean;
    DsmTrickMode        : boolean;
    AdditionalCopyInfo  : boolean;
    CRC                 : boolean ;
    Extension           : boolean;
    HeaderLength        : byte;
    Payload             : TArray<byte>;

    Pts                 : Int64;
    Dts                 : Int64;

    class function Init(): TPesHeader; static;
    class function Parse(const aData: TArray<byte>; const aOffset: integer): TPesHeader; static;
    class function GetTimeStamp(const aData: TArray<byte>; aOffset: integer): int64; static;
    class function TryParse(const aData: TArray<byte>; const aOffset: integer; var aPesHeader: TPesHeader): boolean; static;
  end;

// MPEG-TS transport packet
  TAdaptationField = record
  public
    FieldSize                         : integer;            // Number of bytes in the adaptation field immediately following this byte
    DiscontinuityIndicator            : boolean;
    RandomAccessIndicator             : boolean;
    ElementaryStreamPriorityIndicator : boolean;
    PcrFlag                           : boolean;
    OpcrFlag                          : boolean;
    SplicingPointFlag                 : boolean;
    TransportPrivateDataFlag          : boolean;
    AdaptationFieldExtensionFlag      : boolean;
    Pcr                               : uint64;
    PcrExtension                      : integer;            // PCR extension (27 MHz)
    Opcr                              : uint64;             // 33+6+9 Original Program clock reference. Helps when one TS is copied into another
    OpcrExtension                     : integer;            // OPCR extension (27 MHz)
    Splice                            : integer;            // 8 Indicates how many TS packets from this one a splicing point occurs (may be negative)
    class function Init(): TAdaptationField; static;
    class function Parse(const aData: TArray<byte>; aOffset: integer): TAdaptationField; static;
    class  function ParsePCR(const aData : TArray<byte>; const aOffset: integer; out aPcrBase: uint64; out aPcrExt: integer): boolean; static;
    class function TryParse(const aData: TArray<byte>; aOffset: integer; var aAdaptationField: TAdaptationField): boolean; static;
  end;

  TTsPacket = class
  public const
    PKT_SIZE                      = 188;
    TS_SYNC_BYTE                  = $47;
  private
    FSyncByte                      : byte;
    FTransportErrorIndicator       : boolean;            // 1  Transport Error Indicator
    FPayloadUnitStartIndicator     : boolean;            // 1  Payload Unit Start Indicator (Set when a PES, PSI, or DVB-MIP packet begins immediately following the header.)
    FTransportPriority             : boolean;            // 1  Transport Priority
    FPid                           : integer;            // 13 Packet ID
    FScramblingControl             : integer;            // 2  Transport scrambling control (0,1,2,3) 00 Ц пакет не зашифрован, 01 Ц зарезервировано дл€ будущего использовани€, 10 Ц пакет зашифрован четным ключом, 11 Ц пакет зашифрован нечетным ключом
    FAdaptationFieldExists         : boolean;
    FPayloadExists                 : boolean;
    FContinuityCounter             : integer;            // 4  Continuity counter

    FPesHeader                     : TPesHeader;
    FAdaptationField               : TAdaptationField;

    FPayload                       : TArray<byte>;

    FData                          : TArray<byte>;
  public
    constructor Create(); overload;
    constructor Create(const aData: TBytes; const aOffset: integer); overload;
    destructor Destroy; override;

    procedure Deserialize(const aData: TBytes; const aOffset: integer);
    function Serialize(): TBytes;
    function isNull: boolean;

    class function ParsePacketFromData(const aData: TBytes; const aOffset: integer; var aTsPacket: TTsPacket): boolean; static;
    class function GetTableIdName(aPid: integer): string; static;

    property TransportErrorIndicator: boolean read FTransportErrorIndicator;
    property PayloadUnitStartIndicator: boolean read FPayloadUnitStartIndicator;
    property TransportPriority: boolean read FTransportPriority;
    property Pid: integer read FPid;
    property ScramblingControl: integer read FScramblingControl;
    property AdaptationFieldExists: boolean read FAdaptationFieldExists;
    property PayloadExists: boolean read FPayloadExists;
    property ContinuityCounter: integer read FContinuityCounter;
    property PesHeader: TPesHeader read FPesHeader write FPesHeader;
    property Payload: TArray<byte> read FPayload;
    property AdaptationField: TAdaptationField read FAdaptationField;
    property Data: TArray<byte> read FData;
  end;

implementation

//
class function TAdaptationField.Init(): TAdaptationField;
begin
  FillChar(result, SizeOf(TAdaptationField), #0);
end;

// Program Clock Reference
// http://www.telesputnik.ru/materials/tekhnika-i-tekhnologii/article/osobennosti-formirovaniya-i-izmereniya-pcr-v-mpeg-signale/
class function TAdaptationField.ParsePCR(const aData : TArray<byte>; const aOffset: integer; out aPcrBase: uint64; out aPcrExt: integer): boolean;
var
  lPcrExt   : uint64;
  lPcrBase  : uint64;
begin
  //Packet has PCR
  lPcrBase := (((aData[aOffset]) shl 24) + ((aData[aOffset + 1] shl 16)) + ((aData[aOffset + 2] shl 8)) + (aData[aOffset + 3]));
  lPcrBase := lPcrBase shl 1;
  if ((aData[aOffset + 4] and $80) = 1) then
    lPcrBase :=  lPcrBase or 1;

  lPcrExt := ((aData[aOffset + 4] and 1) shl 8) + aData[aOffset + 5];
  aPcrExt := lPcrExt;

  // PCR(i) = PCR_base(i)*300 + PCR_ext(i)
  aPcrBase := lPcrBase * 300 + lPcrExt;

  result := true;
end;

class function TAdaptationField.TryParse(const aData: TArray<byte>; aOffset: integer; var aAdaptationField: TAdaptationField): boolean;
begin
  result := false;
  try
    aAdaptationField:= TAdaptationField.Parse(aData, aOffset);
    result := true;
  except end;
end;

class function TAdaptationField.Parse(const aData: TArray<byte>; aOffset: integer): TAdaptationField;
var
  lAdaptationField      : TAdaptationField;
  lAdaptationByteCount  : integer;
begin
  lAdaptationField := TAdaptationField.Init();
  lAdaptationByteCount := 0;

  lAdaptationField.FieldSize := aData[aOffset];
  inc(lAdaptationByteCount, 1);

  if lAdaptationField.FieldSize > 0 then
  begin
    lAdaptationField.DiscontinuityIndicator := (aData[aOffset + 1] and $80) <> 0;
    lAdaptationField.RandomAccessIndicator := (aData[aOffset + 1] and $40) <> 0;
    lAdaptationField.ElementaryStreamPriorityIndicator := (aData[aOffset + 1] and $20) <> 0;
    lAdaptationField.PcrFlag := (aData[aOffset + 1] and $10) <> 0;
    lAdaptationField.OpcrFlag := (aData[aOffset + 1] and $08) <> 0;
    lAdaptationField.SplicingPointFlag := (aData[aOffset + 1] and $04) <> 0;
    lAdaptationField.TransportPrivateDataFlag :=   (aData[aOffset + 1] and $02) <> 0;
    lAdaptationField.AdaptationFieldExtensionFlag := (aData[aOffset + 1] and $01) <> 0;
    inc(lAdaptationByteCount, 1);

    // PCR field value
    if lAdaptationField.PcrFlag then
    begin
      ParsePCR(aData, aOffset + lAdaptationByteCount, lAdaptationField.Pcr, lAdaptationField.PcrExtension);
      inc(lAdaptationByteCount, 5);
    end;

    // OPCR field value
    if lAdaptationField.OpcrFlag then
    begin
      ParsePCR(aData, aOffset + lAdaptationByteCount, lAdaptationField.Opcr, lAdaptationField.OpcrExtension);
      inc(lAdaptationByteCount, 5);
    end;

    // OPCR field value
    if lAdaptationField.SplicingPointFlag then
    begin
      lAdaptationField.Splice := aData[aOffset + lAdaptationByteCount];
      inc(lAdaptationByteCount, 1);
    end;

  end;

  result := lAdaptationField;
end;

//
class function TPesHeader.Init(): TPesHeader;
begin
  FillChar(result, SizeOf(TPesHeader), #0);
  result.Pts := -1;
  result.Dts := -1;
  SetLength(result.Payload, 0);
end;

// Packetized Elementary Streams http://dvd.sourceforge.net/dvdinfo/pes-hdr.html
class function TPesHeader.TryParse(const aData: TArray<byte>; const aOffset: integer; var aPesHeader: TPesHeader): boolean;
begin
  result := false;
  try
    aPesHeader:= TPesHeader.Parse(aData, aOffset);
    result := Boolean(aPesHeader.StartCode);
  except end;
end;


class function TPesHeader.GetTimeStamp(const aData: TArray<byte>; aOffset: integer): int64;
var
  a, b, c : int64;
begin
  if ((aData[aOffset + 0] and 1) <> 1) then
    raise EPesSyntax.Create('PES Syntax error: Invalid timestamp marker bit');

  if ((aData[aOffset + 2] and 1) <> 1) then
    raise EPesSyntax.Create('PES Syntax error: Invalid timestamp marker bit');

  if ((aData[aOffset + 4] and 1) <> 1) then
    raise EPesSyntax.Create('PES Syntax error: Invalid timestamp marker bit');

  a := (aData[aOffset + 0] shr 1) and 7;
  b := (aData[aOffset + 1] shl 7) or (aData[aOffset + 2] shr 1);
  c := (aData[aOffset + 3] shl 7) or (aData[aOffset + 4] shr 1);

  result := (a shl 30) or (b shl 15) or c;

end;

class function TPesHeader.Parse(const aData: TArray<byte>; const aOffset: integer): TPesHeader;
var
  lPesHeader : TPesHeader;
begin
  lPesHeader := TPesHeader.Init();

  if ((aData[aOffset] <> 0) or (aData[aOffset + 1] <> 0) or (aData[aOffset + 2] <> 1)) then
  begin
    exit;
    raise EPesSyntax.Create('PES syntax error: no PES startcode found, or payload offset exceeds boundary of data');
  end;

  lPesHeader.Pts := -1;
  lPesHeader.Dts := -1;

  // header  sizeof(6)
  lPesHeader.StartCode := (aData[aOffset] shl 16) + (aData[aOffset + 1] shl 8) +  aData[aOffset + 2];
  lPesHeader.StreamId := TStreamType.Create(aData[aOffset + 3]);
  lPesHeader.PacketLength :=  (aData[aOffset + 4] shl 8) + aData[aOffset + 5];

  // extension header sizeof(3)
  if (((aData[aOffset + 6] and $c0) shr 6) = 2) then  // bin '10'
  begin
    lPesHeader.ScramblingControl := (aData[aOffset + 6] and $30) shr 4; // PES scrambling control -- 00 = not scrambled, others are user defined
    lPesHeader.Priority := ((aData[aOffset + 6] and $08) shr 3);  // PES priority -- provides 2 priority levels, 0 and 1.
    lPesHeader.Alignment := ((aData[aOffset + 6] and $04) shr 2) <> 0;  // data alignment indicator -- if set to 1 indicates that the PES packet header is immediately followed by the video start code or audio syncword.
    lPesHeader.Copyright := ((aData[aOffset + 6] and $02) shr 1) <> 0;  // copyright -- 1 = packet contains copyrighted material.

    // original or copy
    if (aData[aOffset + 6] and $01) <> 0 then  // original or copy -- 1 = original, 0 = copy.
      lPesHeader.Original := true
     else lPesHeader.Copy := true;

    // PTS DTS flags
    if ((aData[aOffset + 7]) shr 6) > 1 then      // PTS DTS flags -- Presentation Time Stamp / Decode Time Stamp. 00 = no PTS or DTS data present, 01 is forbidden
    begin
      lPesHeader.Pts := GetTimeStamp(aData, aOffset + 9);
      if ((aData[aOffset + 7]) shr 6) = 3 then
        lPesHeader.Dts := GetTimeStamp(aData, aOffset + 14);
    end;

    lPesHeader.ESCR := ((aData[aOffset + 7] and $10) shr 4) <> 0; // ESCR -- if set to 1 the following data is appended to the header data field:
    lPesHeader.EsRate := ((aData[aOffset + 7] and $08) shr 3) <> 0;  //ES rate -- if set to 1 the following data is appended to the header data field:
    lPesHeader.DsmTrickMode := ((aData[aOffset + 7] and $04) shr 2) <> 0;
    lPesHeader.AdditionalCopyInfo :=  ((aData[aOffset + 7] and $02) shr 1) <> 0;  //additional copy info -- if set to 1 the following data is appended to the header data field:
    lPesHeader.CRC := (aData[aOffset + 7] and $01) <> 0; // PES CRC flag -- if set to 1 the following data is appended to the header data field: The polynomial used is X16 + X12 + X5 + 1
    lPesHeader.Extension := (aData[aOffset + 7] and $01) <> 0; //PES extension flag -- if set to 1 the following data is appended to the header data field:
    lPesHeader.HeaderLength := aData[aOffset + 8];
  end;

  SetLength(lPesHeader.Payload, lPesHeader.HeaderLength);
  Move(aData[aOffset], lPesHeader.Payload[0], lPesHeader.HeaderLength);

  result := lPesHeader;
end;

//
constructor TTsPacket.Create();
begin
  inherited Create;
end;

constructor TTsPacket.Create(const aData: TBytes; const aOffset: integer);
begin
  inherited Create;
  Self.Deserialize(aData, aOffset);
end;


destructor TTsPacket.Destroy;
begin
  inherited Destroy;
end;

class function TTsPacket.GetTableIdName(aPid: integer): string;
begin
  case aPid of
    $00: result := 'program association';
    $01: result := 'conditional access';
    $02: result := 'program map';
    $03: result := 'transport stream description';
        // 0x04 - 0x3f "reserved"
    $40: result := 'actual network info';
    $41: result := 'other network info';
    $42: result := 'actual service description';
    $46: result := 'other service description';
    $4a: result := 'bouquet association';
    $4e: result := 'actual event info now';
    $4f: result := 'other event info now';
        // 0x50 - 0x5f "event info actual schedule"
        // 0x60 - 0x6f "event info other schedule"
    $70: result := 'time data';
    $71: result := 'running status';
    $72: result := 'stuffing';
    $73: result := 'time offset';
    $74: result := 'application information';
    $75: result := 'container';
    $76: result := 'related content';
    $77: result := 'content id';
    $78: result := 'MPE-FEC';
    $79: result := 'resolution notification';
    $7a: result := 'MPE-IFEC';
        // 0x7b - 0x7d "reserved"
    $7e: result := 'discontinuity info';
    $7f: result := 'selection info';
        // 0x80 - 0xfe "user defined"
    $ff: result := 'reserved';
    else
       result := 'reserved';
  end;
end;

class function TTsPacket.parsePacketFromData(const aData: TBytes; const aOffset: integer; var aTsPacket: TTsPacket): boolean;
var
  lTsPacket: TTsPacket;  
begin
  result := false;
  try
    lTsPacket:= TTsPacket.Create();
    lTsPacket.Deserialize(aData, aOffset);
    aTsPacket := lTsPacket;
    result := true;
  except end;
end;

function TTsPacket.isNull: boolean;
begin
  result := Self.FPid = integer(TPidType.NULL_PID);
end;

procedure TTsPacket.Deserialize(const aData: TBytes; const aOffset: integer);
var
  lPacketOffs           : integer;
  lPayloadOffs          : integer;
  lPayloadSize          : integer;
  lPesHeader            : TPesHeader;
begin
  if aData[aOffset] <> TS_SYNC_BYTE then
    raise ETsPacket.Create('Data not start from SYNC_BYTE');

  // preserve packet source
  SetLength(Self.FData, TTsPacket.PKT_SIZE);
  Move(AData[aOffset], Self.FData[0], TTsPacket.PKT_SIZE);

  // set packet offset
  lPacketOffs := aOffset;

  Self.FSyncByte := TS_SYNC_BYTE;                                                     // 0
  Self.FTransportErrorIndicator := ((AData[lPacketOffs + 1] and $80) shr 7) <> 0;     // 1
  Self.FPayloadUnitStartIndicator := ((AData[lPacketOffs + 1] and $40) shr 6) <> 0;   // 1
  Self.FTransportPriority := ((AData[lPacketOffs + 1] and $20) shr 5) <> 0;           // 1
  Self.FPid := ((AData[lPacketOffs + 1] and $1F) shl 8) or AData[lPacketOffs + 2];    // 2
  Self.FPid := ((AData[lPacketOffs + 1] shl 8) or AData[lPacketOffs + 2]) and $1FFF;  // 2
  Self.FPid := (((AData[lPacketOffs + 1] and $1F) shl 8) + (AData[lPacketOffs + 2])); // 2
  Self.FScramblingControl := (AData[lPacketOffs + 3] and $C0);                        // 3
  Self.FAdaptationFieldExists := (AData[lPacketOffs + 3]and $20) <> 0;                // 3
  Self.FPayloadExists  := (AData[lPacketOffs + 3] and $10) <> 0;                      // 3
  Self.FContinuityCounter := (AData[lPacketOffs + 3] and $F);                         // 3
  lPacketOffs := lPacketOffs + 4;                                                     // 4

  //skip packets with error indicators or on the null PID
  if ((Self.FTransportErrorIndicator) or (Self.isNull)) then
    exit;

  // Payload
  lPayloadOffs := lPacketOffs;
  lPayloadSize := TTsPacket.PKT_SIZE - 4;

  // AdaptationField
  if Self.FAdaptationFieldExists then
  begin
    Self.FAdaptationField := TAdaptationField.Parse(aData, lPacketOffs);
    if (Self.FAdaptationField.FieldSize >= lPayloadSize) then
      raise ETsPacket.Create('TS packet data adaptationFieldSize >= payloadSize');
    lPayloadSize := lPayloadSize - (1 + Self.FAdaptationField.FieldSize);
    lPayloadOffs := lPayloadOffs + (1 + Self.FAdaptationField.FieldSize);
  end;


  // bbbb
  if (Self.FPayloadExists and (not Self.FPayloadUnitStartIndicator)) then
  begin
    if TPesHeader.TryParse(aData, (lPayloadOffs - Self.FAdaptationField.FieldSize) + 1 , lPesHeader) then
    begin
      if lPesHeader.StreamId.asInt = 224 then
      begin
        lPesHeader.Dts := 555;
        Self.PesHeader := lPesHeader;
        
      end;
    end;
  end else


  // Payload
  if (Self.FPayloadExists and Self.FPayloadUnitStartIndicator) then
  begin
    if TPesHeader.TryParse(aData, lPayloadOffs, lPesHeader) then
    begin
      Self.PesHeader := lPesHeader;
      lPayloadOffs := lPayloadOffs + (9 + Self.PesHeader.HeaderLength);
      lPayloadSize := lPayloadSize - (9 + Self.PesHeader.HeaderLength);
    end;
  end;

 // log.d(get_table_id_name(aData[payloadOffs + 1]));

  // preserve packet payload
  SetLength(Self.FPayload, lPayloadSize);
  Move(AData[lPayloadOffs], Self.FPayload[0], lPayloadSize);
end;


function TTsPacket.Serialize(): TBytes;
var
  lPacket : TBytes;
begin
  SetLength(lPacket, TTsPacket.PKT_SIZE);
  FillChar(lPacket, Length(lPacket), #0);
  lPacket[0] := TTsPacket.TS_SYNC_BYTE;

end;



end.
