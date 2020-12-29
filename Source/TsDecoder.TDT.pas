unit TsDecoder.TDT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.DateUtils,
  TsDecoder.Descriptor,
  TsDecoder.EsInfo,
  TsDecoder.Packet,
  TsDecoder.Tables;

type
  TBCD = record
    // Check if a byte is a valid Binary Coded Decimal (BCD) value.
    // @param [in] b A byte containing a BCD-encoded value.
    // @return True if the value is valid BCDn false otherwise.
    class function IsValid(b: Byte): boolean; static;

    // Return the decimal value of a Binary Coded Decimal (BCD) encoded byte.
    // @param [in] b A byte containing a BCD-encoded value.
    // @return The decoded value in the range 0 to 99.
    class function Decode(b: Byte): Integer; static;

    class function Encode(Value: Integer): Byte; static;
  end;

  TMJD = record
    class function TryEncode(const DateTime: TDateTime; out Mjd: Word; out BcdHour: Byte; out BcdMinute: Byte; out BcdSecond: Byte): Boolean; static;
    class function TryDecode(const Mjd: Word; const BcdHour: Byte; const BcdMinute: Byte; const BcdSecond: Byte; out DateTime: TDateTime; const MJD_SIZE: Integer = 5): Boolean; static;
  end;

{$REGION 'Time Date Section'}
(**
  * The TDT (see table 8) carries only the UTC-time and date information.
  * The TDT shall consist of a single section using the syntax of table 8. This TDT section shall be transmitted in TS
  * packets with a PID value of 0x0014, and the table_id shall take the value 0x70.
  * Table 8: Time and date section
  * Syntax No. of
  * bits
  * Identifier
  * time_date_section(){
  * table_id 8 uimsbf
  * section_syntax_indicator 1 bslbf
  * reserved_future_use 1 bslbf
  * reserved 2 bslbf
  * section_length 12 uimsbf
  * UTC_time 40 bslbf
  * }
  * Semantics for the time and date section:
  * table_id: See table 2.
  * section_syntax_indicator: This is a one-bit indicator which shall be set to "0".
  * section_length: This is a 12-bit field, the first two bits of which shall be "00". It specifies the number of bytes of the
  * section, starting immediately following the section_length field and up to the end of the section.
  * UTC_time: This 40-bit field contains the current time and date in UTC and MJD (see annex C). This field is coded as
  * 16 bits giving the 16 LSBs of MJD followed by 24 bits coded as 6 digits in 4-bit BCD.
  * EXAMPLE: 93/10/13 12:45:00 is coded as "0xC079124500".
***)
{$ENDREGION}
  TTimeDateTable = class(TTsTable)
  private const
    // Size in bytes of an encoded complete Modified Julian Date (MJD).
    MJD_SIZE = 5;
    // Minimal size in bytes of an encoded Modified Julian Date (MJD), ie. date only.
    MJD_MIN_SIZE = 2;
  private
    // UTC_time: This 40-bit field contains the current time and date in UTC and MJD (see annex C). This field is coded as
    // 16 bits giving the 16 LSBs of MJD followed by 24 bits coded as 6 digits in 4-bit BCD.
    // EXAMPLE: 93/10/13 12:45:00 is coded as "0xC079124500".
    FDateTime : TDateTime;
  public
    constructor Create();  overload;
    constructor Create(const aTsPacket : TTsPacket); overload;
    class function Parse(const aTsPacket : TTsPacket): TDateTime; static;
    destructor Destroy; override;

    function Deserialize(const aTsPacket : TTsPacket): boolean; override;
    function Serialize(): TBytes;  override;
    function Dump(): string;

    property DateTime: TDateTime read FDateTime;
  end;

implementation

class function TBCD.IsValid(b: Byte): boolean;
begin
  result := (((b and $F0) < $A0) and ((b and $0F) < $0A));
end;

//!
//! Return the decimal value of a Binary Coded Decimal (BCD) encoded byte.
//! @param [in] b A byte containing a BCD-encoded value.
//! @return The decoded value in the range 0 to 99.
//!
class function TBCD.Decode(b: Byte): Integer;
begin
  result:= 10 * ((b and $f0) shr 4) + (b and $0F);
end;

class function TBCD.Encode(Value: Integer): Byte;
begin
  result:= ((Value div 10) shl 4) or (Value mod 10);
end;

//
class function TTimeDateTable.Parse(const aTsPacket : TTsPacket): TDateTime;
var
  lTimeDateTable : TTimeDateTable;
begin
  lTimeDateTable := TTimeDateTable.Create();
  try
    lTimeDateTable.Deserialize(aTsPacket);
    result := lTimeDateTable.DateTime;
  finally
    FreeAndNil(lTimeDateTable);
  end;
end;


constructor TTimeDateTable.Create();
begin
  inherited Create;
  FDateTime := System.DateUtils.EpochAsJulianDate;
end;

constructor TTimeDateTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create;
  FDateTime := System.DateUtils.EpochAsJulianDate;
  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse packet');
end;

destructor TTimeDateTable.Destroy;
begin
  inherited Destroy;
end;

{$REGION 'DUMP'}
function TTimeDateTable.Dump(): string;
begin
  result := Format('*** BEGIN - %s' + #13#10, [Self.Description]);
  result := result + Format('       date: %s', [DateToStr(FDateTime)]) + #13#10;
  result := result + Format('       time: %s', [TimeToStr(FDateTime)]) + #13#10;
  result := result + Format('*** END - %s', [Self.Description]);
end;
{$ENDREGION}


class function TMJD.TryEncode(const DateTime: TDateTime; out Mjd: Word; out BcdHour: Byte; out BcdMinute: Byte; out BcdSecond: Byte): Boolean;
var
  lDay              : Word;
  lMonth            : Word;
  lYear             : Word;
  lHour             : Word;
  lMinute           : Word;
  lSecond           : Word;
  lMilliSecond      : Word;
begin
  result := false;
  try
    DecodeDate(DateTime, lYear, lMonth, lDay);
    Mjd := Trunc(((1461 * (lYear + 4800 + (lMonth - 14) div 12)) div 4 + (367 * (lMonth - 2 - 12 * ((lMonth - 14) div 12))) div 12 - (3 * ((lYear + 4900 + (lMonth - 14) div 12) div 100)) div 4 + lDay - 32075.5 + Abs(Frac(DateTime))) - 2400000.5);

    DecodeTime(DateTime, lHour, lMinute, lSecond, lMilliSecond);
    BcdHour := TBCD.Encode(lHour);
    BcdMinute := TBCD.Encode(BcdMinute);
    BcdSecond := TBCD.Encode(BcdSecond);
    result := true;
  except  end;
end;

class function TMJD.TryDecode(const Mjd: Word; const BcdHour: Byte; const BcdMinute: Byte; const BcdSecond: Byte; out DateTime: TDateTime; const MJD_SIZE: Integer = 5): Boolean;
var
  lValid            : Boolean;
  L                 : Integer;
  N                 : Integer;
  lDay              : Word;
  lMonth            : Word;
  lYear             : Word;
  lHour             : Word;
  lMinute           : Word;
  lSecond           : Word;
begin
  lHour := 0;
  lMinute := 0;
  lSecond := 0;
  lDay := Swap(Mjd);
  lValid:= lDay <> $FFFF; // Often used as invalid date.

  L := Trunc(lDay + 2400000.5) + 68570;
  N := 4 * L div 146097;
  L := L - (146097 * N + 3) div 4;
  LYear := 4000 * (L + 1) div 1461001;
  L := L - 1461 * LYear div 4 + 31;
  LMonth := 80 * L div 2447;
  LDay := L - 2447 * LMonth div 80;
  L := LMonth div 11;
  LMonth := LMonth + 2 - 12 * L;
  LYear := 100 * (N - 49) + LYear + L;

  if ((MJD_SIZE >= 3) and lValid) then
  begin
    lValid := TBCD.IsValid(BcdHour);
    lHour := TBCD.Decode(BcdHour); // Hours
  end;

  if ((MJD_SIZE >= 4) and lValid) then
  begin
    lValid := TBCD.IsValid(BcdMinute);
    lMinute := TBCD.Decode(BcdMinute); // Minutes
  end;

  if ((MJD_SIZE >= 5) and lValid) then
  begin
    lValid := TBCD.IsValid(BcdSecond);
    lSecond := TBCD.Decode(BcdSecond); // Seconds
  end;

  result := TryEncodeDateTime(lYear, lMonth, lDay, lHour, lMinute, lSecond, 0, DateTime);

end;


function TTimeDateTable.Deserialize(const aTsPacket : TTsPacket): boolean;
var
  lCurPos         : integer;
begin
  result := false;
  if not inherited Deserialize(aTsPacket) then
    exit;

  lCurPos := 1;

  if ((Self.SectionLength < MJD_MIN_SIZE) or (Self.SectionLength > MJD_SIZE)) then
    exit;

  result := TMJD.TryDecode(PWord(@aTsPacket.Payload[lCurPos + 3])^, aTsPacket.Payload[lCurPos + 5], aTsPacket.Payload[lCurPos + 6], aTsPacket.Payload[lCurPos + 7], Self.FDateTime);

  if assigned(Self.OnChange) then
    Self.OnChange(Self);
end;

function TTimeDateTable.Serialize(): TBytes;
var
  lPacket : TBytes;
begin
  lPacket := inherited Serialize();
  SetLength(lPacket, 188);
  FillChar(lPacket, 188, #0);
end;



end.
