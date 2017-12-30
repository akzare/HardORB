/***********************************************************************
  $FILENAME    : udp_server.v

  $TITLE       : UDP protocol (server) implementation

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : Transmission Control Protocol layer which transmits UDP packets
                 with an individual specified Dst PORT number (UDP state diagram).  

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/

module udp_server #(
  parameter [15:0] DEVICE_UDP_PORT  = 16'hbed0,      
  parameter [31:0] DEST_IP          = 32'h0a0105ce,  
  parameter [15:0] DEST_UDP_PORT    = 16'h1b3b,
  parameter [31:0] DEVICE_IP        = 32'h0a0105dd
) 
(
  input              clk,             // clock 
  input              reset_n,         // asynchronous active low reset
  
  input              wr_complete,     // asserted when begin DPMEM write operation is complete
  input              tx_done_MAC,
  
  input              instream_fifoempty,
  output wire        instream_rden,
  input [7:0]        instream_rddata,
  input [11:0]       instream_rcnt,

  output reg         wrRAM,            // asserted to tell the DPRAM to write
  output reg  [7:0]  wrData,           // write data bus to the DPRAM
  output reg  [10:0] wrAddr,           // write address bus to the DPRAM
  output wire [15:0] sendDatagramSize, // size of the UDP to transmit to
  output reg         sendDatagram,     // tells the IP layer to send a datagram
  output wire [31:0] destinationIP,    // target IP of the datagram
  output wire [7:0]  protocolOut       // tells the IP layer which protocol it is
);

  parameter [15:0] UDPLEN = 16'd1292; // 8+2+2+1280+1
  parameter [7:0]  UDPHEADERLEN = 8'd8;
  
  // checksum Rec signals - read internet.vhd for checksum Rec commenting
  parameter  stMSB = 1'b0;
  parameter  stLSB = 1'b1;

  // UDP transmit state definitions
  parameter [1:0]
  UDP_SERV_TX_IDLEXMIT        = 2'd0,  
  UDP_SERV_TX_SETWRHEADERXMIT = 2'd1,  
  UDP_SERV_TX_GETWRDATAXMIT   = 2'd2,  
  UDP_SERV_TX_WRITEFINISHXMIT = 2'd3;
  
  reg [1:0] udp_srv_tx_fsm;

  reg [10:0] cntXmit;

  reg        stream_read_d1;
  reg        stream_read_i;
  
  // always set the IP protocol field to UDP (17)
  assign protocolOut =  8'h11;
  assign destinationIP = DEST_IP;
  assign sendDatagramSize = UDPLEN;   
  
  assign instream_rden = stream_read_i & ~instream_fifoempty;

  // ==============================================================================
  // User Datagram Protocol(UDP) data protocol unit header format
  //
  // Standard UDP header
  //
  //  0                      8                      16                                          31
  //  --------------------------------------------------------------------------------------------
  //  |                 Source PORT                |                Destination PORT             |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                   Length                   |                 Checksum                    |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                                          Data                                            |
  //  |                                          ....                                            |
  //  --------------------------------------------------------------------------------------------
  //

  // UDP checksum for IPv4
  //
  // UDP pseudo-header (IPv4)
  //
  //  0                      8                      16                                          31
  //  --------------------------------------------------------------------------------------------
  //  |                                       Source address                                     |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |                                    Destination address                                   |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //  |        Zeros         |       Protocol      |                  UCP length                 |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                 Source PORT                |                Destination PORT             |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                 Length                     |                Checksum                     |
  //  |                                            |                                             |
  //  --------------------------------------------------------------------------------------------
  //  |                                           Data                                           |
  //  |                                                                                          |
  //  --------------------------------------------------------------------------------------------
  //
  // ==============================================================================
  
  
  // ==============================================================================
  // UDP main transmit FSM logic
  always @(posedge clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      // UDP transmit -------------------------------------------------------
      udp_srv_tx_fsm <= UDP_SERV_TX_IDLEXMIT;
      
      stream_read_d1 <= 1'b0;
      
      stream_read_i <= 1'b0;
      wrRAM <= 1'b0;
      wrData <= 8'b0;
      wrAddr <= 11'b0;
      sendDatagram <= 1'b0;
      
      cntXmit <= 11'b0;
    end  
    // catch the rising clock edge
    else begin
      stream_read_i <= 1'b0;
      stream_read_d1 <= instream_rden;
      
      wrRAM <= 1'b0;
      wrData <= 8'b0;
      sendDatagram <= 1'b0;
      wrAddr <= cntXmit[10:0] + {3'b000,8'h22}; // 0x22 is start address of UDP
    
      case(udp_srv_tx_fsm)
        UDP_SERV_TX_IDLEXMIT: // 0
        begin
          cntXmit <= 11'b0;
      
          if (instream_fifoempty) begin
            udp_srv_tx_fsm <= UDP_SERV_TX_IDLEXMIT;
          end  
          else begin
            udp_srv_tx_fsm <= UDP_SERV_TX_SETWRHEADERXMIT;
          end
        end
        
        UDP_SERV_TX_SETWRHEADERXMIT: // 1
        begin
          // write header into RAM        
          if (cntXmit < 11'd8) begin
            udp_srv_tx_fsm <= UDP_SERV_TX_SETWRHEADERXMIT;
            wrRAM <= 1'b1;
            cntXmit <= cntXmit + 1;
          end  
          else begin//if (!instream_fifoempty) begin // read from ISI FIFO
            udp_srv_tx_fsm <= UDP_SERV_TX_GETWRDATAXMIT;
          end  
          
          // choose wrData and inByteXmit values
          // inByteXmit is the data for the checksum signals
          case(cntXmit)
            // write Source port number MSB
            11'd0:
            begin
              wrData <= DEVICE_UDP_PORT[15:8];
            end  
              
            // write Source port number LSB
            11'd1:
            begin
              wrData <= DEVICE_UDP_PORT[7:0];
            end  
                    
            // write Destination port number MSB
            11'd2:
            begin
              wrData <= DEST_UDP_PORT[15:8];
            end  
                    
            // write Destination port number LSB
            11'd3:
            begin
              wrData <= DEST_UDP_PORT[7:0];
            end  
                    
            // write the UDP length MSB
            11'd4:
            begin
              wrData <= UDPLEN[15:8];
            end  
                    
            // write the UDP length LSB
            11'd5:
            begin
              wrData <= UDPLEN[7:0];
            end  
                    
            // write the Checksum
            11'd6, 11'd7:
            begin
              wrData <= 8'h00;
            end  
          
            default:
            begin
              wrData <= 8'b0;
            end
                  
          endcase
        
        end
    
        UDP_SERV_TX_GETWRDATAXMIT: // 2
        begin
          wrData <= instream_rddata[7:0];//cntXmit[7:0];
          wrAddr <= cntXmit[10:0] + {3'b000,8'h22}; // UDP address starts from 0x22
          if (stream_read_d1) begin
            wrRAM <= 1'b1;
            cntXmit <= cntXmit + 1;      
          end  
      
          if (cntXmit < (UDPLEN-2)) begin
            if (!instream_fifoempty) begin
              stream_read_i <= 1'b1;
            end
          end  
          
          if (cntXmit < (UDPLEN-1)) begin
            udp_srv_tx_fsm <= UDP_SERV_TX_GETWRDATAXMIT; 
          end  
          else begin
            // If there is no more data left
            udp_srv_tx_fsm <= UDP_SERV_TX_WRITEFINISHXMIT;
            sendDatagram <= 1'b1;
          end
        end
      
        UDP_SERV_TX_WRITEFINISHXMIT: // 3
        begin
          if (tx_done_MAC) begin
            udp_srv_tx_fsm <= UDP_SERV_TX_IDLEXMIT;
          end  
          else begin
            udp_srv_tx_fsm <= UDP_SERV_TX_WRITEFINISHXMIT;
          end  
        end
        
        default:
        begin
          udp_srv_tx_fsm <= UDP_SERV_TX_IDLEXMIT;
        end
      endcase
    end
  end // always
  
endmodule
