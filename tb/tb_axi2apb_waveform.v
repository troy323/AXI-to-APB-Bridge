`timescale 1ns/1ps

module tb_axi2apb_2fifo_simple_noid();

  // --------------------------------------------------------------------------
  // Parameters
  // --------------------------------------------------------------------------
  parameter AXI_ADDR_W  = 32;
  parameter APB_ADDR_W  = 32;
  parameter REQ_FIFO_AW = 4;
  parameter RSP_FIFO_AW = 4;

  // --------------------------------------------------------------------------
  // Signals
  // --------------------------------------------------------------------------
  // AXI clk/rst
  reg s_axi_aclk;
  reg s_axi_aresetn;

  // AXI Write Address
  reg  s_axi_awvalid;
  wire s_axi_awready;
  reg  [AXI_ADDR_W-1:0] s_axi_awaddr;
  reg  [7:0] s_axi_awlen;
  reg  [2:0] s_axi_awsize;
  reg  [1:0] s_axi_awburst;

  // AXI Write Data
  reg  s_axi_wvalid;
  wire s_axi_wready;
  reg  [31:0] s_axi_wdata;
  reg  [3:0] s_axi_wstrb;
  reg  s_axi_wlast;

  // AXI Write Response
  wire s_axi_bvalid;
  reg  s_axi_bready;
  wire [1:0] s_axi_bresp;

  // AXI Read Address
  reg  s_axi_arvalid;
  wire s_axi_arready;
  reg  [AXI_ADDR_W-1:0] s_axi_araddr;
  reg  [7:0] s_axi_arlen;
  reg  [2:0] s_axi_arsize;
  reg  [1:0] s_axi_arburst;

  // AXI Read Data
  wire s_axi_rvalid;
  reg  s_axi_rready;
  wire [31:0] s_axi_rdata;
  wire s_axi_rlast;
  wire [1:0] s_axi_rresp;

  // APB clk/rst
  reg pclk;
  reg presetn;

  // APB Master Interface
  wire psel;
  wire penable;
  wire pwrite;
  wire [APB_ADDR_W-1:0] paddr;
  wire [31:0] pwdata;
  wire pready;
  wire [31:0] prdata;

  // --------------------------------------------------------------------------
  // Clock & Reset Generation (Testing CDC: AXI @ 100MHz, APB @ 50MHz)
  // --------------------------------------------------------------------------
  initial begin
    s_axi_aclk = 0;
    forever #5 s_axi_aclk = ~s_axi_aclk; // 10ns period -> 100MHz
  end

  initial begin
    pclk = 0;
    forever #10 pclk = ~pclk; // 20ns period -> 50MHz
  end

  initial begin
    s_axi_aresetn = 0;
    presetn = 0;
    #35;
    s_axi_aresetn = 1;
    presetn = 1;
  end

  // --------------------------------------------------------------------------
  // DUT Instantiation
  // --------------------------------------------------------------------------
  axi2apb_2fifo_simple_noid #(
    .AXI_ADDR_W(AXI_ADDR_W),
    .APB_ADDR_W(APB_ADDR_W),
    .REQ_FIFO_AW(REQ_FIFO_AW),
    .RSP_FIFO_AW(RSP_FIFO_AW)
  ) dut (
    .s_axi_aclk(s_axi_aclk),         .s_axi_aresetn(s_axi_aresetn),
    .s_axi_awvalid(s_axi_awvalid),   .s_axi_awready(s_axi_awready),
    .s_axi_awaddr(s_axi_awaddr),     .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),     .s_axi_awburst(s_axi_awburst),
    .s_axi_wvalid(s_axi_wvalid),     .s_axi_wready(s_axi_wready),
    .s_axi_wdata(s_axi_wdata),       .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_bvalid(s_axi_bvalid),     .s_axi_bready(s_axi_bready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_arvalid(s_axi_arvalid),   .s_axi_arready(s_axi_arready),
    .s_axi_araddr(s_axi_araddr),     .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),     .s_axi_arburst(s_axi_arburst),
    .s_axi_rvalid(s_axi_rvalid),     .s_axi_rready(s_axi_rready),
    .s_axi_rdata(s_axi_rdata),       .s_axi_rlast(s_axi_rlast),
    .s_axi_rresp(s_axi_rresp),
    .pclk(pclk),                     .presetn(presetn),
    .psel(psel),                     .penable(penable),
    .pwrite(pwrite),                 .paddr(paddr),
    .pwdata(pwdata),                 .pready(pready),
    .prdata(prdata)
  );

  // --------------------------------------------------------------------------
  // Mock APB Memory (Slave Device) - FIXED
  // --------------------------------------------------------------------------
  reg [31:0] mem [0:255]; // 1KB memory
  
  // Respond immediately when selected and enabled (0 wait states)
  assign pready = 1'b1; 
  
  // Combinatorial Read: Data is ready on the bus as soon as address is stable
  assign prdata = (psel && !pwrite) ? mem[paddr[9:2]] : 32'h0;

  always @(posedge pclk) begin
    if (psel && penable && pready) begin
      if (pwrite) begin
        // Use word-aligned address index (ignore lower 2 bits)
        mem[paddr[9:2]] <= pwdata; 
        $display("[APB] Wrote Data: %h to Addr: %h", pwdata, paddr);
      end else begin
        $display("[APB] Read Data: %h from Addr: %h", mem[paddr[9:2]], paddr);
      end
    end
  end

  // --------------------------------------------------------------------------
  // AXI Master Tasks
  // --------------------------------------------------------------------------
  task axi_write_word;
    input [31:0] addr;
    input [31:0] data;
    begin
      // Address Phase
      @(posedge s_axi_aclk);
      s_axi_awvalid = 1; s_axi_awaddr = addr; 
      s_axi_awlen = 0; s_axi_awsize = 3'b010; s_axi_awburst = 2'b01; // 1 beat, 32-bit, INCR
      wait(s_axi_awready);
      @(posedge s_axi_aclk);
      s_axi_awvalid = 0;

      // Data Phase
      s_axi_wvalid = 1; s_axi_wdata = data;
      s_axi_wstrb = 4'hF; s_axi_wlast = 1;
      wait(s_axi_wready);
      @(posedge s_axi_aclk);
      s_axi_wvalid = 0; s_axi_wlast = 0;

      // Response Phase
      s_axi_bready = 1;
      wait(s_axi_bvalid);
      @(posedge s_axi_aclk);
      s_axi_bready = 0;
      $display("[AXI] Completed Write: Data %h to Addr %h", data, addr);
    end
  endtask

  task axi_read_word;
    input [31:0] addr;
    begin
      // Address Phase
      @(posedge s_axi_aclk);
      s_axi_arvalid = 1; s_axi_araddr = addr;
      s_axi_arlen = 0; s_axi_arsize = 3'b010; s_axi_arburst = 2'b01;
      wait(s_axi_arready);
      @(posedge s_axi_aclk);
      s_axi_arvalid = 0;

      // Read Data Phase
      s_axi_rready = 1;
      wait(s_axi_rvalid);
      $display("[AXI] Completed Read: Data %h from Addr %h", s_axi_rdata, addr);
      @(posedge s_axi_aclk);
      s_axi_rready = 0;
    end
  endtask

  // --------------------------------------------------------------------------
  // Main Stimulus
  // --------------------------------------------------------------------------
  initial begin
    // Initialize signals
    s_axi_awvalid = 0; s_axi_awaddr = 0; s_axi_awlen = 0; s_axi_awsize = 0; s_axi_awburst = 0;
    s_axi_wvalid = 0; s_axi_wdata = 0; s_axi_wstrb = 0; s_axi_wlast = 0;
    s_axi_bready = 0;
    s_axi_arvalid = 0; s_axi_araddr = 0; s_axi_arlen = 0; s_axi_arsize = 0; s_axi_arburst = 0;
    s_axi_rready = 0;

    // Initialize Memory Array to avoid initial "x" propagates if needed
    // for (integer i=0; i<256; i=i+1) mem[i] = 32'h0;

    // Wait for reset to finish
    wait(s_axi_aresetn && presetn);
    #50;

    $display("\n--- Starting Single Transfer Tests ---");
    axi_write_word(32'h0000_0000, 32'hDEADBEEF);
    axi_write_word(32'h0000_0004, 32'hCAFEBABE);
    
    #100; // Let FIFOs clear out
    
    axi_read_word(32'h0000_0000); // Should read DEADBEEF
    axi_read_word(32'h0000_0004); // Should read CAFEBABE
    
    #100;
    $display("--- Simulation Complete ---\n");
    $finish;
  end

  // Dump waves for visualization
  initial begin
    $dumpfile("axi2apb.vcd");
    $dumpvars(0, tb_axi2apb_2fifo_simple_noid);
  end

endmodule
