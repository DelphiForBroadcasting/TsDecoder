unit TsDecoder.SDT;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Descriptor,
  TsDecoder.EsInfo,
  TsDecoder.Packet,
  TsDecoder.Tables;

type
  TServiceDescriptionItem = class
  private
    FServiceId : word;
    FEitScheduleFlag: boolean;
    FEitPresentFollowingFlag: boolean;
    FRunningStatus: byte;
    FFreeCaMode: boolean;
    FDescriptorsLoopLength: word;
    FDescriptors: TDescriptors;
    FDvbDescriptorTag: byte;
    FDescriptorLength: byte;
  public
    constructor Create();  overload;
    destructor Destroy; override;
    property ServiceId : word read FServiceId write FServiceId;
    property EitScheduleFlag: boolean read FEitScheduleFlag write FEitScheduleFlag;
    property EitPresentFollowingFlag: boolean read FEitPresentFollowingFlag write FEitPresentFollowingFlag;
    property RunningStatus: byte read FRunningStatus write FRunningStatus;
    property FreeCaMode: boolean read FFreeCaMode write FFreeCaMode;
    property DescriptorsLoopLength: word read FDescriptorsLoopLength write FDescriptorsLoopLength;
    property Descriptors: TDescriptors read FDescriptors;
    property DvbDescriptorTag: byte read FDvbDescriptorTag write FDvbDescriptorTag;
    property DescriptorLength: byte read FDescriptorLength write FDescriptorLength;
  end;

  TServiceDescriptionItems = class(TObjectList<TServiceDescriptionItem>)
  private

  public

  end;

{$REGION 'Service Description section'}

{$ENDREGION}
  TServiceDescriptionTable = class(TTsTable)
  private
    FTransportStreamId : word;
    FVersionNumber: byte;
    FCurrentNextIndicator: boolean;
    FSectionNumber: byte;
    FLastSectionNumber: byte;
    FOriginalNetworkId: word;
    FServiceDescriptions : TServiceDescriptionItems;
    FCrc: cardinal;
  public
    constructor Create();  overload;
    constructor Create(const aTsPacket : TTsPacket); overload;
    destructor Destroy; override;

    function Deserialize(const aTsPacket : TTsPacket): boolean; override;
    function Dump(): string;

    property TransportStreamId: word read FTransportStreamId;
    property VersionNumber: byte read FVersionNumber;
    property CurrentNextIndicator: boolean read FCurrentNextIndicator;
    property SectionNumber: byte read FSectionNumber;
    property LastSectionNumber: byte read FLastSectionNumber;
    property OriginalNetworkId: word read FOriginalNetworkId;
    property ServiceDescription : TServiceDescriptionItems read FServiceDescriptions;
    property Crc: cardinal read FCrc;
  end;

implementation

//
constructor TServiceDescriptionItem.Create();
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;
end;

destructor TServiceDescriptionItem.Destroy;
begin
  FreeAndNil(Self.FDescriptors);
  inherited Destroy;
end;

//
constructor TServiceDescriptionTable.Create();
begin
  inherited Create;
  Self.FServiceDescriptions := TServiceDescriptionItems.Create;
end;

constructor TServiceDescriptionTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create;
  Self.FServiceDescriptions := TServiceDescriptionItems.Create;

  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse packet');
end;

destructor TServiceDescriptionTable.Destroy;
begin
  FreeAndNil(Self.FServiceDescriptions);
  inherited Destroy;
end;

{$REGION 'DUMP'}
function TServiceDescriptionTable.Dump(): string;
var
  i : integer;
  lDescriptor : TBaseDescriptor;
begin
  result := Format('*** BEGIN - %s' + #13#10, [Self.Description]);
  result := result + Format('       OriginalNetworkId=0x%04x(%d), TransportStreamId=0x%04x(%d)', [Self.OriginalNetworkId, Self.OriginalNetworkId, Self.TransportStreamId, Self.TransportStreamId]) + #13#10;

  for I := 0 to Self.ServiceDescription.Count - 1 do
  begin
    result := result + Format('      ServiceId=0x%04x(%d)', [Self.ServiceDescription[i].FServiceId, Self.ServiceDescription[i].FServiceId]) + #13#10;
      for lDescriptor in Self.ServiceDescription[i].Descriptors do
      begin
        result := result + Format('      Descriptor: %s', [lDescriptor.Name]);
        if lDescriptor is TServiceDescriptor then
          result := result + Format('      ServiceType=%s, ProviderName=%s, ServiceName=%s,', [(lDescriptor as TServiceDescriptor).ServiceTypeDescription, (lDescriptor as TServiceDescriptor).ServiceProviderName, (lDescriptor as TServiceDescriptor).ServiceName]) + #13#10;
      end;
  end;
  result := result + Format('  CRC = 0x%08x', [Self.FCrc]) + #13#10;
  result := result + Format('*** END - %s', [Self.Description]);
end;
{$ENDREGION}

function TServiceDescriptionTable.Deserialize(const aTsPacket : TTsPacket): boolean;
var
  lCurPos                 : integer;
  startOfNextField        : integer;
  transportStreamLoopEnd  : integer;
  lCrcPos                 : integer;

  lServiceDescriptionItem : TServiceDescriptionItem;
begin
  result := false;
  if not inherited Deserialize(aTsPacket) then
    exit;

  try
    lCurPos := 1;
    Self.FTransportStreamId  := word((aTsPacket.Payload[lCurPos + 3] shl 8) + aTsPacket.Payload[lCurPos + 4]);
    Self.FCurrentNextIndicator := (aTsPacket.Payload[lCurPos + 5] and $01) <> 0;
    Self.FVersionNumber := byte((aTsPacket.Payload[lCurPos + 5] and $3E) shr 1);
    Self.FSectionNumber := aTsPacket.Payload[lCurPos + 6];
    Self.FLastSectionNumber := aTsPacket.Payload[lCurPos + 7];
    Self.FOriginalNetworkId :=  word((aTsPacket.Payload[lCurPos + 8] shl 8) + aTsPacket.Payload[lCurPos + 9]);

    startOfNextField := 12;
    transportStreamLoopEnd := Self.SectionLength - 4;
    while (startOfNextField < transportStreamLoopEnd) do
    begin
      lServiceDescriptionItem := TServiceDescriptionItem.Create;
      try
        lServiceDescriptionItem.ServiceId := word((aTsPacket.Payload[startOfNextField] shl 8) + aTsPacket.Payload[startOfNextField + 1]);
        lServiceDescriptionItem.EitScheduleFlag := ((aTsPacket.Payload[startOfNextField + 2]) and $02) = $02;
        lServiceDescriptionItem.EitPresentFollowingFlag := ((aTsPacket.Payload[startOfNextField + 2]) and $01) = $01;
        lServiceDescriptionItem.RunningStatus := byte((aTsPacket.Payload[startOfNextField + 3] shr 5) and $07);
        lServiceDescriptionItem.FreeCaMode := (aTsPacket.Payload[startOfNextField + 3] and $10) = $10;
        lServiceDescriptionItem.DescriptorsLoopLength := word(((aTsPacket.Payload[startOfNextField + 3] and $f) shl 8) + aTsPacket.Payload[startOfNextField + 4]);
        // Get descriptors
        startOfNextField := lServiceDescriptionItem.Descriptors.AddFromBuffer(aTsPacket.Payload, lServiceDescriptionItem.DescriptorsLoopLength, startOfNextField + 5);
      finally
        Self.FServiceDescriptions.Add(lServiceDescriptionItem);
      end;
    end;

    // crc
    lCrcPos := (lCurPos + 3) + (Self.SectionLength - 4); // offset 3, aProgramMapTable.SectionLength - CRC(4byte)
    Self.FCrc := cardinal((((aTsPacket.Payload[lCrcPos]) shl 24) + (aTsPacket.Payload[lCrcPos + 1] shl 16) + (aTsPacket.Payload[lCrcPos + 2] shl 8) + (aTsPacket.Payload[lCrcPos + 3])));

    result := true;

    if assigned(Self.OnChange) then
      Self.OnChange(Self);
  except end;
end;



end.
