/***********************************************************************
  $FILENAME    : internet_rx.v

  $TITLE       : Internet protocol (rx) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : IP layer for network stack project. This accepts byte-streams of data from 
                 the ethernet layer and decodes the IP information to send data to the upper
                 protocols. Reassembly is implemented and two incoming packets can be
                 reassembled at once. Reassembly only works if incoming packets come in 
                 order.

  $AUTHOR     : (C) 2001 Ashley Partis and Jorgen Peddersen (VHDL code)
                Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com) (Verilog code)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module internet_rx #(
  parameter [31:0] DEVICE_IP      = 32'h8d59342b
)
(
  input              clk,            // clock 
  input              reset_n,        // asynchronous active low reset
  
  input              newFrame,		 // new frame received from the layer below
  input              frameType,      // frame TYPE = '1' for IP
  input              newFrameByte,   // signals a new byte in the stream
  input [7:0]        frameData,      // data is streamed in here
  output reg         newDatagram,    // an IP datagram has been fully received
  output reg  [15:0] datagramSize,   // size of the datagram received
  output wire [7:0]  protocol,       // protocol TYPE of datagram
  output wire [31:0] sourceIP	     // lets upper protocol know the source IP
);

  // signal declarations
  // FSM states
  parameter [1:0]
	RX_INT_IDLE    	           = 3'd0,	
	RX_INT_GETHEADERLEN   	   = 3'd1,	
	RX_INT_GETHEADERBYTE   	   = 3'd2,	
	RX_INT_COMPLETEFRAGMENT    = 3'd3;
  
  reg [1:0]  ip_rx_cur_fsm;
  reg [1:0]  ip_rx_nxt_fsm;
  reg [1:0]  returnState;	  // Used to return from RAM 'subroutines' 
  reg [5:0]  headerLen;	      // IP datagram header length
  reg [5:0]  nextHeaderLen;	  // signal for the next header lengh
  reg [10:0] datagramLen;     // IP datagram total length in bytes
  reg [10:0] nextDatagramLen; // signal for the next datagram length
  wire [10:0] dataLen;        // IP datagram data length in bytes
  reg [10:0] nextDataLen;     // signal for the next data length
  reg        incCnt;		  // increments byte address counter
  reg        rstCnt;		  // resets byte address counter
  reg [5:0]  cnt;	          // byte address counter for the frame received
  reg        latchFrameData;  // latch in the data from the stream
  reg [7:0]  frameDataLatch;  // register to hold latched data
  reg [31:0] targetIP;        // stores target IP (destination)
  reg        shiftInTargetIP; // signal to shift in target IP
  reg        shiftInSourceIP; // stores source IP
  reg        latchProtocol;	  // signal to shift in source IP
  // checksum signals
  reg        checkState;
  parameter  stMSB = 1'b0;
  parameter  stLSB = 1'b1;
  reg [16:0] checksumLong;    // stores 2's complement sum
  wire [15:0] checksumInt;    // stores 1's complement sum
  reg [7:0]  latchMSB;	      // latch in first byte
  reg        newHeader;		  // resets checksum
  reg        newByte;		  // indicate new byte
  reg        lastNewByte;	  // detect changes in newByte
  reg [7:0]  inByte;	      // byte to calculate
  wire [15:0] checksum;       // current checksum

  reg [15:0] identification;  		 // identification field
  reg        shiftInIdentification;	 // signal to shift in identification
  reg [12:0] fragmentOffset;         // fragment offset field
  reg        shiftInFragmentOffset;	 // signal to shift in offset
  reg        moreFragments;			 // more fragments flag
  reg        latchMoreFragments;	 // signal to determine MF flag

  parameter  TIMERWIDTH = 7;		 // can be used to vary timeout length
  reg [6:0]  timeout0;	             // timeout counter
  reg        resetTimeout;		     // start timeout counter
  parameter  FULLTIME = 7'b1111111;  // last value of timeout counter
  reg [31:0] sourceIPSig;	         // internal signal for output
  reg [7:0]  protocolSig;		     // internal signal for output	

  // These signals are used instead of buffer ports
  assign sourceIP = sourceIPSig;
  assign protocol = protocolSig;
	
  // Some definitions to make further code simpler
//	targetIdent <= sourceIPSig & protocolSig & identification;
  assign dataLen = datagramLen - {5'b00000,headerLen[5:0]};
	
  // ==============================================================================
  // main clocked logic
  always @(posedge clk or negedge reset_n) 
  begin
    // set up the asynchronous active low reset
    if (!reset_n) begin
	  ip_rx_cur_fsm <= RX_INT_IDLE;
	  returnState <= RX_INT_IDLE;
	  timeout0 <= FULLTIME;
	  cnt <= 6'b0;
	  moreFragments <= 1'b0;
	end
	else begin
	  // Go to next state wether directly or via a RAM state.
	  // If a RAM write or a new byte from the data stream are requested,
	  // the state machine stores ip_rx_nxt_fsm in returnState and goes to the
	  // required state.  After completion, the state machine will go to 
	  // returnState. This is like a 'subroutine' in the state machine.
//	  if (getNewByte) begin
//	    ip_rx_cur_fsm <= RX_INT_GETNEWBYTE;
//		returnState <= ip_rx_nxt_fsm;
//	  end	
//	  else
		ip_rx_cur_fsm <= ip_rx_nxt_fsm;
	  			
	  // increment and reset the counter synchronously to avoid race conditions
	  if (incCnt)
	    cnt <= cnt + 1;
	  else if (rstCnt)
		cnt <= 6'b0;
	  			
	  // latch data read from RAM
      if (latchFrameData)
	    frameDataLatch <= frameData;
	  			
      // these signals must remember their values once set
      headerLen <= nextHeaderLen;
      datagramLen <= nextDatagramLen;

      // shift registers and latches to hold important data
      if (shiftInSourceIP)
        sourceIPSig <= {sourceIPSig[23:0], frameData};
      
      if (shiftInTargetIP)
        targetIP <= {targetIP[23:0], frameData};
      
      if (latchProtocol)
        protocolSig <= frameData;
      
      if (shiftInFragmentOffset)
        fragmentOffset <= {fragmentOffset[4:0], frameData};
      
      if (latchMoreFragments)
        moreFragments <= frameData[5];
      
      if (shiftInIdentification)
        identification <= {identification[7:0], frameData};
      			
      // handle timeout counters, resetTimeout will only reset the current buffer
      if (resetTimeout)
        timeout0 <= 7'b0;
	  else begin
	    // increment timeout counters but don't let them overflow
		if (timeout0 != FULLTIME)
		  timeout0 <= timeout0 + 1;
		else
		  timeout0 <= FULLTIME;
		
	  end
			
    end
  end // always 

  // ==============================================================================
  // IP datagram header format
  //
  //	0          4          8                      16      19             24                    31
  //	--------------------------------------------------------------------------------------------
  //	| Version  | *Header  |    Service Type      |        Total Length including header        |
  //	|   (4)    |  Length  |     (ignored)        |                 (in bytes)                  |
  //	--------------------------------------------------------------------------------------------
  //	|           Identification                   | Flags |       Fragment Offset               |
  //	|                                            |       |      (in 32 bit words)              |
  //	--------------------------------------------------------------------------------------------
  //	|    Time To Live     |       Protocol       |             Header Checksum                 |
  //	|     (ignored)       |                      |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|                                   Source IP Address                                      |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //	|                                 Destination IP Address                                   |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //	|                          Options (if any - ignored)               |       Padding        |
  //	|                                                                   |      (if needed)     |
  //	--------------------------------------------------------------------------------------------
  //	|                                          Data                                            |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //	|                                          ....                                            |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //
  // * - in 32 bit words 
  // ==============================================================================

  // ==============================================================================
  always @(ip_rx_cur_fsm or returnState or cnt or frameData or datagramLen or headerLen or dataLen or newFrame or frameType or checksum or targetIP or timeout0 or	fragmentOffset or moreFragments or newFrameByte)
  begin
    // signal defaults
    datagramSize <= 16'b0;
	incCnt <= 1'b0;
	rstCnt <= 1'b0;
	newDatagram <= 1'b0;
	// the following two signals remember their previous value if not reassigned
	nextHeaderLen <= headerLen;
	nextDatagramLen <= datagramLen;
	latchFrameData <= 1'b0;
	shiftInSourceIP <= 1'b0;
	shiftInTargetIP <= 1'b0;
	latchProtocol <= 1'b0;
	newHeader <= 1'b0;
	newByte <= 1'b0;
	inByte <= 8'b0;
	latchMoreFragments <= 1'b0;
	shiftInFragmentOffset <= 1'b0;

	shiftInIdentification <= 1'b0;		
	resetTimeout <= 1'b0;
	
	case(ip_rx_cur_fsm)
	  RX_INT_IDLE: // 0
	  begin
	    resetTimeout <= 1'b1;
        // wait for the arrival of a new frame that has a frameType of 1
		if (!newFrame || !frameType)
		  ip_rx_nxt_fsm <= RX_INT_IDLE;
		else begin
		  // reset the counters for the next datagram
		  rstCnt <= 1'b1;
		  newHeader <= 1'b1;
		  ip_rx_nxt_fsm <= RX_INT_GETHEADERLEN;
		end
	  end	  

      RX_INT_GETHEADERLEN: // 1
	  begin
		if (newFrameByte) begin  
	      // check ip version
	      if (frameData[7:4] != 4)
		    ip_rx_nxt_fsm <= RX_INT_IDLE;
	      else begin
		    ip_rx_nxt_fsm <= RX_INT_GETHEADERBYTE;
		    // send data to checksum machine
		    inByte <= frameData;
		    newByte <= 1'b1;
		    // get the header length in bytes, rather than 32-bit words
		    nextHeaderLen <= {frameData[3:0], 2'b00};
	      end
		  incCnt <= 1'b1;
		end
		else
		  ip_rx_nxt_fsm <= RX_INT_GETHEADERLEN;
	  end	  
			
      RX_INT_GETHEADERBYTE:  // 2
	  begin
	    // if we've finished getting the headers and processing them, start on the data
	    // once finished, refragmenting will come next
	    if (cnt == headerLen)  begin
	      // only operate on data meant for us, or broadcast data
	      if (checksum == 0 && (targetIP == DEVICE_IP || targetIP == 32'hFFFFFFFF))  
		    ip_rx_nxt_fsm <= RX_INT_COMPLETEFRAGMENT;
	      else
		    // ignore frame as it wasn't for us
		    ip_rx_nxt_fsm <= RX_INT_IDLE;
		end			
		else if (newFrameByte) begin  
	      // operate on each value of the header received according to count
	      // count will be one higher than the last byte received, as it is incremented
	      // at the same time as the data is streamed in, so
	      // when the data is seen to be available, count should also be one higher
				
	      // Send data to checksum PROCESS
	      newByte <= 1'b1;
	      inByte <= frameData;
				
	      // Operate on data in the header
	      case(cnt[4:0])				
	        5'd2://3
	        begin
  	          nextDatagramLen[10:8] <= frameData[2:0];
	        end	
						
	        5'd3://4
	        begin
	          nextDatagramLen[7:0] <= frameData;
	        end	
						
	        5'd4, 5'd5://5 6
	        begin
	          shiftInIdentification <= 1'b1;
	        end	
						
	        5'd6: // 7
	        begin
	          shiftInFragmentOffset <= 1'b1;
	          latchMoreFragments <= 1'b1;
	        end	
						
	        5'd7: // 8
	        begin
	          shiftInFragmentOffset <= 1'b1;
	        end	
						
	        5'd9: // 10=a
	        begin
	          latchProtocol <= 1'b1;
	        end	
						
	        5'd12, 5'd13, 5'd14, 5'd15: // 13, 14 16
	        begin
	          shiftInSourceIP <= 1'b1;
	        end	
						
	        5'd16, 5'd17, 5'd18, 5'd19:	// 17, 18, 19, 20				
	        begin
 	          shiftInTargetIP <= 1'b1;
	        end	
						
	        default:
	        begin
	        end	
		  
	      endcase
		  incCnt <= 1'b1;
		  ip_rx_nxt_fsm <= RX_INT_GETHEADERBYTE;
          resetTimeout <= 1'b1;
		end
	    else if (timeout0 == FULLTIME)
		  ip_rx_nxt_fsm <= RX_INT_IDLE;
		// otherwise get the next header byte from RAM
	    else begin
		  ip_rx_nxt_fsm <= RX_INT_GETHEADERBYTE;
	    end
				
	  end	  
			
	  RX_INT_COMPLETEFRAGMENT: // 3
	  begin
		// Signal the transport protocols if the datagram is finished
		// or await next frame.
		ip_rx_nxt_fsm <= RX_INT_IDLE;
		if (!moreFragments) begin
		  // Last frame so :
		  newDatagram <= 1'b1;		// notify higher protocols it's ready
		  datagramSize <= {5'b00000, dataLen};
	    end
	  end	  
				
      default:
	  begin
 	    ip_rx_nxt_fsm <= RX_INT_IDLE;
	  end	  
	  
	endcase
  end // always
	
  // Perform 2's complement to one's complement conversion, and invert output
  assign checksumInt = checksumLong[15:0] + checksumLong[16];
  assign checksum = ~checksumInt;

  // ==============================================================================
  always @(posedge clk or negedge reset_n) 
  begin
	// reset state and ARP entries  
    if (!reset_n) begin
	  checkState <= stMSB;
	  latchMSB <= 8'b0;
	  checksumLong <= 17'b0;
	  lastNewByte <= 1'b0;
	end
	else begin
	  // this is used to check only for positive transitions
	  lastNewByte <= newByte;		
			
      case(checkState)
	    stMSB:
		begin
		  if (newHeader)  begin
		    // reset calculation
			checkState <= stMSB;
			checksumLong <= 17'b0;
		  end	
		  else if (newByte && !lastNewByte)  begin
		    // latch MSB of 16 bit data
			checkState <= stLSB;
			latchMSB <= inByte;
		  end	
		  else
			checkState <= stMSB;
		end
					
	    stLSB:
		begin		
		  if (newHeader)  begin
		    // reset calculation
			checkState <= stMSB;
			checksumLong <= 17'b0;
		  end	
		  else if (newByte && !lastNewByte)  begin
			// add with 2's complement arithmetic (convert to 1's above)
			checkState <= stMSB;
			checksumLong <= {1'b0,checksumInt} + {1'b0,latchMSB,inByte};
		  end	
		  else
			checkState <= stLSB;
		end
					
		default:
		begin
		  checkState <= stMSB;
		end
		  
	  endcase
	  
    end
  end // always	
	
endmodule
