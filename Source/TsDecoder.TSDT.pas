unit TsDecoder.TSDT;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Descriptor,
  TsDecoder.EsInfo,
  TsDecoder.Packet,
  TsDecoder.Tables;


type
{$REGION 'Transport Stream Description Table'}
   /// <summary>
   /// Transport Stream Description Table
   /// </summary>
   /// <remarks>
   /// For details please refer to the original documentation,
   /// e.g. <i> ISO/IEC 13818-1 : 2000 (E) Table 2-30-1 </i> or alternate versions.
   /// </remarks>
{$ENDREGION}
  TTsDescriptionTable = class(TTsTable)
  private
    FReserved             : word;
    FVersionNumber        : byte;
    FCurrentNextIndicator : boolean;
    FSectionNumber        : byte;
    FLastSectionNumber    : byte;
    FDescriptors          : TDescriptors;
    FCrc                  : cardinal;
  public
    constructor Create();  overload;
    constructor Create(const aTsPacket : TTsPacket); overload;
    destructor Destroy; override;

    function Deserialize(const aTsPacket : TTsPacket): boolean; override;
    function Dump(): string;

    property VersionNumber: byte read FVersionNumber;
    property CurrentNextIndicator: boolean read FCurrentNextIndicator;
    property SectionNumber: byte read FSectionNumber;
    property LastSectionNumber: byte read FLastSectionNumber;
    property Descriptors : TDescriptors read FDescriptors;
    property Crc: cardinal read FCrc;
  end;

implementation

//
constructor TTsDescriptionTable.Create();
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;
end;

constructor TTsDescriptionTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;

  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse packet');
end;

destructor TTsDescriptionTable.Destroy;
begin
  FreeAndNil(Self.FDescriptors);
  inherited Destroy;
end;

{$REGION 'DUMP'}
function TTsDescriptionTable.Dump(): string;
var
  lDescriptor : TBaseDescriptor;
begin
  result := Format('*** BEGIN - %s' + #13#10, [Self.Description]);
  for lDescriptor in Self.Descriptors do
  begin
    result := result + Format('      Descriptor: %s', [lDescriptor.Name]);
    if lDescriptor is TCADescriptor then
      result := result + Format('      SystemID=%d (0x%04x), PID=%d (0x%04x)', [(lDescriptor as TCADescriptor).SystemID, (lDescriptor as TCADescriptor).SystemID, (lDescriptor as TCADescriptor).Pid, (lDescriptor as TCADescriptor).Pid]) + #13#10;
  end;
  result := result + Format('  CRC = 0x%08x', [Self.FCrc]) + #13#10;
  result := result + Format('*** END - %s', [Self.Description]);
end;
{$ENDREGION}

function TTsDescriptionTable.Deserialize(const aTsPacket : TTsPacket): boolean;
var
  lCurPos                 : integer;
  lStartDescriptors       : integer;
  lDescriptorsLength      : integer;
  lCrcPos                 : integer;
begin
  result := false;
  if not inherited Deserialize(aTsPacket) then
    exit;

  lCurPos := 1;

  Self.FReserved := word((aTsPacket.Payload[lCurPos + 3] shl 8) + aTsPacket.Payload[lCurPos + 4]);
  Self.FCurrentNextIndicator := (aTsPacket.Payload[lCurPos + 5] and $01) <> 0;
  Self.FVersionNumber := byte((aTsPacket.Payload[lCurPos + 5] and $3E) shr 1);
  Self.FSectionNumber := aTsPacket.Payload[lCurPos + 6];
  Self.FLastSectionNumber := aTsPacket.Payload[lCurPos + 7];

  // Get descriptors
  lStartDescriptors := lCurPos + 8;
  lDescriptorsLength := Self.SectionLength - lStartDescriptors;
  Self.Descriptors.AddFromBuffer(aTsPacket.Payload, lDescriptorsLength, lStartDescriptors);

  // crc
  lCrcPos := (lCurPos + 3) + (Self.SectionLength - 4);
  Self.FCrc := cardinal((((aTsPacket.Payload[lCrcPos]) shl 24) + (aTsPacket.Payload[lCrcPos + 1] shl 16) + (aTsPacket.Payload[lCrcPos + 2] shl 8) + (aTsPacket.Payload[lCrcPos + 3])));

  result := true;

  if assigned(Self.OnChange) then
    Self.OnChange(Self);
end;



end.
