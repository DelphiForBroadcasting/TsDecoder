unit TsDecoder.Descriptor;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TBaseDescriptor = class
  private
    FTag : byte;
    FLength : byte;
    FData : TArray<byte>;
    function GetTag(): byte;
    function GetLength(): byte;
    function GetData(): TArray<byte>;
    function GetSize(): integer;
    function GetDescriptorName(): string;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property Tag: byte read GetTag;
    property Length: byte read GetLength;
    property Data: TArray<byte> read GetData;
    property Size: integer read GetSize;
    property Name: string read GetDescriptorName;
  end;

  /// <summary>
  /// ISO 639 language descriptor <see cref="Descriptor"/>.
  /// </summary>
  /// <remarks>
  /// For details please refer to the original documentation,
  /// e.g. <i>ISO/IEC 13818-1 : 2000 (E) 2.6.18</i> or alternate versions.
  /// </remarks>
  TIso639LanguageDescriptor = class(TBaseDescriptor)
  private
    FLanguage  : string;
    FAudioType : byte;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property Language : string read FLanguage;
    property AudioType : byte read FAudioType;
  end;

  /// <summary>
  /// A Networkname Descriptor <see cref="Descriptor"/>.
  /// </summary>
  /// <remarks>
  /// For details please refer to the original documentation,
  /// e.g. <i>ETSI EN 300 468 V1.15.1 (2016-03)</i> or alternate versions.
  /// </remarks>
  TNetworkNameDescriptor = class(TBaseDescriptor)
  private
    FNetworkName  : string;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property NetworkName : string read FNetworkName ;
  end;

   /// <summary>
   /// Data stream alignment descriptor  <see cref="Descriptor"/>.
   /// </summary>
   /// <remarks>
   /// For details please refer to the original documentation,
   /// e.g. <i> ISO/IEC 13818-1 : 2000 (E) 2.6.10</i> or alternate versions.
   /// </remarks>
  TDataStreamAlignmentDescriptor = class(TBaseDescriptor)
  private const
    BaseTag = $06;
  private
    FAlignmentType : byte;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property AlignmentType: byte read FAlignmentType;
  end;


   /// <summary>
   /// Data stream alignment descriptor  <see cref="Descriptor"/>.
   /// </summary>
   /// <remarks>
   /// For details please refer to the original documentation,
   /// e.g. <i> ISO/IEC 13818-1 : 2000 (E) 2.6.8</i> or alternate versions.
   /// </remarks>
  TRegistrationDescriptor = class(TBaseDescriptor)
  private type
    TFormatIdentifier = record
      FValue : TBytes;
    public
      class function Create(const Value: TBytes): TFormatIdentifier; overload; static;
      class function Create(const Value: TBytes; const Offset: Integer; const Size: Integer): TRegistrationDescriptor.TFormatIdentifier; overload; static;
      function asString(): string;
    end;
  private const
    BaseTag = $05;
  private
    FFormatIdentifier             : TFormatIdentifier;
    FAdditionalIdentificationInfo : TBytes;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property FormatIdentifier: TFormatIdentifier read FFormatIdentifier;
    property AdditionalIdentificationInfo: TBytes read FAdditionalIdentificationInfo;
  end;

   /// <summary>
   /// A Stream Identifier Descriptor <see cref="Descriptor"/>.
   /// </summary>
   /// <remarks>
   /// For details please refer to the original documentation,
   /// e.g. <i>ETSI EN 300 468 V1.15.1 (2016-03)</i> or alternate versions.
   /// </remarks>
  TStreamIdentifierDescriptor = class(TBaseDescriptor)
  private
    FComponentTag : byte;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property ComponentTag: byte read FComponentTag;
  end;

  /// <summary>
  /// A AAC Descriptor <see cref="Descriptor"/>.
  /// </summary>
  /// <remarks>
  /// For details please refer to the original documentation,
  /// e.g. <i>ETSI EN 300 468 V1.15.1 (2016-03) Table H.1 </i> or alternate versions.
  /// </remarks>
  TAACDescriptor = class(TBaseDescriptor)
  private
    FProfileAndLevel    : byte;
    FAACTypeFlag        : integer;
    FSAOCDETypeFlag     : boolean;
    FAACType            : byte;
    FAdditionalInfoBytes: TArray<Byte>;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;

    property ProfileAndLevel: byte read FProfileAndLevel;
    property AACTypeFlag: integer read FAACTypeFlag;
    property SAOCDETypeFlag: boolean read FSAOCDETypeFlag;
    property AACType: byte read FAACType;
    property AdditionalInfoBytes:  TArray<Byte> read FAdditionalInfoBytes;

  end;

  /// <summary>
  /// A Service Descriptor <see cref="Descriptor"/>.
  /// </summary>
  /// <remarks>
  /// For details please refer to the original documentation,
  /// e.g. <i>ETSI EN 300 468 V1.15.1 (2016-03)</i> or alternate versions.
  /// </remarks>
  TServiceDescriptor = class(TBaseDescriptor)
  private
    FServiceType: byte;
    FServiceProviderNameLength: byte;
    FServiceProviderName: string;
    FServiceNameLength: byte;
    FServiceName: string;
    function GetServiceTypeDescription: string;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;

    property ServiceType: byte read FServiceType;
    property ServiceTypeDescription: string read GetServiceTypeDescription;
    property ServiceProviderName: string read FServiceProviderName;
    property ServiceName: string read FServiceName;
  end;

  /// <summary>
  /// Cue Identifier Descriptor <see cref="Descriptor"/>.
  /// </summary>
  /// <remarks>
  /// For details please refer to the original documentation,
  /// e.g. <i> SCTE 35 2016 8.2. Cue Identifier Descriptor </i> or alternate versions.
  /// </remarks>
  TCueIdentifierDescriptor = class(TBaseDescriptor)
  private const
    BaseTag = $8A;
  private
    (*
      0x00 splice_insert, splice_null, splice_schedule
      0x01 All Commands
      0x02 Segmentation
      0x03 Tiered Splicing
      0x04 Tiered Segmentation
      0x05-0x7f Reserved
      0x80 - 0xff User Defined
    *)
    FCueStreamType : byte;
  protected
    function GetCueType(): byte;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    class function CueTypeToString(const aCueType: byte): string; static;
    property CueType: byte read GetCueType;
  end;

  /// <summary>
  /// Conditional access descriptor <see cref="Descriptor"/>.
  /// </summary>
  /// <remarks>
  /// For details please refer to the original documentation,
  /// e.g. <i>ISO/IEC 13818-1 : 2000 (E) 2.6.16 </i> or alternate versions.
  /// </remarks>
  TCADescriptor = class(TBaseDescriptor)
  private
    FSystemID       : word;
    FPid            : word;
    FPrivateData    : TBytes;
  public
    constructor Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);  overload;
    destructor Destroy; override;
    property SystemID: word read FSystemID;
    property Pid: word read FPid;
    property PrivateData: TBytes read FPrivateData;
  end;

  TDescriptors = class(TObjectList<TBaseDescriptor>)
  private

  public
    constructor Create(); overload;
    destructor Destroy; override;

    function AddFromBuffer(const aData : TArray<byte>; const aDescriptorsLength: integer; const aOffset: integer): integer; overload;
  end;

implementation

//
constructor TDescriptors.Create();
begin
  inherited Create;
end;

destructor TDescriptors.Destroy;
begin
  inherited Destroy;
end;

function TDescriptors.AddFromBuffer(const aData : TArray<byte>; const aDescriptorsLength: integer; const aOffset: integer): integer;
var
  lOffset : integer;
  lTag    : byte;
  lLength : byte;
begin
  lOffset := aOffset;
  while (lOffset < aOffset + aDescriptorsLength) do
  begin
    lTag := aData[lOffset];
    lLength := aData[lOffset + 1];
    case lTag of
      $05:
        begin
          Self.Add(TRegistrationDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $06:
        begin
          Self.Add(TDataStreamAlignmentDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $09:
        begin
          Self.Add(TCADescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $0a:
        begin
          Self.Add(TIso639LanguageDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $8a:
        begin
          Self.Add(TCueIdentifierDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $40:
        begin
          Self.Add(TNetworkNameDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $48:
        begin
          Self.Add(TServiceDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $52:
        begin
          Self.Add(TStreamIdentifierDescriptor.Create(lTag, aData, lOffset, lLength));
        end;
      $7c:
        begin
          Self.Add(TAACDescriptor.Create(lTag, aData, lOffset, lLength));
        end
      else
        Self.Add(TBaseDescriptor.Create(lTag, aData, lOffset, lLength));
    end;
    lOffset := lOffset + 2 + lLength;
  end;
  result := lOffset
end;

//
constructor TStreamIdentifierDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  Self.FComponentTag := aData[aOffset + 2];
end;

destructor TStreamIdentifierDescriptor.Destroy;
begin
  inherited Destroy;
end;

//
constructor TDataStreamAlignmentDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  Self.FAlignmentType := aData[aOffset + 2];
end;

destructor TDataStreamAlignmentDescriptor.Destroy;
begin
  inherited Destroy;
end;


//
class function TRegistrationDescriptor.TFormatIdentifier.Create(const Value: TBytes): TRegistrationDescriptor.TFormatIdentifier;
begin
  result := TRegistrationDescriptor.TFormatIdentifier.Create(Value, 0, 4);
end;

class function TRegistrationDescriptor.TFormatIdentifier.Create(const Value: TBytes; const Offset: Integer; const Size: Integer): TRegistrationDescriptor.TFormatIdentifier;
begin
  SetLength(result.FValue, Size);
  Move(Value[Offset], result.FValue[0], Size);
end;

function TRegistrationDescriptor.TFormatIdentifier.asString(): string;
begin
  result := TEncoding.ASCII.GetString(FValue);
end;

constructor TRegistrationDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  if (((System.Length(aData) - aOffset) - 4) >= Self.Length)  then
    Self.FFormatIdentifier := TFormatIdentifier.Create(aData, aOffset + 2, 4);

  if (Self.Length > 4) then
  begin
    SetLength(FAdditionalIdentificationInfo, Self.Length - 4);
    Move(aData[aOffset + 6], FAdditionalIdentificationInfo[0], Self.Length - 4);
  end;
end;

destructor TRegistrationDescriptor.Destroy;
begin
  inherited Destroy;
end;

//
// 47 48 00 14 00 FC 30 11 00 00 00 00 00 00 00 FF
// FF FF 00 00 00 4F 25 33 96 FF FF FF FF FF FF FF
constructor TCueIdentifierDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  FCueStreamType := aData[aOffset + 2];
end;

destructor TCueIdentifierDescriptor.Destroy;
begin
  inherited Destroy;
end;

function TCueIdentifierDescriptor.GetCueType(): byte;
begin
  result := FCueStreamType;
end;

class function TCueIdentifierDescriptor.CueTypeToString(const aCueType: byte): string;
begin
  result := 'User Defined';
  case aCueType of
    $00: result:= 'splice_insert, splice_null, splice_schedule';
    $01: result:= 'All Commands';
    $02: result:= 'Segmentation';
    $03: result:= 'Tiered Splicing';
    $04: result:= 'Tiered Segmentation';
    else
      begin
        if ((aCueType >= $05) and (aCueType <= $7f)) then
          result := 'Reserved';
      end;
  end;
end;

//
constructor TCADescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  FSystemID := aData[aOffset+2] shl 8 + aData[aOffset+3];
  FPid := (aData[aOffset+4] and $1f) shl 8 + aData[aOffset+5];

  SetLength(FPrivateData, Self.Length - 4);
  move(aData[aOffset + 6], Self.FPrivateData[0], Self.Length - 4);
end;

destructor TCADescriptor.Destroy;
begin
  inherited Destroy;
end;

//
constructor TBaseDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create;
  FTag := aTag;
  FLength := aLength;

  if (System.Length(aData) < aOffset + 2 + FLength) then
    raise Exception.Create('TBaseDescriptor.Data.Length');

  SetLength(FData, FLength);
  Move(aData[aOffset+2], FData[0], aLength);
end;

destructor TBaseDescriptor.Destroy;
begin
  inherited Destroy;
end;

function TBaseDescriptor.GetSize(): integer;
begin
  result := 2 + FLength;
  if FLength <> System.Length(FData) then
    raise Exception.Create('Error Message');
end;

function TBaseDescriptor.GetTag(): byte;
begin
  result := FTag;
end;

function TBaseDescriptor.GetLength(): byte;
begin
  result := FLength;
end;

function TBaseDescriptor.GetData(): TArray<byte>;
begin
  result := FData;
end;

function TBaseDescriptor.GetDescriptorName(): string;
begin
(* From ISO/IEC 13818-1 *)
  case Self.FTag of
    $00: result := 'Reserved';
    $01: result := 'Reserved';
    $02: result := 'Video Stream Descriptor';
    $03: result := 'Audio Stream Descriptor';
    $04: result := 'Hierarchy Descriptor';
    $05: result := 'Registration Descriptor';
    $06: result := 'Data Stream Alignment Descriptor';
    $07: result := 'Target Background Grid Descriptor';
    $08: result := 'Video Window Descriptor';
    $09: result := 'CA Descriptor';
    $0A: result := 'ISO 639 Language Descriptor';
    $0B: result := 'System Clock Descriptor';
    $0C: result := 'Multiplex Buffer Utilization Descriptor';
    $0D: result := 'Copyright Descriptor';
    $0E: result := 'Maximum Bitrate Descriptor';
    $0F: result := 'Private Data Indicator Descriptor';
    $10: result := 'Smoothing Buffer Descriptor';
    $11: result := 'STD Descriptor';
    $12: result := 'IBP Descriptor';

    (* From ETSI TR 101 202 *)
    $13: result := 'Carousel Identifier Descriptor';
    $14: result := 'Association Tag Descriptor';
    $15: result := 'Deferred Association Tag Descriptor';

    (* From ISO/IEC 13818-1 *)
    $1B: result := 'MPEG 4 Video Descriptor';
    $1C: result := 'MPEG 4 Audio Descriptor';
    $1D: result := 'IOD Descriptor';
    $1E: result := 'SL Descriptor';
    $1F: result := 'FMC Descriptor';
    $20: result := 'External ES ID Descriptor';
    $21: result := 'MuxCode Descriptor';
    $22: result := 'FmxBufferSize Descriptor';
    $23: result := 'MultiplexBuffer Descriptor';
    $24: result := 'Content Labeling Descriptor';
    $25: result := 'Metadata Pointer Descriptor';
    $26: result := 'Metadata Descriptor';
    $27: result := 'Metadata STD Descriptor';
    $28: result := 'AVC Video Descriptor';
    $29: result := 'IPMP Descriptor';
    $2A: result := 'AVC Timing and HRD Descriptor';
    $2B: result := 'MPEG2 AAC Descriptor';
    $2C: result := 'FlexMuxTiming Descriptor';

    (* From ETSI EN 300 468 *)
    $40: result := 'Network Name Descriptor';
    $41: result := 'Service List Descriptor';
    $42: result := 'Stuffing Descriptor';
    $43: result := 'Satellite Delivery System Descriptor';
    $44: result := 'Cable Delivery System Descriptor';
    $45: result := 'VBI Data Descriptor';
    $46: result := 'VBI Teletext Descriptor';
    $47: result := 'Bouquet Name Descriptor';
    $48: result := 'Service Descriptor';
    $49: result := 'Country Availability Descriptor';
    $4A: result := 'Linkage Descriptor';
    $4B: result := 'NVOD Reference Descriptor';
    $4C: result := 'Time Shifted Service Descriptor';
    $4D: result := 'Short Event Descriptor';
    $4E: result := 'Extended Event Descriptor';
    $4F: result := 'Time Shifted Event Descriptor';
    $50: result := 'Component Descriptor';
    $51: result := 'Mosaic Descriptor';
    $52: result := 'Stream Identifier Descriptor';
    $53: result := 'CA Identifier Descriptor';
    $54: result := 'Content Descriptor';
    $55: result := 'Parent Rating Descriptor';
    $56: result := 'Teletext Descriptor';
    $57: result := 'Telephone Descriptor';
    $58: result := 'Local Time Offset Descriptor';
    $59: result := 'Subtitling Descriptor';
    $5A: result := 'Terrestrial Delivery System Descriptor';
    $5B: result := 'Multilingual Network Name Descriptor';
    $5C: result := 'Multilingual Bouquet Name Descriptor';
    $5D: result := 'Multilingual Service Name Descriptor';
    $5E: result := 'Multilingual Component Descriptor';
    $5F: result := 'Private Data Specifier Descriptor';
    $60: result := 'Service Move Descriptor';
    $61: result := 'Short Smoothing Buffer Descriptor';
    $62: result := 'Frequency List Descriptor';
    $63: result := 'Partial Transport Stream Descriptor';
    $64: result := 'Data Broadcast Descriptor';
    $65: result := 'Scrambling Descriptor';
    $66: result := 'Data Broadcast ID Descriptor';
    $67: result := 'Transport Stream Descriptor';
    $68: result := 'DSNG Descriptor';
    $69: result := 'PDC Descriptor';
    $6A: result := 'AC-3 Descriptor';
    $6B: result := 'Ancillary Data Descriptor';
    $6C: result := 'Cell List Descriptor';
    $6D: result := 'Cell Frequency Link Descriptor';
    $6E: result := 'Announcement Support Descriptor';
    $6F: result := 'Application Signalling Descriptor';
    $70: result := 'Adaptation Field Data Descriptor';
    $71: result := 'Service Identifier Descriptor';
    $72: result := 'Service Availability Descriptor';
    $73: result := 'Default Authority Descriptor';
    $74: result := 'Related Content Descriptor';
    $75: result := 'TVA ID Descriptor';
    $76: result := 'Content Identifier Descriptor';
    $77: result := 'Time Slice FEC Identifier Descriptor';
    $78: result := 'ECM Repetition Rate Descriptor';
    $79: result := 'S2 Satellite Delivery System Descriptor';
    $7A: result := 'Enhanced AC-3 Descriptor';
    $7B: result := 'DTS Descriptor';
    $7C: result := 'AAC Descriptor';
    $7D: result := 'XAIT Content Location Descriptor';
    $7E: result := 'FTA Content Management Descriptor';
    $7F: result := 'Extension Descriptor';

    (* *)
    $8A: result := 'Cue Identifier Descriptor';

    (* From ETSI EN 301 790 *)
    $A0: result := 'Network Layer Info Descriptor';
    $A1: result := 'Correction Message Descriptor';
    $A2: result := 'Logon Initialize Descriptor';
    $A3: result := 'ACQ Assign Descriptor';
    $A4: result := 'SYNC Assign Descriptor';
    $A5: result := 'Encrypted Logon ID Descriptor';
    $A6: result := 'Echo Value Descriptor';
    $A7: result := 'RCS Content Descriptor';
    $A8: result := 'Satellite Forward Link Descriptor';
    $A9: result := 'Satellite Return Link Descriptor';
    $AA: result := 'Table Update Descriptor';
    $AB: result := 'Contention Control Descriptor';
    $AC: result := 'Correction Control Descriptor';
    $AD: result := 'Forward Interaction Path Descriptor';
    $AE: result := 'Return Interaction Path Descriptor';
    $Af: result := 'Connection Control Descriptor';
    $B0: result := 'Mobility Control Descriptor';
    $B1: result := 'Correction Message Extension Descriptor';
    $B2: result := 'Return Transmission Modes Descriptor';
    $B3: result := 'Mesh Logon Initialize Descriptor';
    $B5: result := 'Implementation Type Descriptor';
    $B6: result := 'LL FEC Identifier Descriptor';
    else
      result := 'Unknown Descriptor';
  end;
end;



//
constructor TAACDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
var
  lHeaderLength : integer;
begin
  inherited Create(aTag, aData, aOffset, aLength);

  if aLength = 0 then
    raise Exception.Create('The AAC Descriptor Message is short!');


  lHeaderLength := 2;
  Self.FProfileAndLevel := aData[aOffset + 2];
  Self.FAACTypeFlag := (aData[aOffset + 3] shr 7) and $01;
  if (Self.FAACTypeFlag = $01) then
  begin
    inc(lHeaderLength);
    Self.FAACType := aData[aOffset + 3];
  end;

  if (Self.Length - lHeaderLength) < 0 then
    raise Exception.Create('The AAC Descriptor Message is short!');

  SetLength(Self.FAdditionalInfoBytes, Self.Length - lHeaderLength);
  move(aData[aOffset + 4], Self.FAdditionalInfoBytes, Self.Length - lHeaderLength);
end;

destructor TAACDescriptor.Destroy;
begin
  inherited Destroy;
end;

//
constructor TIso639LanguageDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  Self.FLanguage := TEncoding.UTF8.GetString(aData, aOffset + 2, 3);
  Self.FAudioType := aData[aOffset + 5];
end;

destructor TIso639LanguageDescriptor.Destroy;
begin
  inherited Destroy;
end;

//
constructor TNetworkNameDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
var
  lStartOfName  : integer;
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  lStartOfName := aOffset + 2;
  case  aData[aOffset + 2] of
    $1F: inc(lStartOfName, 2);
    $10: inc(lStartOfName, 3);
  end;

  SetString(Self.FNetworkName, PAnsiChar(@aData[lStartOfName]), Self.Length - (lStartOfName - aOffset) + 2);
end;

destructor TNetworkNameDescriptor.Destroy;
begin
  inherited Destroy;
end;

//
constructor TServiceDescriptor.Create(const aTag: byte; const aData: TArray<byte>; aOffset: integer; aLength: integer);
begin
  inherited Create(aTag, aData, aOffset, aLength);
  if aLength = 0 then
    raise Exception.Create('The Descriptor Message is short!');

  FServiceType := aData[aOffset + 2];
  FServiceProviderNameLength := aData[aOffset + 3];
  SetString(FServiceProviderName, PAnsiChar(@aData[aOffset + 4]), FServiceProviderNameLength);
  FServiceNameLength := aData[aOffset + 4 + FServiceProviderNameLength];
  SetString(FServiceName, PAnsiChar(@aData[aOffset + 4 + FServiceProviderNameLength + 1]), FServiceNameLength);
end;

destructor TServiceDescriptor.Destroy;
begin
  inherited Destroy;
end;

function TServiceDescriptor.GetServiceTypeDescription(): string;
begin
  case Self.FServiceType of
    $00:
      result := 'reserved for future use';
    $01:
      result := 'digital television service (see note 1)';
    $02:
      result := 'digital radio sound service (see note 2)';
    $03:
      result := 'Teletext service';
    $04:
      result := 'NVOD reference service (see note 1)';
    $05:
      result := 'NVOD time-shifted service (see note 1)';
    $06:
      result := 'mosaic service';
    $07:
      result := 'FM radio service';
    $08:
      result := 'DVB SRM service [49]';
    $09:
      result := 'reserved for future use';
    $0A:
      result := 'advanced codec digital radio sound service';
    $0B:
      result := 'H.264/AVC mosaic service';
    $0C:
      result := 'data broadcast service';
    $0D:
      result := 'reserved for Common Interface Usage (EN 50221[37])';
    $0E:
      result := 'RCS Map (see EN301790[7])';
    $0F:
      result := 'RCS FLS (see EN301790[7])';
    $10:
      result := 'DVB MHP service 0x11 MPEG-2 HD digital television service';
    $16:
      result := 'H.264/AVC SD digital television service';
    $17:
      result := 'H.264/AVC SD NVOD time-shifted service';
    $18:
      result := 'H.264/AVC SD NVOD reference service';
    $19:
      result := 'H.264/AVC HD digital television service';
    $1A:
      result := 'H.264/AVC HD NVOD time-shifted service';
    $1B:
      result := 'H.264/AVC HD NVOD reference service';
    $1C:
      result := 'H.264/AVC frame compatible plano-stereoscopic HD digital television service (see note 3)';
    $1D:
      result := 'H.264/AVC frame compatible plano-stereoscopic HD NVOD time-shifted service (see note 3)';
    $1E:
      result := 'H.264/AVC frame compatible plano-stereoscopic HD NVOD reference service (see note 3)';
    $1F:
      result := 'HEVC digital television service';
    $FF:
      result := 'reserved for future use';
    else
      begin
        if ((FServiceType >= $20) or (FServiceType <= $7F)) then
          result := 'reserved for future use'
        else if ((FServiceType >= $80) or (FServiceType <= $FE)) then
          result := 'user defined'
        else if ((serviceType >= $12) or (serviceType <= $15)) then
          result := 'reserved for future use'
        else
          result := 'unknown';
      end;
  end;
end;



end.
