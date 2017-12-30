/***********************************************************************
  $FILENAME    : arp_reply_rx.v

  $TITLE       : ARP protocol (rx) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : Manages an ARP table for the network stack project. This protocol listens
                 to incoming data and when an ARP request or reply arrives, the data of the
                 source is added to the ARP table. The ARP table contains two entries.
                 When a request arrives a signal is also asserted telling the arp sender to
                 send an ARP reply when possible. The incoming data from the ethernet layer
                 is a byte stream.

  $AUTHOR     : (C) 2001 Ashley Partis and Jorgen Peddersen (VHDL code)
                Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com) (Verilog code)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module arp_reply_rx #(
  parameter [31:0] DEVICE_IP      = 32'h0a0105dd,
  parameter [47:0] DEVICE_MAC     = 48'h001999cf956f
)
(
  input              clk,               // clock 
  input              reset_n,           // asynchronous active low reset
  input              newFrame,			// from ethernet layer indicates data arrival
  input              frameType,			// '0' for an ARP message
  input              newFrameByte,		// indicates a new byte in the stream
  input [7:0]        frameData,	        // the stream data
  input              frameValid, 		// indicates validity while endFrame is asserted
  input              ARPSendAvail,		// ARP sender asserts this when the reply is transmitted
  input [31:0]       requestIP,	        // ARP sender can request MACs for this address
  output reg         genARPRep,		    // tell ARP sender to generate a reply
  output reg  [31:0] genARPIP,          // destination IP for generated reply
  output reg  [47:0] lookupMAC,         // if valid, MAC for requested IP
  output reg         validEntry         // indicates if requestIP is in table
);

  //-- State signals and types
  parameter [1:0]
	RX_ARP_IDLE    	           = 2'd0,	// IDLE State
	RX_ARP_HANDLEARP   	       = 2'd1,	// WAIT1 State
	RX_ARP_OPERATE   	       = 2'd2,	// WAIT2 State
	RX_ARP_CHECKVALID  	       = 2'd3;	// WAIT3 State
  
  reg [1:0]  arp_rep_rx_cur_fsm;
  reg [1:0]  arp_rep_rx_nxt_fsm;

  reg [4:0]  cnt;		         // header count
  reg        incCnt;			 // signal to increment cnt
  reg        rstCnt;			 // signal to clear cnt

  reg        latchFrameData;	 // signal to latch stream data
  reg [7:0]  frameDataLatch;	 // register for latched data
  reg        shiftSourceIPIn;	 // signal to shift in source IP
  reg [31:0] sourceIP;	         // stores source IP
  reg        shiftSourceMACIn;	 // signal to shift in source MAC
  reg [47:0] sourceMAC;	         // stores source MAC

  reg        ARPOperation;		 // '0' for reply, '1' for request
  reg        determineOperation; // signal to latch ARPOperation from stream

  reg        updateARPTable;	 // this signal updates the ARP table
  reg [31:0] ARPEntryIP;	     // most recent ARP entry IP
  reg [47:0] ARPEntryMAC;	     // most recent ARP entry MAC
  reg [31:0] ARPEntryIPOld;	     // 2nd ARP entry IP
  reg [47:0] ARPEntryMACOld;	 // 2nd ARP entry MAC

  reg        doGenARPRep;		 // asserted when an ARP reply must be generated

  // ==============================================================================
  always @(posedge clk or negedge reset_n) 
  begin
	// reset state and ARP entries  
    if (!reset_n) begin
	  arp_rep_rx_cur_fsm <= RX_ARP_IDLE;
	  ARPEntryIP <= 32'b0;
	  ARPEntryMAC <= 48'b0;
	  ARPEntryIPOld <= 32'b0;
	  ARPEntryMACOld <= 48'b0;
      genARPRep <= 1'b0;
	  ARPOperation <= 1'b0;
	  cnt <= 5'b0;
	end
	else begin
	  arp_rep_rx_cur_fsm <= arp_rep_rx_nxt_fsm;	// go to next state
	  
	  if (incCnt)	            // handle counter
	    cnt <= cnt + 1;
	  else if (rstCnt)
	    cnt <= 5'b0;
	  
	  if (latchFrameData)	    // latch stream data
	    frameDataLatch <= frameData;
	  
	  if (determineOperation)	// determine ARP Operation value
	    ARPOperation <= frameDataLatch[0];
	  
	  if (shiftSourceIPIn)	    // shift in IP
	    sourceIP <= {sourceIP[23:0], frameDataLatch};
	  
	  if (shiftSourceMACIn)	    // shift in MAC
	    sourceMAC <= {sourceMAC[39:0], frameDataLatch};
	  
	  if (updateARPTable) begin	// update ARP table
	    if (ARPEntryIP == sourceIP)	        // We already have this ARP, so update
	      ARPEntryMAC <= sourceMAC;
	    else begin							// Lose one old ARP entry and add new one.
	      ARPEntryIPOld <= ARPEntryIP;
	      ARPEntryMACOld <= ARPEntryMAC;
	      ARPEntryIP <= sourceIP;
	      ARPEntryMAC <= sourceMAC;
	    end
	  end
	  
	  // genARPRep is asserted by doGenARPRep and will stay high until cleared 
	  // by ARPSendAvail
	  if (doGenARPRep) begin	
	    genARPRep <= 1'b1;		// when a request is needed assert genARPRep
	    genARPIP <= sourceIP;	// and latch the outgoing address
	  end	
	  else if (ARPSendAvail) 
	    genARPRep <= 1'b0;		// when the request has been generated, stop requesting
	  						
	  
    end
  end // always 

  // ==============================================================================
  // ARP rx fsm
  always @(arp_rep_rx_cur_fsm or sourceIP or ARPOperation or cnt or newFrame or frameType or newFrameByte or frameDataLatch or frameValid)
  begin
    // defaulting of signals
	rstCnt <= 1'b0;
	incCnt <= 1'b0;
	shiftSourceIPIn <= 1'b0;
	determineOperation <= 1'b0;
	updateARPTable <= 1'b0;
	shiftSourceIPIn <= 1'b0;
	shiftSourceMACIn <= 1'b0;
	latchFrameData <= 1'b0;
	doGenARPRep <= 1'b0;
	
    case (arp_rep_rx_cur_fsm)
	  RX_ARP_IDLE:
	  begin
		// wait for an ARP frame to arrive
		if (newFrame && !frameType) begin
		  arp_rep_rx_nxt_fsm <= RX_ARP_HANDLEARP;
		  rstCnt <= 1'b1;
		end  
		else
		  arp_rep_rx_nxt_fsm <= RX_ARP_IDLE;
      end

	  RX_ARP_HANDLEARP:
	  begin
		// receive a byte from the stream
		if (!newFrameByte)
		  arp_rep_rx_nxt_fsm <= RX_ARP_HANDLEARP;
		else begin
		  arp_rep_rx_nxt_fsm <= RX_ARP_OPERATE;
		  latchFrameData <= 1'b1;
		end
	  end
			
	  RX_ARP_OPERATE:
	  begin
	    // increment counter
		incCnt <= 1'b1;
		// choose state based on values in the header
		// The following will make us ignore the frame (all values hexadecimal):
		// Hardware Type /= 1
		// Protocol Type /= 800
		// Hardware Length /= 6
		// Protocol Length /= 8
		// Operation /= 1 or 2
		// Target IP /= our IP (i.e. message is not meant for us)
	    if ( 
			  ((cnt == 5'b0 || cnt == 5'b00011 || cnt == 5'b00110) && frameDataLatch != 8'd0 ) || 
			  (cnt == 5'b00001 && frameDataLatch != 8'd1) || 
			  (cnt == 5'b00010 && frameDataLatch != 8'd8) || 
			  (cnt == 5'b00100 && frameDataLatch != 8'd6) ||	
			  (cnt == 5'b00101 && frameDataLatch != 8'd4) ||	 
			  (cnt == 5'b00111 && frameDataLatch != 8'd1 && frameDataLatch != 8'd2 ) || 
			  (cnt == 5'b11000 && frameDataLatch != DEVICE_IP[31:24]) ||	
			  (cnt == 5'b11001 && frameDataLatch != DEVICE_IP[23:16]) || 
			  (cnt == 5'b11010 && frameDataLatch != DEVICE_IP[15:8]) || 
			  (cnt == 5'b11011 && frameDataLatch != DEVICE_IP[7:0])
			)
	      arp_rep_rx_nxt_fsm <= RX_ARP_IDLE;
	    else if (cnt == 5'b11011) 
	      arp_rep_rx_nxt_fsm <= RX_ARP_CHECKVALID;	// exit when data is totally received
	    else
	      arp_rep_rx_nxt_fsm <= RX_ARP_HANDLEARP;	// otherwise loop until complete
				
	    // latch and shift in signals from stream when needed
	    if (cnt == 5'b00111)
	      determineOperation <= 1'b1;	
	    
	    if (cnt == 5'b01000 || cnt ==  5'b01001 || cnt == 5'b01010 || cnt == 5'b01011 || cnt == 5'b01100 || cnt == 5'b01101)
		  shiftSourceMACIn <= 1'b1;
	    
	    if (cnt == 5'b01110 || cnt == 5'b01111 || cnt == 5'b10000 || cnt == 5'b10001) 
	      shiftSourceIPIn <= 1'b1;
	    
	  end
								
	  RX_ARP_CHECKVALID:
	  begin
		// wait for the END of the frame
	    if (!frameValid)
		  // frame failed CRC so ignore it
		  arp_rep_rx_nxt_fsm <= RX_ARP_CHECKVALID;
	    else begin
		  // generate a reply if required and wait for more messages
		  if (ARPOperation)
		    doGenARPRep <= 1'b1;
		  			
		  arp_rep_rx_nxt_fsm <= RX_ARP_IDLE;
		  updateARPTable <= 1'b1;	// update the ARP table with the new data
	    end
	  end

	  default:
	  begin
          arp_rep_rx_nxt_fsm <= RX_ARP_IDLE;
	  end
	
    endcase 
	
  end // always
			
  // ==============================================================================
  // handle requests for entries in the ARP table.
  always @(requestIP or ARPEntryIP or ARPEntryMAC or ARPEntryIPOld or ARPEntryMACOld)
  begin
    if (requestIP == ARPEntryIP) begin			// check most recent entry
	  validEntry <= 1'b1;
	  lookupMAC <= ARPEntryMAC;
	end  
	else if (requestIP == ARPEntryIPOld) begin	// check 2nd entry
	  validEntry <= 1'b1;
	  lookupMAC <= ARPEntryMACOld;
	end  
	else begin									// if neither entry matches, valid = 0
	  validEntry <= 1'b0;
	  lookupMAC <= 48'b1;
	end
  
  end // always

endmodule
