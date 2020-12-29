unit TsDecoder.Tables;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Descriptor,
  TsDecoder.Packet;

type
  TTsTable = class
  type
      TOnTableChange = reference to procedure(TsTable: TTsTable);
  private
    FTsPacket       : TTsPacket;
    FPid            : smallInt;
    FPointerField   : byte;
    FTableId        : byte;
    FSectionLength  : SmallInt;

    FOnTableChange  : TTsTable.TOnTableChange;

    function GetPidDescription(): string;
  public
    constructor Create();  overload;
    constructor Create(const aTsPacket : TTsPacket); overload;
    destructor Destroy; override;

    function Deserialize(const aTsPacket : TTsPacket): boolean; virtual;
    function Serialize(): TBytes; virtual;

    property Pid: smallInt read FPid;
    property PointerField: byte read FPointerField;
    property TableId: byte read FTableId;
    property SectionLength: SmallInt read FSectionLength;
    property Description: string read GetPidDescription;

    property  OnChange: TTsTable.TOnTableChange read FOnTableChange write FOnTableChange;
  end;



implementation

constructor TTsTable.Create();
begin
  inherited Create;
  Self.FPid            := -1;
  Self.FTableId        := 0;
  Self.FSectionLength  := 0;
end;

constructor TTsTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create;

  Self.FPid            := -1;
  Self.FTableId        := 0;
  Self.FSectionLength  := 0;

  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse packet');
end;

destructor TTsTable.Destroy;
begin
  inherited Destroy;
end;

function TTsTable.GetPidDescription(): string;
begin
  result := '';
  try
    case TPidType(FPid) of
      TPidType.PAT_PID: result := 'Program Association Table (PAT)';
      TPidType.CAT_PID: result := 'Conditional Access Table (CAT)';
      TPidType.TSDT_PID: result := 'Transport Stream Description (TSDT)';
      TPidType.NIT_PID: result := 'Network Information Table (NIT)';
      TPidType.SDT_PID: result := 'Service Description Table (SDT)';
      TPidType.TDT_PID: result := 'Time Date Table (TDTs)';
    end;
  except  end;
end;

function TTsTable.Deserialize(const aTsPacket : TTsPacket): boolean;
begin
  Self.FTsPacket := aTsPacket;
  result := false;

  if Self.FPid = aTsPacket.Pid then
    exit;

  if ((Self.FPid <> aTsPacket.Pid) and (Self.FPid <> -1)) then
    raise Exception.Create('TableFactory cannot have mixed PIDs added after startup');

  Self.FPid := aTsPacket.Pid;

  if not aTsPacket.PayloadUnitStartIndicator then
    raise Exception.Create('Error Not PayloadUnitStartIndicator');


  Self.FPointerField := aTsPacket.Payload[0];
  Self.FTableId := aTsPacket.Payload[1];
  Self.FSectionLength := SmallInt(((aTsPacket.Payload[2] and $03) shl 8) + aTsPacket.Payload[3]);

  result := true;
end;

function TTsTable.Serialize(): TBytes;
var
  lPacket : TBytes;
begin
  SetLength(lPacket, TTsPacket.PKT_SIZE);
  FillChar(lPacket, Length(lPacket), #0);

  //TTsPacket.Serialize<TTsTable>(Self)
end;



end.
