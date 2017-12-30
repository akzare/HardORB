/***********************************************************************
  $FILENAME    : eth_tx_fifo_wraper.v

  $TITLE       : 

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : .

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module eth_tx_fifo_wraper
(
  input              clk_i,
  input              reset_n,
  input              clk_en,
  input [15:0]       tx_len_fifo_data,
  input [7:0]        tx_data_fifo_data,
  // from register intf 
  input              tx_len_fifo_write,
  input              tx_data_fifo_write,
  // From MAC Interface
  input              tx_macread,       // MAC side Tx Data FIFO read signal
  input              txmac_clk,

  // To MAC Interface
  output reg         tx_fifoempty,
  output wire [7:0]  tx_fifodata,
  output reg         tx_fifoeof
);

  // ==============================================================================
  // internal signals
  reg [15:0]  tx_len_fifo_data_1d;
  reg [7:0]   tx_data_fifo_data_1d;
  reg         tx_len_fifo_write_1d;     // WB side Tx len FIFO write signal pipelined 1 time
  reg         tx_data_fifo_write_1d;    // WB side Tx data FIFO write signal pipelined 1 time
  reg         mac_rd_tx_len_fifo;	    // FSM read tx_len_fifo signal
  reg [15:0]  byte_cnt;	                // byte counter
  reg         load_cnt;		            // load byte counter
  reg [2:0]   eth_txfifo_ctrl_fsm;	    // Control FSM states

  wire        mac_rd_tx_data_fifo;      // FSM read tx_data_fifo signal

  wire [7:0]  tx_fifo_data;             // 8 bit tx data from tx data FIFO
  wire [15:0] tx_fifo_len;              // 16 bit tx len from tx len FIFO
  reg  [15:0] tx_fifo_len_minus1;       // 16 bit (tx len from tx len FIFO - 1) used by FSM

  wire        mac_rd_tx_len_fifo_x;     // FSM read tx_len_fifo signal ANDed with clk_en
  wire        mac_rd_tx_data_fifo_x;    // FSM read tx_data_fifo signal ANDed with clk_en

  wire        tx_len_fifo_empty;

  wire        tx_data_fifo_full;
  wire        tx_data_fifo_empty;  

  // control state machine 
  // states
  parameter [1:0]
	TX_CTRL_FSM_IDLE    	= 2'd0,
	TX_CTRL_FSM_DATA_AVAIL  = 2'd1,
	TX_CTRL_FSM_PULL_PKT   	= 2'd2,
	TX_CTRL_FSM_WAIT3   	= 2'd3;

  // wire assignments
  assign mac_rd_tx_data_fifo = tx_macread;

  assign mac_rd_tx_len_fifo_x = mac_rd_tx_len_fifo & clk_en;
  assign mac_rd_tx_data_fifo_x = (mac_rd_tx_data_fifo) & clk_en;
   
  // ==============================================================================
  // PIPELINE 
  always @(posedge clk_i or negedge reset_n) 
  begin
    if (!reset_n) begin
      tx_len_fifo_data_1d   <= 16'h0000;
      tx_data_fifo_data_1d  <= 8'h00;
      tx_len_fifo_write_1d  <= 1'b0;
      tx_data_fifo_write_1d <= 1'b0;
    end
    else begin
      tx_len_fifo_data_1d   <= tx_len_fifo_data;
      tx_data_fifo_data_1d  <= tx_data_fifo_data;
      tx_len_fifo_write_1d  <= tx_len_fifo_write;
      tx_data_fifo_write_1d <= tx_data_fifo_write;
    end
  end // always 

  assign tx_fifodata[7:0] = tx_fifo_data[7:0];
  
  // ==============================================================================
  // BYTE COUNTER (16 Bit)
  always @(posedge txmac_clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      byte_cnt <= 16'd0;
    end
	else if (clk_en) begin
      if (load_cnt) begin
        byte_cnt <= tx_fifo_len_minus1[15:0];
      end
      else if (tx_macread) begin
        byte_cnt <= byte_cnt - 1;
      end
	end
  end // always 

  always @(posedge txmac_clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      tx_fifo_len_minus1 <= 16'd0;
    end
	else if (clk_en) begin
	  tx_fifo_len_minus1 <= (tx_fifo_len - 1);
	end
  end // always 
   
  // ==============================================================================
  // TX CONTROL FSM 
  always @(posedge txmac_clk or negedge reset_n) 
  begin
    if (!reset_n) begin
      eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_IDLE;
      tx_fifoempty <= 1'b1;
      load_cnt <= 1'b0;
      tx_fifoeof <= 1'b0;
      mac_rd_tx_len_fifo <= 1'b0;
    end
    else if (clk_en) begin
	  // default values
	  load_cnt <= 1'b0;
	  tx_fifoeof <= 1'b0;
	  mac_rd_tx_len_fifo <= 1'b0;

	  case (eth_txfifo_ctrl_fsm)

	    TX_CTRL_FSM_IDLE:
	    begin
	      tx_fifoempty <= 1'b1;

	      if (!tx_len_fifo_empty) begin // len fifo not empty
	        mac_rd_tx_len_fifo <= 1'b1;
	      load_cnt <= 1'b1;
            eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_DATA_AVAIL;
	        
	      end
	    end
				 
	    TX_CTRL_FSM_DATA_AVAIL:
	    begin
	      tx_fifoempty <= 1'b0;
	      eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_PULL_PKT;
	    end
				 
	    TX_CTRL_FSM_PULL_PKT:
	    begin
	      if (byte_cnt == 16'd0) begin
	        tx_fifoeof <= 1'b1;
	        tx_fifoempty <= 1'b1;
	        eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_WAIT3;
	      end
	      else begin
	        eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_PULL_PKT;

	      end
	    end
				 
	    TX_CTRL_FSM_WAIT3:
	    begin
	      // 1 clk delay
	      eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_IDLE;
	    end
				 
	    default:
	    begin
	      eth_txfifo_ctrl_fsm <= TX_CTRL_FSM_IDLE;
	      tx_fifoempty <= 1'b1;
	      load_cnt <= 1'b0;
	      tx_fifoeof <= 1'b0;
	      mac_rd_tx_len_fifo <= 1'b0;
	    end
	  endcase 
	end
  end // always 

 
  // ==============================================================================
  // TX LEN FIFO
  async_fifo #(16, 10)
  u_tx_len_fifo
  (
    .wclk(clk_i),
    .wrst_n(reset_n),
    .winc(tx_len_fifo_write_1d),
    .wdata(tx_len_fifo_data_1d),
    .wfull(),
    
    .rclk(txmac_clk),
    .rrst_n(reset_n),
    .rinc(mac_rd_tx_len_fifo_x),
    .rdata(tx_fifo_len[15:0]),
    .rempty(tx_len_fifo_empty)
  );

  // ==============================================================================
  // TX DATA FIFO
  async_fifo #(16, 10)
  u_tx_data_fifo
  (
    .wclk(clk_i),
    .wrst_n(reset_n),
    .winc(tx_data_fifo_write_1d),
    .wdata(tx_data_fifo_data_1d),
    .wfull(tx_data_fifo_full),
    
    .rclk(txmac_clk),
    .rrst_n(reset_n),
    .rinc(mac_rd_tx_data_fifo_x),
    .rdata(tx_fifo_data[7:0]),
    .rempty(tx_data_fifo_empty)
  );

endmodule
