unit TsDecoder.CAT;

interface

uses
  System.SysUtils, System.Generics.Collections,
  TsDecoder.Descriptor,
  TsDecoder.EsInfo,
  TsDecoder.Packet,
  TsDecoder.Tables;

(*

CA ID	    Name	    Developed by	      Introduced (year)	        Security	      Notes
0x4AEB	Abel Quintic	Abel DRM Systems	2009	Secure
0x4AF0	ABV CAS	ABV International Pte. Ltd	2006	Secure (Farncombe Certified)	CA,DRM,Middleware & Turnkey Solution Provider For DTH, DVBT/T2, DVBC, OTT, IPTV, VOD,Catchup TV, Audience Measurement System, EAD etc.
0x4AFC	Panaccess	Panaccess Systems GmbH	2010	Secure (Farncombe Certified)	CA for DVB-S/S2, DVB-T/T2, DVB-C, DVB-IP, OTT, VOD, Catchup etc.
0x4B19	RCAS or RIDSYS cas	RIDSYS, INDIA	2012	Secure
0x4B30, 0x4B31	ViCAS	Vietnam Multimedia Corporation (VTC)	Unknown	Secure (Farncombe Certified)
0x4800	Accessgate	Telemann	Unknown
0x4A20	AlphaCrypt	AlphaCrypt	Unknown
N/A	B-CAS ARIB STD-B25 (Multi-2)	Association of Radio Industries and Businesses (ARIB)	2000		CA for ISDB. Used in Japan only
0x1702, 0x1722, 0x1762	reserved for various non-BetaResearch CA systems	Formally owned by BetaTechnik/Beta Research (subsidiary of KirchMedia). Handed over to TV operators to handle with their CA systems.	Unknown
0x1700 – 0x1701, 0x1703 – 0x1721, 0x1723 – 0x1761, 0x1763 – 0x17ff, 0x5601 – 0x5604	VCAS DVB	Verimatrix Inc.	Unknown
0x2600	BISS	European Broadcasting Union	Unknown	Compromised
0x4900	China Crypt	CrytoWorks (China) (Irdeto)	Unknown
0x22F0	Codicrypt	Scopus Network Technologies (now part of Harmonic)	Unknown	Secure
0x4AEA	Cryptoguard	Cryptoguard AB	2008	Secure
0x0B00	Conax Contego	Conax AS	Unknown	Secure
0x0B00	Conax CAS 5	Conax AS	Unknown	Compromised	Pirate cards has existed
0x0B00	Conax CAS 7.5	Conax AS	Unknown	Secure
0x0B00, 0x0B01, 0x0B02, 0x0BAA	Conax CAS 7	Conax AS	Unknown	Compromised	Cardsharing
0x0B01, 0x0B02, 0x0B03, 0x0B04, 0x0B05, 0x0B06, 0x0B07	Conax CAS 3	Conax AS	Unknown	Compromised	Pirate cards has existed
0x4AE4	CoreCrypt	CoreTrust(Korea)	2000	S/W & H/W Security	CA for IPTV, Satellite, Cable TV and Mobile TV
0x4347	CryptOn	CryptOn	Unknown
0x0D00, 0x0D02, 0x0D03, 0x0D05, 0x0D07, 0x0D20	Cryptoworks	Philips CryptoTec	Unknown	Partly compromised (older smartcards)
0x4ABF	CTI-CAS	Beijing Compunicate Technology Inc.	Unknown
0x0700	DigiCipher 2	Jerrold/GI/Motorola 4DTV	1997	Compromised	DVB-S2 compatible, used for retail BUD dish service and for commercial operations as source programming for cable operators.
Despite the Programming Center shut down its consumer usage of DigiCipher 2 (as 4DTV) on August 24, 2016, it is still being used for cable headends across the United States, as well as on Shaw Direct in Canada.

0x4A70	DreamCrypt	Dream Multimedia	2004		Proposed conditional access system used for Dreambox receivers.
0x4A10	EasyCas	Easycas	Unknown
0x2719,0xEAD0	InCrypt Cas	S-Curious Research & Technology Pvt. Ltd., Equality Consultancy Services	Unknown
0x0464	EuroDec	Eurodec	Unknown
0x5448	Gospell VisionCrypt	GOSPELL DIGITAL TECHNOLOGY CO., LTD.	Unknown	Secure
0x5501	Griffin	Nucleus Systems, Ltd.	Unknown
0x5581	Bulcrypt	Bulcrypt	2009		Used in Bulgaria and Serbia
0x0606	Irdeto 1	Irdeto	1995	Compromised
0x0602, 0x0604, 0x0606, 0x0608, 0x0622, 0x0626, 0x0664, 0x0614	Irdeto 2	Irdeto	2000
0x0692	Irdeto 3	Irdeto	2010	Secure
0x4AA1	KeyFly	SIDSA	Unknown	Partly compromised (v. 1.0)
0x0100	Seca Mediaguard 1	SECA	Unknown	Compromised
0x0100	Seca Mediaguard 2 (v1+)	SECA	Unknown	Partly compromised (MOSC available)
0x0100	Seca Mediaguard 3	SECA	2008
0x1800, 0x1801, 0x1810, 0x1830	Nagravision	Nagravision	2003	Compromised
0x1801	Nagravision Carmageddon	Nagravision	Unknown	Combination of Nagravision with BetaCrypt
0x1702, 0x1722, 0x1762, 0x1801	Nagravision Aladin	Nagravision	Unknown
0x1801	Nagravision 3 - Merlin	Nagravision	2007	Secure
0x1801	Nagravision - ELK	Nagravision	Circa 2008	IPTV
0x4A02	Tongfang	Tsinghua Tongfang Company	Unknown	Secure
0x4AD4	OmniCrypt	Widevine Technologies	2004
0x0E00	PowerVu	Scientific Atlanta	1998	Compromised	Professional system widely used by cable operators for source programming
0x0E00	PowerVu+	Scientific Atlanta	Unknown
0x1000	RAS (Remote Authorisation System)	Tandberg Television	Unknown		Professional system, not intended for consumers.
0x4AC1	Latens Systems	Latens	2002
0xA101	RosCrypt-M	NIIR	2006
0x4A60, 0x4A61, 0x4A63	SkyCrypt/Neotioncrypt/Neotion SHL	AtSky/Neotion[1]	2003
Unknown	T-crypt	Tecsys	Unknown
0x4A80	ThalesCrypt	Thales Broadcast & Multimedia[2]	Unknown		Viaccess modification. Was developed after TPS-Crypt was compromised.[3]
0x0500	TPS-Crypt	France Telecom	Unknown	Compromised	Viaccess modification used with Viaccess 2.3
0x0500	Viaccess PC2.3, or Viaccess 1	France Telecom	Unknown
0x0500	Viaccess PC2.4, or Viaccess 2	France Telecom	2002
0x0500	Viaccess PC2.5, or Viaccess 2	France Telecom	Unknown
0x0500	Viaccess PC2.6, or Viaccess 3	France Telecom	2005
0x0500	Viaccess PC3.0	France Telecom	Unknown
0x0500	Viaccess PC4.0	France Telecom	2008
Unknown	Viaccess PC5.0	France Telecom	2011	Secure
Unknown	Viaccess PC6.0	France Telecom	Unknown
0x0930, 0x0942	Cisco VideoGuard 1	NDS (now part of Cisco)	1994	Partly compromised (older smartcards)
0x0911, 0x0960	Cisco VideoGuard 2	NDS (now part of Cisco)	1999	Secure
0x0919, 0x0961, 0x09AC	Cisco VideoGuard 3	NDS (now part of Cisco)	2004	Secure
0x0927, 0x0963, 0x093b, 0x09CD	Cisco VideoGuard 4	NDS (now part of Cisco)	2009	Secure
0x4AD0, 0x4AD1	X-Crypt	XCrypt Inc.		Secure
0x4AE0, 0x4AE1, 0x7be1	DRE-Crypt	Cifra	2004	Secure
Unknown	PHI CAS	RSCRYPTO	2016	Secure

*)

type
{$REGION 'Conditional access Table'}
   /// <summary>
   /// Conditional access Table
   /// </summary>
   /// <remarks>
   /// For details please refer to the original documentation,
   /// e.g. <i> ISO/IEC 13818-1 : 2000 (E) 2.4.4.6</i> or alternate versions.
   /// </remarks>
{$ENDREGION}
  TConditionalAccessTable = class(TTsTable)
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
constructor TConditionalAccessTable.Create();
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;
end;

constructor TConditionalAccessTable.Create(const aTsPacket : TTsPacket);
begin
  inherited Create;
  Self.FDescriptors := TDescriptors.Create;

  if not Deserialize(aTsPacket) then
    raise Exception.Create('Error parse packet');
end;

destructor TConditionalAccessTable.Destroy;
begin
  FreeAndNil(Self.FDescriptors);
  inherited Destroy;
end;

{$REGION 'DUMP'}
function TConditionalAccessTable.Dump(): string;
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

function TConditionalAccessTable.Deserialize(const aTsPacket : TTsPacket): boolean;
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
