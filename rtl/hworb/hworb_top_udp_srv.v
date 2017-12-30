/***********************************************************************
  $FILENAME    : hworb_top.v

  $TITLE       : Hardware ORB implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : Hardware ORB(Object Request Broker) implementation inside the FPGA

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module hworb_top #(
  parameter [31:0] DEST_IP            = 32'h0a0105ce,     // Destination IP Address
  parameter [15:0] DEST_TCPCLNT_PORT  = 16'hBC14,         // Destination TCP Client Port
  parameter [15:0] SRC_TCPCLNT_PORT   = 16'hDFCC,         // Source TCP Client Port
  parameter [31:0] DEVICE_IP          = 32'h0a0105dd,     // IP Address
  parameter [47:0] DEVICE_MAC         = 48'h001999cf95fa, // MAC Address
  parameter [15:0] DEVICE_TCP_PORT    = 16'hBC14,
  parameter [15:0] DEVICE_TCP_PAYLOAD = 16'h0400,         // 1024-byte payload
  parameter [15:0] DEVICE_UDP_PORT    = 16'hbed0,         // 48848			
  parameter [15:0] DEST_UDP_PORT      = 16'h1b3b          // Destination UDP Port
)
(
  input              instream_fifoempty,
  output wire        instream_rden,
  input [7:0]        instream_rddata,
  input [11:0]       instream_rcnt,
  
  input              clk_i,
  input              reset_n,
  // from rx_fifo_ctl 
  input [15:0]       rx_len_fifo_data,
  input [7:0]        rx_data_fifo_data,
  input              rx_len_fifo_empty,
  input [47:0]       dst_add,
  input [47:0]       src_add,
  input              en,
	
  input              TCP_StrtClnt,
  input              tx_done,
  input              rx_done,
  // to tx_fifo_ctl module
  output wire [15:0] tx_len_fifo_data,
  output wire [7:0]  tx_data_fifo_data,
  output reg         tx_len_fifo_write,
  output reg         tx_data_fifo_write,
  output reg         rx_len_fifo_read,
  output reg         rx_data_fifo_read,
  
  output wire        triger_signal,
  output reg         en_rst
);

  // ==============================================================================
  // internal signals
  reg         transmit_start_prev;
  reg         rx_done_int;
  reg         tx_data_fifo_write_int;
  
  reg         tx_dpmem_wr;
  reg  [10:0] tx_dpmem_addr_wr;
  reg  [10:0] tx_dpmem_addr_rd;
  reg  [7:0]  tx_dpmem_data_in;
  wire [7:0]  tx_dpmem_data_out;
  
  reg         arp_en;
  reg         tx_done_int;

  wire [7:0]  rx_data_byte;
  reg  [7:0]  rx_data_byte_d1;
  reg  [7:0]  rx_data_byte_d2;
  reg         rx_data_new_byte;
  reg         rx_data_new_byte_d1;
  reg         rx_data_new_byte_d2;

  wire        iprec_newDatagram;
  wire [15:0] iprec_datagramSize;
  wire [7:0]  iprec_protocol;
  wire [31:0] iprec_sourceIP;
  
  wire        ipxmit_sendDatagram;
  wire [15:0] ipxmit_datagramSize;
  wire [31:0] ipxmit_destinationIP;
  wire [7:0]  ipxmit_protocol;
  
  reg         ipxmit_complete;
  reg         ipxmit_frameSent;

  wire        ipxmit_tx_dpmem_wr;
  wire [7:0]  ipxmit_tx_dpmem_wr_data;
  wire [7:0]  ipxmit_tx_dpmem_wr_addr;
  wire        ipxmit_sendFrame;
  wire [10:0] ipxmit_frameSize;
  wire [31:0] ipxmit_ARPIP;
  
  // ICMP layer
  wire        icmprply_newDatagram;
  wire [15:0] icmprply_datagramSize;
  wire [7:0]  icmprply_protocolIn;
  wire [31:0] icmprply_sourceIP;
  wire        icmprply_complete;
  
  wire        icmprply_tx_dpmem_wr;
  reg         icmprply_wrRAM_cmplt;
  wire [7:0]  icmprply_tx_dpmem_wr_data;
  wire [7:0]  icmprply_tx_dpmem_wr_addr;
  wire [15:0] icmprply_sendDatagramSize;
  wire        icmprply_sendDatagram;
  wire [31:0] icmprply_destinationIP;
  wire [7:0]  icmprply_protocolOut;

  // UDP Layer
  wire        udphndl_wrRAM = 1'b0;
  reg         udphndl_wrRAM_cmplt;
  wire [7:0]  udphndl_wrData;
  wire [10:0] udphndl_wrAddr;
  wire [15:0] udphndl_sendDatagramSize;
  wire        udphndl_sendDatagram;
  wire [31:0] udphndl_destinationIP;
  wire [7:0]  udphndl_protocolOut;
  
  reg  [3:0]  eth_xmit_state_cnt;

  // ARP layer
  reg         arpiprec_newFrame;
  reg         arpiprec_frameType;
  reg         arprec_frameValid;
  wire        arprec_ARPSendAvail;
  wire [31:0] arprec_requestIP;
  wire        arprec_genARPRep;
  wire [31:0] arprec_genARPIP;
  wire [47:0] arprec_lookupMAC;
  wire        arprec_validEntry;

  reg         arpxmit_complete;
  reg         arpxmit_frameSent;
  wire        arpxmit_sendFrame;
  wire [10:0] arpxmit_frameLen;
  wire [31:0] arpxmit_targetIP;
  wire        arpxmit_ARPEntryValid;
  wire        arpxmit_genARPReply;
  wire [31:0] arpxmit_genARPIP;
  wire [47:0] arpxmit_lookupMAC;
  wire        arpxmit_tx_dpmem_wr;
  wire [7:0]  arpxmit_tx_dpmem_wr_data;
  wire [7:0]  arpxmit_tx_dpmem_wr_addr;
  wire        arpxmit_sendingFrame;
  wire        arpxmit_sendingReply;
  wire [47:0] arpxmit_targetMAC;
  wire        arpxmit_genFrame;
  wire        arpxmit_frameType;
  wire [31:0] arpxmit_lookupIP;
  wire [10:0] arpxmit_frameSize;

  wire        tcp_RcvOvrHd_TrigSg;
  wire        tcp_RcvOvrHd_TrigSg_d;
  reg         triger_signal_clnt;
  wire        triger_signal_srv;

  reg  [15:0] rx_len_down_cnt;      // length down counter
  reg  [4:0]  rx_len_up_cnt;        // long_word up counter
  reg  [15:0] rx_len_in_bytes;      // length in bytes out of length_flag fifo
  reg         rx_load_cnt;          // load long_word counter

  reg  [15:0] tx_len_down_cnt;      // long_word down counter
  reg  [15:0] tx_len_in_bytes;      // length in bytes out of length_flag fifo
  reg         tx_load_cnt;          // load long_word counter

  reg  [7:0]  tx_byte2word;
  // control state machine 
  // states
  // State signals and types
  parameter [2:0]
	RX_IDLE    	       = 3'd0,	// IDLE State
	RX_WAIT1   	       = 3'd1,	// WAIT1 State
	RX_WAIT2   	       = 3'd2,	// WAIT2 State
	RX_PULL_PUSH_PKT   = 3'd3,	// PULL and PUSH PACKET State
	RX_WAIT3   	       = 3'd4;	// WAIT3 State
  
  reg [2:0] hworb_rx_fsm; // Rx Control FSM states
  
  parameter [1:0]
	TX_IDLE       	   = 2'd0,	// IDLE State
	TX_WAIT1   	       = 2'd1,	// WAIT1 State
	TX_PULL_PUSH_PKT   = 2'd2,	// PULL and PUSH PACKET State
	TX_WAIT2   	       = 2'd3;	// WAIT3 State
	
  reg [1:0] hworb_tx_fsm; // Tx Control FSM states
	
  reg         OrbCmd_start_tx;
  reg         transmit_start;

  // ==============================================================================
  // dual port RAM instance
  dpram #(
    8,
    11)
  u_tx_dpram
  (
    .WrAddress (tx_dpmem_addr_wr), 	
    .RdAddress (tx_dpmem_addr_rd), 
    .Data      (tx_dpmem_data_in), 
    .WE        (tx_dpmem_wr), 
    .clk       (clk_i), 
    .Q         (tx_dpmem_data_out)
  );  

  // ==============================================================================
  // ARP reply RX
  arp_reply_rx #(
    .DEVICE_IP     (DEVICE_IP),
    .DEVICE_MAC    (DEVICE_MAC)
  )
  u_arp_rep_rx
  (
    .clk           (clk_i),
    .reset_n       (reset_n),
    .newFrame      (arpiprec_newFrame),     // new frame received from the layer below
    .frameType     (arpiprec_frameType),    // '0' for an ARP message
    .newFrameByte  (rx_data_new_byte_d1),   // signals a new byte in the stream
    .frameData     (rx_data_byte),          // input data from MAC layer is streamed in here
    .frameValid    (arprec_frameValid),	    // indicates validity while endFrame is asserted
    .ARPSendAvail  (arprec_ARPSendAvail),   // ARP sender asserts this when the reply is transmitted
    .requestIP     (arprec_requestIP),	    // ARP sender can request MACs for this address
    .genARPRep     (arprec_genARPRep),	    // tell ARP sender to generate a reply
    .genARPIP      (arprec_genARPIP),       // destination IP for generated reply
    .lookupMAC     (arprec_lookupMAC),	    // if valid, MAC for requested IP
    .validEntry    (arprec_validEntry)	    // indicates if requestIP is in table
  );	
   
  // ==============================================================================
  // ARP reply TX
  arp_reply_tx  #( 
    .DEVICE_IP     (DEVICE_IP),
    .DEVICE_MAC    (DEVICE_MAC)
  )
  u_arp_rep_tx
  (
    .clk           (clk_i),
    .reset_n       (reset_n),
    .complete      (arpxmit_complete),      // complete signal from the RAM operation
    .frameSent     (arpxmit_frameSent),	    // indicates the Ethernet has sent a frame
    .sendFrame     (arpxmit_sendFrame),	    // send an Ethernet frame - from IP layer
    .frameLen      (arpxmit_frameLen),	    // input from IP giving frame length
    .targetIP      (arpxmit_targetIP),	    // destination IP from the Internet layer
    .ARPEntryValid (arpxmit_ARPEntryValid), // input from ARP indicating that it contains the requested IP
    .genARPReply   (arpxmit_genARPReply),   // input from ARP requesting an ARP reply
    .genARPIP      (arpxmit_genARPIP),	    // input from ARP saying which IP to send a reply to
    .lookupMAC     (arpxmit_lookupMAC),	    // input from ARP giving a requested MAC

    .lookupIP      (arpxmit_lookupIP),	    // output to ARP requesting an IP to be looked up in the table
    .sendingReply  (arpxmit_sendingReply),  // output to ARP to tell it's sending the ARP reply
    .targetMAC     (arpxmit_targetMAC),	    // destination MAC for the physical layer
    .genFrame      (arpxmit_genFrame),	    // tell the Ethernet layer (PHY) to send a frame
    .frameType     (arpxmit_frameType),	    // tell the PHY to send an ARP frame or normal IP Datagram
    .frameSize     (arpxmit_frameSize),     // tell the PHY what size the frame size IS
    .idle          (),   		    // idle signal
    .sendingFrame  (arpxmit_sendingFrame),  // tell the IP layer that we're sending their data
    .wrRAM         (arpxmit_tx_dpmem_wr),   // write RAM signal to the TX DPMEM
    .wrData        (arpxmit_tx_dpmem_wr_data),	// write data bus to the TX DPMEM
    .wrAddr        (arpxmit_tx_dpmem_wr_addr)	// write address for the TX DPMEM
  );

  // ==============================================================================
  // IP rx
  internet_rx  #(
    .DEVICE_IP     (DEVICE_IP)
  )
  u_ip_rx
  (
    .clk           (clk_i),
    .reset_n       (reset_n),
    .newFrame      (arpiprec_newFrame),     // new frame received from the layer below
    .frameType     (arpiprec_frameType),    // frame type = '1' for IP
    .newFrameByte  (rx_data_new_byte_d1),   // signals a new byte in the stream
    .frameData     (rx_data_byte),          // input data from MAC layer is streamed in here
    .newDatagram   (iprec_newDatagram),     // an IP datagram has been fully received
    .datagramSize  (iprec_datagramSize),    // size of the datagram received
    .protocol      (iprec_protocol),        // protocol type of datagram
    .sourceIP      (iprec_sourceIP)         // lets upper protocol know the source IP
  );

  // ==============================================================================
  // IP tx
  internet_tx  #(
    .DEVICE_IP     (DEVICE_IP)
  )
  u_ip_tx
  (
    .clk          (clk_i),		    // clock
    .reset_n      (reset_n),		    // active low asynchronous reset
    .frameSent    (ipxmit_frameSent),	    // indicates the Ethernet has sent a frame
    .sendDatagram (ipxmit_sendDatagram),    // signal to send a datagram message
    .datagramSize (ipxmit_datagramSize),    // size of datagram to transmit
    .destinationIP(ipxmit_destinationIP),   // IP to transmit message to
    .protocol     (ipxmit_protocol),	    // protocol of the datagram to be sent
    .complete     (ipxmit_complete),        // complete signal from the RAM operation
    .rdData       (8'b0),                   // read data from RAM
    .wrRAM        (ipxmit_tx_dpmem_wr),	    // write signal for the TX DPMEM
    .wrData       (ipxmit_tx_dpmem_wr_data),// write data for the TX DPMEM
    .wrAddr       (ipxmit_tx_dpmem_wr_addr),// write address for the TX DPMEM
    .sendFrame    (ipxmit_sendFrame),	    // signal to get Ethernet to send frame
    .datagramSent (),	                    // tells higher protocol WHEN the datagram was sent
    .frameSize    (ipxmit_frameSize),	    // tells the Ethernet layer how long the frame IS
    .ARPIP        (ipxmit_ARPIP)            // IP that the ARP layer must look up
  );

  // ==============================================================================
  // ICMP reply
  icmp_reply
  u_icmp_rep
  (
    .clk              (clk_i),			  // clock
    .reset_n          (reset_n),	 	  // asynchronous active low reset
    .newDatagram      (icmprply_newDatagram),	  // asserted when a new datagram arrive
    .datagramSize     (icmprply_datagramSize),    // size of the arrived datagram
    .bufferSelect     (1'b0),			  // informs which IP buffer the data IS in
    .protocolIn       (icmprply_protocolIn),	  // protocol type of the datagram
    .sourceIP         (icmprply_sourceIP),	  // IP address that sent the message
    .complete         (icmprply_complete),	  // asserted when then RAM operation IS complete
    .rdData           (rx_data_byte),    	  // read data bus from the RAM
    .wrRAM            (icmprply_tx_dpmem_wr),	  // asserted to tell the TX DPMEM to write
    .wrData           (icmprply_tx_dpmem_wr_data),// write data bus to the TX DPMEM
    .wrAddr           (icmprply_tx_dpmem_wr_addr),// write address bus to the TX DPMEM
    .sendDatagramSize (icmprply_sendDatagramSize),// size of the ping to reply to
    .sendDatagram     (icmprply_sendDatagram),    // tells the IP layer to send a datagram
    .destinationIP    (icmprply_destinationIP),   // target IP of the datagram
    .addressOffset    (),		          // tells the IP layer which buffer the data is in
    .protocolOut      (icmprply_protocolOut)      // tells the IP layer which protocol it is
  );
  
  // ==============================================================================
  // UDP Server
  udp_server #(
    .DEVICE_UDP_PORT     (DEVICE_UDP_PORT),
    .DEST_IP             (DEST_IP),
    .DEST_UDP_PORT       (DEST_UDP_PORT),
    .DEVICE_IP           (DEVICE_IP)
  ) 
  u_udp_srv
  (
    .clk                 (clk_i),		// clock
    .reset_n             (reset_n),		// asynchronous active low reset
  
    .wr_complete         (udphndl_wrRAM_cmplt),  	
    .tx_done_MAC         (tx_done_int),
  
    .instream_fifoempty  (instream_fifoempty),//1'b1),
    .instream_rden       (instream_rden),
    .instream_rddata     (instream_rddata),
    .instream_rcnt       (instream_rcnt),

    .wrRAM               (udphndl_wrRAM),	    // asserted to tell the DPRAM to write
    .wrData              (udphndl_wrData),	    // write data bus to the DPRAM
    .wrAddr              (udphndl_wrAddr),	    // write address bus to the DPRAM
    .sendDatagramSize    (udphndl_sendDatagramSize),// size of the UDP to transmit to
    .sendDatagram        (udphndl_sendDatagram),    // tells the IP layer to send a datagram
    .destinationIP       (udphndl_destinationIP),   // target IP of the datagram
    .protocolOut         (udphndl_protocolOut)	    // tells the IP layer which protocol it is
  );
  

  // ICMP
  assign icmprply_newDatagram  = iprec_newDatagram;
  assign icmprply_datagramSize = iprec_datagramSize;
  assign icmprply_protocolIn   = iprec_protocol;
  assign icmprply_sourceIP     = iprec_sourceIP;
  assign icmprply_complete     = rx_data_new_byte_d1 | icmprply_wrRAM_cmplt;

  // ==============================================================================
  // Transmit layer (ICMP & UDP) multiplexer
  assign ipxmit_datagramSize[15:0] = (icmprply_sendDatagram) ? icmprply_sendDatagramSize[15:0]:udphndl_sendDatagramSize[15:0];
  assign ipxmit_destinationIP[31:0] = (icmprply_sendDatagram) ? icmprply_destinationIP[31:0]:udphndl_destinationIP[31:0];
  assign ipxmit_protocol[7:0] = (icmprply_sendDatagram) ? icmprply_protocolOut[7:0]:udphndl_protocolOut[7:0];
  assign ipxmit_sendDatagram = (icmprply_sendDatagram || udphndl_sendDatagram) ? 1'b1:1'b0;

  // ARP
  assign arpxmit_genARPIP      = arprec_genARPIP;
  assign arpxmit_genARPReply   = arprec_genARPRep;
  assign arpxmit_sendFrame     = ipxmit_sendFrame;
  assign arpxmit_lookupMAC     = arprec_lookupMAC;
  assign arpxmit_ARPEntryValid = arprec_validEntry;
  assign arprec_requestIP      = arpxmit_lookupIP;
  assign arpxmit_targetIP      = ipxmit_ARPIP; 
  assign arprec_ARPSendAvail   = arpxmit_sendingReply;
  assign arpxmit_frameLen      = ipxmit_frameSize[10:0];

  // ==============================================================================
  // LONG WORD COUNTER (14 Bit)
  always @(posedge clk_i or negedge reset_n) 
  begin
    if (!reset_n) begin
      rx_len_down_cnt <= 16'd0;
      rx_len_up_cnt <= 5'd0;
    end
    else begin
      if (rx_load_cnt) begin
        rx_len_down_cnt <= rx_len_in_bytes[15:0];
        rx_len_up_cnt <= 5'd0;
      end
      else if (rx_data_fifo_read) begin
        rx_len_down_cnt <= rx_len_down_cnt - 1;

        if (rx_len_up_cnt < 5'd31) begin
          rx_len_up_cnt <= rx_len_up_cnt + 1;
        end
      end
	  
      if (tx_load_cnt) begin
        tx_len_down_cnt <= tx_len_in_bytes[15:0];
      end
      else if (tx_data_fifo_write_int) begin
        tx_len_down_cnt <= tx_len_down_cnt - 1;
      end
	  
    end
  end // always 
  
  // ==============================================================================
  // RX CONTROL FSM 
  always @(posedge clk_i or negedge reset_n) 
  begin
    if (!reset_n) begin
      rx_done_int <= 1'b0;
      rx_data_new_byte <= 1'b0;
      rx_data_byte_d1 <= 8'b0;
      rx_data_byte_d2 <= 8'b0;
      rx_data_new_byte_d1 <= 1'b0; 
      rx_data_new_byte_d2 <= 1'b0; 
      arpiprec_frameType <= 1'b1;
      arpiprec_newFrame <= 1'b0;
      arprec_frameValid <= 1'b0;
      triger_signal_clnt <= 1'b0;
	
      hworb_rx_fsm <= RX_IDLE;
      rx_load_cnt <= 1'b0;
      rx_len_fifo_read <= 1'b0;
      rx_data_fifo_read <= 1'b0;
      rx_len_in_bytes <= 16'b0;
	  
      en_rst <= 1'b1;

    end
    else begin
      // ==============================================================================
      // MAC layer RX SPY section
      rx_data_byte_d1 <= rx_data_byte;
      rx_data_byte_d2 <= rx_data_byte_d1;

      // ==============================================================================
      // IP layer RX section
      rx_data_new_byte_d1 <= rx_data_new_byte;
      rx_data_new_byte_d2 <= rx_data_new_byte_d1;
	  
      // ==============================================================================
      // ARP layer RX section
      arpiprec_frameType <= 1'b1;
      arpiprec_newFrame <= 1'b0;

      if (rx_done_int) begin
        triger_signal_clnt <= 1'b0;
      end

      if ((rx_len_up_cnt == 5'h0E) && (rx_data_byte_d2 == 8'd8) && (rx_data_new_byte_d1 == 1'b1)) begin // 0x01A = 26 
        triger_signal_clnt <= tcp_RcvOvrHd_TrigSg;
        en_rst <= 1'b0;
           
        if (rx_data_byte == 8'd6)  begin
          arpiprec_frameType <= 1'b0; // ARP
          arpiprec_newFrame <= 1'b1;
        end  
        else if (rx_data_byte == 8'b0) begin // 0x01A = 26
          arpiprec_frameType <= 1'b1; // IP
          arpiprec_newFrame <= 1'b1;
        end
      end

      arprec_frameValid <= 1'b0;
      if (rx_done_int) begin
        arprec_frameValid <= 1'b1;
      end

      // default values
      rx_load_cnt <= 1'b0;
      rx_len_fifo_read <= 1'b0;
      rx_data_fifo_read <= 1'b0;
      rx_data_new_byte <= 1'b0;
      rx_done_int <= 1'b0;

      case (hworb_rx_fsm)
        RX_IDLE:
        begin
          if (!rx_len_fifo_empty) begin // len fifo not empty
            rx_len_fifo_read <= 1'b1;
            hworb_rx_fsm <= RX_WAIT1;
          end
        end
		   
        RX_WAIT1:
        begin
          // delay for data out of len fifo
          hworb_rx_fsm <= RX_WAIT2;
        end
				 
        RX_WAIT2:
        begin
          // delay for data out of len fifo
          rx_load_cnt <= 1'b1;
          rx_len_in_bytes[15:0] <= rx_len_fifo_data[15:0];
          hworb_rx_fsm <= RX_PULL_PUSH_PKT;
        end
				 				 
        RX_PULL_PUSH_PKT:
        begin
          if (rx_len_down_cnt == 16'd0) begin
            rx_data_fifo_read <= 1'b1;
            hworb_rx_fsm <= RX_WAIT3;
          end
          else begin
            rx_data_fifo_read <= 1'b1;
            hworb_rx_fsm <= RX_WAIT3;
          end
        end
				 
        RX_WAIT3:
        begin
          // 1 clk delay
          if (rx_len_down_cnt == 16'd0) begin
            hworb_rx_fsm <= RX_IDLE;
            rx_done_int <= 1'b1;
          end
          else begin
            hworb_rx_fsm <= RX_PULL_PUSH_PKT;
            rx_data_new_byte <= 1'b1;
          end
        end
		
        default:
        begin
          hworb_rx_fsm <= RX_IDLE;
          rx_load_cnt <= 1'b0;
          rx_len_fifo_read <= 1'b0;
          rx_data_fifo_read <= 1'b0;
          rx_len_in_bytes <= 16'b0;
          rx_data_new_byte <= 1'b0;
        end
      endcase 
    end
  end // always 
  
  assign rx_data_byte[7:0] = rx_data_fifo_data[7:0];
  // ==============================================================================
  // TX CONTROL FSM 
  always @(posedge clk_i or negedge reset_n) 
  begin
    if (!reset_n) begin
      tx_dpmem_wr <= 1'b0;
      tx_dpmem_addr_wr <= 11'b0;
      tx_dpmem_addr_rd <= 11'b0;
      tx_dpmem_data_in <= 8'b0;
      OrbCmd_start_tx <= 1'b0;
      transmit_start_prev <= 1'b0;
      eth_xmit_state_cnt <= 4'b0;
      tx_len_fifo_write <= 1'b0;
      tx_data_fifo_write_int <= 1'b0;
      tx_data_fifo_write <= 1'b0;
      arp_en <= 1'b0;
      ipxmit_complete <= 1'b0;
      icmprply_wrRAM_cmplt <= 1'b0;
      tcp_tx_dpmem_wr_cmplt <= 1'b0;

      hworb_tx_fsm <= TX_IDLE;
      tx_load_cnt <= 1'b0;
      tx_len_in_bytes <= 16'b0;
      tx_done_int <= 1'b0;
	  
    end
    else begin
      // ==============================================================================
      // ETH DPMEM write en signal section
      if ( (eth_xmit_state_cnt != 4'b0 && eth_xmit_state_cnt != 4'b1111) || arpxmit_tx_dpmem_wr || ipxmit_tx_dpmem_wr || icmprply_tx_dpmem_wr || udphndl_wrRAM )
        tx_dpmem_wr <= 1'b1;
      else
        tx_dpmem_wr <= 1'b0;
		
      // ==============================================================================
      // Ethernet layer TX section
      OrbCmd_start_tx <= 1'b0;
           
      transmit_start_prev <= transmit_start;
      casez (eth_xmit_state_cnt[3:0])
        4'd0:
	    begin
          tx_dpmem_addr_wr <= 11'b11111111111;
          tx_dpmem_data_in <= 8'h00;
              
          if (arpxmit_genFrame) begin 
            eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
            tx_len_in_bytes    <= {5'b0, arpxmit_frameSize};
          end
	    end
		
        // ==============================================================================
        // Destination MAC address
        4'd1:
	    begin
          if (!arp_en)
            tx_dpmem_addr_wr <= 11'b0;     // ETH memory start address for normal IP packet : 0x000
          else
            tx_dpmem_addr_wr <= 11'd1532;  // ETH memory start address for ARP packet : 0x5FC
		  
          tx_dpmem_data_in   <= arpxmit_targetMAC[47:40];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd2:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= arpxmit_targetMAC[39:32];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd3:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= arpxmit_targetMAC[31:24];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd4:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= arpxmit_targetMAC[23:16];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd5:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= arpxmit_targetMAC[15:8];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd6:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= arpxmit_targetMAC[7:0];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
        // ==============================================================================
        // Source MAC address
	    4'd7:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= DEVICE_MAC[47:40];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd8:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= DEVICE_MAC[39:32];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd9:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= DEVICE_MAC[31:24];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd10:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= DEVICE_MAC[23:16];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd11:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= DEVICE_MAC[15:8];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd12:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= DEVICE_MAC[7:0];
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd13:
	    begin
          tx_dpmem_addr_wr   <= tx_dpmem_addr_wr + 1;
          tx_dpmem_data_in   <= 8'h08; 
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
        // ==============================================================================
        // Type: IP (0x0800)  
	    4'd14:
	    begin
          tx_dpmem_addr_wr <= tx_dpmem_addr_wr + 1;
          if (!arpxmit_frameType)
            tx_dpmem_data_in <= 8'h06; //-- ARP
          else
            tx_dpmem_data_in <= 8'h00; //-- IP
          
          eth_xmit_state_cnt <= eth_xmit_state_cnt + 1;
	    end
		
	    4'd15:
	    begin
          if ( !transmit_start && transmit_start_prev )
            eth_xmit_state_cnt <= 4'b0;
          else if ( !transmit_start ) begin
            OrbCmd_start_tx <= 1'b1;
          end else  
            eth_xmit_state_cnt <= 4'd15;
          
	    end
		
	    default:
	    begin
          eth_xmit_state_cnt <= 4'b0;
	    end
		
      endcase 
		
      // ==============================================================================
      // IP layer TX section
      ipxmit_frameSent <= ipxmit_sendFrame;
      if (ipxmit_tx_dpmem_wr) begin
        tx_dpmem_addr_wr <= {3'b0, ipxmit_tx_dpmem_wr_addr}; //-- Todo: size of ipxmit_tx_dpmem_wr_addr is high!
        tx_dpmem_data_in <= ipxmit_tx_dpmem_wr_data;
      end
      ipxmit_complete <= ipxmit_tx_dpmem_wr;
      // ==============================================================================
      // ARP layer TX section
      arpxmit_frameSent <= 1'b0;
      if (OrbCmd_start_tx) begin
        arpxmit_frameSent <= 1'b1;
        arp_en <= 1'b0;
      end
      if (arpxmit_tx_dpmem_wr) begin
        tx_dpmem_addr_wr <= {3'b0,arpxmit_tx_dpmem_wr_addr} + 11'd1532; //-- Todo: size of ipxmit_tx_dpmem_wr_addr is high!
        tx_dpmem_data_in <= arpxmit_tx_dpmem_wr_data;
        arp_en <= 1'b1;
      end
      arpxmit_complete <= arpxmit_tx_dpmem_wr;
      // ==============================================================================
      // ICMP layer Reply section
      icmprply_wrRAM_cmplt <= 1'b0;
      if (icmprply_tx_dpmem_wr) begin
        tx_dpmem_addr_wr <= {3'b0,icmprply_tx_dpmem_wr_addr};
        tx_dpmem_data_in <= icmprply_tx_dpmem_wr_data;
        icmprply_wrRAM_cmplt <= 1'b1;
      end
      // ==============================================================================
      // UDP layer handler section
      udphndl_wrRAM_cmplt <= 1'b0;
      if (udphndl_wrRAM) begin
        tx_dpmem_addr_wr <= udphndl_wrAddr;
        tx_dpmem_data_in <= udphndl_wrData;
        udphndl_wrRAM_cmplt <= 1'b1;
      end

      // default values
      tx_load_cnt <= 1'b0;
      tx_len_fifo_write <= 1'b0;
      transmit_start <= 1'b0;
      tx_data_fifo_write_int <= 1'b0;
      tx_data_fifo_write <= tx_data_fifo_write_int;

      case (hworb_tx_fsm)
        TX_IDLE:
        begin
          tx_len_fifo_write <= 1'b0;
			        
          if (OrbCmd_start_tx) begin
            hworb_tx_fsm <= TX_WAIT1;
            transmit_start <= 1'b1;
			
            if (!arp_en) 
              tx_dpmem_addr_rd <= 11'b0;     // ETH memory start address for normal IP packet : 0x000
            else
              tx_dpmem_addr_rd <= 11'd1532;  // ETH memory start address for ARP packet : 0x5FC
			
          end
        end
		   
        TX_WAIT1:
        begin
          // delay for data out of len fifo
          hworb_tx_fsm <= TX_PULL_PUSH_PKT;
          tx_load_cnt <= 1'b1;
        end
			 			 
        TX_PULL_PUSH_PKT:
        begin
          if (tx_len_down_cnt == 16'd1) begin
            tx_len_fifo_write <= 1'b1;
            hworb_tx_fsm <= TX_WAIT2;
          end 
          else begin
            hworb_tx_fsm <= TX_PULL_PUSH_PKT;
            tx_data_fifo_write_int <= 1'b1;
          end	
          tx_byte2word[7:0] <= tx_dpmem_data_out[7:0];
          tx_dpmem_addr_rd <= tx_dpmem_addr_rd + 1;
        end
				 
        TX_WAIT2:
        begin
          // 1 clk delay
          hworb_tx_fsm <= TX_IDLE;
        end
		
        default:
        begin
          hworb_tx_fsm <= TX_IDLE;
          tx_load_cnt <= 1'b0;
          tx_len_fifo_write <= 1'b0;
          tx_data_fifo_write_int <= 1'b0;
          tx_len_in_bytes <= 16'b0;
        end
	
      endcase 
	  
      tx_done_int <= 1'b0;
      if (tx_dpmem_addr_rd == 11'd35) begin
        tx_done_int <= 1'b1;
      end	  
	  
    end
  end // always 
  
  assign tx_data_fifo_data  = tx_byte2word;
  assign tx_len_fifo_data   = tx_len_in_bytes[15:0];

endmodule
