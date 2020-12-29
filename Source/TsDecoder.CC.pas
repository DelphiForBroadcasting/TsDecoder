unit TsDecoder.CC;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  // Continuty Counter
  TTsContinutyCounter = class
  public type
    TContinutyError = reference to procedure(const Sender:TObject; const Pid: Integer; const CC: Integer; const NewCC: Integer);
  private
    FPid    : Integer;
    FCC     : Integer;
    FOnContinutyError : TTsContinutyCounter.TContinutyError;
    procedure SetCC(const AValue: Integer);
  public
    constructor Create(const APid: Integer; const FCC: Integer); overload;
    property Pid: Integer read FPid;
    property CC: Integer read FCC write SetCC;
    property OnContinutyError: TTsContinutyCounter.TContinutyError read FOnContinutyError write FOnContinutyError;
  end;

type
  TTsContinutyCounters = class(TObjectList<TTsContinutyCounter>)
  private
    FLock : TObject;
    FOnContinutyError : TTsContinutyCounter.TContinutyError;

    procedure DoNotifyChange(Sender: TObject; const Item: TTsContinutyCounter; Action: TCollectionNotification);
    function TrySetCC(const APid: Integer; const ACC: Integer): boolean;
  public
    constructor Create(); overload;
    destructor Destroy; override;

    procedure AddOrSetCC(const APid: Integer; const ACC: Integer);
    function ContainsPid(const APid: Integer): Boolean;

    property OnContinutyError: TTsContinutyCounter.TContinutyError read FOnContinutyError write FOnContinutyError;
  end;

implementation

//
constructor TTsContinutyCounter.Create(const APid: Integer; const FCC: Integer);
begin
  inherited Create;
  Self.FPid := APid;
  Self.FCC := FCC;
end;

procedure TTsContinutyCounter.SetCC(const AValue: Integer);
begin
  if((AValue - Self.FCC <> 1) and (abs(AValue - Self.FCC) <> 15)) then
    if assigned(Self.FOnContinutyError) then
      Self.FOnContinutyError(Self, FPid, FCC, AValue);
  Self.FCC := AValue;
end;
//
constructor TTsContinutyCounters.Create();
begin
  inherited Create;
  FLock := TObject.Create;
  Self.OnNotify := DoNotifyChange;
end;

destructor TTsContinutyCounters.Destroy;
begin
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TTsContinutyCounters.DoNotifyChange(Sender: TObject; const Item: TTsContinutyCounter; Action: TCollectionNotification);
begin
  ;
end;

function TTsContinutyCounters.TrySetCC(const APid: Integer; const ACC: Integer): boolean;
var
  I : Integer;
begin
  result := false;
  TMonitor.Enter(FLock);
  try
    for I := 0 to Self.Count - 1 do
    begin
      if Items[i].Pid = APid then
      begin
        Items[i].SetCC(ACC);
        result := true;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TTsContinutyCounters.AddOrSetCC(const APid: Integer; const ACC: Integer);
var
  lTsContinutyCounter : TTsContinutyCounter;
begin
  if TrySetCC(APid, ACC) then
    exit;

  TMonitor.Enter(FLock);
  try
    lTsContinutyCounter := TTsContinutyCounter.Create(APid, ACC);
    lTsContinutyCounter.OnContinutyError :=  procedure(const Sender:TObject; const Pid: Integer; const CC: Integer; const NewCC: Integer)
    begin
      if assigned(FOnContinutyError) then
        FOnContinutyError(Self, Pid, CC, NewCC);
    end;
    Self.Add(lTsContinutyCounter);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TTsContinutyCounters.ContainsPid(const APid: Integer): Boolean;
var
  I : Integer;
begin
  result := false;
  TMonitor.Enter(FLock);
  try
    for I := 0 to Self.Count - 1 do
    begin
      if Items[i].Pid = APid then
      begin
        result := true;
        exit;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;


end.
