unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, System.ImageList, Vcl.ImgList;

type
  TForm1 = class(TForm)
    pnlLeft: TPanel;
    pnlRight: TPanel;
    pnlCount: TPanel;
    lvProcesses: TListView;
    lvPorts: TListView;
    Panel1: TPanel;
    btnRefresh: TButton;
    btnPortFilter: TButton;
    imgBtn: TImageList;
    btnAbout: TButton;
    img100x100: TImageList;
    procedure btnRefreshClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lvProcessesChange(Sender: TObject; Item: TListItem; Change:
        TItemChange);
    procedure btnPortFilterClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
  private
    procedure FillList;
    procedure GetPortListByPID(const pid: Cardinal);
    procedure UpdateCounterCaption(const tcp, udp: Integer);
    procedure PortFind(const Port: String);
  end;

  TMibTcpRowOwnerPid = packed record
    dwState     : DWORD;
    dwLocalAddr : DWORD;
    dwLocalPort : DWORD;
    dwRemoteAddr: DWORD;
    dwRemotePort: DWORD;
    dwOwningPid : DWORD;
  end;
  PMibTcpRowOwnerPid = ^TMibTcpRowOwnerPid;

  MIB_TCPTABLE_OWNER_PID = packed record
   dwNumEntries: DWord;
   table: array [0..0] of TMibTcpRowOwnerPid;
  end;
  PMIB_TCPTABLE_OWNER_PID  = ^MIB_TCPTABLE_OWNER_PID;

  TMibUdpRowOwnerPID = packed record
    dwLocalAddr: DWORD;
    dwLocalPort: DWORD;
    dwOwningPid: DWORD;
  end;
  PMibUdpRowOwnerPID = ^TMibUdpRowOwnerPID;

  MIB_UDPTABLE_OWNER_PID = packed record
    dwNumEntries: DWORD;
    table: Array[0..0] of TMibUdpRowOwnerPID;
  end;
  PMIB_UDPTABLE_OWNER_PID = ^MIB_UDPTABLE_OWNER_PID;

  function GetExtendedTcpTable(pTcpTable: Pointer; pdwSize: PDWORD; bOrder: BOOL; ulAf: LongWord;
    TableClass: Integer; Reserved: LongWord): DWORD; stdcall; external 'iphlpapi.dll';

  function GetExtendedUdpTable( pUdpTable: Pointer; pdwSize: PDWORD; bOrder: BOOL; ulAf: LongWord;
    TableClass: Integer; Reserved: LongWord): LongInt; stdcall; external 'iphlpapi.dll';

const
  AF_INET                 = 2; // WinSock
  TCP_TABLE_OWNER_PID_ALL = 5;
  UDP_TABLE_OWNER_PID     = 1;
  Counter_Caption         = 'TCP: %d,     UDP: %d';

var
  Form1: TForm1;

implementation

uses TlHelp32;

{$R *.dfm}



function GetPIDName(hSnapShot: THandle; PID: DWORD): string;
var
ProcInfo: TProcessEntry32;
begin
ProcInfo.dwSize := SizeOf(ProcInfo);
if not Process32First(hSnapShot, ProcInfo) then
   Result := 'Unknown!'
else
repeat
  if ProcInfo.th32ProcessID = PID then
     Result := ProcInfo.szExeFile;
until not Process32Next(hSnapShot, ProcInfo);
end;



procedure TForm1.PortFind(const Port: String);
var
i: integer;
dllHandle : THandle;
 GetExtendedTcpTable: function(pTcpTable: Pointer; dwSize: PDWORD; bOrder: BOOL; lAf: ULONG; TableClass: Integer; Reserved: ULONG): DWord; stdcall;
PID, TableSize: DWORD;
Snapshot: THandle;
FExtendedTcpTable : PMIB_TCPTABLE_OWNER_PID;
AppName: string;
PortList: TMemo;
AppList: TMemo;
_Port: Cardinal;
Finded: Integer;
begin
  dllHandle := LoadLibrary('iphlpapi.dll');
  if dllHandle = 0 then exit;

  GetExtendedTcpTable := GetProcAddress(dllHandle, 'GetExtendedTcpTable');
  if not Assigned(GetExtendedTcpTable) then exit;

   TableSize := 0;
   if GetExtendedTcpTable(nil, @TableSize, False, AF_INET, 5, 0) <> ERROR_INSUFFICIENT_BUFFER then
   exit;
   try
     GetMem(FExtendedTcpTable, TableSize);
     Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
     if GetExtendedTcpTable(FExtendedTcpTable, @TableSize, True, AF_INET, 5, 0) = NO_ERROR then
      for I := 0 to FExtendedTcpTable.dwNumEntries  - 1 do
       begin
         PID := FExtendedTcpTable.table[i].dwOwningPid;
         AppName := GetPidName(SnapShot, PID);
         _Port := FExtendedTcpTable.table[i].dwLocalPort;

         if _Port = StrToInt(Port) then
         begin
           MessageBox(handle, pChar('The entered port number is used: ' + AppName), 'Found it!', MB_OK + MB_ICONWARNING);
           exit;
         end;
       end;
       MessageBox(handle, 'Port number is not used!', 'Not used!', MB_OK + MB_ICONINFORMATION);
   finally
     FreeMem(FExtendedTcpTable);
   end;
end;



procedure TForm1.FillList;
var
  Snapshot: THandle;
  ProcessEntry: TProcessEntry32;
  aItem: TListItem;
begin
  UpdateCounterCaption(0, 0);

  lvProcesses.Items.BeginUpdate;
  lvProcesses.Clear;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  try
    ProcessEntry.dwSize := SizeOf(TProcessEntry32);
    if not Process32First(Snapshot, ProcessEntry) then Exit;
    repeat
      aItem := lvProcesses.Items.Add;
      aItem.Caption := ProcessEntry.szExeFile;
      aItem.SubItems.Add(IntToStr(ProcessEntry.th32ProcessID));
    until not Process32Next(Snapshot, ProcessEntry);
  finally
    CloseHandle(Snapshot);
    lvProcesses.Items.EndUpdate;
  end;
end;

procedure TForm1.btnPortFilterClick(Sender: TObject);
var
 UsersPort: string;
begin
 UsersPort := InputBox('Enter a port number', 'Port number:', '');

 if Trim(UsersPort) <> '' then
 begin
  PortFind(UsersPort);
 end;
end;

procedure TForm1.btnRefreshClick(Sender: TObject);
begin
  FillList;
end;

procedure TForm1.btnAboutClick(Sender: TObject);
begin
 MessageBox(handle, pChar('Developers by DelphiCan Team' + sLineBreak + sLineBreak + 'Thanks: ' + sLineBreak + 'SimaWB' + sLineBreak + 'Halil Han Badem'), 'Developers', MB_OK + MB_ICONINFORMATION);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  FillList;
end;

procedure TForm1.GetPortListByPID(const pid: Cardinal);
var
  i: integer;
  TableSize: DWORD;
  FExtendedTcpTable: PMIB_TCPTABLE_OWNER_PID;
  FExtendedUdpTable: PMIB_UDPTABLE_OWNER_PID;
  tcp_count, udp_count: Integer;
begin
  tcp_count := 0; udp_count := 0;
  lvPorts.Items.BeginUpdate;
  lvPorts.Clear;
  try
    TableSize := 0;
    if GetExtendedTcpTable(nil, @TableSize, False, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) <> ERROR_INSUFFICIENT_BUFFER then
      Exit;

    GetMem(FExtendedTcpTable, TableSize);
    try
      if GetExtendedTcpTable(FExtendedTcpTable, @TableSize, TRUE, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) = NO_ERROR then
        for i := 0 to FExtendedTcpTable.dwNumEntries - 1 do
          if FExtendedTcpTable.Table[i].dwOwningPid = pid then
          begin
            Inc(tcp_count);
            with lvPorts.Items.Add do
            begin
              Caption :=  IntToStr(FExtendedTcpTable.Table[i].dwLocalPort);
              SubItems.Add(IntToStr(FExtendedTcpTable.Table[i].dwRemotePort));
              SubItems.Add('TCP');
            end;
          end;
    finally
      FreeMem(FExtendedTcpTable);
    end;

    TableSize := 0;
    if GetExtendedUdpTable(nil, @TableSize, False, AF_INET, UDP_TABLE_OWNER_PID, 0) <> ERROR_INSUFFICIENT_BUFFER then
      Exit;

    GetMem(FExtendedUdpTable, TableSize);
    try
      if GetExtendedUdpTable(FExtendedUdpTable, @TableSize, TRUE, AF_INET, UDP_TABLE_OWNER_PID, 0) = NO_ERROR then
        for i := 0 to FExtendedUdpTable.dwNumEntries - 1 do
          if FExtendedUdpTable.Table[i].dwOwningPid = pid then
          begin
            Inc(udp_count);
            with lvPorts.Items.Add do
            begin
              Caption :=  IntToStr(FExtendedUdpTable.Table[i].dwLocalPort);
              SubItems.Add('');
              SubItems.Add('UDP');
            end;
          end;
    finally
      FreeMem(FExtendedUdpTable);
    end;
  finally
    lvPorts.Items.EndUpdate;
  end;
  UpdateCounterCaption(tcp_count, udp_count);
end;

procedure TForm1.lvProcessesChange(Sender: TObject; Item: TListItem; Change:
    TItemChange);
begin
  if Item.SubItems.Count = 0 then
    Exit;
  UpdateCounterCaption(0, 0);
  GetPortListByPID(StrToInt(Item.SubItems[0]));
end;

procedure TForm1.UpdateCounterCaption(const tcp, udp: Integer);
begin
  pnlCount.Caption := Format(Counter_Caption, [tcp, udp]);
end;

end.
