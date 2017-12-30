/***********************************************************************
  $FILENAME    : internet_tx.v

  $TITLE       : Internet protocol (tx) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : Internet packet sending layer. Sends TPDUs from the transport layers as IP
                 packets. If the datagram is too large to fit into one frame (1480 bytes),
                 fragments are transmitted until the full datagram is transmitted. All
                 fragments transmitted except for the last fragment are 1024 bytes long. The
                 last fragment may be anything from 1 byte to 1480 bytes long depending on 
                 how much of the datagram is left. Fragments are transmitted as soon as the
                 previous fragment is transmitted, and all fragments will be transmitted 
                 before the IP layer becomes idle again.

  $AUTHOR     : (C) 2001 Ashley Partis and Jorgen Peddersen (VHDL code)
                Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com) (Verilog code)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module internet_tx #(
  parameter [31:0] DEVICE_IP      = 32'h0a0105dd
)
(
  input              clk,           // clock 
  input              reset_n,       // asynchronous active low reset
  
  input              frameSent,		// indicates the ethernet has sent a frame
  input              sendDatagram,	// signal to send a datagram message
  input [15:0]       datagramSize,	// size of datagram to transmit
  input [31:0]       destinationIP,	// IP to transmit message to
  input [7:0]        protocol,		// protocol of the datagram to be sent
  input              complete,	    // complete signal from the RAM operation
  input [7:0]        rdData,	    // read data from RAM
  output reg         wrRAM,		    // write signal for RAM
  output reg  [7:0]  wrData,	    // write data for RAM
  output reg  [7:0]  wrAddr,	    // write address for RAM
  output reg         sendFrame,	    // signal to get ethernet to send frame
  output reg         datagramSent,  // tells higher protocol when the datagram was sent
  output reg  [10:0] frameSize,	    // tells the ethernet layer how long the frame is
  output wire [31:0] ARPIP		    // IP that the ARP layer must look up
);

  // signal declarations
  // FSM states
  parameter [2:0]
	TX_INT_IDLE    	    = 3'd0,	
	TX_INT_SETHEADER   	= 3'd1,	
	TX_INT_WRHEADER   	= 3'd2,	
	TX_INT_WRCHKSUMHI   = 3'd3,
	TX_INT_WRCHKSUMLO   = 3'd4,	
	TX_INT_GETDATA      = 3'd5,	
	TX_INT_WRDATA       = 3'd6;
  
  reg [2:0]  ip_tx_cur_fsm;
  reg [2:0]  ip_tx_nxt_fsm;

  // Remember value of wrData
  reg [7:0]  nextWrData;
  // counter signals
  reg [7:0]  cnt;
  reg        incCnt;
  reg        rstCnt;
  // identification counter to tell different messages apart
  reg [25:0] idenCnt;
  // length of datagram to transmit next
  wire [15:0] datagramLen;
  // latch data read from RAM into the write data register
  reg        latchRdData;
  // checksum signals : see internet.vhd for comments
  reg        checkState;
  parameter  stMSB = 1'b0;
  parameter  stLSB = 1'b1;
  reg [16:0] checksumLong;
  wire [15:0] checksumInt;
  reg [7:0]  latchMSB;
  reg        lastNewByte;
  reg        newHeader;
  reg        newByte;
  reg [7:0]  inByte;
  wire [15:0] checksum;
  reg        valid; 
  // destination IP register and signal
  reg [31:0] destinationIPLatch;
  reg        latchDestinationIP;
  // addressOffset register and signal
  reg        latchAddressOffset;
  // protocol register and signal
  reg [7:0]  protocolLatch;
  reg        latchProtocol;
  // datagram size register and signal
  reg [15:0] datagramSizeLatch;  
  reg        latchDatagramSize;
  // current fragment offset and control signals
  wire [15:0] sizeRemaining;	// size of untransmitted data
  reg [15:0] idenLatch;	// register to hold idenCnt value for all fragments
  reg        latchIden;						// latch idenLatch register

  // Transmit to destination IP
  assign ARPIP = destinationIPLatch;
  // Caclulate size remaining, whether this is the last fragment and the size of the next fragment to send
  assign sizeRemaining = datagramSizeLatch;
  // size is either sizeRemaining + 20 or 1024 + 20.  The header is always 20 bytes
  assign datagramLen = sizeRemaining + 20; // x"414" = 1024 + 20
	
  // ==============================================================================
  always @(posedge clk or negedge reset_n) 
  begin
    if (!reset_n) begin
	  ip_tx_cur_fsm <= TX_INT_IDLE;
      idenCnt <= 26'b0; 
	end  
	else begin
	  ip_tx_cur_fsm <= ip_tx_nxt_fsm; // change state
	  idenCnt <= idenCnt + 1;		  // increment identification counter every cycle
	  if (latchRdData) 	   	          // either latch wrData from RAM or get the next value
	    wrData <= rdData;
	  else
	    wrData <= nextWrData;
	  
	  if (incCnt)			    // increment or clear counter
	    cnt <= cnt + 1;
	  else if (rstCnt)
	    cnt <= 8'b0;
	  
	  if (latchDestinationIP)	// latch destination IP
	    destinationIPLatch <= destinationIP;
	  
	  if (latchProtocol)			// latch protocol
	    protocolLatch <= protocol;
	  
	  if (latchDatagramSize)		// latch size of datagram
	    datagramSizeLatch <= datagramSize;

	  if (latchIden)				// Get current value of upper bits of identification counter
	    idenLatch <= idenCnt[25:10];
      
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
  always @(ip_tx_cur_fsm or wrData or datagramLen or datagramSize or checksum or cnt or sendDatagram or complete or idenLatch or destinationIPLatch or protocolLatch or frameSent)
  begin
    // default signals and outputs
	rstCnt <= 1'b0;
	incCnt <= 1'b0;
	nextWrData <= wrData;
	newHeader <= 1'b0;
	newByte <= 1'b0;
	inByte <= 8'b0;
	wrRAM <= 1'b0;
	wrAddr <= 8'b0;
	sendFrame <= 1'b0;
	frameSize <= 11'b0;
	latchRdData <= 1'b0;
	datagramSent <= 1'b0;
	latchAddressOffset <= 1'b0;
	latchDestinationIP <= 1'b0;
	latchProtocol <= 1'b0;
	latchDatagramSize <= 1'b0;
	latchIden <= 1'b0;
		
	case(ip_tx_cur_fsm)
      TX_INT_IDLE:
	  begin
	    // wait until told to transmit
		if (!sendDatagram)
		  ip_tx_nxt_fsm <= TX_INT_IDLE;
		else begin
		  // latch all information about the datagram and set up first fragment
		  ip_tx_nxt_fsm <= TX_INT_SETHEADER;
		  rstCnt <= 1'b1;
		  newHeader <= 1'b1;
		  latchDatagramSize <= 1'b1;
		  latchIden <= 1'b1;
		  latchAddressOffset <= 1'b1;
		  latchDestinationIP <= 1'b1;
		  latchProtocol <= 1'b1;
		end
	  end
			
	  TX_INT_SETHEADER:
	  begin
	    // write header into RAM				
		if (cnt == 8'h14) begin
		  // header has been fully written so go to data stage
		  ip_tx_nxt_fsm <= TX_INT_WRCHKSUMHI;
		  nextWrData <= checksum[15:8];
		end  
		else begin
		  ip_tx_nxt_fsm <= TX_INT_WRHEADER;
		  newByte <= 1'b1;			// send byte to checksum calculator
		  // choose wrData and inByte values
		  // inByte is the data for the checksum signals
					
		  case(cnt[4:0])
		    // version and header length
			5'b0:
			begin
			  nextWrData <= 8'h45;
			  inByte <= 8'h45;
			end  
							
			// total length high byte
			5'd2:
			begin
			  nextWrData <= datagramLen[15:8];
			  inByte <= datagramLen[15:8];
			end  
							
			// total length low byte
			5'd3:
			begin
			  nextWrData <= datagramLen[7:0];
			  inByte <= datagramLen[7:0];			
			end  
							
			// identification high byte
			5'd4:
			begin
			  nextWrData <= idenLatch[15:8];
			  inByte <= idenLatch[15:8];
			end  
							
			// identification low byte
			5'd5:
			begin
			  nextWrData <= idenLatch[7:0];
			  inByte <= idenLatch[7:0];
			end  
							
			// flags and fragmentOffset high bits
			5'd6:
			begin
			  nextWrData <= 8'h40; // akzare
			  inByte <= 8'h40; // akzare
			end  
							
			// fragmentOffset low byte
			5'd7:
			begin
			  nextWrData <= 8'h00;
			  inByte <= 8'h00;
			end  
							
			// time to live
			5'd8:
			begin
			  nextWrData <= 8'h40; // akzare : TTL 20->40
			  inByte <= 8'h40; // akzare : 20->40
			end  
							
			// protocol
			5'd9:
			begin
			  nextWrData <= protocolLatch;
			  inByte <= protocolLatch;					
			end  
							
			// source IP for C, D, E, F
			5'd12:
			begin
			  nextWrData <= DEVICE_IP[31:24];
			  inByte <= DEVICE_IP[31:24];					
			end  
							
			5'd13:
			begin
			  nextWrData <= DEVICE_IP[23:16];
			  inByte <= DEVICE_IP[23:16];						
			end  
							
			5'd14:
			begin
			  nextWrData <= DEVICE_IP[15:8];
			  inByte <= DEVICE_IP[15:8];
			end  
							
			5'd15:
			begin
			  nextWrData <= DEVICE_IP[7:0];
			  inByte <= DEVICE_IP[7:0];				
			end  
							
			// destination IP for 10, 11, 12, 13
			5'd16:
			begin
			  nextWrData <= destinationIPLatch[31:24];
			  inByte <= destinationIPLatch[31:24];
			end  
							
			5'd17:
			begin
			  nextWrData <= destinationIPLatch[23:16];
			  inByte <= destinationIPLatch[23:16];
			end  
							
			5'd18:
			begin
			  nextWrData <= destinationIPLatch[15:8];
			  inByte <= destinationIPLatch[15:8];					
			end  
							
			5'd19:
			begin
			  nextWrData <= destinationIPLatch[7:0];
			  inByte <= destinationIPLatch[7:0];						
			end
							
			// Service TYPE and checksum which will be updated later
			default:
			begin
			  nextWrData <= 8'b0;
			  inByte <= 8'b0;
			end  
							
		  endcase
		end
	  end
			
	  TX_INT_WRHEADER:
	  begin
		// Write a byte to RAM
		if (!complete) begin
		  // Wait for RAM to acknowledge the write
		  ip_tx_nxt_fsm <= TX_INT_WRHEADER;
		  wrRAM <= 1'b1;
		  wrAddr <= cnt + 8'h0E;
		end  
		else begin
		  // When it does increment the counter and go to next header byte
		  ip_tx_nxt_fsm <= TX_INT_SETHEADER;
		  incCnt <= 1'b1;
		end
	  end
			
	  TX_INT_WRCHKSUMHI:
	  begin
		// Write high byte of the checksum to RAM
		if (!complete) begin
		  // Wait for RAM to acknowledge the write
		  ip_tx_nxt_fsm <= TX_INT_WRCHKSUMHI;
		  wrRAM <= 1'b1;
		  wrAddr <= 8'h0A + 8'h0E; 
		end  
		else begin
		  // When it does write the lower byte
		  ip_tx_nxt_fsm <= TX_INT_WRCHKSUMLO;
		  nextWrData <= checksum[7:0];
		end
	  end
			
	  TX_INT_WRCHKSUMLO:
	  begin
	    // Write low byte of the checksum to RAM
		if (!complete) begin
		  ip_tx_nxt_fsm <= TX_INT_WRCHKSUMLO;
		  wrRAM <= 1'b1;
		  wrAddr <= 8'h0B + 8'h0E;
		end  
		else
		  // When it does copy data from RAM to write location
		  ip_tx_nxt_fsm <= TX_INT_GETDATA;
	  end	

	  TX_INT_GETDATA:
	  begin
	    // Read data from RAM if there is more left
		if (cnt == 12'h014) begin // akzare
		  // If there is no more data left, wait until the frame completes sending
		  if (frameSent) 
            ip_tx_nxt_fsm <= TX_INT_IDLE;
		  else begin
			// otherwise tell the frame to send until it does finish sending
			ip_tx_nxt_fsm <= TX_INT_GETDATA;
			sendFrame <= 1'b1;
			frameSize <= datagramLen[10:0];
		  end
		end  
		else begin
		  // if there is more data begin perform a read from RAM
		  if (!complete)
		    // Wait for RAM to acknowledge read
			ip_tx_nxt_fsm <= TX_INT_GETDATA;
		  else begin
			// Then get ready to write the data
			ip_tx_nxt_fsm <= TX_INT_WRDATA;
			latchRdData <= 1'b1;
		  end
		end
      end
	  
	  TX_INT_WRDATA:
	  begin
	    // Write one data byte
		if (!complete) begin
		  // Wait for RAM to acknowledge the write
		  ip_tx_nxt_fsm <= TX_INT_WRDATA;
		  wrRAM <= 1'b1;
		  wrAddr <= cnt + 8'h0E; 
		end  
		else begin
		  // When done, read another byte
		  ip_tx_nxt_fsm <= TX_INT_GETDATA;
		  incCnt <= 1'b1;
		end
	  end

	  default:
	  begin
	    ip_tx_nxt_fsm <= TX_INT_IDLE;
	  end
	   
	endcase
  end // always
	
  // checksum calculator : see internet.vhd for comments
  assign checksumInt = checksumLong[15:0] + checksumLong[16];
  assign checksum = ~checksumInt;

  // ==============================================================================
  always @(posedge clk or negedge reset_n) 
  begin
    if (!reset_n) begin
	  checkState <= stMSB;
	  latchMSB <= 8'b0;
	  checksumLong <= 17'b0;
	  valid <= 1'b0;
	  lastNewByte <= 1'b0;
	end  
	else begin
	  lastNewByte <= newByte;		
	  case(checkState)
	    stMSB:
		begin 
		  if (newHeader) begin
		    checkState <= stMSB;
			checksumLong <= 17'b0;
			valid <= 1'b0;
		  end	
		  else if (newByte && !lastNewByte) begin
		    checkState <= stLSB;
			latchMSB <= inByte;
			valid <= 1'b0;
		  end	
		  else begin
		    checkState <= stMSB;
			valid <= 1'b1;
		  end
	    end
		
	    stLSB:
		begin
		  valid <= 1'b0;		
		  if (newHeader) begin
		    checkState <= stMSB;
			checksumLong <= 17'b0;
		  end	
		  else if (newByte && !lastNewByte) begin
		    checkState <= stMSB;
			checksumLong <= {1'b0,checksumInt} + {1'b0,latchMSB,inByte};
		  end	
		  else
			checkState <= stLSB;
		  
		end
		
        default:
	    begin
		  checkState <= stMSB;
		  valid <= 1'b0;
		end
					
	  endcase
	end
  end // always	

endmodule
