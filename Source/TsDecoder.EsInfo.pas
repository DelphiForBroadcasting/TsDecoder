unit TsDecoder.EsInfo;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Descriptor;

type
  TStreamType = record
  private
    FStreamType : byte;
    function GetStreamId(): string;
  public
    class function Create(const aStreamId: byte): TStreamType; static;
    class function StreamIdToString(aStreamId : integer): string; static;
    property asInt : byte read FStreamType;
    property asString: string read GetStreamId;
  end;

type
  TEsInfo = class
  private
    FStreamType: TStreamType;
    FElementaryPid: smallInt;
    FLength: word;
    FDescriptors: TDescriptors;
    FData : TArray<byte>;
  public
    constructor Create();  overload;
    destructor Destroy; override;
    function WriteData(const aData : TArray<byte>; const aLength: integer; const aOffset: integer): integer;

    property StreamType: TStreamType read FStreamType write FStreamType;
    property ElementaryPid: smallInt read FElementaryPid write FElementaryPid;
    property Length: word read FLength write FLength;
    property Descriptors: TDescriptors read FDescriptors;
    property Data: TArray<byte> read FData;
  end;

  TEsInfoList = class(TObjectList<TEsInfo>)
  private

  public
    constructor Create(); overload;
    destructor Destroy; override;

    function AddFromBuffer(const aData : TArray<byte>; const aSectionLength: integer; const aOffset: integer): integer;

    // By Pid
    function ContainsPid(const ElementaryPid: SmallInt): boolean;
    function IndexOfPid(const ElementaryPid: SmallInt): integer;
    function TryGetByPid(const ElementaryPid: SmallInt; var EsInfo: TEsInfo): boolean;
  end;

implementation


class function TStreamType.Create(const aStreamId: byte): TStreamType;
begin
  result.FStreamType := aStreamId;
end;

function TStreamType.GetStreamId(): string;
begin
  result := TStreamType.StreamIdToString(FStreamType);
end;

class function TStreamType.StreamIdToString(aStreamId : integer): string;
begin
  result := '';
  case aStreamId of
    $0000: result := 'reserved';
    $0001: result := 'ISO/IEC 11172-2 (MPEG-1 Video)';
    $0002: result := 'ISO/IEC 13818-2 (MPEG-2 Video)';
    $0003: result := 'ISO/IEC 11172-3 (MPEG-1 Audio)';
    $0004: result := 'ISO/IEC 13818-3 (MPEG-2 Audio)';
    $0005: result := 'ISO/IEC 13818-1 (private section)';
    $0006: result := 'ISO/IEC 13818-1 PES';
    $0007: result := 'ISO/IEC 13522 MHEG';
    $0008: result := 'ITU-T H.222.0 annex A DSM-CC';
    $0009: result := 'ITU-T H.222.1';
    $000a: result := 'ISO/IEC 13818-6 DSM-CC type A';
    $000b: result := 'ISO/IEC 13818-6 DSM-CC type B';
    $000c: result := 'ISO/IEC 13818-6 DSM-CC type C';
    $000d: result := 'ISO/IEC 13818-6 DSM-CC type D';
    $000e: result := 'ISO/IEC 13818-1 (auxiliary)';
    $000f: result := 'ISO/IEC 13818-7 (AAC Audio)';
    $0010: result := 'ISO/IEC 14496-2 (MPEG-4 Video)';
    $0011: result := 'ISO/IEC 14496-3 (AAC LATM Audio)';
    $001b: result := 'ITU-T H.264 (h264 Video)';
    $00ea: result := '(VC-1 Video)';
    $00d1: result := '(DIRAC Video)';
    $0081: result := '(AC3 Audio)';
    $008a: result := '(DTS Audio)';
    $00bd: result := '(non-MPEG Audio, subpictures)';
    $00be: result := '(padding stream)';
    $00bf: result := '(navigation data)';
    else
    begin
      if ((aStreamId >= $c0) and (aStreamId <= $df)) then
        result := '(AUDIO stream)'
      else if ((aStreamId >= $e0) and (aStreamId <= $ef)) then
        result := '(VIDEO stream)';
    end;
  end;
end;


//
constructor TEsInfoList.Create();
begin
  inherited Create;
end;

destructor TEsInfoList.Destroy;
begin
  inherited Destroy;
end;

function TEsInfoList.AddFromBuffer(const aData : TArray<byte>; const aSectionLength: integer; const aOffset: integer): integer;
var
  lOffset : integer;
  lEsInfo : TEsInfo;
begin
  lOffset := aOffset;
  // read ES Info
  while (lOffset < aSectionLength) do
  begin
    lEsInfo := TEsInfo.Create();
    try
      lEsInfo.StreamType := TStreamType.Create(aData[lOffset]);
      lEsInfo.ElementaryPid := smallInt(((aData[lOffset + 1] and $1f) shl 8) + aData[lOffset + 2]);
      lEsInfo.Length := word(((aData[lOffset + 3] and $03) shl 8) + aData[lOffset + 4]);
      lEsInfo.WriteData(aData, 5 + lEsInfo.Length, lOffset + 3);
      lOffset:= lOffset + 5;
   //   if ((lEsInfo.StreamType.asInt = 6) and (lEsInfo.ElementaryPid = 2622)) then
   //   lOffset := lOffset;

      // Get descriptors
      lOffset := lEsInfo.Descriptors.AddFromBuffer(aData, lEsInfo.Length, lOffset);
    finally
        Self.Add(lEsInfo)
    end;
  end;
  result := lOffset
end;

function TEsInfoList.ContainsPid(const ElementaryPid: SmallInt): boolean;
var
  i  : integer;
begin
  result := false;
  for I := 0 to Self.Count - 1 do
  begin
    if Self.Items[i].ElementaryPid = ElementaryPid then
    begin
      result := true;
      break;
    end;
  end;
end;

function TEsInfoList.IndexOfPid(const ElementaryPid: SmallInt): integer;
var
  i  : integer;
begin
  result := -1;
  for I := 0 to Self.Count - 1 do
  begin
    if Self.Items[i].ElementaryPid = ElementaryPid then
    begin
      result := i;
      break;
    end;
  end;
end;

function TEsInfoList.TryGetByPid(const ElementaryPid: SmallInt; var EsInfo: TEsInfo): boolean;
var
  lIndex : integer;
begin
  result := false;
  EsInfo := nil;
  lIndex := Self.IndexOfPid(ElementaryPid);
  if ((lIndex >= 0) and (lIndex < Self.Count)) then
  begin
    EsInfo := Self.Items[lIndex];
    result := true;
  end;
end;

//
constructor TEsInfo.Create();
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;
end;

destructor TEsInfo.Destroy;
begin
  FreeAndNil(Self.FDescriptors);
  inherited Destroy;
end;

function TEsInfo.WriteData(const aData : TArray<byte>; const aLength: integer; const aOffset: integer): integer;
begin
  SetLength(Self.FData, aLength);
  Move(aData[aOffset], Self.FData[0], aLength);
  result := aLength;
end;

end.
