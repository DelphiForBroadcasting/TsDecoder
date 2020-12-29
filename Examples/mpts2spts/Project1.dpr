program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  System.Types,
  System.Diagnostics,
  System.Threading,
  System.RegularExpressions,
  WinApi.WinSock2,

  (* TsDecoder Library *)
  TsDecoder.Descriptor in '..\..\Source\TsDecoder.Descriptor.pas',
  TsDecoder.EsInfo in '..\..\Source\TsDecoder.EsInfo.pas',
  TsDecoder.PMT in '..\..\Source\TsDecoder.PMT.pas',
  TsDecoder.PAT in '..\..\Source\TsDecoder.PAT.pas',
  TsDecoder.SDT in '..\..\Source\TsDecoder.SDT.pas',
  TsDecoder.Packet in '..\..\Source\TsDecoder.Packet.pas',
  TsDecoder.Tables in '..\..\Source\TsDecoder.Tables.pas',
  TsDecoder.CC in '..\..\Source\TsDecoder.CC.pas',
  TsDecoder.TDT in '..\..\Source\TsDecoder.TDT.pas',
  TsDecoder in '..\..\Source\TsDecoder.pas';

// http://www.delphikingdom.com/asp/viewitem.asp?catalogid=1060
{$REGION 'Multicast Client'}
function StringToSockAddr(const AValue: string{udp://239.12.12.32:1234}): TSockAddrIn;
const
  SearchPattern = '^(?:(?P<scheme>[^\:]*)\:\/\/)?\/?((?P<username>.*?)(:(?P<password>.*?)|)@)?(?P<host>[^:\/\s]+)(:(?P<port>[^\/]\d+))?(\?(?P<params>[^#]*))?(#(?P<bookmark>.*))?$';
var
  lRegEx            : TRegEx;
begin
  FillChar(result, SizeOf(result), #0);
  LRegEx := TRegEx.Create(SearchPattern);
  if LRegEx.IsMatch(AValue) then
  begin
    result.sin_family := AF_INET;
    result.sin_port := htons(StrToIntDef(LRegEx.Match(AValue).Groups['port'].Value, 1234));
    result.sin_addr.S_addr := inet_addr(MarshaledAString(TEncoding.UTF8.GetBytes(LRegEx.Match(AValue).Groups['host'].Value)));
  end else
    raise Exception.Create('Error StringToSockAddr');
end;

function SetMulticastInterface(const ASocket: TSocket; const AValue: TSockAddrIn): boolean;
const
  IP_MULTICAST_IF = 9;
var
  OptVal: Cardinal;
begin
  OptVal := AValue.sin_addr.S_addr;
  result := SetSockOpt(ASocket, IPPROTO_IP, IP_MULTICAST_IF, MarshaledAString(@OptVal), SizeOf(OptVal)) = 0;
end;

function SetMulticastLoopBack(const ASocket: TSocket; const AValue: Boolean): boolean;
const
  IP_MULTICAST_LOOP = 11;
var
  OptVal: Integer;
begin
  OptVal := Integer(AValue);
  result := SetSockOpt(ASocket, IPPROTO_IP, IP_MULTICAST_LOOP, MarshaledAString(@OptVal), SizeOf(OptVal)) = 0;
end;

function SetMulticastTtl(const ASocket: TSocket; const AValue: Integer = 1): boolean;
const
  IP_MULTICAST_TTL = 10;
var
  OptVal: Integer;
begin
  OptVal := AValue;
  result := SetSockOpt(ASocket, IPPROTO_IP, IP_MULTICAST_TTL, MarshaledAString(@OptVal), SizeOf(OptVal)) = 0;
end;

function SetReuseAddr(const ASocket: TSocket; const AValue: Boolean): boolean;
var
  OptVal: Integer;
begin
  OptVal := Integer(AValue);
  result := SetSockOpt(ASocket, SOL_SOCKET, SO_REUSEADDR, MarshaledAString(@OptVal), SizeOf(OptVal)) = 0;
end;

function SetRecvBuffer(const ASocket: TSocket; const AValue: Integer = 8192): boolean;
var
  OptVal: Integer;
begin
  OptVal := AValue;
  result := SetSockOpt(ASocket, SOL_SOCKET, SO_RCVBUF, MarshaledAString(@OptVal), SizeOf(OptVal)) = 0;
end;

function JoinGroup(const ASocket: TSocket; const AGroupAddr: in_addr; const AIntfAddr: in_addr): boolean;
const
  IP_ADD_MEMBERSHIP = 12;
type
  TIpMreqSource = record
    imr_multiaddr   : in_addr;
    imr_interface   : in_addr;
  end;
var
  imr : TIpMreqSource;
begin
  imr.imr_multiaddr := AGroupAddr;
  imr.imr_interface  := AIntfAddr;
  result := SetSockOpt(ASocket, IPPROTO_IP, IP_ADD_MEMBERSHIP, MarshaledAString(@imr), sizeof(imr)) = 0;
end;

function LeaveGroup(const ASocket: TSocket;  const AGroupAddr: in_addr; const AIntfAddr: in_addr): boolean;
const
  IP_DROP_MEMBERSHIP  = 13;
type
  TIpMreqSource = record
    imr_multiaddr   : in_addr;
    imr_interface   : in_addr;
  end;
var
  imr : TIpMreqSource;
begin
  imr.imr_multiaddr := AGroupAddr;
  imr.imr_interface := AIntfAddr;
  result := SetSockOpt(ASocket, IPPROTO_IP, IP_DROP_MEMBERSHIP, MarshaledAString(@imr), sizeof(imr)) = 0;
end;


procedure ReceiveMulticast(const groupUrl: string; OnReceiveData: TProc<TBytes>);
const
  RECV_BUFF_SIZE = 8192;

var
  lSockAddr         : TSockAddrIn;
  lGroupAddr        : TSockAddrIn;
  lSocketHandle     : TSocket;
  lWSADATA          : TWsaData;
  lRecvBytes        : Integer;

  lRecvBuffer       : array[0..RECV_BUFF_SIZE - 1] of Byte;
  lRecvData         : TBytes;
begin
  if (WSAStartup(2 or 2 shl 8, lWSADATA) <> 0) then
    raise Exception.Create('Error Message');
  try
    // Create the socket - remember to specify the multicast flags
    lSocketHandle := WSASocket(AF_INET, SOCK_DGRAM, 0, nil, 0, WSA_FLAG_OVERLAPPED or WSA_FLAG_MULTIPOINT_C_LEAF or WSA_FLAG_MULTIPOINT_D_LEAF);
    if (lSocketHandle = INVALID_SOCKET) then
      raise ExCeption.CreateFmt('(af = %d) failed: %d', [AF_INET, WSAGetLastError()]);
    try

      if not SetReuseAddr(lSocketHandle, True) then
        raise Exception.Create('SetReuseAddr True');

      // BIND
      lSockAddr := StringToSockAddr(groupUrl);
      lSockAddr.sin_addr.S_addr := htonl(INADDR_ANY);
      if bind(lSocketHandle, TSockAddr(lSockAddr), SizeOf(TSockAddr)) = SOCKET_ERROR then
        raise Exception.CreateFmt('bind failed: %d', [WSAGetLastError()]);

      // JOIN TO GROUP
      //if not JoinGroup(lSocketHandle, StringToSockAddr(sourceUrl).sin_addr, in_addr(htonl(INADDR_ANY))) then
      //  raise Exception.CreateFmt('JoinGroup failed: %d', [WSAGetLastError()]);
      lGroupAddr:= StringToSockAddr(groupUrl);
      lGroupAddr.sin_port := htons(0);
      if WSAJoinLeaf(lSocketHandle, TSockAddr(lGroupAddr), SizeOf(TSockAddr), nil, nil, nil, nil, JL_RECEIVER_ONLY) = INVALID_SOCKET then
       raise Exception.CreateFmt('WSAJoinLeaf failed: %d', [WSAGetLastError()]);


      while True do
      begin
        lRecvBytes := recv(lSocketHandle, lRecvBuffer, RECV_BUFF_SIZE, 0);
        if lRecvBytes = -1 then
          raise Exception.CreateFmt('recv failed: %d', [WSAGetLastError]);

        if assigned(OnReceiveData) then
        begin
          SetLength(lRecvData, lRecvBytes);
          move(lRecvBuffer[0], lRecvData[0], lRecvBytes);
          OnReceiveData(lRecvData);
        end;
      end;

    finally
      CloseSocket(lSocketHandle);
    end;

  finally
    WSACleanup();
  end;
end;

{$ENDREGION}

function Usage(): string;
begin
  result := 'Usage: %s -i udp://238.45.45.200:1234 -dump dump.mp2 -pid 200';
end;

var
  lTsDecoder        : TTsDecoder;
  lStreamDump       : TFileStream;
  lArgI             : string;
  lArgDump          : string;
  lArgPid           : string;
  lDumpPid          : integer;
  lRecvQueue        : TThreadedQueue<TBytes>;
  lPacketQueue      : TThreadedQueue<TBytes>;
  lMainThread       : TThread;
  lSendThread       : TThread;
begin
  try
    ReportMemoryLeaksOnShutdown := true;

    // -i udp://238.45.45.200:1234
    if not FindCmdLineSwitch('i', lArgI, True) then
    begin
      writeln(format(Usage, [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
      exit;
    end;

    // -dump  filename
    // -pid
    if (FindCmdLineSwitch('dump', lArgDump, True) and (not FindCmdLineSwitch('pid', lArgPid, True))) then
    begin
      writeln(format(Usage, [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
      exit;
    end;
    if not lArgDump.IsEmpty then
    begin
      lArgDump := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), lArgDump));
      if System.IOUtils.TFile.Exists(lArgDump) then
        System.IOUtils.TFile.Delete(lArgDump);
    end;
    lDumpPid := StrToIntDef(lArgPid, -1);

    lPacketQueue := TThreadedQueue<TBytes>.Create(1024,100,100);
    try
      lRecvQueue:= TThreadedQueue<TBytes>.Create(1024,100,100);
      try

        lTsDecoder := TTsDecoder.Create;
        try
          lTsDecoder.OnParsePacket := procedure(Sender: TObject; TsPacket: TTsPacket)
          begin
            if (TsPacket.Pid = Integer(TPidType.TDT_PID))  then
            begin
              case lPacketQueue.PushItem(TsPacket.Data) of
                    wrTimeout:      writeln('lPacketQueue.PushItem wrTimeout');
                    wrAbandoned:    writeln('lPacketQueue.PushItem wrAbandoned');
                    wrError:        writeln('lPacketQueue.PushItem wrError');
                    wrIOCompletion: writeln('lPacketQueue.PushItem wrIOCompletion');
              end;
            end;
          end;

          lTsDecoder.OnContinutyError := procedure(const Sender:TObject; const Pid: Integer; const CC: Integer; const NewCC: Integer)
          begin
            System.Writeln(Format('ContinutyError: %s - PID: %d, CC: %d, NewCC: %d', [FormatDateTime('hh:mm:ss.zzz', now), Pid, CC, NewCC]));
          end;

          lTsDecoder.OnTableChange := procedure(Sender: TObject; TsTable: TTsTable)
          begin
            if TsTable is TProgramMapTable then
            begin
              System.Writeln(Format('PMT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
              System.Writeln((TsTable as TProgramMapTable).Dump);
            end else
            if TsTable is TProgramAssociationTable then
            begin
              System.Writeln(Format('PAT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
              System.Writeln((TsTable as TProgramAssociationTable).Dump);
            end else
            if TsTable is TTimeDateTable then
            begin
              System.Writeln(Format('%d', [FormatDateTime('YYYT-mm-dd hh:nn:ss', (TsTable as TTimeDateTable).DateTime)]));
            end else
            if TsTable is TServiceDescriptionTable then
            begin
              System.Writeln(Format('SDT: packet %d, PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
              System.Writeln((TsTable as TServiceDescriptionTable).Dump);
            end else
              System.Writeln(Format('TABLE: packet, %d PID = 0x%04x (%d)', [(Sender as TTsDecoder).PacketCounter.Packets, TsTable.Pid, TsTable.Pid]));
          end;

          //System.Write('Press Enter to stop processing mpeg-ts...');


          System.Write(Format('', [lArgI]));
          TThread.CreateAnonymousThread(procedure()
          begin
            try
              ReceiveMulticast(lArgI,
                procedure(aRecvData : TBytes)
                begin
                  case lRecvQueue.PushItem(aRecvData) of
                    wrTimeout:      writeln('lRecvQueue.PushItem wrTimeout');
                    wrAbandoned:    writeln('lRecvQueue.PushItem wrAbandoned');
                    wrError:        writeln('lRecvQueue.PushItem wrError');
                    wrIOCompletion: writeln('lRecvQueue.PushItem wrIOCompletion');
                  end;
                end
              );
            except
              on E:Exception do
                writeln(Format('ReceiveMulticast Exception: %d', [E.Message]));
            end;
          end).Start;

          lSendThread:= TThread.CreateAnonymousThread(procedure()
            const
              SEND_BUFF_SIZE = 8192;
            var
              lSockAddr         : TSockAddrIn;
              lGroupAddr        : TSockAddrIn;
              lSocketHandle     : TSocket;
              lWSADATA          : TWsaData;
              lSendBuffer       : array[0..SEND_BUFF_SIZE - 1] of Byte;
              lSizeBuffer       : Integer;
              lTsPacket         : TBytes;
              lSendBytes        : Integer;
            begin
              if (WSAStartup(2 or 2 shl 8, lWSADATA) <> 0) then
                raise Exception.Create('Error Message');
              try
                // Create the socket - remember to specify the multicast flags
                lSocketHandle := WSASocket(AF_INET, SOCK_DGRAM, 0, nil, 0, WSA_FLAG_OVERLAPPED or WSA_FLAG_MULTIPOINT_C_LEAF or WSA_FLAG_MULTIPOINT_D_LEAF);
                if (lSocketHandle = INVALID_SOCKET) then
                  raise ExCeption.CreateFmt('(af = %d) failed: %d', [AF_INET, WSAGetLastError()]);
                try

                  if not SetReuseAddr(lSocketHandle, True) then
                    raise Exception.Create('SetReuseAddr True');

                  if not SetMulticastTtl(lSocketHandle, 1) then
                    raise Exception.Create('SetMulticastTtl True');

                  // Set sender interface
                  FillChar(lSockAddr, SizeOf(lSockAddr), #0);
                  lSockAddr.sin_addr.S_addr :={ htonl(INADDR_ANY);} inet_addr(MarshaledAString(TEncoding.UTF8.GetBytes('10.1.1.17')));
                  if not SetMulticastInterface(lSocketHandle, lSockAddr) then
                    raise Exception.CreateFmt('SetMulticastInterface: %d', [WSAGetLastError()]);

                  // Set SendTo Addr
                  lGroupAddr:= StringToSockAddr('udp://239.45.45.20:1234');

                  while True do
                  begin
                    lTsPacket := lPacketQueue.PopItem;
                    lSizeBuffer := Length(lTsPacket);
                    if lSizeBuffer >0 then
                    begin
                      move(lTsPacket[0], lSendBuffer[0], lSizeBuffer);

                      lSendBytes := SendTo(lSocketHandle, lSendBuffer, lSizeBuffer, 0, @TSockAddr(lGroupAddr), SizeOf(TSockAddr));
                      if lSendBytes = -1 then
                              raise Exception.CreateFmt('recv failed: %d', [WSAGetLastError]);
                    end;

                  end;

                finally
                  CloseSocket(lSocketHandle);
                end;
              finally
                WSACleanup();
              end;

          end);
          lSendThread.Start;

          lMainThread:= TThread.CreateAnonymousThread(procedure()
          begin
            while True do
              lTsDecoder.AddData(lRecvQueue.PopItem);
          end);
          lMainThread.Start;
          lMainThread.WaitFor;


          System.Writeln(Format('Processing Packets: %d', [lTsDecoder.PacketCounter.Packets]))

        finally
          FreeAndNil(lTsDecoder);
        end;
      finally
        FreeAndNil(lRecvQueue);
      end;
      finally
        FreeAndNil(lPacketQueue);
      end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  System.Writeln;
  System.Write('Press Enter to exit...');
  System.Readln;
end.
