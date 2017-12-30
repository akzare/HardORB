//===========================================
// Function : Synchronous read write RAM
// Coder    : Deepak Kumar Tala
// Date     : 1-Nov-2005
//===========================================
module dpram #(
  parameter DATA_WIDTH = 8,
  parameter ADDR_WIDTH = 8,
  parameter RAM_DEPTH = (1 << ADDR_WIDTH)
)
(
  input  wire                  clk,        // Clock Input
  input  wire [ADDR_WIDTH-1:0] WrAddress,  // WrAddress Input
  input  wire [DATA_WIDTH-1:0] Data,       // Data Input
  input  wire                  WE,         // Write Enable
  input  wire [ADDR_WIDTH-1:0] RdAddress,  // RdAddress Input
  output wire [DATA_WIDTH-1:0] Q           // Q Output
); 

	
//--------------Internal variables---------------- 
reg [DATA_WIDTH-1:0] data_1_out;
reg [DATA_WIDTH-1:0] Q_out;
reg [DATA_WIDTH-1:0] mem [RAM_DEPTH-1:0];

//--------------Code Starts Here------------------ 
// Memory Write Block 
// Write Operation : When WE = 1
always @ (posedge clk)
begin : MEM_WRITE
  if ( WE ) begin
    mem[WrAddress] = Data;
  end
end


//Second Port of RAM
// output :
assign Q = data_1_out; 
// Memory Read Block
// Read Operation :
always @ (posedge clk)
begin : MEM_READ_1
  data_1_out = mem[RdAddress]; 
end

endmodule // End of Module dpram
