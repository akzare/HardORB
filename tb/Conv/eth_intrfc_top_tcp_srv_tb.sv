/***********************************************************************
  $FILENAME    : eth_intrfc_top_tb.v

  $TITLE       : Conventional testbech for TCP (server)/IP off-loading

  $DATE        : 19 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : 

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module eth_intrfc_top_tb;
  import eth_intrfc_top_pkg::*;


  // =================================================================
  // C O N S T A N T S
  
  
  // =================================================================
  // I N T E R N A L   S I G N A L S
  
  event monitor_event;

  integer rec_timeout = 0;
  
  bit  [7:0]   ARP_CLIENT_REQ_q[$];
  bit  [7:0]   ICMP_CLIENT_PING_REQ_q[$];
  bit  [7:0]   TCP_CLIENT_SYN_q[$];
  bit  [7:0]   TCP_CLIENT_SYNC_ACK_ACK_q[$];
  bit  [7:0]   TCP_CLIENT_GIOP_REQ_q[$];
  bit  [7:0]   TCP_CLIENT_GIOP_DATA_ACK_q[$];
  bit  [7:0]   TCP_CLIENT_FIN_ACK_q[$];
  bit  [7:0]   TCP_CLIENT_ACK_LAST_q[$];
  
  bit  [7:0]   ARP_SERV_REPLY_q[$];
  bit  [7:0]   ICMP_SERV_REPLY_q[$];
  bit  [7:0]   TCP_SERV_SYNC_ACK_REPLY_q[$];
  bit  [7:0]   TCP_SERV_GIOP_REQ_ACK_REPLY_q[$];
  bit  [7:0]   TCP_SERV_GIOP_DATA_REPLY_q[$];
  bit  [7:0]   TCP_SERV_FIN_ACK_REPLY_q[$];

  bit  [7:0]   REC_MSG_q[$];


  reg  [7:0]   instream_wrdata = 8'b0; 
  reg          instream_wrclk = 1'b0; 
  reg          instream_wren = 1'b0;
  wire         instream_fifofull;
  
  reg          reset_n = 1'b1;
  reg          sys_clk = 1'b1;
  
  reg          rx_write = 1'b0;
  reg  [7:0]   rx_dbout = 8'b0;
  reg          rx_eof = 1'b0;
  
  reg          tx_macread = 1'b0;
  wire [7:0]   tx_fifodata;
  wire         tx_fifoeof;
  wire         tx_fifoempty;
  
  reg          rxmac_clk    = 1'b0;
  reg          rxmac_clk_en = 1'b0;
  reg          txmac_clk    = 1'b1;
  reg          txmac_clk_en = 1'b1;

  reg          pkt_gen_en_ri = 1'b0;
    
  // =================================================================
  // I N S T A T I A T E   D U T
  eth_intrfc_top #(
    .DEST_IP            (DEST_IP           ),
    .DEST_TCPCLNT_PORT  (DEST_TCPCLNT_PORT ),
    .SRC_TCPCLNT_PORT   (SRC_TCPCLNT_PORT  ),
    .DEVICE_IP          (DEVICE_IP         ),
    .DEVICE_MAC         (DEVICE_MAC        ),
    .DEVICE_TCP_PORT    (DEVICE_TCP_PORT   ),
    .DEVICE_TCP_PAYLOAD (DEVICE_TCP_PAYLOAD),
    .DEVICE_UDP_PORT    (DEVICE_UDP_PORT   ),
    .DEST_UDP_PORT      (DEST_UDP_PORT     )
  )
  DUT 
  (    
    .reset_n            (reset_n),
    .sys_clk            (sys_clk),
    .txmac_clk          (txmac_clk),
    .rxmac_clk          (rxmac_clk),
    .txmac_clk_en       (txmac_clk_en),
    .rxmac_clk_en       (rxmac_clk_en),
    .rx_write           (rx_write),
    .rx_dbout           (rx_dbout),
    .rx_eof             (rx_eof),
    .tx_macread         (tx_macread),
    .tx_fifodata        (tx_fifodata),
    .tx_fifoeof         (tx_fifoeof),
    .tx_fifoempty       (tx_fifoempty),
    	
    .pkt_gen_en_ri      (pkt_gen_en_ri),
        	
    .instream_wrdata    (instream_wrdata), 
    .instream_wrclk     (instream_wrclk), 
    .instream_wren      (instream_wren), 
    .instream_fifofull  (instream_fifofull)
  );


  // ===============================================================
  // R E S E T   &   C L O C K   G E N E R A T O R
  
  // System clock
  always #8ns sys_clk = ~sys_clk;
  	
  // RX clock generation
  always #5ns rxmac_clk = ~rxmac_clk;
  // RX clock enable (half of the main clock freq)
  always @(posedge rxmac_clk or negedge reset_n)
  begin
    if (~reset_n) begin
  	  rxmac_clk_en <= 1'b0;
    end	  
  	else begin
      rxmac_clk_en = ~rxmac_clk_en;
    end
  end
  
  // TX clock generation
  always #5ns txmac_clk = ~txmac_clk;
  // TX clock enable (half of the main clock freq)
  always @(posedge txmac_clk or negedge reset_n)
  begin
  	if (~reset_n) begin
  	  txmac_clk_en <= 1'b0;
  	end	  
  	else begin
  	  txmac_clk_en = ~txmac_clk_en;
  	end
  end

  // Input stream clock generation
  always #10ns instream_wrclk = ~instream_wrclk;
  
  // ===============================================================
  // D E B U G G I N G

  task print_arp_req_array;
    foreach (ARP_CLIENT_REQ[i]) begin
  	  $display("ARP_CLIENT_REQ[%0d] = 0x%2h", i, ARP_CLIENT_REQ[i]); 
    end
    $write("\n");
    $write("Finish Arry\n");
  endtask

  task print_arp_reply_queue;
    integer i;
    $write("ARP_SERV_REPLY_q contains ");
    for (i = 0; i < ARP_SERV_REPLY_q.size(); i++) begin
      $write (" 0x%2h", ARP_SERV_REPLY_q[i]);
    end
    $write("\n");
  endtask

  task print_icmp_reply_queue;
    integer i;
    $write("ICMP_SERV_REPLY_q contains ");
    for (i = 0; i < ICMP_SERV_REPLY_q.size(); i++) begin
  	  $write (" 0x%2h", ICMP_SERV_REPLY_q[i]);
    end
    $write("\n");
  endtask

  task print_tcp_serv_sync_ack_reply_queue;
    integer i;
    $write("TCP_SERV_SYNC_ACK_REPLY_q contains ");
  	for (i = 0; i < TCP_SERV_SYNC_ACK_REPLY_q.size(); i++) begin
  	  $write (" 0x%2h", TCP_SERV_SYNC_ACK_REPLY_q[i]);
    end
    $write("\n");
  endtask

  task print_tcp_serv_giop_req_ack_reply_queue;
    integer i;
    $write("TCP_SERV_GIOP_REQ_ACK_REPLY_q contains ");
    for (i = 0; i < TCP_SERV_GIOP_REQ_ACK_REPLY_q.size(); i++) begin
  	  $write (" 0x%2h", TCP_SERV_GIOP_REQ_ACK_REPLY_q[i]);
    end
    $write("\n");
  endtask

  task print_tcp_serv_giop_data_reply_queue;
    integer i;
    $write("TCP_SERV_GIOP_DATA_REPLY_q contains ");
    for (i = 0; i < TCP_SERV_GIOP_DATA_REPLY_q.size(); i++) begin
  	  $write (" 0x%2h", TCP_SERV_GIOP_DATA_REPLY_q[i]);
    end
    $write("\n");
  endtask
  	
  task print_tcp_serv_fin_ack_reply_queue;
    integer i;
    $write("TCP_SERV_FIN_ACK_REPLY_q contains ");
    for (i = 0; i < TCP_SERV_FIN_ACK_REPLY_q.size(); i++) begin
	  $write (" 0x%2h", TCP_SERV_FIN_ACK_REPLY_q[i]);
    end
    $write("\n");
  endtask

  task print_rec_msg_queue;
    integer i;
    $write("  REC_MSG_q contains ");
    for (i = 0; i < REC_MSG_q.size(); i++) begin
      $write (" 0x%2h", REC_MSG_q[i]);
    end
    $write("\n");
  endtask


  // ===============================================================
  // M A I N   T E S T   P R O C E S S  
  initial begin
  	
  	// ======================================================
  	// R E S E T   P H A S E
  	reset_n <= 1'b0;
    // from tsmac core
    tx_macread <= 1'b0;

    // from reg_intf
    pkt_gen_en_ri <= 1'b0;
  
    #40ns;
    @ (posedge rxmac_clk);
    #2ns;
    reset_n <= 1'b1;
    
    
    ARP_CLIENT_REQ_q              = ARP_CLIENT_REQ;
    ICMP_CLIENT_PING_REQ_q        = ICMP_CLIENT_PING_REQ;
    TCP_CLIENT_SYN_q              = TCP_CLIENT_SYN;
    TCP_CLIENT_SYNC_ACK_ACK_q     = TCP_CLIENT_SYNC_ACK_ACK;
    TCP_CLIENT_GIOP_REQ_q         = TCP_CLIENT_GIOP_REQ;
    TCP_CLIENT_GIOP_DATA_ACK_q    = TCP_CLIENT_GIOP_DATA_ACK;
    TCP_SERV_GIOP_DATA_REPLY_q    = TCP_SERV_GIOP_DATA_REPLY;
    TCP_CLIENT_FIN_ACK_q          = TCP_CLIENT_FIN_ACK;
    TCP_CLIENT_ACK_LAST_q         = TCP_CLIENT_ACK_LAST;
    
    ARP_SERV_REPLY_q              = ARP_SERV_REPLY;
    ICMP_SERV_REPLY_q             = ICMP_SERV_REPLY;
    TCP_SERV_SYNC_ACK_REPLY_q     = TCP_SERV_SYNC_ACK_REPLY;
    TCP_SERV_GIOP_REQ_ACK_REPLY_q = TCP_SERV_GIOP_REQ_ACK_REPLY;
    TCP_SERV_FIN_ACK_REPLY_q      = TCP_SERV_FIN_ACK_REPLY;

    repeat(20) @(posedge rxmac_clk);

    // ======================================================
    // S T A R T I N G   m o n i t o r H a n d l e r  A S   P A R A L L E L   T H R E A D
    fork 
      monitorHandler();
    join_none

//    print_arp_req_array;

    // ####################################################################################
    // A R P   P R O T O C O L
    // ####################################################################################

    // ======================================================
    // X M I T _ A R P _ R E Q
    $write("%dns : driver::wrTrans ARP_CLIENT_REQ...\n", $time);    
    while(ARP_CLIENT_REQ_q.size())
    begin
      rx_dbout <= #1ns ARP_CLIENT_REQ_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    
    // ======================================================
    // R E C _ A R P _ R E P L Y
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for RX_REC_ARP_REPLY\n", $time);
    @ (monitor_event);
    $write("%dns : driver::wrTrans Received RX_REC_ARP_REPLY\n", $time);

    // ======================================================
    // A R P   S E R V E R   S C O R E B O A R D

    $display("%dns : scoreboard: ARP_REPLY Packet Size: Expected = %h, Got = %h", $time, ARP_SERV_REPLY_q.size(), REC_MSG_q.size());
    assert(REC_MSG_q.size() === ARP_SERV_REPLY_q.size()) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, ARP_SERV_REPLY_q.size(), REC_MSG_q.size());

    $display("%dns : scoreboard: ARP_REPLY Packet Payload...", $time);
    print_arp_reply_queue;
    print_rec_msg_queue;
    while(REC_MSG_q.size() && ARP_SERV_REPLY_q.size())
    begin
      bit [7:0] rec_msg = REC_MSG_q.pop_front();
      bit [7:0] ref_msg = ARP_SERV_REPLY_q.pop_front();
      assert(rec_msg === ref_msg) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, rec_msg, ref_msg);
    end

    // ####################################################################################
    // I C M P   P R O T O C O L
    // ####################################################################################
    
    // ======================================================
    // X M I T _ I C M P _ P I N G _ R E Q
    $write("%dns : driver::wrTrans ICMP_PING_REQ...\n", $time);    
    while(ICMP_CLIENT_PING_REQ_q.size())
    begin
      rx_dbout <= #1ns ICMP_CLIENT_PING_REQ_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    
    // ======================================================
    // R E C _ I C M P _ R E P L Y
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for RX_REC_ICMP_REPLY\n", $time);
    @ (monitor_event);
    $write("%dns : driver::wrTrans Received RX_REC_ICMP_REPLY\n", $time);

    // ======================================================
    // I C M P   S E R V E R   R E P L Y   S C O R E B O A R D
    
    $display("%dns : scoreboard: ICMP_REPLY Packet Size: Expected = %h, Got = %h", $time, ICMP_SERV_REPLY_q.size(), REC_MSG_q.size());
    assert(REC_MSG_q.size() === ICMP_SERV_REPLY_q.size()) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, ICMP_SERV_REPLY_q.size(), REC_MSG_q.size());
    
    $display("%dns : scoreboard: ICMP_REPLY Packet Payload...", $time);
    print_icmp_reply_queue;
    print_rec_msg_queue;
    while(REC_MSG_q.size() && ICMP_SERV_REPLY_q.size())
    begin
      bit [7:0] rec_msg = REC_MSG_q.pop_front();
      bit [7:0] ref_msg = ICMP_SERV_REPLY_q.pop_front();
      assert(rec_msg === ref_msg) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, rec_msg, ref_msg);
    end

    // ####################################################################################
    // T C P   P R O T O C O L
    // ####################################################################################
	
    // ======================================================
    // X M I T _ T C P _ C L I E N T _ S Y N C
    $write("%dns : driver::wrTrans TCP_CLIENT_SYN...\n", $time);    
    while(TCP_CLIENT_SYN_q.size())
    begin
	  rx_dbout <= #1ns TCP_CLIENT_SYN_q.pop_front();
	  rx_write <= 1'b1;
	  @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    
    // ======================================================
    // R E C _ T C P _ S E R V E R _ S Y N C _ A C K _ R E P L Y
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for TCP_SERV_SYNC_ACK_REPLY\n", $time);
    @ (monitor_event);
    $write("%dns : driver::wrTrans Received TCP_SERV_SYNC_ACK_REPLY\n", $time);

    
    // ======================================================
    // T C P _ S E R V E R _ S Y N C _ A C K   S C O R E B O A R D  
    $display("%dns : scoreboard: TCP_SERV_SYNC_ACK_REPLY Packet Size: Expected = %h, Got = %h", $time, TCP_SERV_SYNC_ACK_REPLY_q.size(), REC_MSG_q.size());
    assert(REC_MSG_q.size() === TCP_SERV_SYNC_ACK_REPLY_q.size()) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, TCP_SERV_SYNC_ACK_REPLY_q.size(), REC_MSG_q.size());
    
    $display("%dns : scoreboard: TCP_SERV_SYNC_ACK_REPLY Packet Payload...", $time);
    print_tcp_serv_sync_ack_reply_queue;
    print_rec_msg_queue;
    while(REC_MSG_q.size() && TCP_SERV_SYNC_ACK_REPLY_q.size())
    begin
      bit [7:0] rec_msg = REC_MSG_q.pop_front();
      bit [7:0] ref_msg = TCP_SERV_SYNC_ACK_REPLY_q.pop_front();
      assert(rec_msg === ref_msg) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, rec_msg, ref_msg);
    end

    
    // ======================================================
    // X M I T _ T C P _ C L I E N T _ S Y N C _ A C K
    $write("%dns : driver::wrTrans TCP_CLIENT_SYNC_ACK_ACK...\n", $time);    
    while(TCP_CLIENT_SYNC_ACK_ACK_q.size())
    begin
      rx_dbout <= #1ns TCP_CLIENT_SYNC_ACK_ACK_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    // ####################################################################################

    repeat(500) @(posedge rxmac_clk);

    // ####################################################################################
    
    // ======================================================
    // X M I T _ T C P _ C L I E N T _ G I O P _ R E Q
    $write("%dns : driver::wrTrans TCP_CLIENT_GIOP_REQ...\n", $time);    
    while(TCP_CLIENT_GIOP_REQ_q.size())
    begin
      rx_dbout <= #1ns TCP_CLIENT_GIOP_REQ_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    // ======================================================
    // R E C _ T C P _ S E R V E R _ G I O P _ R E Q _ A C K _ R E P L Y
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for TCP_SERV_GIOP_REQ_ACK_REPLY\n", $time);
    @ (monitor_event);
    $write("%dns : driver::wrTrans Received TCP_SERV_GIOP_REQ_ACK_REPLY\n", $time);

    
    // ======================================================
    // T C P _ S E R V E R _ G I O P _ R E Q _ A C K   S C O R E B O A R D  
    $display("%dns : scoreboard: TCP_SERV_GIOP_REQ_ACK_REPLY Packet Size: Expected = %h, Got = %h", $time, TCP_SERV_GIOP_REQ_ACK_REPLY_q.size(), REC_MSG_q.size());
    assert(REC_MSG_q.size() === TCP_SERV_GIOP_REQ_ACK_REPLY_q.size()) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, TCP_SERV_GIOP_REQ_ACK_REPLY_q.size(), REC_MSG_q.size());
    
    $display("%dns : scoreboard: TCP_SERV_GIOP_REQ_ACK_REPLY Packet Payload...", $time);
    print_tcp_serv_giop_req_ack_reply_queue;
    print_rec_msg_queue;
    while(REC_MSG_q.size() && TCP_SERV_GIOP_REQ_ACK_REPLY_q.size())
    begin
      bit [7:0] rec_msg = REC_MSG_q.pop_front();
      bit [7:0] ref_msg = TCP_SERV_GIOP_REQ_ACK_REPLY_q.pop_front();
      assert(rec_msg === ref_msg) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, rec_msg, ref_msg);
    end

    // ####################################################################################
    
    // ======================================================
    // R E C _ T C P _ S E R V E R _ G I O P _ D A T A _ R E P L Y
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for TCP_SERV_GIOP_DATA_REPLY\n", $time);
    @ (monitor_event);
    $write("%dns : driver::wrTrans Received TCP_SERV_GIOP_DATA_REPLY\n", $time);

    
    // ======================================================
    // T C P _ S E R V E R _ G I O P _ D A T A   S C O R E B O A R D  
    $display("%dns : scoreboard: TCP_SERV_GIOP_DATA_REPLY Packet Size: Expected = %h, Got = %h", $time, TCP_SERV_GIOP_DATA_REPLY_q.size(), REC_MSG_q.size());
    assert(REC_MSG_q.size() === TCP_SERV_GIOP_DATA_REPLY_q.size()) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, TCP_SERV_GIOP_DATA_REPLY_q.size(), REC_MSG_q.size());
    
    $display("%dns : scoreboard: TCP_SERV_GIOP_DATA_REPLY Packet Payload...", $time);
    print_tcp_serv_giop_data_reply_queue;
    print_rec_msg_queue;
    while(REC_MSG_q.size() && TCP_SERV_GIOP_DATA_REPLY_q.size())
    begin
      bit [7:0] rec_msg = REC_MSG_q.pop_front();
      bit [7:0] ref_msg = TCP_SERV_GIOP_DATA_REPLY_q.pop_front();
      assert(rec_msg === ref_msg) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, rec_msg, ref_msg);
    end

    // ======================================================
    // X M I T _ T C P _ C L I E N T _ G I O P _ D A T A _ A C K
    $write("%dns : driver::wrTrans TCP_CLIENT_GIOP_DATA_ACK...\n", $time);    
    while(TCP_CLIENT_GIOP_DATA_ACK_q.size())
    begin
      rx_dbout <= #1ns TCP_CLIENT_GIOP_DATA_ACK_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    // ####################################################################################

    repeat(500) @(posedge rxmac_clk);

    // ####################################################################################

    // ======================================================
    // X M I T _ T C P _ C L I E N T _ F I N _ A C K
    $write("%dns : driver::wrTrans TCP_CLIENT_FIN_ACK...\n", $time);    
    while(TCP_CLIENT_FIN_ACK_q.size())
    begin
      rx_dbout <= #1ns TCP_CLIENT_FIN_ACK_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    // ======================================================
    // R E C _ T C P _ S E R V E R _ F I N _ A C K _ R E P L Y
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for TCP_SERV_FIN_ACK_REPLY\n", $time);
    @ (monitor_event);
    $write("%dns : driver::wrTrans Received TCP_SERV_FIN_ACK_REPLY\n", $time);

    
    // ======================================================
    // T C P _ S E R V E R _ F I N _ A C K   S C O R E B O A R D  
    $display("%dns : scoreboard: TCP_SERV_FIN_ACK_REPLY Packet Size: Expected = %h, Got = %h", $time, TCP_SERV_FIN_ACK_REPLY_q.size(), REC_MSG_q.size());
    assert(REC_MSG_q.size() === TCP_SERV_FIN_ACK_REPLY_q.size()) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, TCP_SERV_GIOP_REQ_ACK_REPLY_q.size(), REC_MSG_q.size());
    
    $display("%dns : scoreboard: TCP_SERV_FIN_ACK_REPLY Packet Payload...", $time);
    print_tcp_serv_fin_ack_reply_queue;
    print_rec_msg_queue;
    while(REC_MSG_q.size() && TCP_SERV_FIN_ACK_REPLY_q.size())
    begin
    	bit [7:0] rec_msg = REC_MSG_q.pop_front();
    	bit [7:0] ref_msg = TCP_SERV_FIN_ACK_REPLY_q.pop_front();
    	assert(rec_msg === ref_msg) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, rec_msg, ref_msg);
    end
    
    // ======================================================
    // X M I T _ T C P _ C L I E N T _ F I N _ A C K
    $write("%dns : driver::wrTrans TCP_CLIENT_ACK_LAST_q...\n", $time);    
    while(TCP_CLIENT_ACK_LAST_q.size())
    begin
      rx_dbout <= #1ns TCP_CLIENT_ACK_LAST_q.pop_front();
      rx_write <= 1'b1;
      @(posedge rxmac_clk iff rxmac_clk_en);
    end
    rx_eof   <= 1'b1;
    rx_write <= 1'b0;
    @(posedge rxmac_clk iff rxmac_clk_en);
    rx_eof   <= 1'b0;
    
    // ####################################################################################
    // E N D I N G   T H E   S I M U L A T I O N
    // ####################################################################################
    repeat(10) @(posedge rxmac_clk);
    $write("%dns : Terminating simulations\n", $time);
    $stop;

  end  // Main Test Process

  
  // ####################################################################################
  // M O N I T O R
  // ####################################################################################
  
  // ===============================================================
  // T R A N S A C T I O N   M O N I T O R   A N D   R E P L Y   H A N D L E R
  task monitorHandler();
  begin
  	forever begin
      rec_timeout = 0;
      while (tx_fifoempty) begin
        @ (posedge txmac_clk iff txmac_clk_en);
        rec_timeout++;
        if (rec_timeout > 10000) begin
          $error("%dns : wrTrans Warning : tx_fifoempty is 0 for more then 10000 clocks\n", $time);
          repeat(20) @(posedge txmac_clk);
          -> monitor_event;
        end
      end
      rec_timeout = 0;
      
      while (!tx_fifoempty) begin
        tx_macread = 1'b1;
        @ (posedge txmac_clk iff txmac_clk_en);
        REC_MSG_q.push_back(tx_fifodata);      
      end
      tx_macread = 1'b0;
    	
      -> monitor_event;
      @ (negedge txmac_clk);
    
    end
  end
  endtask : monitorHandler
  
  // ####################################################################################
  // I N P U T   S T R E A M   S T I M U L U S
  // ####################################################################################
  int j=0;
  initial begin
    instream_wren = 1'b0;
    instream_wrdata = '0;

    repeat(500) @(posedge instream_wrclk);
    
    for (int i=0; i<DEVICE_TCP_PAYLOAD*2; i++) begin
      @(negedge instream_wrclk iff !instream_fifofull);
      instream_wren = (i%2 == 0)? 1'b1 : 1'b0;
      if (instream_wren) begin
        instream_wrdata = TCP_SERV_GIOP_DATA_XMIT[j];
        j++;
      end
    end
  end
  		
endmodule