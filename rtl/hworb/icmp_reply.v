/***********************************************************************
  $FILENAME    : icmp_reply.v

  $TITLE       : ICMP protocol (tx) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : ICMP(ing) layer which responds only to echo requests with an echo reply.  
                 Any other ICMP messages are discarded/ignored. Can respond to any ping
                 containing up to (64k - 8) bytes of data.

  $AUTHOR     : (C) 2001 Ashley Partis and Jorgen Peddersen (VHDL code)
                Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com) (Verilog code)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module icmp_reply 
(
  input              clk,                          // clock 
  input              reset_n,                      // asynchronous active low reset
  
  input              newDatagram,                  // asserted  a new datagram arrive
  input [15:0]       datagramSize,                 // size of the arrived datagram
  input              bufferSelect,                 // informs which IP buffer the data is in
  input [7:0]        protocolIn,                   // protocol TYPE of the datagram
  input [31:0]       sourceIP,                     // IP address that sent the message
  input              complete,                     // asserted  begin RAM operation is complete
  input [7:0]        rdData,                       // read data bus from the RAM
  output reg         wrRAM,                        // asserted to tell the RAM to write
  output reg  [7:0]  wrData,                       // write data bus to the RAM
  output reg  [7:0]  wrAddr,                       // write address bus to the RAM
  output reg  [15:0] sendDatagramSize,             // size of the ping to reply to
  output reg         sendDatagram,                 // tells the IP layer to send a datagram
  output reg  [31:0] destinationIP,                // target IP of the datagram
  output wire [2:0]  addressOffset,                // tells the IP layer which buffer the data is in
  output wire [7:0]  protocolOut                   // tells the IP layer which protocol it is
);

  // SIGNAL declarations
  // FSM states
  parameter [2:0]
	ICMP_IDLE    	            = 3'd0,	
	ICMP_GETICMPBYTE   	        = 3'd1,	
	ICMP_WRITEICMPBYTE          = 3'd2,
	ICMP_WRITECHKSUM1           = 3'd3,	
	ICMP_WRITECHKSUM2           = 3'd4,	
	ICMP_WAITFORCHECKSUM        = 3'd5,	
	ICMP_WAITFORCHECKSUMCALC    = 3'd6;
  
  reg [2:0]  icmp_rep_cur_fsm;
  reg [2:0]  icmp_rep_nxt_fsm;

  // buffer to hold the size of the ICMP message received, and to send
  reg [15:0]  ICMPSize;
  reg [15:0]  nextICMPSize;

  // counter to handle the message
  reg        incCnt;
  reg        rstCnt;
  reg [7:0]  cnt;

  // SIGNAL to remember the previous wrData value
  reg [7:0]  nextWrData;

  // read RAM from the correct address depending on this buffer
  reg [1:0]  IPSourceBuffer;

  // SIGNAL to latch the inputs from the previous layer
  reg        latchDestinationIP;

  // checksum signals - read internet.vhd for checksum commenting
  reg        checkState;
  parameter  stMSB = 1'b0;
  parameter  stLSB = 1'b1;

  reg [16:0]  checksumLong;
  wire [15:0] checksumInt;

  reg [7:0]  latchMSB;

  reg        newHeader;
  reg        newByte;
  reg [7:0]  inByte;

  wire [15:0] checksum;
  reg        valid;

  // always set the IP protocol field to ICMP (01), and set address offset to 
  // the location of the ICMP buffer
  assign protocolOut = 8'h01;
  assign addressOffset = 3'b100;
	
  // ==============================================================================
  // main clocked PROCESS
  always @(posedge clk or negedge reset_n) 
  begin
    // set up the asynchronous active low reset
	if (!reset_n)
	  icmp_rep_cur_fsm <= ICMP_IDLE;
	  // catch the rising clock edge
	else begin
	  icmp_rep_cur_fsm <= icmp_rep_nxt_fsm;
	  // set the ICMP size and write data buses to their next values
	  ICMPSize <= nextICMPSize;
	  wrData <= nextWrData;
	  
	  // increment and reset the counter asynchronously to avoid race conditions
	  if (incCnt)
		cnt <= cnt + 1;
	  else if (rstCnt)
	    cnt <= 8'b0;
	  
	  // latch the inputs and set the IP source buffer accordingly
	  if (latchDestinationIP) begin
	    destinationIP <= sourceIP;
	    if (!bufferSelect)
		  IPSourceBuffer <= 2'b01;
	    else
		  IPSourceBuffer <= 2'b10;
	    
	  end
	end
	
  end // always

  // ==============================================================================
  // ICMP data protocol unit header format
  //
  // Standard echo request and reply ICMP header
  //
  //	0                      8                      16                                          31
  //	--------------------------------------------------------------------------------------------
  //	|   Type (8 = echo    |         Code         |                  Checksum                   |
  //	| request, 0 = reply) |         (0)          |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|                 Identifier                 |                Sequence Number              |
  //	|                                            |                                             |
  //	--------------------------------------------------------------------------------------------
  //	|                                       Optional Data                                      |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //	|                                          ....                                            |
  //	|                                                                                          |
  //	--------------------------------------------------------------------------------------------
  //
  // ==============================================================================

  // ==============================================================================
  // main FSM
  always @(icmp_rep_cur_fsm or newDatagram or datagramSize or ICMPSize or rdData or cnt or complete or wrData or checksum or protocolIn or IPSourceBuffer)	
  begin
    // SIGNAL defaults
    incCnt <= 1'b0;
    rstCnt <= 1'b0;
    wrRAM <= 1'b0;
    // remember the values of wrData and ICMPSize by default
    nextWrData <= wrData;
    nextICMPSize <= ICMPSize;
    wrAddr <= 8'b0;
    sendDatagram <= 1'b0;
    sendDatagramSize <= 16'b0;
    newHeader <= 1'b0;
    newByte <= 1'b0;
    inByte <= 8'b0;
    latchDestinationIP <= 1'b0;
	
    case(icmp_rep_cur_fsm)
      ICMP_IDLE:
      begin
        // wait for a new datagram to arrive with the correct protocol for ICMP
        if (newDatagram && protocolIn == 8'd1 && rdData == 8'd8 && complete) begin
          icmp_rep_nxt_fsm <= ICMP_WRITEICMPBYTE;
          // latch or remember the inputs about the datagram from the previous layer
          latchDestinationIP <= 1'b1;
          nextICMPSize <= datagramSize;
          // give the checksum the data
          newByte <= 1'b1;
          nextWrData <= 8'b0;
        end	
        else begin
          icmp_rep_nxt_fsm <= ICMP_IDLE;
          rstCnt <= 1'b1;
          newHeader <= 1'b1;
        end
      end
				
      ICMP_GETICMPBYTE:
      begin
		// if finished write the checksum and continue
		if (cnt[7:0] == ICMPSize[7:0]) begin
		  icmp_rep_nxt_fsm <= ICMP_WAITFORCHECKSUMCALC;
		  // if uneven number of bytes, pad the checksum with a byte of 0s
		  if (ICMPSize[0]) begin
		    newByte <= 1'b1;
		    inByte <= 8'b0;
		  end
		end
		else begin
		  // read the current ICMP byte from RAM (using IPSourceBuffer
		  // for the correct address) according to count
		  if (!complete)
		    icmp_rep_nxt_fsm <= ICMP_GETICMPBYTE;
		  else begin
            icmp_rep_nxt_fsm <= ICMP_WRITEICMPBYTE;
            // give the checksum the data
            newByte <= 1'b1;
            // set the ICMP data to send according the value of count
            case(cnt)
              // code
              8'h01:
              begin
                nextWrData <= 8'b0;
              end

              // checksum upper byte - write 0s for now
              8'h02:
              begin
                nextWrData <= 8'b0;
              end

              // checksum lower byte
              8'h03:
              begin
                nextWrData <= 8'b0;
              end
					
              // all other cases - identifier, sequence number and data
              // must be the same as what we received
              default:
              begin
                nextWrData <= rdData;
                inByte <= rdData;
              end
            endcase
		  end
		end
      end
			

      ICMP_WRITEICMPBYTE:
      begin
        // write the new ICMP data
        wrRAM <= 1'b1;
        wrAddr <= cnt + 8'h22; // 34 decimal akzare
	    // go back and get the next byte of data
		icmp_rep_nxt_fsm <= ICMP_GETICMPBYTE;
		incCnt <= 1'b1;
      end
			
      // if there was an uneven number of bytes, begin the checksum method will require an 
      // extra clock cycle to work it out
      ICMP_WAITFORCHECKSUMCALC:
      begin
        icmp_rep_nxt_fsm <= ICMP_WAITFORCHECKSUM;
      end
			
      // setup the write data bus to write the ICMP checksum
      ICMP_WAITFORCHECKSUM:
      begin
        icmp_rep_nxt_fsm <= ICMP_WRITECHKSUM1;
        nextWrData <= checksum[15:8];
      end
			
      ICMP_WRITECHKSUM1:
      begin
        // write the ICMP checksum MSB
        if (!complete) begin
		  icmp_rep_nxt_fsm <= ICMP_WRITECHKSUM1;
		  wrRAM <= 1'b1;
		  wrAddr <= 8'h24; // akzare
		end			
		else begin
		  icmp_rep_nxt_fsm <= ICMP_WRITECHKSUM2;
		  // setup the lower byte of the ICMP checksum to write
		  nextWrData <= checksum[7:0];
		end	
      end

      ICMP_WRITECHKSUM2:
      begin
        // write the ICMP checksum LSB
        if (!complete) begin
          icmp_rep_nxt_fsm <= ICMP_WRITECHKSUM2;
          wrRAM <= 1'b1;
          wrAddr <= 8'h25; // akzare
		end			
		else begin
          icmp_rep_nxt_fsm <= ICMP_IDLE;
          sendDatagram <= 1'b1;
          sendDatagramSize <= ICMPSize;
		end	
      end
			
      default:
	  begin
	  end	  
    endcase
  end // always


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
	end		
	else begin	
	  case(checkState)
	    stMSB:
		begin
		  if (newHeader) begin
		    checkState <= stMSB;
		    checksumLong <= 17'b0;
		    valid <= 1'b0;
		  end			
		  else if (newByte) begin
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
		  else if (newByte) begin
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
