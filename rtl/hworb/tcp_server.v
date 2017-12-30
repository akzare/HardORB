/***********************************************************************
  $FILENAME    : tcp_server.v

  $TITLE       : TCP protocol (server) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : Transmission Control Protocol layer which responds only to TCP requests 
                 with an individual specified Dst port number with a required reply (TCP state diagram).  
                 Any other TCP messages are discarded / ignored.  

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module tcp_server #(
  parameter [15:0] DEVICE_TCP_PORT        = 16'hBC14,
  parameter [15:0] DEVICE_TCP_PAYLOAD     = 16'h0400,         // 1024-byte payload
  parameter [31:0] DEVICE_IP              = 32'h8d59342b
) 
(
  input              clk,               // clock 
  input              reset_n,           // asynchronous active low reset
  
  input              newDatagram,       // asserted when a new datagram arrive
  input [15:0]       datagramSize,      // size of the arrived datagram
  input [7:0]        protocolIn,        // protocol TYPE of the datagram
  input [31:0]       sourceIP,          // IP address that sent the message
  input              instream_fifoempty, // asserted when begin external memory read operation is complete
  input [7:0]        instream_rddata,   // read data bus from the DDR MEM
  output reg         instream_rden,     // asserted to tell the RAM to read
  input              mac_rx_data_new,   // asserted when begin RX new byte SPY section operation is complete
  input [7:0]        mac_rx_data,       // received data from MAC layer
  input              mac_tx_done,
  input              mac_rx_done,
  input              tx_dpmem_wr_cmplt, // asserted when begin TX DPMEM memory write operation is complete
  output reg         tx_dpmem_wr,       // asserted to tell the RAM to write
  output reg  [7:0]  tx_dpmem_data,     // write data bus to the RAM
  output reg  [10:0] tx_dpmem_addr,     // write address bus to the RAM
  output reg  [15:0] sendDatagramSize,  // size of the ping to reply to
  output reg         sendDatagram,      // tells the IP layer to send a datagram
  output reg  [31:0] destinationIP,     // target IP of the datagram
  output wire        sndOvrhd_trigSg,
  output wire [7:0]  protocolOut        // tells the IP layer which protocol it is
);


  // Signal declarations

  // Server Timeout Counters
  parameter  TIMERWIDTHSrv = 30;   // can be used to vary timeout length
  reg [29:0] timout0Srv;                                  // timeout counter
  reg        rstTimoutSrv;                                // start timeout counter
  parameter [29:0] FULTIMSrv  = 30'b111111111111111111111111111111; // last value of timeout counter

  // Receiver Timeout Counters
  parameter  TIMERWIDTHRec = 9;     // can be used to vary timeout length
  reg [8:0] timout0Rec;             // timeout counter
  reg        rstTimoutRec;     // start timeout counter
  parameter [8:0]  FULTIMRec = 9'b111111111;  // last value of timeout counter

  // TCP receive state definitions
  // FSM states
  parameter [3:0]
  TCP_SERV_RX_IDLE                   = 4'd0,  
  TCP_SERV_RX_SETUPWRITETCPBYTEREC   = 4'd1,  
  TCP_SERV_RX_WRITETCPBYTEREC        = 4'd2,  
  TCP_SERV_RX_WAITFINREC             = 4'd3,
  TCP_SERV_RX_SETPSEUDOHEADREC       = 4'd4,  
  TCP_SERV_RX_WRPSEUDOHEADREC        = 4'd5,  
  TCP_SERV_RX_WRITECHKSUM1REC        = 4'd6,  
  TCP_SERV_RX_WRITECHKSUM2REC        = 4'd7,
  TCP_SERV_RX_WAITFORCHECKSUMREC     = 4'd8,
  TCP_SERV_RX_WAITFORCHECKSUMCALCREC = 4'd9;
  
  reg [3:0] tcp_srv_rx_pres_fsm;
  reg [3:0] tcp_srv_rx_nxt_fsm;

  // buffer to hold the size of the TCP message received 
  reg [15:0] TCPSizeRec;
  reg [15:0] nxtTCPSizeRec;
  
  // counter to handle the message
  reg        incCntRec;
  reg        rstCntRec;
  reg [15:0] cntRec;
  reg        incCntOptRec;
  reg        rstCntOptRec;
  reg [7:0]  CntOptRec;

  // Signal and buffer to latch and hold the data from RAM
  reg [7:0]  rxData;

  // Signal and buffer to latch and hold the data from DDR RAM
  reg [7:0]  rdLatchMem;
  reg        latchRdDataXmit;

  // Signal to remember the previous tx_dpmem_data value
  reg [7:0]  nextWrData;

  // Signal to latch the inputs from the previous layer
  reg        latchDestinationIP;

  // checksum Rec signals - read internet.vhd for checksum Rec commenting
  reg         chkStateRec;
  parameter   stMSB = 1'b0;
  parameter   stLSB = 1'b1;
  reg  [16:0] chksmLongRec;
  wire [15:0] chksmIntRec;
  reg  [7:0]  latchMSBRec;
  reg         newHeaderRec;
  reg         newByteRec;
  reg  [7:0]  inByteRec;
  wire [15:0] chksmCalRec;
  reg         validRec;

  reg         incCntPsdoHdRec;
  reg         rstCntPsdoHdRec;
  reg  [3:0]  cntPsdoHdRec;

  // latch the source and destination ports, for use later in TCP state diagram
  reg [15:0] srcPrtRec;
  reg [15:0] nxtSrcPrtRec;
  reg [15:0] dstPrtRec;
  reg [15:0] nxtDstPrtRec;
  reg [31:0] seqNumRec;
  reg [31:0] nxtSeqNumRec;
  reg [31:0] ackNumRec;
  reg [31:0] nxtAckNumRec;
  reg [7:0]  headLenRec;
  reg [7:0]  nxtHeadLenRec;
  reg [3:0]  headLenSaveRec;
  reg [3:0]  nxtHeadLenSaveRec;
  reg [7:0]  flagsRec;
  reg [7:0]  nxtFlagsRec;
  reg [15:0] winSizeRec;
  reg [15:0] nxtWinSizeRec;
  reg [15:0] chkSumRec;
  reg [15:0] nxtChkSumRec;

  reg [7:0]  optLenRec;
  reg [7:0]  nxtOptLenRec;
  
  parameter [2:0]
  TCP_SERV_RX_OPTNON           = 3'd0,  
  TCP_SERV_RX_OPTNOP           = 3'd1,  
  TCP_SERV_RX_OPTMAXSEGSIZE    = 3'd2,  
  TCP_SERV_RX_OPTSACKPERMITTED = 3'd3,
  TCP_SERV_RX_OPTTIMESTAMP     = 3'd4,  
  TCP_SERV_RX_OPTWINSCLE       = 3'd5;

  reg [2:0]  optTypRec;
  reg [2:0]  nxtOptTypRec;

  reg [15:0] maxSegSizeRec;
  reg [15:0] nxtMaxSegSizeRec;
  reg [31:0] tsValRec;
  reg [31:0] nxtTsValRec;
  reg [31:0] tsEcrRec;
  reg [31:0] nxtTsEcrRec;
  reg        sAckPermitRec;
  reg        nxtSAckPermitRec;
  reg [7:0]  winScaleRec;
  reg [7:0]  nxtWinScaleRec;

  reg        nxtCmpltRec;
  reg        cmpltRec;
  
  // TCP Server state definitions
  parameter [3:0]
  TCP_SERV_IDLESRV                  = 4'd0,
  TCP_SERV_WAIT4SYNSRV              = 4'd1,
  TCP_SERV_RPLYSYNACKSRV            = 4'd2,
  TCP_SERV_WAIT4SYNACKACKSRV        = 4'd3,
  TCP_SERV_WAIT4GIOPREQSRV          = 4'd4,
  TCP_SERV_RPLYGIOPREQACKSRV        = 4'd5,
  TCP_SERV_WAITXMITFINSRV           = 4'd6,
  TCP_SERV_XMITGIOPRPLYSRV          = 4'd7,
  TCP_SERV_WAIT4XMITGIOPRPLYACKSRV  = 4'd8,
  TCP_SERV_WAIT4FINACKSRV           = 4'd9,
  TCP_SERV_RPLYFINACKSRV            = 4'd10,
  TCP_SERV_WAIT4ACKSRV              = 4'd11;
           
  reg [3:0]  tcp_srv_pres_fsm;
  reg [3:0]  tcp_srv_nxt_fsm;
  reg [3:0]  retStateSrv;

  reg        sendTCP;
  reg        nxtSendTCP;

  reg        sndOvrhdTrigSg; 
  reg        nxtSndOvrhdTrigSg; 

  reg        goWaitSrv;

  // TCP transmit state definitions
  parameter [3:0]
  TCP_SERV_TX_IDLEXMIT                = 4'd0,  
  TCP_SERV_TX_SETHEADERXMIT           = 4'd1,  
  TCP_SERV_TX_WRHEADERXMIT            = 4'd2,  
  TCP_SERV_TX_GETDATAXMIT             = 4'd3,
  TCP_SERV_TX_WRDATAXMIT              = 4'd4,  
  TCP_SERV_TX_SETPSEUDOHEADXMIT       = 4'd5,  
  TCP_SERV_TX_WRPSEUDOHEADXMIT        = 4'd6,  
  TCP_SERV_TX_WRITECHKSUM1XMIT        = 4'd7,
  TCP_SERV_TX_WRITECHKSUM2XMIT        = 4'd8,
  TCP_SERV_TX_WAITFORCHECKSUMXMIT     = 4'd9,
  TCP_SERV_TX_WAITFORCHECKSUMCALCXMIT = 4'd10,
  TCP_SERV_TX_WRITEFINISHXMIT         = 4'd11;
  
  reg [3:0] tcp_srv_tx_pres_fsm;
  reg [3:0] tcp_srv_tx_nxt_fsm;

  // checksum Xmit signals - read internet.vhd for checksum Xmit commenting
  reg        chkStateXmit;

  reg  [16:0] chksmLongXmit;
  wire [15:0] chksmIntXmit;
  reg  [7:0]  latchMSBXmit;
  reg         newHeaderXmit;
  reg         newByteXmit;
  reg  [7:0]  inByteXmit;
  wire [15:0] chksmXmit;
  reg         validXmit;

  // buffer to hold the size of the TCP message transmit 
  reg  [15:0] TCPSizeXmit;
  reg  [15:0] nxtTCPSizeXmit;

  reg         busyXmit;
  reg         nxtBusyXmit;

  reg         incCntXmit;
  reg         rstCntXmit;
  reg  [15:0] cntXmit;

  reg         incCntPsdoHdXmit;
  reg         rstCntPsdoHdXmit;
  reg  [3:0]  cntPsdoHdXmit;

  reg  [31:0] seqNumXmit;
  reg  [31:0] nxtSeqNumXmit;
  reg  [31:0] ackNumXmit;  
  reg  [31:0] nxtAckNumXmit;
  reg  [7:0]  headLenXmit;
  reg  [7:0]  nxtHeadLenXmit;
  reg  [7:0]  flagsXmit;
  reg  [7:0]  nxtFlagsXmit;
  reg  [15:0] winSizeXmit;
  reg  [15:0] nxtWinSizeXmit;

  reg  [31:0] tsValXmit;
  reg  [31:0] nxtTsValXmit;
  reg  [31:0] tsEcrXmit;
  reg  [31:0] nxtTsEcrXmit;

  reg         incCntRplyXmit;
  reg         rstCntRplyXmit;
  reg  [3:0]  cntXmitRply;

  reg  [15:0] tcpDLenPrvXmit;
  reg  [15:0] nxtTcpDLenPrvXmit;

  // GIOP 1.2 definitions
  parameter [31:0]  MAGIC_NUM_GIOP                   = 32'h47494F50; // GIOP Magic Number
  parameter [15:0]  VER_GIOP                         = 16'h0102; // version 1.2
  parameter [7:0]   FLAG_LIT_END_GIOP                = 8'h01; // Little-endian
  parameter [7:0]   MSG_TYP_REQ_GIOP                 = 8'h00; // GIOP Request
  parameter [7:0]   MSG_TYP_REP_GIOP                 = 8'h01; // GIOP Reply
  parameter [31:0]  MSG_SIZE_REQ_SHORT_GIOP          = 32'h54000000; // Test: op=get_short Request
  parameter [31:0]  MSG_SIZE_REQ_SHORTSEQ_GIOP       = 32'h58000000; // Test: op=get_shortseq Request
  parameter [31:0]  REQ_ID_GIOP                      = 32'h01000000; // Request ID
  parameter [7:0]   RESPONSE_FLAGS_GIOP              = 8'h03; // Response Flags (SYNC_WITH_TARGET)
  parameter [23:0]  RES_FLAGS_GIOP                   = 24'h000000; // Reserve Flags
  parameter [15:0]  TARGET_ADDR_DISC_GIOP            = 16'h0000; // Target Address Discrimin
  parameter [31:0]  OBJ_KEX_LEN_GIOP                 = 32'h1B000000; // Key Address (Obj KEY Len) 27
  parameter [215:0] OBJ_KEX_GIOP                     = 216'h14010f0052535448a0134b56d60900000000000100000001000000; // Key Address (Obj KEY)
  parameter [31:0]  OPR_LEN_REQ_SHORT_GIOP           = 32'h0a000000; // Operation Len 10
  parameter [31:0]  OPR_LEN_REQ_SHORTSEQ_GIOP        = 32'h0d000000; // Operation Len 13
  parameter [79:0]  REQ_OPR_REQ_SHORT_GIOP           = 80'h6765745f73686f727400; // Operation Len 10
  parameter [103:0] REQ_OPR_REQ_SHORTSEQ_GIOP        = 104'h6765745f73686f727473657100; // Operation Len 13
  parameter [31:0]  SEQ_LEN_REQ_GIOP                 = 32'h01000000; // Sequence Len request
  parameter [31:0]  SRV_CONTX_ID_GIOP                = 32'h01000000; // Service Context ID
  parameter [31:0]  ISO_8859_1_GIOP                  = 32'h01000100; // char_data
  parameter [31:0]  ISO_UTF_16_GIOP                  = 32'h09010100; // wchar_data

  parameter [15:0]  MSG_SIZE_REP_SHORTSEQ_GIOP_DUMMY = (DEVICE_TCP_PAYLOAD + 16);
  parameter [31:0]  MSG_SIZE_REP_SHORTSEQ_GIOP       = {MSG_SIZE_REP_SHORTSEQ_GIOP_DUMMY[7:0],MSG_SIZE_REP_SHORTSEQ_GIOP_DUMMY[15:8],16'h0000};
  parameter [31:0]  REP_STATUS_GIOP                  = 32'h00000000; // No exception
  parameter [31:0]  SEQ_LEN_REP_GIOP                 = 32'h00000000; // Sequence Len request
  parameter [15:0]  REP_STUB_DATA_LEN_GIOP_DUMMY     = {1'b0,DEVICE_TCP_PAYLOAD[15:1]};
  parameter [31:0]  REP_STUB_DATA_LEN_GIOP           = {REP_STUB_DATA_LEN_GIOP_DUMMY[7:0],REP_STUB_DATA_LEN_GIOP_DUMMY[15:8],16'h0000};
 
  reg        isGIOP; 
  reg        nxtIsGIOP;
  
  reg [15:0] tcpDLenLeftRec;  // variable
  reg [15:0] tcpDLenLeftXmit; // variable
  
  // always set the IP protocol field to tcp (06)
  assign protocolOut =  8'h06;
  assign sndOvrhd_trigSg = sndOvrhdTrigSg;

  // ==============================================================================
  // main clocked PROCESS
  always @(posedge clk or negedge reset_n) 
  begin
    // set up the asynchronous active low reset
    if (!reset_n) begin
      timout0Srv <= FULTIMSrv;
      timout0Rec <= FULTIMRec;

      // TCP Receive -------------------------------------------------------
      tcp_srv_rx_pres_fsm <= TCP_SERV_RX_IDLE;
      cmpltRec <= 1'b0;
      
      // TCP transmit -------------------------------------------------------
      tcp_srv_tx_pres_fsm <= TCP_SERV_TX_IDLEXMIT;
      busyXmit <= 1'b0;
  
      // TCP main handler ----------------------------------------------------
      tcp_srv_pres_fsm <= TCP_SERV_IDLESRV;
      retStateSrv <= TCP_SERV_IDLESRV;
      sendTCP <= 1'b0;

      // GIOP handler -------------------------------------------------------
      isGIOP <= 1'b1;

    end  
    // catch the rising clock edge
    else begin
      // handle timeout counters, rstTimoutSrv will only reset the current buffer
      if (rstTimoutSrv) begin
        timout0Srv <= 30'b0;
      end  
      else begin
        // increment timeout counters but don't let them overflow
        if (timout0Srv != FULTIMSrv)
          timout0Srv <= timout0Srv + 1;
        else
          timout0Srv <= FULTIMSrv;
    
      end

      // TCP Receive -------------------------------------------------------
      tcp_srv_rx_pres_fsm <= tcp_srv_rx_nxt_fsm;
      // remember the source port, destination port, and length
      srcPrtRec <= nxtSrcPrtRec;
      dstPrtRec <= nxtDstPrtRec;

      seqNumRec <= nxtSeqNumRec;
      ackNumRec <= nxtAckNumRec;
      headLenRec <= nxtHeadLenRec;
      headLenSaveRec <= nxtHeadLenSaveRec;
      flagsRec <= nxtFlagsRec;
      winSizeRec <= nxtWinSizeRec;

      optLenRec <= nxtOptLenRec;
      optTypRec <= nxtOptTypRec;

      maxSegSizeRec <= nxtMaxSegSizeRec;
      tsValRec <= nxtTsValRec;
      tsEcrRec <= nxtTsEcrRec;
      sAckPermitRec <= nxtSAckPermitRec;
      winScaleRec <= nxtWinScaleRec;
      chkSumRec <= nxtChkSumRec;
      
      cmpltRec <= nxtCmpltRec;
      
      // set the TCP size and write data buses to their next values
      TCPSizeRec <= nxtTCPSizeRec;
      // increment and reset the counter asynchronously to avoid race conditions
//    if (incCntRec)    
      if (rstCntRec)
        cntRec <= 16'b0;
      else if (mac_rx_data_new)
        cntRec <= cntRec + 1;
    
      // increment and reset the TCP header options counter asynchronously to avoid race conditions
      if (rstCntOptRec)
        CntOptRec <= 8'b0;
      else if (incCntOptRec)
        CntOptRec <= CntOptRec + 1;

      // latch the RAM data after reading from the RAM
      if (mac_rx_data_new)
        rxData <= mac_rx_data;
      
      if (incCntPsdoHdRec)
        cntPsdoHdRec <= cntPsdoHdRec + 1;
      else if (rstCntPsdoHdRec)
        cntPsdoHdRec <= 4'b0;

      // latch the inputs and set the IP source buffer accordingly
      if (latchDestinationIP)
        destinationIP <= sourceIP;
    
      // TCP transmit -------------------------------------------------------
      tcp_srv_tx_pres_fsm <= tcp_srv_tx_nxt_fsm;
      tx_dpmem_data <= nextWrData;
      busyXmit <= nxtBusyXmit;
      
      tcpDLenPrvXmit <= nxtTcpDLenPrvXmit;

      // latch the RAM data after reading from the RAM
      if (latchRdDataXmit)
        rdLatchMem <= instream_rddata;
      else
        rdLatchMem <= rdLatchMem;
      
      // increment and reset the counter asynchronously to avoid race conditions
      if (incCntXmit)
        cntXmit <= cntXmit + 1;
      else if (rstCntXmit)
        cntXmit <= 16'b0;

      if (incCntPsdoHdXmit)
        cntPsdoHdXmit <= cntPsdoHdXmit + 1;
      else if (rstCntPsdoHdXmit)
        cntPsdoHdXmit <= 4'b0;

      // TCP main handler -------------------------------------------------------
      tcp_srv_pres_fsm <= tcp_srv_nxt_fsm;
      sendTCP <= nxtSendTCP;

      sndOvrhdTrigSg <= nxtSndOvrhdTrigSg;
      
      // increment and reset the counter asynchronously to avoid race conditions
      if (incCntRplyXmit)
        cntXmitRply <= cntXmitRply + 1;
      else if (rstCntRplyXmit)
        cntXmitRply <= 4'b0;

      seqNumXmit <= nxtSeqNumXmit;
      ackNumXmit <= nxtAckNumXmit;

      TCPSizeXmit <= nxtTCPSizeXmit;
      headLenXmit <= nxtHeadLenXmit;
      flagsXmit <= nxtFlagsXmit;
      winSizeXmit <= nxtWinSizeXmit;
  
      tsValXmit <= nxtTsValXmit;
      tsEcrXmit <= nxtTsEcrXmit;
      
      if (goWaitSrv) begin    
        tcp_srv_pres_fsm <= TCP_SERV_WAITXMITFINSRV;
        retStateSrv <= tcp_srv_nxt_fsm;
      end  
      else
        tcp_srv_pres_fsm <= tcp_srv_nxt_fsm;
            
      // handle timeout counters, rstTimoutRec will only reset the current buffer
      if (rstTimoutRec)
        timout0Rec <= 9'b0;
      else begin
        // increment timeout counters but don't let them overflow
        if (timout0Rec != FULTIMRec)
          timout0Rec <= timout0Rec + 1;
        else
          timout0Rec <= FULTIMRec;
    
      end
      
      // GIOP handler -------------------------------------------------------
      isGIOP <= nxtIsGIOP;

    end

  end // always

  // ==============================================================================
  // TCP data protocol unit header format
  //
  // Standard TCP request and reply TCP header
  //
  //  0                      8                      16                                          31
  //  --------------------------------------------------------------------------------------------
  //  |                 Source port                |                Destination port             |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                                       Sequence number                                    |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |                                    Acknowledgment number                                 |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |  Data offset  |  Reserved  |C|E|U|A|P|R|S|F|                  Window Size                |
  //  |               |            |W|C|R|C|S|S|Y|I|                                             |
  //  |               |            |R|E|G|K|H|T|N|N|                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                   Checksum                 |                 Urgent pointer              |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                               Options (if Data Offset > 5)                               |
  //  |                                          ....                                            |
  //  --------------------------------------------------------------------------------------------
  //

  // TCP checksum for IPv4
  //
  // TCP pseudo-header (IPv4)
  //
  //  0                      8                      16                                          31
  //  --------------------------------------------------------------------------------------------
  //  |                                       Source address                                     |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |                                    Destination address                                   |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |        Zeros         |       Protocol      |                  TCP length                 |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                 Source port                |                Destination port             |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                                       Sequence number                                    |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |                                    Acknowledgment number                                 |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |  Data offset  |  Reserved  |   flagsRec    |                  Window Size                |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |                   Checksum                 |                 Urgent pointer              |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                                    Options (optional)                                    |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |                                           Data                                           |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //
  // ==============================================================================
 
  
  // ==============================================================================
  // TCP main FSM PROCESS
  always @(tcp_srv_pres_fsm or cmpltRec or sendTCP or busyXmit or nxtBusyXmit or TCPSizeXmit or seqNumXmit or timout0Srv or ackNumXmit or headLenXmit or flagsXmit or winSizeXmit or tsValXmit or tsEcrXmit or isGIOP or sndOvrhdTrigSg)  
  begin
    rstTimoutSrv <= 1'b0;
    goWaitSrv <= 1'b0;
    nxtSndOvrhdTrigSg <= sndOvrhdTrigSg;
    incCntRplyXmit <= 1'b0;
    rstCntRplyXmit <= 1'b0;
    nxtSendTCP <= 1'b0;
    nxtTCPSizeXmit <= TCPSizeXmit;
    nxtSeqNumXmit <= seqNumXmit;
    nxtAckNumXmit <= ackNumXmit;
    nxtHeadLenXmit <= headLenXmit;
    nxtFlagsXmit <= flagsXmit;
    nxtWinSizeXmit <= winSizeXmit;
    nxtTsValXmit <= tsValXmit;
    nxtTsEcrXmit <= tsEcrXmit;
    
    case(tcp_srv_pres_fsm)
      TCP_SERV_IDLESRV:
      begin
        // wait until told to receive new packet
        if (!cmpltRec) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
          nxtSndOvrhdTrigSg <= 1'b0;
        end  
        else
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4SYNSRV;
      end
      
      TCP_SERV_WAIT4SYNSRV:
      begin
        if (flagsRec != 8'h02) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
        end  
        else begin
          tcp_srv_nxt_fsm <= TCP_SERV_RPLYSYNACKSRV;
          rstCntRplyXmit <= 1'b1;
        end
      end
      
      TCP_SERV_RPLYSYNACKSRV:
      begin
        if (!busyXmit) begin
          nxtSendTCP <= 1'b1;
          nxtSeqNumXmit <= 32'hC4B3440F; // SEQs=start
          nxtAckNumXmit <= seqNumRec + {8'h00,TCPSizeRec} - {12'h000,2'b00,headLenSaveRec,2'b00} + 1; // ACKs – SEQc=1
          nxtHeadLenXmit <= 8'h28; // 40 bytes
          nxtFlagsXmit <= 8'h12; // SYN ACK
          nxtWinSizeXmit <= 16'h16A0; // Win(multiply by 1)=5792
          nxtTsValXmit <= 32'h03BB5B77; // start
          nxtTsEcrXmit <= tsValRec;
          nxtTCPSizeXmit <= 16'h0028; // 40 bytes
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4SYNACKACKSRV;
          goWaitSrv <= 1'b1;
        end  
        else begin
          tcp_srv_nxt_fsm <= TCP_SERV_RPLYSYNACKSRV;
        end
      end
      
      TCP_SERV_WAIT4SYNACKACKSRV:
      begin
        if (cntXmitRply == 4'h2) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
        end  
        else if (timout0Srv == FULTIMSrv) begin
          tcp_srv_nxt_fsm <= TCP_SERV_RPLYSYNACKSRV;
          incCntRplyXmit <= 1'b1;
        end  
        else if (!cmpltRec) begin
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4SYNACKACKSRV;
        end  
        else begin
          if ((flagsRec == 8'h10) && (ackNumRec == (seqNumXmit + {8'h00,tcpDLenPrvXmit} + 1))) begin
            tcp_srv_nxt_fsm <= TCP_SERV_WAIT4GIOPREQSRV;
            rstTimoutSrv <= 1'b1;  // start/restart timer
          end  
          else begin
            tcp_srv_nxt_fsm <= TCP_SERV_RPLYSYNACKSRV;
          end
        end
      end
      
      TCP_SERV_WAIT4GIOPREQSRV:
      begin
        if (timout0Srv == FULTIMSrv) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
        end  
        else if (!cmpltRec) begin
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4GIOPREQSRV;
        end  
        else begin
          if ((flagsRec == 8'h18) && (ackNumRec == (seqNumXmit + {8'h00,tcpDLenPrvXmit} + 1)) && (isGIOP)) begin
            tcp_srv_nxt_fsm <= TCP_SERV_RPLYGIOPREQACKSRV;
          end  
          else begin
            tcp_srv_nxt_fsm <= TCP_SERV_WAIT4GIOPREQSRV;
          end
        end
      end
      
      TCP_SERV_RPLYGIOPREQACKSRV:
      begin
        if (!busyXmit) begin
          nxtSendTCP <= 1'b1;
          nxtSeqNumXmit <= seqNumXmit + {8'h00,tcpDLenPrvXmit} + 1; // SEQs=SEQs_prev+TCP_Data_Length_prev+1
          nxtAckNumXmit <= seqNumRec + {8'h00,TCPSizeRec} - {12'h000,2'b00,headLenSaveRec,2'b00}; // ACKs–SEQc=100
          nxtHeadLenXmit <= 8'h20; // 32 bytes
          nxtFlagsXmit <= 8'h10; // ACK
          nxtWinSizeXmit <= 16'h002E; // Win(multiply by 128)=5888
          nxtTsValXmit <= 32'h03BB5B77; // Tsval=Tsval_prev+0
          nxtTsEcrXmit <= tsValRec; // Tsecr=Tsval(s)
          nxtTCPSizeXmit <= 16'h0020; // 32 bytes
          tcp_srv_nxt_fsm <= TCP_SERV_XMITGIOPRPLYSRV;
          rstCntRplyXmit <= 1'b1;
          goWaitSrv <= 1'b1;
        end  
        else begin
          tcp_srv_nxt_fsm <= TCP_SERV_RPLYGIOPREQACKSRV;
        end
      end
      
      TCP_SERV_XMITGIOPRPLYSRV:
      begin
        if (!busyXmit) begin
          nxtSndOvrhdTrigSg <= 1'b1;
          nxtSendTCP <= 1'b1;
          nxtSeqNumXmit <= seqNumXmit + {8'h00,tcpDLenPrvXmit}; // SEQs=SEQs_prev+TCP_Data_Length_prev+0 
          nxtAckNumXmit <= seqNumRec + {8'h00,TCPSizeRec} - {12'h000,2'b00,headLenSaveRec,2'b00}; // ACKs–SEQc=100 
          nxtHeadLenXmit <= 8'h20; // 32 bytes
          nxtFlagsXmit <= 8'h18; // PSH ACK
          nxtWinSizeXmit <= 16'h002E; // Win(multiply by 128)=5888
          nxtTsValXmit <= 32'h03BB5B77; // Tsval=Tsval_prev+0
          nxtTsEcrXmit <= tsValRec; // Tsecr=Tsval(s)
//          nxtTCPSizeXmit <= x"0212";//x"0424"; // 1060 bytes
          nxtTCPSizeXmit <= (DEVICE_TCP_PAYLOAD + 60); //x"0424"; // 1060 bytes (1000+60)
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4XMITGIOPRPLYACKSRV;
          goWaitSrv <= 1'b1;
        end  
        else begin
          tcp_srv_nxt_fsm <= TCP_SERV_XMITGIOPRPLYSRV;
        end
      end
      
      TCP_SERV_WAIT4XMITGIOPRPLYACKSRV:
      begin
        if (cntXmitRply == 4'h2) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
        end  
        else if (timout0Srv == FULTIMSrv) begin
          tcp_srv_nxt_fsm <= TCP_SERV_XMITGIOPRPLYSRV;
          incCntRplyXmit <= 1'b1;
        end  
        else if (!cmpltRec) begin 
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4XMITGIOPRPLYACKSRV;
        end  
        else begin
//          if ((flagsRec == 8'h10) && (ackNumRec == (seqNumXmit + {8'h00,tcpDLenPrvXmit}))) begin // ACK
          if ((flagsRec == 8'h10)) begin // ACK
            tcp_srv_nxt_fsm <= TCP_SERV_WAIT4FINACKSRV;
            rstTimoutSrv <= 1'b1;  // start/restart timer
          end  
          else begin
            tcp_srv_nxt_fsm <= TCP_SERV_XMITGIOPRPLYSRV;
          end          
        end
      end
      
      TCP_SERV_WAIT4FINACKSRV:
      begin
        if (timout0Srv == FULTIMSrv) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
        end  
        else if (!cmpltRec) begin 
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4FINACKSRV;
        end  
        else begin
//       	if ((flagsRec == 8'h11) && (ackNumRec == (seqNumXmit + {8'h00,tcpDLenPrvXmit}))) begin // FIN ACK
          if ((flagsRec == 8'h11)) begin // FIN ACK
            tcp_srv_nxt_fsm <= TCP_SERV_RPLYFINACKSRV;
            rstCntRplyXmit <= 1'b1;
          end  
          else begin
            tcp_srv_nxt_fsm <= TCP_SERV_WAIT4FINACKSRV;
          end          
        end
      end
      
      TCP_SERV_RPLYFINACKSRV:
      begin
        if (!busyXmit) begin
          nxtSendTCP <= 1'b1;
          nxtSeqNumXmit <= seqNumXmit + {8'h00,tcpDLenPrvXmit}; // SEQs=SEQs_prev+
          nxtAckNumXmit <= seqNumRec + {8'h00,TCPSizeRec} - {12'h000,2'b00,headLenSaveRec,2'b00} + 1; // ACKs–SEQc=1
          nxtHeadLenXmit <= 8'h20; // 32 bytes
          nxtFlagsXmit <= 8'h11; // FIN ACK
          nxtWinSizeXmit <= 16'h002E; // Win(multiply by 128)=5888
          nxtTsValXmit <= 32'h03BB5B8C; // Tsval=Tsval_prev+21
          nxtTsEcrXmit <= tsValRec; // Tsecr=Tsval(s)
          nxtTCPSizeXmit <= 16'h0020; // 32 bytes
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4ACKSRV;
          goWaitSrv <= 1'b1;
        end  
        else begin
          tcp_srv_nxt_fsm <= TCP_SERV_RPLYFINACKSRV;
        end
      end
      
      TCP_SERV_WAIT4ACKSRV:
      begin
        if (cntXmitRply == 4'h2) begin
          tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
        end  
        else if (timout0Srv == FULTIMSrv) begin
          tcp_srv_nxt_fsm <= TCP_SERV_RPLYFINACKSRV;
          incCntRplyXmit <= 1'b1;
        end  
        else if (!cmpltRec) begin 
          tcp_srv_nxt_fsm <= TCP_SERV_WAIT4ACKSRV;
        end  
        else begin
          if ((flagsRec == 8'h10) && (ackNumRec == (seqNumXmit + {2'b00,tcpDLenPrvXmit} + 1))) begin // ACK
            tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
          end  
          else begin
            tcp_srv_nxt_fsm <= TCP_SERV_RPLYFINACKSRV;
            rstCntRplyXmit <= 1'b1;
         end
        end
      end
      
      TCP_SERV_WAITXMITFINSRV:
      begin
        rstTimoutSrv <= 1'b1;  // start/restart timer
        if (busyXmit && !nxtBusyXmit) begin
          tcp_srv_nxt_fsm <= retStateSrv;
          nxtSndOvrhdTrigSg <= 1'b0;
        end  
        else begin
          tcp_srv_nxt_fsm <= TCP_SERV_WAITXMITFINSRV;
        end
      end
          
      default:
      begin
        tcp_srv_nxt_fsm <= TCP_SERV_IDLESRV;
      end
    
    endcase
  end // always

  // ==============================================================================
  // TCP main transmit FSM PROCESS
  always @(tcp_srv_tx_pres_fsm or sendTCP or tx_dpmem_data or busyXmit or tx_dpmem_wr_cmplt or instream_fifoempty or tcpDLenPrvXmit or 
  TCPSizeXmit or seqNumXmit or ackNumXmit or headLenXmit or flagsXmit or winSizeXmit or tsValXmit or tsEcrXmit or mac_tx_done or chksmXmit)
  begin
    incCntXmit <= 1'b0;
    rstCntXmit <= 1'b0;
    
    nxtBusyXmit <= busyXmit;
    nxtTcpDLenPrvXmit <= tcpDLenPrvXmit;
    
    incCntPsdoHdXmit <= 1'b0;
    rstCntPsdoHdXmit <= 1'b0;

    tx_dpmem_wr <= 1'b0;
    // remember the values of tx_dpmem_data and TCPSizeXmit by default
    nextWrData <= tx_dpmem_data;
    tx_dpmem_addr <= 11'b0;
    sendDatagram <= 1'b0;
    sendDatagramSize <= 16'b0;
    instream_rden <= 1'b0;
    newHeaderXmit <= 1'b0;
    newByteXmit <= 1'b0;
    inByteXmit <= 8'b0;

    case(tcp_srv_tx_pres_fsm)
      TCP_SERV_TX_IDLEXMIT:
      begin
        rstCntPsdoHdXmit <= 1'b1;
        // wait until told to transmit
        if (!sendTCP) begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_IDLEXMIT;
          rstCntXmit <= 1'b1;
          nxtBusyXmit <= 1'b0;
          newHeaderXmit <= 1'b1;
        end  
        else begin
          // latch all information about the TCP datagram
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_SETHEADERXMIT;
          nxtBusyXmit <= 1'b1;
        end
      end
        
      TCP_SERV_TX_SETHEADERXMIT:
      begin
        // write header into RAM        
        if (cntXmit == headLenXmit) begin
          // header has been fully written so go to data stage
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_GETDATAXMIT;
        end  
        else begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRHEADERXMIT;
          // give the checksum the data
          newByteXmit <= 1'b1;      // send byte to checksum calculator
          // choose tx_dpmem_data and inByteXmit values
          // inByteXmit is the data for the checksum signals
          case(cntXmit)
            // write Source port number MSB
            16'h0000:
            begin
              nextWrData <= dstPrtRec[15:8];
              inByteXmit <= dstPrtRec[15:8];
              // write Source port number LSB
            end  
              
            16'h0001:
            begin
              nextWrData <= dstPrtRec[7:0];
              inByteXmit <= dstPrtRec[7:0];
            end  
                    
            // write Destination port number MSB
            16'h0002:
            begin
              nextWrData <= srcPrtRec[15:8];
              inByteXmit <= srcPrtRec[15:8];
            end  
                    
            // write Destination port number LSB
            16'h0003:
            begin
              nextWrData <= srcPrtRec[7:0];
              inByteXmit <= srcPrtRec[7:0];
            end  
                    
            // write Sequence number 3
            16'h0004:
            begin
              nextWrData <= seqNumXmit[31:24];
              inByteXmit <= seqNumXmit[31:24];
            end  
                    
            // write Sequence number 2
            16'h0005:
            begin
              nextWrData <= seqNumXmit[23:16];
              inByteXmit <= seqNumXmit[23:16];
            end  
                    
            // write Sequence number 1
            16'h0006:
            begin
              nextWrData <= seqNumXmit[15:8];
              inByteXmit <= seqNumXmit[15:8];
            end  
                    
            // write Sequence number 0
            16'h0007:
            begin
              nextWrData <= seqNumXmit[7:0];
              inByteXmit <= seqNumXmit[7:0];
            end  
                    
            // write Acknowledge number 3
            16'h0008:
            begin
              nextWrData <= ackNumXmit[31:24];
              inByteXmit <= ackNumXmit[31:24];
            end  
                    
            // write Acknowledge number 2
            16'h0009:
            begin
              nextWrData <= ackNumXmit[23:16];
              inByteXmit <= ackNumXmit[23:16];
            end  
                    
            // write Acknowledge number 1
            16'h000A:
            begin
              nextWrData <= ackNumXmit[15:8];
              inByteXmit <= ackNumXmit[15:8];
            end  
                    
            // write Acknowledge number 0
            16'h000B:
            begin
              nextWrData <= ackNumXmit[7:0];
              inByteXmit <= ackNumXmit[7:0];
            end  
                    
            // write the header length
            16'h000C:
            begin
              nextWrData <= {headLenXmit[5:2],4'b0000} ;
              inByteXmit <= {headLenXmit[5:2],4'b0000} ;
            end  
                    
            // write the flags
            16'h000D:
            begin
              nextWrData <= flagsXmit;
              inByteXmit <= flagsXmit;
            end  
                    
            // write the Window Size (1)
            16'h000E:
            begin
              nextWrData <= winSizeXmit[15:8];
              inByteXmit <= winSizeXmit[15:8];
            end  
                    
            // write the Window Size (0)
            16'h000F:
            begin
              nextWrData <= winSizeXmit[7:0];
              inByteXmit <= winSizeXmit[7:0];
            end  
                    
            // write the Checksum
            16'h0010, 16'h0011:
            begin
              nextWrData <= 8'h00;
              inByteXmit <= 8'h00;
            end  
                    
            // write the Urgent pointer
            16'h0012, 16'h0013:
            begin
              nextWrData <= 8'h00;
              inByteXmit <= 8'h00;
            end  
                    
            // write the Options
            16'h0014:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Max Segment Size 3
                nextWrData <= 8'h02;
                inByteXmit <= 8'h02;
              end  
              else begin
                // write the NOP
                nextWrData <= 8'h01;
                inByteXmit <= 8'h01;
              end
            end  
              
            16'h0015:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Max Segment Size 2
                nextWrData <= 8'h04;
                inByteXmit <= 8'h04;
              end  
              else begin
                // write the NOP
                nextWrData <= 8'h01;
                inByteXmit <= 8'h01;
              end
            end  
              
            16'h0016:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Max Segment Size 1
                nextWrData <= 8'h05;
                inByteXmit <= 8'h05;
              end  
              else begin
                // write the Timestamps kind
                nextWrData <= 8'h08;
                inByteXmit <= 8'h08;
              end
            end  
              
            16'h0017:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Max Segment Size 0
                nextWrData <= 8'hB4;
                inByteXmit <= 8'hB4;
              end  
              else begin
                // write the Timestamps length
                nextWrData <= 8'h0A;
                inByteXmit <= 8'h0A;
              end
            end  
              
            16'h0018:
            begin
              if (headLenXmit == 8'h28) begin
                // write the SACK permitted kind
                nextWrData <= 8'h04;
                inByteXmit <= 8'h04;
              end  
              else begin
                // write the Timestamps TSval 3
                nextWrData <= tsValXmit[31:24];
                inByteXmit <= tsValXmit[31:24];
              end
            end  
              
            16'h0019:
            begin
              if (headLenXmit == 8'h28) begin
                // write the SACK permitted length
                nextWrData <= 8'h02;
                inByteXmit <= 8'h02;
              end  
              else begin
                // write the Timestamps TSval 2
                nextWrData <= tsValXmit[23:16];
                inByteXmit <= tsValXmit[23:16];
              end
            end  
              
            16'h001A:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Timestamps kind
                nextWrData <= 8'h08;
                inByteXmit <= 8'h08;
              end  
              else begin
                // write the Timestamps TSval 1
                nextWrData <= tsValXmit[15:8];
                inByteXmit <= tsValXmit[15:8];
              end
            end  
              
            16'h001B:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Timestamps length
                nextWrData <= 8'h0A;
                inByteXmit <= 8'h0A;
              end  
              else begin
                // write the Timestamps TSval 0
                nextWrData <= tsValXmit[7:0];
                inByteXmit <= tsValXmit[7:0];
              end
            end  
              
            16'h001C:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Timestamps TSval 3
                nextWrData <= tsValXmit[31:24];
                inByteXmit <= tsValXmit[31:24];
              end  
              else begin
                // write the Timestamps TSecr 3
                nextWrData <= tsEcrXmit[31:24];
                inByteXmit <= tsEcrXmit[31:24];
              end
            end  
              
            16'h001D:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Timestamps TSval 2
                nextWrData <= tsValXmit[23:16];
                inByteXmit <= tsValXmit[23:16];
              end  
              else begin
                // write the Timestamps TSecr 2
                nextWrData <= tsEcrXmit[23:16];
                inByteXmit <= tsEcrXmit[23:16];
              end
            end  
              
            16'h001E:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Timestamps TSval 1
                nextWrData <= tsValXmit[15:8];
                inByteXmit <= tsValXmit[15:8];
              end  
              else begin
                // write the Timestamps TSecr 1
                nextWrData <= tsEcrXmit[15:8];
                inByteXmit <= tsEcrXmit[15:8];
              end
            end  
              
            16'h001F:
            begin
              if (headLenXmit == 8'h28) begin
                // write the Timestamps TSval 0
                nextWrData <= tsValXmit[7:0];
                inByteXmit <= tsValXmit[7:0];
              end  
              else begin
                // write the Timestamps TSecr 0
                nextWrData <= tsEcrXmit[7:0];
                inByteXmit <= tsEcrXmit[7:0];
              end
            end  
              
            16'h0020:
            begin
              // write the Timestamps TSecr 3
              nextWrData <= tsEcrXmit[31:24];
              inByteXmit <= tsEcrXmit[31:24];
            end  
                  
            16'h0021:
            begin
              // write the Timestamps TSecr 2
              nextWrData <= tsEcrXmit[23:16];
              inByteXmit <= tsEcrXmit[23:16];
            end  
                  
            16'h0022:
            begin
              // write the Timestamps TSecr 1
              nextWrData <= tsEcrXmit[15:8];
              inByteXmit <= tsEcrXmit[15:8];
            end  
                  
            16'h0023:
            begin
              // write the Timestamps TSecr 0
              nextWrData <= tsEcrXmit[7:0];
              inByteXmit <= tsEcrXmit[7:0];
            end  
                  
            16'h0024:
            begin
              // write the NOP
              nextWrData <= 8'h01;
              inByteXmit <= 8'h01;
            end  
                  
            16'h0025:
            begin
              // write the Window Scale kind
              nextWrData <= 8'h03;
              inByteXmit <= 8'h03;
            end  
                  
            16'h0026:
            begin
              // write the Window Scale length
              nextWrData <= 8'h03;
              inByteXmit <= 8'h03;
            end
                  
            16'h0027:
            begin
              // write the Window Scale shift count
              nextWrData <= 8'h07;
              inByteXmit <= 8'h07;
            end
                  
            default:
            begin
              nextWrData <= 8'b0;
              inByteXmit <= 8'b0;
            end
                  
          endcase
        end
      end
    
      TCP_SERV_TX_WRHEADERXMIT:
      begin
        // Write a byte to RAM
        if (!tx_dpmem_wr_cmplt) begin // write 2 DPMEM
          // Wait for RAM to acknowledge the write
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRHEADERXMIT;
          tx_dpmem_wr <= 1'b1;
          tx_dpmem_addr <= cntXmit[10:0] + {3'b000,8'h22}; // 0x22 is start address of TCP
        end  
        else begin
          // When it does increment the counter and go to next header byte
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_SETHEADERXMIT;
          incCntXmit <= 1'b1;
        end
      end
    
      TCP_SERV_TX_GETDATAXMIT:
      begin
        tcpDLenLeftXmit = cntXmit - {8'h00,headLenXmit};
        // Read data from RAM if there is more left
        if (cntXmit == TCPSizeXmit) begin
          // If there is no more data left
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_SETPSEUDOHEADXMIT;
        end  
        else begin
          // Handle GIOP 1.2 Reply with No Exception
          case(tcpDLenLeftXmit)
            // write the GIOP Magic Number 0
            16'h0000:
            begin
              nextWrData <= MAGIC_NUM_GIOP[31:24];
              inByteXmit <= MAGIC_NUM_GIOP[31:24];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Magic Number 1
            16'h0001:
            begin
              nextWrData <= MAGIC_NUM_GIOP[23:16];
              inByteXmit <= MAGIC_NUM_GIOP[23:16];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Magic Number 2
            16'h0002:
            begin
              nextWrData <= MAGIC_NUM_GIOP[15:8];
              inByteXmit <= MAGIC_NUM_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Magic Number 3
            16'h0003:
            begin
              nextWrData <= MAGIC_NUM_GIOP[7:0];
              inByteXmit <= MAGIC_NUM_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
          
            // write the GIOP Version Number MSB
            16'h0004:
            begin
              nextWrData <= VER_GIOP[15:8];
              inByteXmit <= VER_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Version Number LSB
            16'h0005:
            begin
              nextWrData <= VER_GIOP[7:0];
              inByteXmit <= VER_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Flags (little-endian)
            16'h0006:
            begin
              nextWrData <= FLAG_LIT_END_GIOP;
              inByteXmit <= FLAG_LIT_END_GIOP;
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Message Type (Reply)
            16'h0007:
            begin
              nextWrData <= MSG_TYP_REP_GIOP;
              inByteXmit <= MSG_TYP_REP_GIOP;
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Message Size 0 (Test: req_shortseq())
            16'h0008:
            begin
              nextWrData <= MSG_SIZE_REP_SHORTSEQ_GIOP[31:24];// Todo: it should be calculated
              inByteXmit <= MSG_SIZE_REP_SHORTSEQ_GIOP[31:24];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Message Size 1 (Test: req_shortseq())
            16'h0009:
            begin
              nextWrData <= MSG_SIZE_REP_SHORTSEQ_GIOP[23:16];
              inByteXmit <= MSG_SIZE_REP_SHORTSEQ_GIOP[23:16];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Message Size 2 (Test: req_shortseq())
            16'h000A:
            begin
              nextWrData <= MSG_SIZE_REP_SHORTSEQ_GIOP[15:8];
              inByteXmit <= MSG_SIZE_REP_SHORTSEQ_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Message Size 3 (Test: req_shortseq())
            16'h000B:
            begin
              nextWrData <= MSG_SIZE_REP_SHORTSEQ_GIOP[7:0];
              inByteXmit <= MSG_SIZE_REP_SHORTSEQ_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Request ID 0
            16'h000C:
            begin
              nextWrData <= REQ_ID_GIOP[31:24];
              inByteXmit <= REQ_ID_GIOP[31:24];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Request ID 1
            16'h000D:
            begin
              nextWrData <= REQ_ID_GIOP[23:16];
              inByteXmit <= REQ_ID_GIOP[23:16];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Request ID 2
            16'h000E:
            begin
              nextWrData <= REQ_ID_GIOP[15:8];
              inByteXmit <= REQ_ID_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Request ID 3
            16'h000F:
            begin
              nextWrData <= REQ_ID_GIOP[7:0];
              inByteXmit <= REQ_ID_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Reply status 0
            16'h0010:
            begin
              nextWrData <= REP_STATUS_GIOP[31:24];
              inByteXmit <= REP_STATUS_GIOP[31:24];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Reply status 1
            16'h0011:
            begin
              nextWrData <= REP_STATUS_GIOP[23:16];
              inByteXmit <= REP_STATUS_GIOP[23:16];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Reply status 2
            16'h0012:
            begin
              nextWrData <= REP_STATUS_GIOP[15:8];
              inByteXmit <= REP_STATUS_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Reply status 3
            16'h0013:
            begin
              nextWrData <= REP_STATUS_GIOP[7:0];
              inByteXmit <= REP_STATUS_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Sequence Length 0
            16'h0014:
            begin
              nextWrData <= SEQ_LEN_REP_GIOP[31:24];
              inByteXmit <= SEQ_LEN_REP_GIOP[31:24];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Sequence Length 1
            16'h0015 :
            begin
              nextWrData <= SEQ_LEN_REP_GIOP[23:16];
              inByteXmit <= SEQ_LEN_REP_GIOP[23:16];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Sequence Length 2
            16'h0016 :
            begin
              nextWrData <= SEQ_LEN_REP_GIOP[15:8];
              inByteXmit <= SEQ_LEN_REP_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Sequence Length 3
            16'h0017 :
            begin
              nextWrData <= SEQ_LEN_REP_GIOP[7:0];
              inByteXmit <= SEQ_LEN_REP_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Stub Data Length 0
            16'h0018 :
            begin
              nextWrData <= REP_STUB_DATA_LEN_GIOP[31:24]; // Todo: it should be calculated
              inByteXmit <= REP_STUB_DATA_LEN_GIOP[31:24];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Stub Data Length 1
            16'h0019 :
            begin
              nextWrData <= REP_STUB_DATA_LEN_GIOP[23:16];
              inByteXmit <= REP_STUB_DATA_LEN_GIOP[23:16];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Stub Data Length 2
            16'h001A :
            begin
              nextWrData <= REP_STUB_DATA_LEN_GIOP[15:8];
              inByteXmit <= REP_STUB_DATA_LEN_GIOP[15:8];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            // write the GIOP Stub Data Length 3
            16'h001B :
            begin
              nextWrData <= REP_STUB_DATA_LEN_GIOP[7:0];
              inByteXmit <= REP_STUB_DATA_LEN_GIOP[7:0];
              newByteXmit <= 1'b1;      // send byte to checksum calculator
              tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
            end
              
            default:
            begin
              // if there is more data begin perform a read from input stream FIFO
              if (instream_fifoempty) begin
                // Wait for RAM to acknowledge read
                tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_GETDATAXMIT;
                instream_rden <= 1'b0;
              end  
              else begin
                // Then get ready to write the data
                tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
                instream_rden <= 1'b1;
                latchRdDataXmit <= 1'b1; // Todo: is it necessary???
                // give the checksum the data
                newByteXmit <= 1'b1;      // send byte to checksum calculator
                inByteXmit <= instream_rddata;
                nextWrData <= instream_rddata; // Todo: or rdLatchMem???
              end
            end
          endcase
    
        end
      end
    
      TCP_SERV_TX_WRDATAXMIT:
      begin
        instream_rden <= 1'b0;      	
        // Write one data byte
        if (!tx_dpmem_wr_cmplt) begin // write 2 DPMEM
          // Wait for RAM to acknowledge the write
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRDATAXMIT;
          tx_dpmem_wr <= 1'b1;
          tx_dpmem_addr <= cntXmit[10:0] + {3'b000,8'h22}; // TCP address starts from 0x22
        end  
        else begin
          // When done, read another byte
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_GETDATAXMIT;
          incCntXmit <= 1'b1;
        end
      end
    
      TCP_SERV_TX_WRPSEUDOHEADXMIT:
      begin
        tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_SETPSEUDOHEADXMIT;
        incCntPsdoHdXmit <= 1'b1;
      end
    
      TCP_SERV_TX_SETPSEUDOHEADXMIT:
      begin
        if (cntPsdoHdXmit == 4'hC ) begin
        // If there is no more data left, wait until the frame completes sending
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WAITFORCHECKSUMCALCXMIT;
          // if uneven number of bytes, pad the checksum with a byte of 0s
          if (TCPSizeXmit[0]) begin
            newByteXmit <= 1'b1;
            inByteXmit <= 8'b0;
          end
        end  
        else begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRPSEUDOHEADXMIT;
          // give the checksum the data
          newByteXmit <= 1'b1;      // send byte to checksum calculator
          // choose tx_dpmem_data and inByteXmit values
          // inByteXmit is the data for the checksum signals
          case(cntPsdoHdXmit)
            // write Source ip address number 3
            4'b0000 :
            begin
              inByteXmit <= DEVICE_IP[31:24];
            end
              
              // write Source ip address number 2
            4'b0001 :
            begin
              inByteXmit <= DEVICE_IP[23:16];
            end
                    
            // write Source ip address number 1
            4'b0010 :
            begin
              inByteXmit <= DEVICE_IP[15:8];
            end
                    
            // write Source ip address number 0
            4'b0011 :
            begin
              inByteXmit <= DEVICE_IP[7:0];
            end
                    
            // write Destination ip address number 3
            4'b0100 :
            begin
              inByteXmit <= destinationIP[31:24];
            end
                    
            // write Destination ip address number 2
            4'b0101 :
            begin
              inByteXmit <= destinationIP[23:16];
            end
                    
            // write Destination ip address number 1
            4'b0110 :
            begin
              inByteXmit <= destinationIP[15:8];
            end
                    
            // write Destination ip address number 0
            4'b0111 :
            begin
              inByteXmit <= destinationIP[7:0];
            end
                    
            // write Zeros
            4'b1000 :
            begin
              inByteXmit <= 8'h00 ;
            end
                    
            // write Protocol
            4'b1001 :
            begin
              inByteXmit <= 8'h06 ;
            end
                    
            // write TCP Length MSB
            4'b1010 :
            begin
              inByteXmit <= TCPSizeXmit[15:8];
            end
                    
            // write TCP Length LSB
            4'b1011 :
            begin
              inByteXmit <= TCPSizeXmit[7:0];
            end
                    
            default:
            begin
              inByteXmit <= 8'b0;
            end
                  
          endcase
        end
      end
    
      // if there was an uneven number of bytes, begin the checksum method will require an 
      // extra clock cycle to work it out
      TCP_SERV_TX_WAITFORCHECKSUMCALCXMIT:
      begin
        tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WAITFORCHECKSUMXMIT;
      end
        
      // setup the write data bus to write the TCP checksum
      TCP_SERV_TX_WAITFORCHECKSUMXMIT:
      begin
        tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRITECHKSUM1XMIT;
        nextWrData <= chksmXmit[15:8];
      end
        
      TCP_SERV_TX_WRITECHKSUM1XMIT:
      begin
        // write the TCP checksum MSB
        if (!tx_dpmem_wr_cmplt) begin // write 2 DPMEM
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRITECHKSUM1XMIT;
          tx_dpmem_wr <= 1'b1;
          tx_dpmem_addr <= {3'b000,8'h32}; // TCP Checksum address start at 0x32
        end  
        else begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRITECHKSUM2XMIT;
          // setup the lower byte of the TCP checksum to write
          nextWrData <= chksmXmit[7:0];
        end  
      end
    
      TCP_SERV_TX_WRITECHKSUM2XMIT:
      begin
        // write the TCP checksum LSB
        if (!tx_dpmem_wr_cmplt) begin // write 2 DPMEM
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRITECHKSUM2XMIT;
          tx_dpmem_wr <= 1'b1;
          tx_dpmem_addr <= {3'b000,8'h33};
        end  
        else begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRITEFINISHXMIT;
          sendDatagram <= 1'b1;
          sendDatagramSize <= TCPSizeXmit;
        end  
      end
          
      TCP_SERV_TX_WRITEFINISHXMIT:
      begin
        if (mac_tx_done) begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_IDLEXMIT;
          nxtTcpDLenPrvXmit <= TCPSizeXmit - {8'h00,headLenXmit};
        end  
        else begin
          tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_WRITEFINISHXMIT;
        end  
      end
        
      default:
      begin
        tcp_srv_tx_nxt_fsm <= TCP_SERV_TX_IDLEXMIT;
      end
    endcase
  end // always
  
  // ==============================================================================
  // TCP main receive FSM PROCESS
  always @(tcp_srv_rx_pres_fsm or dstPrtRec or srcPrtRec or seqNumRec or ackNumRec or headLenRec or flagsRec or winSizeRec or newDatagram or 
  optLenRec or optTypRec or maxSegSizeRec or tsValRec or tsEcrRec or sAckPermitRec or winScaleRec or cmpltRec or mac_rx_done or timout0Rec or
  datagramSize or rxData or TCPSizeRec or cntRec or CntOptRec or mac_rx_data_new or chkSumRec or protocolIn or chkSumRec or isGIOP or headLenSaveRec)
  begin
    // Signal defaults
    incCntPsdoHdRec <= 1'b0;
    rstCntPsdoHdRec <= 1'b0;
    
    rstTimoutRec <= 1'b0;
    
    incCntOptRec <= 1'b0;
    rstCntOptRec <= 1'b0;
    incCntRec <= 1'b0;
    rstCntRec <= 1'b0;
    // remember the values of tx_dpmem_data and TCPSizeRec by default
    nxtTCPSizeRec <= TCPSizeRec;
    newHeaderRec <= 1'b0;
    newByteRec <= 1'b0;
    inByteRec <= 8'b0;
    latchDestinationIP <= 1'b0;
    
    // remember these signals
    nxtDstPrtRec <= dstPrtRec;
    nxtSrcPrtRec <= srcPrtRec;
    nxtSeqNumRec <= seqNumRec;
    nxtAckNumRec <= ackNumRec;
    nxtHeadLenRec <= headLenRec;
    nxtHeadLenSaveRec <= headLenSaveRec;
    nxtFlagsRec <= flagsRec;
    nxtWinSizeRec <= winSizeRec;
    nxtChkSumRec <= chkSumRec;
    
    nxtOptLenRec <= optLenRec;
    nxtOptTypRec <= optTypRec;
    
    nxtMaxSegSizeRec <= maxSegSizeRec;
    nxtTsValRec <= tsValRec;
    nxtTsEcrRec <= tsEcrRec;
    nxtSAckPermitRec <= sAckPermitRec;
    nxtWinScaleRec <= winScaleRec;
    
    nxtCmpltRec <= cmpltRec;
    
    nxtIsGIOP <= isGIOP;
      
    case(tcp_srv_rx_pres_fsm)
      TCP_SERV_RX_IDLE:
      begin
        rstCntPsdoHdRec <= 1'b1;
        rstTimoutRec <= 1'b1;
        nxtCmpltRec <= 1'b0;
        rstCntRec <= 1'b1;
        rstCntOptRec <= 1'b1;
        // wait for a new datagram to arrive with the correct protocol for TCP
        if (!newDatagram || protocolIn != 8'd6) begin
          tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_IDLE;
          newHeaderRec <= 1'b1;
        end  
        else begin
          tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_SETUPWRITETCPBYTEREC;
          // latch or remember the inputs about the datagram from the previous layer
          latchDestinationIP <= 1'b1;
          nxtTCPSizeRec <= datagramSize;
          nxtIsGIOP <= 1'b1;
        end
      end
    
      TCP_SERV_RX_SETUPWRITETCPBYTEREC:
      begin
        // if finished write the checksum and continue
        if (cntRec == TCPSizeRec) begin
          tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_SETPSEUDOHEADREC;
          rstTimoutRec <= 1'b1;
        end  
        else begin
    
          tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WRITETCPBYTEREC;
          // give the checksum the data
          newByteRec <= 1'b1;
          // set the TCP data to send according the value of count
          case(cntRec)
            // latch the source port MSB
            16'b0000000000000000 :
            begin
              nxtSrcPrtRec[15:8] <= rxData;
              inByteRec <= rxData;
            end
            
            // latch the source port LSB
            16'b0000000000000001 :
            begin
              nxtSrcPrtRec[7:0] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the destination port MSB
            16'b0000000000000010 :
            begin
              nxtDstPrtRec[15:8] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the destination port LSB
            16'b0000000000000011 :
            begin
              nxtDstPrtRec[7:0] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the sequence number (3)
            16'b0000000000000100 :
            begin
              // check the destination port
              if (dstPrtRec != DEVICE_TCP_PORT) begin
                tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_IDLE;
              end
              nxtSeqNumRec[31:24] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the sequence number (2)
            16'b0000000000000101 :
            begin
              nxtSeqNumRec[23:16] <= rxData;
              inByteRec <= rxData;
            end
                
            // latch the sequence number (1)
            16'b0000000000000110 :
            begin
              nxtSeqNumRec[15:8] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the sequence number (0)
            16'b0000000000000111 :
            begin
              nxtSeqNumRec[7:0] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the acknowledge number (3)
            16'b0000000000001000 :
            begin
              nxtAckNumRec[31:24] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the acknowledge number (2)
            16'b0000000000001001 :
            begin
              nxtAckNumRec[23:16] <= rxData;
              inByteRec <= rxData;
            end
                
            // latch the acknowledge number (1)
            16'b0000000000001010 :
            begin
              nxtAckNumRec[15:8] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the acknowledge number (0)
            16'b0000000000001011 :
            begin
              nxtAckNumRec[7:0] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the header length
            16'b0000000000001100 :
            begin
              nxtHeadLenRec <= {2'b00, rxData[7:4], 2'b00};
              nxtHeadLenSaveRec <= rxData[7:4];
              inByteRec <= rxData;
            end
              
            // latch the flagsRec
            16'b0000000000001101 :
            begin
              nxtFlagsRec <= rxData;
              nxtHeadLenRec <= headLenRec - 8'h13 ;
              inByteRec <= rxData;
            end
              
            // latch the Window Size (1)
            16'b0000000000001110 :
            begin
              nxtWinSizeRec[15:8] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the Window Size (0)
            16'b0000000000001111 :
            begin
              nxtWinSizeRec[7:0] <= rxData;
              inByteRec <= rxData;
            end
              
            // latch the Checksum MSB
            16'b0000000000010000 :
            begin
              nxtChkSumRec[15:8] <= rxData;
              inByteRec <= 8'h00 ;
            end
              
            // latch the Checksum LSB
            16'b0000000000010001 :
            begin
              nxtChkSumRec[7:0] <= rxData;
              inByteRec <= 8'h00 ;
            end
              
            // latch the Urgent pointer
            16'b0000000000010010  | 16'b0000000000010011 :
            begin
              nxtOptLenRec <= 8'hFF ;
              rstCntOptRec <= 1'b1;
              inByteRec <= 8'h00 ;
            end
              
            // all other cases - TCP header options and data
            // must be the same as what we received
            default:
            begin
              if (headLenRec != 8'h00 ) begin
                nxtHeadLenRec <= headLenRec - 8'h01 ;
                inByteRec <= 8'h00 ;
                incCntOptRec <= 1'b1;
                if (CntOptRec == optLenRec) begin
                  rstCntOptRec <= 1'b1;
                  nxtOptTypRec <= TCP_SERV_RX_OPTNON;
                end
                else if (CntOptRec == 8'h00)  begin  
                    
                  case(rxData)
                    // Get the Maximum Segment Size option
                    8'h02 :
                    begin
                      nxtOptLenRec <= 8'h03 ;
                      nxtOptTypRec <= TCP_SERV_RX_OPTMAXSEGSIZE;
                      inByteRec <= rxData;
                    end
                
                    // Get the SACK Permitted option
                    8'h04 :
                    begin
                      nxtOptLenRec <= 8'h01 ;
                      nxtOptTypRec <= TCP_SERV_RX_OPTSACKPERMITTED;
                      inByteRec <= rxData;
                    end
                
                    // Get the Timestamps option
                    8'h08 :
                    begin
                      nxtOptLenRec <= 8'h09 ;
                      nxtOptTypRec <= TCP_SERV_RX_OPTTIMESTAMP;
                      inByteRec <= rxData;
                    end
                
                    // Get the NOP option
                    8'h01 :
                    begin
                      nxtOptLenRec <= 8'hFF ;
                      nxtOptTypRec <= TCP_SERV_RX_OPTNOP;
                      rstCntOptRec <= 1'b1;
                      inByteRec <= rxData;
                    end
                
                    // Get the Window Scale option
                    8'h03 :
                    begin
                      nxtOptLenRec <= 8'h02 ;
                      nxtOptTypRec <= TCP_SERV_RX_OPTWINSCLE;
                      inByteRec <= rxData;
                    end
                
                    default:
                    begin
                      nxtOptLenRec <= 8'hFF ;
                      nxtOptTypRec <= TCP_SERV_RX_OPTNON;
                      inByteRec <= rxData;
                    end
              
                  endcase
            
                end // if
                  
                case(optTypRec)
                  // Get the Maximum Segment Size option
                  TCP_SERV_RX_OPTMAXSEGSIZE: // 2
                  begin
            
                    inByteRec <= rxData;
                    case(CntOptRec)
                      8'h02 :
                      begin
                        nxtMaxSegSizeRec[15:8] <= rxData;
                      end
                
                      8'h03 :
                      begin
                        nxtMaxSegSizeRec[7:0] <= rxData;
                      end
                  
                      default:
                      begin
                        nxtMaxSegSizeRec[15:0] <= 16'h0;
                      end
                
                    endcase
                  end
              
                  // Get the SACK Permitted option
                  TCP_SERV_RX_OPTSACKPERMITTED: // 3
                  begin
                    inByteRec <= rxData;
                    case(CntOptRec)
              
                      8'h01 :
                      begin
                        nxtSAckPermitRec <= 1'b1;
                      end
              
                      default:
                      begin
                        nxtSAckPermitRec <= 1'b0;
                      end
              
                    endcase
                  end
              
                  // Get the Timestamps option
                  TCP_SERV_RX_OPTTIMESTAMP: // 4
                  begin
                    inByteRec <= rxData;
                    case(CntOptRec)
                      8'h02 :
                      begin
                        nxtTsValRec[31:24] <= rxData;
                      end
                
                      8'h03 :
                      begin
                        nxtTsValRec[23:16] <= rxData;
                      end
              
                      8'h04 :
                      begin
                        nxtTsValRec[15:8] <= rxData;
                      end
              
                      8'h05 :
                      begin
                        nxtTsValRec[7:0] <= rxData;
                      end
              
                      8'h06 :
                      begin
                        nxtTsEcrRec[31:24] <= rxData;
                      end
              
                      8'h07 :
                      begin
                        nxtTsEcrRec[23:16] <= rxData;
                      end
              
                      8'h08 :
                      begin
                        nxtTsEcrRec[15:8] <= rxData;
                      end
              
                      8'h09 :
                      begin
                        nxtTsEcrRec[7:0] <= rxData;
                      end
              
                      default:
                      begin
                        nxtTsEcrRec[15:0] <= 16'b0;
                      end
              
                    endcase
                  end
              
                  // Get the Window Scale option
                  TCP_SERV_RX_OPTWINSCLE: // 5
                  begin
                    inByteRec <= rxData;
                    case(CntOptRec)
                      8'h02 :
                      begin
                        nxtWinScaleRec <= rxData; // Todo: <= 2^rxData
                      end
              
                      default:
                      begin
                        nxtWinScaleRec <= 8'b0;
                      end
                
                    endcase
                  end
              
                  default:
                  begin
                    inByteRec <= rxData;
                  end
                endcase // optTypRec
              end
              else begin // TCP Data
                tcpDLenLeftRec = cntRec - {8'h00, 2'b00, headLenSaveRec, 2'b00};
                inByteRec <= rxData;
                // extract GIOP 1.2 data  
                case(tcpDLenLeftRec)
    
                  // check the GIOP Magic Number 0
                  16'h0000 :
                  begin
                    if (MAGIC_NUM_GIOP[31:24] != rxData) 
                      nxtIsGIOP <= 1'b0;
                  end
                
                  // check the GIOP Magic Number 1
                  16'h0001 :
                  begin
                    if (MAGIC_NUM_GIOP[23:16] != rxData) begin
                      nxtIsGIOP <= 1'b0;
                    end
                  end
             
                  // check the GIOP Magic Number 2
                  16'h0002 :
                  begin
                    if (MAGIC_NUM_GIOP[15:8] != rxData) begin
                      nxtIsGIOP <= 1'b0;
                    end
                  end
             
                  // check the GIOP Magic Number 3
                  16'h0003 :
                  begin
                    if (MAGIC_NUM_GIOP[7:0] != rxData) begin
                      nxtIsGIOP <= 1'b0;
                    end
                  end
             
                  // check the GIOP Version Number MSB
                  16'h0004 :
                  begin
                    if (VER_GIOP[15:8] != rxData) begin
                      nxtIsGIOP <= 1'b0;
                    end
                  end
             
                  // check the GIOP Version Number LSB
                  16'h0006 :
                  begin
                    if (VER_GIOP[7:0] != rxData) begin
                      nxtIsGIOP <= 1'b0;
                    end
                  end
             
                  // check the GIOP Flags (little-endian)
                  16'h0007 :
                  begin
                    if (FLAG_LIT_END_GIOP != rxData) begin
                      nxtIsGIOP <= 1'b1;
                    end
                  end
             
                  // check the GIOP Message Type (Request)
                  16'h0008 :
                  begin
                    if (MSG_TYP_REQ_GIOP != rxData) begin
                      nxtIsGIOP <= 1'b1;
                    end
                  end
             
                  // check the GIOP Message Size 0 (Test: req_shortseq())
                  16'h0009 :
                  begin
                    if (MSG_SIZE_REQ_SHORTSEQ_GIOP[31:24] != rxData) begin
                      nxtIsGIOP <= 1'b1;
                    end
                  end
             
                  // check the GIOP Message Size 1 (Test: req_shortseq())
                  16'h000A :
                  begin
                    if (MSG_SIZE_REQ_SHORTSEQ_GIOP[23:16] != rxData) begin
                      nxtIsGIOP <= 1'b1;
                    end
                  end
             
                  // check the GIOP Message Size 2 (Test: req_shortseq())
                  16'h000B :
                  begin
                    if (MSG_SIZE_REQ_SHORTSEQ_GIOP[15:8] != rxData) begin
                      nxtIsGIOP <= 1'b1;
                    end
                  end
             
                  // check the GIOP Message Size 3 (Test: req_shortseq())
                  16'h000C :
                  begin
                    if (MSG_SIZE_REQ_SHORTSEQ_GIOP[7:0] != rxData) begin
                      nxtIsGIOP <= 1'b1;
                    end
                  end
                
//                default:
//                 begin
//                  nxtIsGIOP <= 1'b0;
//                 end
                
                endcase // tcpDLenLeftRec
            
              end // TCP Data else
            end // default
          endcase // cntRec
        end // else: cntRec == TCPSizeRec
      end // TCP_SERV_RX_SETUPWRITETCPBYTEREC
    
      TCP_SERV_RX_WRPSEUDOHEADREC:
      begin
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_SETPSEUDOHEADREC;
        incCntPsdoHdRec <= 1'b1;
      end
    
      TCP_SERV_RX_SETPSEUDOHEADREC:
      begin
        if (cntPsdoHdRec == 4'hC)  begin
          tcp_srv_rx_nxt_fsm <=  TCP_SERV_RX_WAITFORCHECKSUMCALCREC;
          // if uneven number of bytes, pad the checksum with a byte of 0s
          if (TCPSizeRec[0]) begin
          newByteRec <= 1'b1;
          inByteRec <= 8'b0;
          end
        end
        else begin
          tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WRPSEUDOHEADREC;
          // give the checksum the data
          newByteRec <= 1'b1;      // send byte to checksum calculator
          // choose tx_dpmem_data and inByteXmit values
          // inByteXmit is the data for the checksum signals
          case(cntPsdoHdRec)
            // write Source ip address number 3
            4'b0000 :
            begin
              inByteRec <= DEVICE_IP[31:24];
            end
                  
            // write Source ip address number 2
            4'b0001 :
            begin
              inByteRec <= DEVICE_IP[23:16];
            end
                  
            // write Source ip address number 1
            4'b0010 :
            begin
              inByteRec <= DEVICE_IP[15:8];
            end
                  
            // write Source ip address number 0
            4'b0011 :
            begin
              inByteRec <= DEVICE_IP[7:0];
            end
                  
            // write Destination ip address number 3
            4'b0100 :
            begin
              inByteRec <= destinationIP[31:24];
            end
                  
            // write Destination ip address number 2
            4'b0101 :
            begin
              inByteRec <= destinationIP[23:16];
            end
                  
            // write Destination ip address number 1
            4'b0110 :
            begin
              inByteRec <= destinationIP[15:8];
            end
                  
             // write Destination ip address number 0
            4'b0111 :
            begin
              inByteRec <= destinationIP[7:0];
            end
                
            // write Zeros
            4'b1000 :
            begin
              inByteRec <= 8'h00 ;
            end
                
            // write Protocol
            4'b1001 :
            begin
              inByteRec <= 8'h06 ;
            end
                
            // write TCP Length MSB
            4'b1010 :
            begin
              inByteRec <= TCPSizeRec[15:8];
            end
                
            // write TCP Length LSB
            4'b1011 :
            begin
              inByteRec <= TCPSizeRec[7:0];
            end
                
            default:
            begin
              inByteRec <= 8'b0;
            end
          endcase
        end
      end
    
      TCP_SERV_RX_WRITETCPBYTEREC:
      begin
        // write the new TCP data
        // go back and get the next byte of data
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_SETUPWRITETCPBYTEREC;
        rstTimoutRec <= 1'b1;
        incCntRec <= 1'b1;
      end
        
      // if there was an uneven number of bytes, begin the checksum method will require an 
      // extra clock cycle to work it out
       TCP_SERV_RX_WAITFORCHECKSUMCALCREC:
      begin
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WAITFORCHECKSUMREC;
      end
        
      // setup the write data bus to write the TCP checksum
      TCP_SERV_RX_WAITFORCHECKSUMREC:
      begin
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WRITECHKSUM1REC;
      end
        
      TCP_SERV_RX_WRITECHKSUM1REC:
      begin
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WRITECHKSUM2REC;
      end
    
      TCP_SERV_RX_WRITECHKSUM2REC:
      begin
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WAITFINREC;
        rstTimoutRec <= 1'b1;
      end
    
      TCP_SERV_RX_WAITFINREC:
      begin
//      if (timout0Rec == FULTIMRec) begin
//        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_IDLE;
//      end      
//          else if (mac_rx_done) begin
        tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_IDLE;
        if (chksmCalRec == chkSumRec) begin
          nxtCmpltRec <= 1'b1;
        end
//      end  
//          else begin
//            tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_WAITFINREC;
//          end
      end
        
      default:
      begin
          tcp_srv_rx_nxt_fsm <= TCP_SERV_RX_IDLE;
      end
      
    endcase
  end // always

  // Xmit Checksum calculation //---------------------------------------
  assign chksmIntXmit = chksmLongXmit[15:0] + chksmLongXmit[16];
  assign chksmXmit = ~chksmIntXmit;

  // ==============================================================================
  always @(posedge clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      chkStateXmit <= stMSB;
      latchMSBXmit <= 8'b0;
      chksmLongXmit <= 17'b0;
      validXmit <= 1'b0;
    end    
    else begin  
      case(chkStateXmit)
        stMSB:
        begin
          if (newHeaderXmit) begin
            chkStateXmit <= stMSB;
            chksmLongXmit <= 17'b0;
            validXmit <= 1'b0;
          end  
          else if (newByteXmit) begin
            chkStateXmit <= stLSB;
            latchMSBXmit <= inByteXmit;
            validXmit <= 1'b0;
          end  
          else begin
            chkStateXmit <= stMSB;
            validXmit <= 1'b1;
          end
        end
              
        stLSB:
        begin
          validXmit <= 1'b0;    
          if (newHeaderXmit) begin
            chkStateXmit <= stMSB;
            chksmLongXmit <= 17'b0;
          end  
          else if (newByteXmit) begin
            chkStateXmit <= stMSB;
            chksmLongXmit <= {1'b0,chksmIntXmit} + {1'b0,latchMSBXmit,inByteXmit};
          end  
          else
            chkStateXmit <= stLSB;
          
        end
              
        default:
        begin
          chkStateXmit <= stMSB;
          validXmit <= 1'b0;
        end
          
      endcase
    end
  end // always

  // Rec Checksum calculation -----------------------------------------
  assign chksmIntRec = chksmLongRec[15:0] + chksmLongRec[16];
  assign chksmCalRec = ~chksmIntRec;

  // ==============================================================================
  always @(posedge clk or negedge reset_n) 
  begin
    if (!reset_n) begin
    chkStateRec <= stMSB;
    latchMSBRec <= 8'b0;
    chksmLongRec <= 17'b0;
    validRec <= 1'b0;
  end    
  else begin  
    case(chkStateRec)
      stMSB:
    begin
      if (newHeaderRec) begin
        chkStateRec <= stMSB;
      chksmLongRec <= 17'b0;
      validRec <= 1'b0;
      end  
      else if (newByteRec) begin
        chkStateRec <= stLSB;
        latchMSBRec <= inByteRec;
        validRec <= 1'b0;
      end  
      else begin
        chkStateRec <= stMSB;
        validRec <= 1'b1;
      end
    end  
    
    stLSB:
    begin
      validRec <= 1'b0;    
      if (newHeaderRec) begin
      chkStateRec <= stMSB;
      chksmLongRec <= 17'b0;
      end        
      else if (newByteRec) begin
      chkStateRec <= stMSB;
      chksmLongRec <= {1'b0,chksmIntRec} + {1'b0,latchMSBRec,inByteRec};
      end        
      else
      chkStateRec <= stLSB;
      
    end  
          
    default:
    begin
      chkStateRec <= stMSB;
      validRec <= 1'b0;
    end  
    endcase
  end
  
  end // always

endmodule
