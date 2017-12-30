/***********************************************************************
  $FILENAME    : eth_rx_fifo_wraper.v

  $TITLE       : 

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : .

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module eth_rx_fifo_wraper (
  input              clk_i,
  input              reset_n,
  input              clk_en,

  input              rx_len_fifo_read,
  input              rx_data_fifo_read,

  input              rx_write,          // MAC side Rx Data FIFO write signal
  input              rx_eof,            // MAC side Rx Data FIFO EOF (End Of Frame) signal
  input [7:0]        rx_dbout,          // MAC side Rx Data FIFO data
  input              rxmac_clk,

  output wire [15:0] rx_len_fifo_data,  // Rx Length FIFO data
  output wire [7:0]  rx_data_fifo_data, // Rx Data FIFO data

  output wire        rx_data_fifo_full,
  output wire        rx_data_fifo_empty,
  output wire        rx_len_fifo_full,
  output wire        rx_len_fifo_empty
);

  // ==============================================================================
  // Internal signals
  reg         rx_write_1d;
  reg         rx_eof_1d;
  reg [7:0]   rx_dbout_1d;
  reg [12:0]  byte_cnt;	              // byte counter (8192 bytes max)
  reg [1:0]   eth_rxfifo_ctrl_fsm;	  // Control FSM states

  reg         mac_wr_rx_data_fifo;    // write rx_data_fifo signal
  reg         mac_wr_rx_len_fifo;     // FSM write rx_len_fifo signal

  reg [7:0]   rx_fifo_data;           // 8-bit Rx Data FIFO data from 8b to 32b conversion

  wire [15:0] rx_len_fifo_data_minus1;  // Rx Length in FIFO is (num_data_bytes - 1)
  wire        byte_enb_sel;             // Byte_0 enable select (31:24) 
  wire [15:0] rx_fifo_len;

  wire        mac_wr_rx_data_fifo_x;    // write rx_data_fifo signal ANDed with clk_en
  wire        mac_wr_rx_len_fifo_x;     // FSM write rx_len_fifo signal ANDed with clk_en

  

  // control state machine 
  // states
  parameter [1:0]
	RX_FSM_IDLE    	= 2'd0,	// IDLE State
	RX_FSM_WR_DATA  = 2'd1,	// WRITE DATA State
	RX_FSM_WR_LEN   = 2'd2;	// WRITE LEN State


  // wire assignments
  assign byte_enb_sel = ( (rx_write_1d == 1'b1) && byte_cnt < 13'd2047 ) ? 1:0;
  assign rx_fifo_len[15:0] = {3'b000, byte_cnt[12:0]};
  assign rx_len_fifo_data  = (rx_len_fifo_data_minus1 + 1);
 
  assign mac_wr_rx_data_fifo_x = mac_wr_rx_data_fifo & clk_en;
  assign mac_wr_rx_len_fifo_x  = mac_wr_rx_len_fifo & clk_en;
   
  // ==============================================================================
  // PIPELINE 
  always @(posedge rxmac_clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      rx_write_1d <= 1'b0;
      rx_eof_1d <= 1'b0;
      rx_dbout_1d <= 8'h00;
      mac_wr_rx_data_fifo <= 1'b0;
	end
	else if (clk_en) begin
      rx_write_1d <= rx_write;
      rx_eof_1d <= rx_eof;
      rx_dbout_1d <= rx_dbout;
      mac_wr_rx_data_fifo <= (rx_eof_1d | byte_enb_sel);
	end
 end // always 


  // ==============================================================================
  // Long Word Register (8bit to 32bit conversion) - data into Rx data FIFO 
  always @(posedge rxmac_clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      rx_fifo_data[7:0] <= 8'd0;
	end
	else if (clk_en) begin
      rx_fifo_data[7:0] <= rx_dbout_1d[7:0];
	end
  end // always 
  

  // ==============================================================================
  // RX CONTROL FSM 
  always @(posedge rxmac_clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      eth_rxfifo_ctrl_fsm <= RX_FSM_IDLE;
      byte_cnt <= 13'd0;
      mac_wr_rx_len_fifo <= 1'b0;
	end
	else if (clk_en) begin
	  // default values
      mac_wr_rx_len_fifo <= 1'b0;

      case (eth_rxfifo_ctrl_fsm)

        RX_FSM_IDLE:
        begin
          if (rx_write == 1'b1) begin 
            byte_cnt <= 13'd0;
            eth_rxfifo_ctrl_fsm <= RX_FSM_WR_DATA;
          end
        end
		
        RX_FSM_WR_DATA:
        begin
          if (rx_eof_1d == 1'b1) begin
            eth_rxfifo_ctrl_fsm <= RX_FSM_WR_LEN;
          end
          else begin
            if (rx_write == 1'b1 && byte_cnt < 13'd2047) begin 
              byte_cnt <= byte_cnt + 1;
            end
            eth_rxfifo_ctrl_fsm <= RX_FSM_WR_DATA;
          end
        end
				 
        RX_FSM_WR_LEN:
        begin
          // 1 clk delay
          eth_rxfifo_ctrl_fsm <= RX_FSM_IDLE;
          mac_wr_rx_len_fifo <= 1'b1;
        end
				 
        default:
        begin
          eth_rxfifo_ctrl_fsm <= RX_FSM_IDLE;
          byte_cnt <= 13'd0;
          mac_wr_rx_len_fifo <= 1'b0;
        end
	  endcase 
    end
  end // always 
   
   
  // ==============================================================================
  // RX LEN FIFO 
  async_fifo #(16, 10)
  u_rx_len_fifo
  (
  	.wrst_n (reset_n),
  	.wclk   (rxmac_clk),
    .winc   (mac_wr_rx_len_fifo_x),
    .wdata  (rx_fifo_len[15:0]),
    .wfull  (rx_len_fifo_full),
    
    .rrst_n (reset_n),
    .rclk   (clk_i),
    .rinc   (rx_len_fifo_read),
    .rdata  (rx_len_fifo_data_minus1[15:0]),
    .rempty (rx_len_fifo_empty)
  );
	
  // ==============================================================================
  // RX DATA FIFO
  async_fifo #(8, 10)
  u_rx_data_fifo
  (
  	.wrst_n (reset_n),
  	.wclk   (rxmac_clk),
    .winc   (mac_wr_rx_data_fifo_x),
    .wdata  (rx_fifo_data[7:0]),
    .wfull  (rx_data_fifo_full),
    
    .rrst_n (reset_n),
    .rclk   (clk_i),
    .rinc   (rx_data_fifo_read),
    .rdata  (rx_data_fifo_data[7:0]),
    .rempty (rx_data_fifo_empty)
  );

endmodule // 
