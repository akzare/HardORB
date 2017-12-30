/***********************************************************************
  $FILENAME    : eth_intrfc_top.v

  $TITLE       : MAC and Hardware ORB logic block

  $DATE        : 19 July 2012

  $VERSION     : 1.0.0

  $DESCRIPTION : GiETH and Hardware ORB logic block

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module eth_intrfc_top #(
  parameter [31:0] DEST_IP            = 32'h0a0105ce,     //10.1.5.206:notebook:0a0105ce
  parameter [15:0] DEST_TCPCLNT_PORT  = 16'hBC14,
  parameter [15:0] SRC_TCPCLNT_PORT   = 16'hDFCC,         // Source TCP Client Port
  parameter [31:0] DEVICE_IP          = 32'h0a0105dd,     // 10.1.5.221:0a0105dd //32'h8d593489
  parameter [47:0] DEVICE_MAC         = 48'h001999cf95fa, // 001999cf956f, //48'h001AA0D5CF0F,  // 02:00:00:00:00:00
  parameter [15:0] DEVICE_TCP_PORT    = 16'hBC14,
  parameter [15:0] DEVICE_TCP_PAYLOAD = 16'h0400,         // 1024-byte payload
  parameter [15:0] DEVICE_UDP_PORT    = 16'hbed0,         // 48848			
  parameter [15:0] DEST_UDP_PORT      = 16'h1b3b//1356,   // 6971 4950
)
(  
  input              reset_n,
  input              sys_clk,
  input              txmac_clk,
  input              rxmac_clk,
  input              txmac_clk_en,
  input              rxmac_clk_en,
	
  
  // from MAC
  input              rx_write,
  input [7:0]        rx_dbout,
  input              rx_eof,
  
  input              tx_macread,
  
  // to MAC
  output wire [7:0]  tx_fifodata,
  output wire        tx_fifoeof,
  output wire        tx_fifoempty,
  
  
  // from register interface
  input              pkt_gen_en_ri,

  
  input [7:0]        instream_wrdata, 
  input              instream_wrclk, 
  input              instream_wren, 
  output wire        instream_fifofull
);


  // ==============================================================================
  // internal signals
  wire        tx_fifo_empty;	// tx fifo empty

  wire [7:0]  tx_dbin;
  wire        tx_write;
  wire        tx_eof;

  wire        rx_data_fifo_full;
  wire        rx_data_fifo_empty;
  wire        rx_len_fifo_full;
  wire        rx_len_fifo_empty;
  wire [15:0] rx_len_fifo_data;
  wire [7:0]  rx_data_fifo_data;
  wire        rx_len_fifo_read;
  wire        rx_data_fifo_read;

  wire [15:0] tx_len_fifo_data;
  wire [7:0]  tx_data_fifo_data;
  wire        tx_len_fifo_write;
  wire        tx_data_fifo_write;

  wire [7:0]  instream_rddata;
  wire [11:0] instream_rcnt;
  wire        instream_rden;
  wire        instream_fifoempty;
  
  assign tx_fifoempty = tx_fifo_empty;

  // ==============================================================================
  // instanciate modules 
  eth_rx_fifo_wraper u_eth_rx_fifo_wraper
  (
    .clk_i                  (sys_clk),
	.reset_n                (reset_n),
	.clk_en                 (rxmac_clk_en),
	.rx_len_fifo_data       (rx_len_fifo_data),
	.rx_data_fifo_data      (rx_data_fifo_data),
	.rx_len_fifo_read       (rx_len_fifo_read),
	.rx_data_fifo_read      (rx_data_fifo_read),
	.rxmac_clk              (rxmac_clk),
	.rx_write               (rx_write),
	.rx_eof                 (rx_eof),
	.rx_dbout               (rx_dbout[7:0]),
	.rx_data_fifo_full      (rx_data_fifo_full),
	.rx_data_fifo_empty     (rx_data_fifo_empty),
	.rx_len_fifo_full       (rx_len_fifo_full),
    .rx_len_fifo_empty      (rx_len_fifo_empty)
  );

  // ==============================================================================
  hworb_top 
  #(
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
  u_hworb_top 
  (
  	.instream_rddata        (instream_rddata), 
	.instream_rden          (instream_rden),
	.instream_rcnt          (instream_rcnt), 
	.instream_fifoempty     (instream_fifoempty), 

    .clk_i                  (sys_clk),
	.reset_n                (reset_n),
	.dst_add                (mac_dst_add_ri),
	.src_add                (mac_src_add_ri),
	.en                     (pkt_gen_en_ri),
	.rx_len_fifo_data       (rx_len_fifo_data),
	.rx_data_fifo_data      (rx_data_fifo_data),
	.rx_len_fifo_empty      (rx_len_fifo_empty),
	.tx_len_fifo_data       (tx_len_fifo_data),
	.tx_data_fifo_data      (tx_data_fifo_data),
	.tx_len_fifo_write      (tx_len_fifo_write),
	.tx_data_fifo_write     (tx_data_fifo_write),
	.rx_len_fifo_read       (rx_len_fifo_read),
	.rx_data_fifo_read      (rx_data_fifo_read),
	.TCP_StrtClnt           (),
	.tx_done                (tx_fifoeof),
	.rx_done                (rx_eof),
	.triger_signal          (),
	.en_rst                 ()
  );


  // ==============================================================================
  eth_tx_fifo_wraper u_eth_tx_fifo_wraper
  (
    .clk_i                  (sys_clk),
	.reset_n                (reset_n),
	.clk_en                 (txmac_clk_en),
	.tx_len_fifo_data       (tx_len_fifo_data),
	.tx_data_fifo_data      (tx_data_fifo_data),
	.tx_len_fifo_write      (tx_len_fifo_write),
	.tx_data_fifo_write     (tx_data_fifo_write),
	.tx_macread             (tx_macread),
	.txmac_clk              (txmac_clk),
	.tx_fifoempty           (tx_fifo_empty),
	.tx_fifodata            (tx_fifodata),
	.tx_fifoeof             (tx_fifoeof)
  );


  // ==============================================================================
  // incoming stream FIFO
  async_fifo #(8, 10) u_eth_instream_fifo
  (
    .winc   (instream_wren),
    .wclk   (instream_wrclk),
    .wrst_n (reset_n),
    .rinc   (instream_rden),
    .rclk   (sys_clk),
    .rrst_n (reset_n),
    .wdata  (instream_wrdata),
    .rdata  (instream_rddata),
    .wfull  (instream_fifofull),
    .rempty (instream_fifoempty)
  );

	
endmodule
