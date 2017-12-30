/***********************************************************************
  $FILENAME    : arp_reply_tx.v

  $TITLE       : ARP protocol (tx) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : Sits transparently between the internet send and ethernet send layers.
                 All frame send requests from the internet layer are passed through after
                 the destination MAC is either looked up from the ARP table, or an ARP 
                 request is sent out and an ARP reply is receiver. ARP replies are created
                 and begin sent to the ethernet later after being requested by the ARP layer.  
                 After each frame is passed on to the ethernet layer and begin sent, it informs
                 the layer above that the frame has been sent.

  $AUTHOR     : (C) 2001 Ashley Partis and Jorgen Peddersen (VHDL code)
                Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com) (Verilog code)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module arp_reply_tx #(
  parameter [31:0] DEVICE_IP      = 32'h0a0105dd,
  parameter [47:0] DEVICE_MAC     = 48'h001999cf956f
)
(
  input              clk,            // clock 
  input              reset_n,        // asynchronous active low reset
  input              complete,       // RAM complete SIGNAL
  input              frameSent,      // input from the PHY that it's processed our frame
  input              sendFrame,      // send an ethernet frame - from IP layer
  input [10:0]       frameLen,       // input from IP giving frame length
  input [31:0]       targetIP,       // destination IP from the internet layer
  input              ARPEntryValid,  // input from ARP indicating that it contains the requested IP
  input              genARPReply,    // input from ARP requesting an ARP reply
  input [31:0]       genARPIP,       // input from ARP saying which IP to send a reply to
  input [47:0]       lookupMAC,      // input from ARP giving a requested MAC
  output reg  [31:0] lookupIP,       // output to ARP requesting an IP to be looked up in the table
  output reg         sendingReply,   // output to ARP to tell it's sending the ARP reply
  output reg  [47:0] targetMAC,      // destination MAC for the physical layer
  output reg         genFrame,       // tell the ethernet layer (PHY) to send a frame
  output reg         frameType,      // tell the PHY to send an ARP frame or normal IP datagram
  output reg  [10:0] frameSize,      // tell the PHY what size the frame size is
  output reg         idle,           // idle SIGNAL
  output reg         sendingFrame,   // tell the IP layer that we're sending their data
  output reg         wrRAM,          // write RAM SIGNAL to the RAM
  output reg  [7:0]  wrData,         // write data bus to the RAM
  output reg  [7:0]  wrAddr		     // write address bus to the RAM
);

  // FSM state definitions
  parameter [3:0]
	TX_ARP_IDLE    	               = 4'd0,	
	TX_ARP_GENARPREPLY   	       = 4'd1,	
	TX_ARP_GETREPLYMAC   	       = 4'd2,	
	TX_ARP_STOREARPREPLY  	       = 4'd3,
	TX_ARP_CHECKARPENTRY           = 4'd4,	
	TX_ARP_CHECKARPENTRY2          = 4'd5,	
	TX_ARP_GENARPREQUEST           = 4'd6,	
	TX_ARP_STOREARPREQUEST         = 4'd7,	
	TX_ARP_WAITFORVALIDENTRY       = 4'd8,	
	TX_ARP_GENETHFRAME             = 4'd9;	
  
  reg [3:0]  arp_rep_tx_cur_fsm;
  reg [3:0]  arp_rep_tx_nxt_fsm;

  // signals to synchronously increment and reset the counter
  reg [4:0]  cnt;
  reg        incCnt;
  reg        rstCnt;

  // next write data value
  reg [7:0]  nextWrData;

  // signals and buffers to latch input data
  reg        latchTargetIP;
  reg        latchInternetIP;
  reg [31:0] latchedIP;
  reg        latchTargetMAC;
  reg [47:0] latchedMAC;
  reg        latchFrameSize;
  reg [10:0] latchedFrameSize;

  // 20 second ARP reply timeout counter at 50MHz
  reg [29:0] ARPTimeoutCnt;
  reg        rstARPCnt;
  reg        ARPCntOverflow;

  // ==============================================================================
  // main clocked logic
  always @(posedge clk or negedge reset_n) 
  begin
    // set up the asynchronous active low reset
    if (!reset_n) begin
	  arp_rep_tx_cur_fsm <= TX_ARP_IDLE;
	  cnt <= 5'b0;
	  ARPCntOverflow <= 1'b0;
	end
	else begin
	  arp_rep_tx_cur_fsm <= arp_rep_tx_nxt_fsm;
	  // set the write data bus to it's next value
	  wrData <= nextWrData;
      
  	  // increment and reset the counter synchronously to avoid race conditions
	  if (incCnt)
	    cnt <= cnt + 1;
	  else if (rstCnt)
		cnt <= 5'b0;
	  
	  // set the ARP counter to 1
	  if (rstARPCnt) begin
	    ARPTimeoutCnt <= 30'd1;
	    ARPCntOverflow <= 1'b0;
	  end	
	  // if the ARP counter isn't 0, keep incrementing it
	  else if (ARPTimeoutCnt != 30'b0) begin
	    ARPTimeoutCnt <= ARPTimeoutCnt + 1;
	    ARPCntOverflow <= 1'b0;
	  end	
	  // if the counter is 0, set the overflow SIGNAL
	  else
	    ARPCntOverflow <= 1'b1;
	  
	  // latch the IP to send the ARP request to, send the ARP reply to or to lookup
	  // from either the ARP layer or internet send layer
	  if (latchTargetIP)
	    latchedIP <= genARPIP;
	  else if (latchInternetIP)
	    latchedIP <= targetIP;
	  
	  // latch the MAC from the ARP table that has been looked up
	  if (latchTargetMAC) 
	    latchedMAC <= lookupMAC;
	  
	  // latch the size of the frame size to send from the internet layer
	  if (latchFrameSize) begin
        if (genARPReply)    
		  latchedFrameSize <= {3'b0,8'h2A};
        else
		  latchedFrameSize <= frameLen + 14;
        
	  end
    end
  end // always 

  // ==============================================================================
  // ARP header format
  // 
  //	0                      8                      16                                          31
  //	--------------------------------------------------------------------------------------------
  //	|                Hardware Type               |               Protocol Type                 |
  //	|                                            |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|   Hardware Address  |   Protocol Address   |                 Operation                   |
  //	|       Length        |       Length         |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|                          Sender Hardware Address (MAC) (bytes 0 - 3)                     |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //	|           Sender MAC (bytes 4 - 5)         |        Sender IP Address (bytes 0 - 1)      |
  //	|                                            |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|            Sender IP (bytes 2 - 3)         |    Target Hardware Address (bytes 0 - 1)    |
  //	|                                            |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|                                  Target MAC (bytes 2 - 5)                                |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //	|                               Target IP Address (bytes 0 - 3)                            |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //
  // ==============================================================================

  // ==============================================================================
  // ARP tx fsm
  always @(arp_rep_tx_cur_fsm or sendFrame or genARPReply or cnt or complete or latchedIP or latchedMAC or wrData or	ARPEntryValid or latchedFrameSize or ARPCntOverflow or frameSent)
  begin
    // remember the value of the RAM write data bus by default
	nextWrData <= wrData;
	// lookup the latched IP by default
	lookupIP <= latchedIP;
	wrRAM <= 1'b0;
	wrAddr <= 8'b0;
	rstCnt <= 1'b0;
	incCnt <= 1'b0;
	sendingReply <= 1'b0;
	idle <= 1'b0;
	targetMAC <= 48'b0;
		
    genFrame <= 1'b0;
    
	frameType <= 1'b0;
	sendingFrame <= 1'b0;
	frameSize <= 11'b0;
	latchFrameSize <= 1'b0;
	latchInternetIP <= 1'b0;
	latchTargetIP <= 1'b0;
	latchTargetMAC <= 1'b0;
	rstARPCnt <= 1'b0;

    case (arp_rep_tx_cur_fsm)
	  TX_ARP_IDLE: // 0
	  begin
		// wait for a frame to arrive
		if (!sendFrame && !genARPReply) begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_IDLE;
		  idle <= 1'b1;
		  rstCnt <= 1'b1;
		  // create an ARP reply when asked, giving ARP message priority
		end  
		else if (genARPReply) begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_GETREPLYMAC;
		  // latch the target IP from the ARP layer
		  latchTargetIP <= 1'b1;
		  latchFrameSize <= 1'b1;
		end  
		  // pass through the frame form the IP layer, 
		else begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_CHECKARPENTRY;
		  // latch input from the IP layer
		  latchInternetIP <= 1'b1;
		  latchFrameSize <= 1'b1;
		end
	  end
			
	  // create the ARP reply, getting the target MAC from the ARP table
	  TX_ARP_GETREPLYMAC: // 2
	  begin
	    arp_rep_tx_nxt_fsm <= TX_ARP_GENARPREPLY;
		lookupIP <= latchedIP;
		latchTargetMAC <= 1'b1;
		// tell the ARP table that we're sending the reply
		sendingReply <= 1'b1;
	  end
			
	  // generate each byte of the ARP reply according to count
	  TX_ARP_GENARPREPLY: // 1
	  begin
	    arp_rep_tx_nxt_fsm <= TX_ARP_STOREARPREPLY;
		case (cnt)
	      // Hardware type MSB
	      5'b00000:
		  begin
			nextWrData <= 8'b0;
		  end
					
	      // Hardware type LSB
		  5'b00001:
		  begin
			nextWrData <= 8'h01;
		  end
						
	      // Protocol type MSB
		  5'b00010:
		  begin
			nextWrData <= 8'h08;
		  end
					
	      // Protocol type LSB
		  5'b00011:
		  begin
			nextWrData <= 8'b0;
		  end
						
	      // Hardware Address length in bytes
		  5'b00100:
		  begin
			nextWrData <= 8'h06;
		  end
						
	      // IP Address length in bytes
		  5'b00101:
		  begin
			nextWrData <= 8'h04;
		  end
					
	      // Operation MSB
		  5'b00110:
		  begin
			nextWrData <= 8'h00;
		  end
					
	      // Operation LSB
		  5'b00111:
		  begin
			nextWrData <= 8'h02;
		  end
					
	      // Sender Hardware Address byte 0
		  5'b01000:
		  begin
			nextWrData <= DEVICE_MAC[47:40];
		  end
						
	      // Sender Hardware Address byte 1
		  5'b01001:
		  begin
			nextWrData <= DEVICE_MAC[39:32];
		  end

	      // Sender Hardware Address byte 2
		  5'b01010:
		  begin
			nextWrData <= DEVICE_MAC[31:24];
		  end
						
	      // Sender Hardware Address byte 3
		  5'b01011:
		  begin
			nextWrData <= DEVICE_MAC[23:16];
		  end
						
	      // Sender Hardware Address byte 4
		  5'b01100:
		  begin
			nextWrData <= DEVICE_MAC[15:8];
		  end
						
	      // Sender Hardware Address byte 5
		  5'b01101:
		  begin
			nextWrData <= DEVICE_MAC[7:0];
		  end
					
	      // Sender IP Address byte 0
		  5'b01110:
		  begin
			nextWrData <= DEVICE_IP[31:24];
		  end

	      // Sender IP Address byte 1
		  5'b01111:
		  begin
			nextWrData <= DEVICE_IP[23:16];
		  end

	      // Sender IP Address byte 2
		  5'b10000:
		  begin
			nextWrData <= DEVICE_IP[15:8];
		  end

	      // Sender IP Address byte 3
		  5'b10001:
		  begin
			nextWrData <= DEVICE_IP[7:0];
		  end

	      // Target Hardware Address byte 0
		  5'b10010:
		  begin
			nextWrData <= latchedMAC[47:40];
		  end

	      // Target Hardware Address byte 1
		  5'b10011:
		  begin
			nextWrData <= latchedMAC[39:32];
		  end

	      // Target Hardware Address byte 2
		  5'b10100:
		  begin
			nextWrData <= latchedMAC[31:24];
		  end

	      // Target Hardware Address byte 3
		  5'b10101:
		  begin
			nextWrData <= latchedMAC[23:16];
		  end

	      // Target Hardware Address byte 4
		  5'b10110:
		  begin
			nextWrData <= latchedMAC[15:8];
		  end

	      // Target Hardware Address byte 5
		  5'b10111:
		  begin
			nextWrData <= latchedMAC[7:0];
		  end

	      // Target IP Address byte 0
		  5'b11000:
		  begin
			nextWrData <= latchedIP[31:24];
		  end

	      // Target IP Address byte 1
		  5'b11001:
		  begin
			nextWrData <= latchedIP[23:16];
		  end

	      // Target IP Address byte 2
		  5'b11010:
		  begin
			nextWrData <= latchedIP[15:8];
		  end

	      // Target IP Address byte 3
		  5'b11011:
		  begin
			nextWrData <= latchedIP[7:0];
		  end

		  default:
		  begin
		    nextWrData <= 8'hAA;	  
		  end
		  
		endcase 
		end
			
	  // store the ARP reply for the Ethernet sender
	  TX_ARP_STOREARPREPLY: // 3
	  begin
	    // if we've finished storing the ARP reply, begin inform the ethernet layer to send it
	    // and wait for the ethernet layer to begin tell us that it has sent it
	    if (cnt == 5'b11100) begin
	      // if the frame has been sent, return to idle
	      if (frameSent)
	        arp_rep_tx_nxt_fsm <= TX_ARP_IDLE;
	      else begin
			arp_rep_tx_nxt_fsm <= TX_ARP_STOREARPREPLY;
			genFrame <= 1'b1;
			// give the ethernet sender the MAC address to send the reply to and tell it 
			// to send an ARP message
			targetMAC <= latchedMAC;
			frameType <= 1'b0;
            frameSize <= latchedFrameSize;
		  end
		end  
		else if (!complete) begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_STOREARPREPLY;
		  wrRAM <= 1'b1;
		  wrAddr <= {3'b000, cnt[4:0]} + 8'h0E;
		end  
		// if not finished, continue to create the reply
		else begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_GENARPREPLY;
		  incCnt <= 1'b1;
		end
	  end		
				
  // ==============================================================================
	  // handle frames passed on to us from the Internet layer
	  // check to the see if the desired IP is in the ARP table
	  TX_ARP_CHECKARPENTRY: // 4
	  begin
		arp_rep_tx_nxt_fsm <= TX_ARP_CHECKARPENTRY2;
		lookupIP <= latchedIP;
	  end

	  // check to see if the ARP entry is valid
	   TX_ARP_CHECKARPENTRY2: // 5
	   begin
		lookupIP <= latchedIP;
		// if it's not a valid ARP entry, begin generate an ARP request to find the
		// desired MAC address
		if (!ARPEntryValid)
		  arp_rep_tx_nxt_fsm <= TX_ARP_GENARPREQUEST;
		  // otherwise latch the target MAC and pass on the frame to the ethernet layer
		else begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_GENETHFRAME;
		  latchTargetMAC <= 1'b1;
		end
	  end

	  // Todo: it will destroy the prepared reply message with upper layers!!! akzare
      // create each byte of the ARP request according to cnt
	  TX_ARP_GENARPREQUEST: // 6
	  begin
	    arp_rep_tx_nxt_fsm <= TX_ARP_STOREARPREQUEST;
		case (cnt)
	      // Hardware type MSB
	      5'b00000:
		  begin
			nextWrData <= 8'b0;
		  end
					
		  // Hardware type LSB
	      5'b00001:
		  begin
			nextWrData <= 8'h01;
		  end
						
	      // Protocol type MSB
	      5'b00010:
		  begin
			nextWrData <= 8'h08;
		  end
					
	      // Protocol type LSB
	      5'b00011:
		  begin
			nextWrData <= 8'b0;
		  end
						
	      // Hardware Address length in bytes
	      5'b00100:
		  begin
			nextWrData <= 8'h06;
		  end
						
	      // IP Address length in bytes
	      5'b00101:
		  begin
			nextWrData <= 8'h04;
		  end
					
	      // Operation MSB
	      5'b00110:
		  begin
			nextWrData <= 8'h00;
		  end
					
	      // Operation LSB
	      5'b00111:
		  begin
			nextWrData <= 8'h01;
		  end
					
	      // Sender Hardware Address byte 0
	      5'b01000:
		  begin
			nextWrData <= DEVICE_MAC[47:40];
		  end
						
	      // Sender Hardware Address byte 1
	      5'b01001:
		  begin
			nextWrData <= DEVICE_MAC[39:32];
		  end

	      // Sender Hardware Address byte 2
	      5'b01010:
		  begin
			nextWrData <= DEVICE_MAC[31:24];
		  end
						
	      // Sender Hardware Address byte 3
	      5'b01011:
		  begin
			nextWrData <= DEVICE_MAC[23:16];
		  end
						
	      // Sender Hardware Address byte 4
	      5'b01100:
		  begin
			nextWrData <= DEVICE_MAC[15:8];
		  end
						
	      // Sender Hardware Address byte 5
	      5'b01101:
		  begin
			nextWrData <= DEVICE_MAC[7:0];
		  end
					
	      // Sender IP Address byte 0
	      5'b01110:
		  begin
			nextWrData <= DEVICE_IP[31:24];
		  end

	      // Sender IP Address byte 1
	      5'b01111:
		  begin
			nextWrData <= DEVICE_IP[23:16];
		  end

		  // Sender IP Address byte 2
	      5'b10000:
		  begin
			nextWrData <= DEVICE_IP[15:8];
		  end

	      // Sender IP Address byte 3
	      5'b10001:
		  begin
			nextWrData <= DEVICE_IP[7:0];
		  end

	      // Target Hardware Address byte 0
	      // should be 0's for an ARP request
	      5'b10010:
		  begin
			nextWrData <= 8'h00;
		  end

	      // Target Hardware Address byte 1
	      5'b10011:
		  begin
			nextWrData <= 8'h00;
		  end

	      // Target Hardware Address byte 2
	      5'b10100:
		  begin
			nextWrData <= 8'h00;
		  end

	      // Target Hardware Address byte 3
	      5'b10101:
		  begin
			nextWrData <= 8'h00;
		  end

	      // Target Hardware Address byte 4
	      5'b10110:
		  begin
			nextWrData <= 8'h00;
		  end

	      // Target Hardware Address byte 5
	      5'b10111:
		  begin
			nextWrData <= 8'h00;
		  end

	      // Target IP Address byte 0
	      5'b11000:
		  begin
			nextWrData <= latchedIP[31:24];
		  end

	      // Target IP Address byte 1
	      5'b11001:
		  begin
			nextWrData <= latchedIP[23:16];
		  end

	      // Target IP Address byte 2
	      5'b11010:
		  begin
			nextWrData <= latchedIP[15:8];
		  end

	      // Target IP Address byte 3
	      5'b11011:
		  begin
			nextWrData <= latchedIP[7:0];
		  end

		  default:
		  begin
			nextWrData <= 8'b0;
		  end
	    endcase
	  end

	  // store the ARP request 
	  TX_ARP_STOREARPREQUEST: // 7
	  begin
		// once the ARP request has been generated, inform the ethernet layer to send it
		// wait for the ethernet layer to inform us that it's sent before continuing
		if (cnt == 5'b11100) begin
		  if (frameSent) begin
			arp_rep_tx_nxt_fsm <= TX_ARP_WAITFORVALIDENTRY;
			// reset the ARP timeout counter to start counting
			rstARPCnt <= 1'b1;
		  end	
		  else begin
			arp_rep_tx_nxt_fsm <= TX_ARP_STOREARPREQUEST;
			genFrame <= 1'b1;
			targetMAC <= 48'hFFFFFFFFFFFF;
			frameType <= 1'b0;
            frameSize <= {3'b000,8'h0x2A};
		  end
		end  
		else if (!complete) begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_STOREARPREQUEST;
		  wrRAM <= 1'b1;
		  wrAddr <= {3'b000, cnt[4:0]} + 8'h0E;
		end  
		// if the ARP request hasn't been fully generated begin continue creating and 
		// storing it
		else begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_GENARPREQUEST;
		  incCnt <= 1'b1;
		end
	  end		
			
	  // wait for the ARP entry to become valid
	  TX_ARP_WAITFORVALIDENTRY: // 8
	  begin
		// if the ARP entry becomes valid begin we fire off the reply
		if (ARPEntryValid) begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_GENETHFRAME;
		  latchTargetMAC <= 1'b1;
		end 
		  // otherwise give a certain amount of time for the ARP reply to come
		  // back in (21.5 secs on a 50MHz clock)
		else begin
		  // if the reply doesn't come back, begin inform the above layer that the
		  // frame was sent.  Assume the higher level protocol can account for this
		  // problem, or possibly an error SIGNAL could be created once a higher level
		  // protocol has been written that can accomodate this
		  if (ARPCntOverflow) begin
		    arp_rep_tx_nxt_fsm <= TX_ARP_IDLE;
			sendingFrame <= 1'b1;
		  end	
		  else				
			arp_rep_tx_nxt_fsm <= TX_ARP_WAITFORVALIDENTRY;
		  
		end
		lookupIP <= latchedIP;
	  end
					
	  // send the requested frame
	  TX_ARP_GENETHFRAME: // 9
	  begin
		// wait for the ethernet layer to tell us that the frame was sent, and begin
		// inform the internet layer that the frame was sent
		if (frameSent) begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_IDLE;
		  sendingFrame <= 1'b1;
		end
		  // keep telling the ethernet layer to send the frame until it is sent
		else begin
		  arp_rep_tx_nxt_fsm <= TX_ARP_GENETHFRAME;
		  genFrame <= 1'b1;
		  frameType <= 1'b1;
		  targetMAC <= latchedMAC;
		  frameSize <= latchedFrameSize;
		end
	  end
				
	  default:
	  begin
	    arp_rep_tx_nxt_fsm <= TX_ARP_IDLE;
  	    wrRAM <= 1'b0;
  	    wrAddr <= 8'b0;
  	    rstCnt <= 1'b0;
  	    incCnt <= 1'b0;
  	    sendingReply <= 1'b0;
  	    idle <= 1'b0;
  	    targetMAC <= 48'b0;
  	    genFrame <= 1'b0;
  	    frameType <= 1'b0;
  	    sendingFrame <= 1'b0;
  	    frameSize <= 11'b0;
  	    latchFrameSize <= 1'b0;
  	    latchInternetIP <= 1'b0;
  	    latchTargetIP <= 1'b0;
  	    latchTargetMAC <= 1'b0;
  	    rstARPCnt <= 1'b0;
	  end
	  
    endcase

  end // always

endmodule
