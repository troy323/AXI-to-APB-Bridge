
`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Top: bridge wrapper
// -----------------------------------------------------------------------------
module axi2apb_2fifo_simple_noid
#(
  parameter AXI_ADDR_W  = 32,
  parameter APB_ADDR_W  = 32,   // Full Byte Address
  parameter REQ_FIFO_AW = 4,    // depth = 2^REQ_FIFO_AW
  parameter RSP_FIFO_AW = 4
)
(
  // AXI clocks/resets
  input  wire                     s_axi_aclk,
  input  wire                     s_axi_aresetn,

  // AXI4 Write Address
  input  wire                     s_axi_awvalid,
  output wire                     s_axi_awready,
  input  wire [AXI_ADDR_W-1:0]    s_axi_awaddr,
  input  wire [7:0]               s_axi_awlen,
  input  wire [2:0]               s_axi_awsize,
  input  wire [1:0]               s_axi_awburst,

  // AXI4 Write Data
  input  wire                     s_axi_wvalid,
  output wire                     s_axi_wready,
  input  wire [31:0]              s_axi_wdata,
  input  wire [3:0]               s_axi_wstrb,
  input  wire                     s_axi_wlast,

  // AXI4 Write Response
  output wire                     s_axi_bvalid,
  input  wire                     s_axi_bready,
  output wire [1:0]               s_axi_bresp,

  // AXI4 Read Address
  input  wire                     s_axi_arvalid,
  output wire                     s_axi_arready,
  input  wire [AXI_ADDR_W-1:0]    s_axi_araddr,
  input  wire [7:0]               s_axi_arlen,
  input  wire [2:0]               s_axi_arsize,
  input  wire [1:0]               s_axi_arburst,

  // AXI4 Read Data
  output wire                     s_axi_rvalid,
  input  wire                     s_axi_rready,
  output wire [31:0]              s_axi_rdata,
  output wire                     s_axi_rlast,
  output wire [1:0]               s_axi_rresp,

  // APB clock/reset
  input  wire                     pclk,
  input  wire                     presetn,

  // APB3 Master Interface
  output wire                     psel,
  output wire                     penable,
  output wire                     pwrite,
  output wire [APB_ADDR_W-1:0]    paddr,
  output wire [31:0]              pwdata,
  input  wire                     pready,
  input  wire [31:0]              prdata
);

  // --------- Payload widths ---------
  // REQ: {op(1), last(1), addr(APB_ADDR_W), data(32)}
  localparam REQ_W = 1 + 1 + APB_ADDR_W + 32;
  // RSP: {rtype(2), last(1), data(32)}
  localparam RSP_W = 2 + 1 + 32;

  // REQ FIFO
  wire [REQ_W-1:0] req_wdata, req_rdata;
  wire             req_we, req_re, req_full, req_empty;

  // RSP FIFO
  wire [RSP_W-1:0] rsp_wdata, rsp_rdata;
  wire             rsp_we, rsp_re, rsp_full, rsp_empty;

  // AXI frontend
  axi_frontend_simple_noid
  #(
    .AXI_ADDR_W (AXI_ADDR_W),
    .APB_ADDR_W (APB_ADDR_W),
    .REQ_W      (REQ_W),
    .RSP_W      (RSP_W)
  )
  u_axi_fe
  (
    .clk              (s_axi_aclk),
    .rstn             (s_axi_aresetn),

    .s_axi_awvalid    (s_axi_awvalid),
    .s_axi_awready    (s_axi_awready),
    .s_axi_awaddr     (s_axi_awaddr),
    .s_axi_awlen      (s_axi_awlen),
    .s_axi_awsize     (s_axi_awsize),
    .s_axi_awburst    (s_axi_awburst),

    .s_axi_wvalid     (s_axi_wvalid),
    .s_axi_wready     (s_axi_wready),
    .s_axi_wdata      (s_axi_wdata),
    .s_axi_wstrb      (s_axi_wstrb),
    .s_axi_wlast      (s_axi_wlast),

    .s_axi_bvalid     (s_axi_bvalid),
    .s_axi_bready     (s_axi_bready),
    .s_axi_bresp      (s_axi_bresp),

    .s_axi_arvalid    (s_axi_arvalid),
    .s_axi_arready    (s_axi_arready),
    .s_axi_araddr     (s_axi_araddr),
    .s_axi_arlen      (s_axi_arlen),
    .s_axi_arsize     (s_axi_arsize),
    .s_axi_arburst    (s_axi_arburst),

    .s_axi_rvalid     (s_axi_rvalid),
    .s_axi_rready     (s_axi_rready),
    .s_axi_rdata      (s_axi_rdata),
    .s_axi_rlast      (s_axi_rlast),
    .s_axi_rresp      (s_axi_rresp),

    .req_wdata        (req_wdata),
    .req_we           (req_we),
    .req_full         (req_full),

    .rsp_rdata        (rsp_rdata),
    .rsp_re           (rsp_re),
    .rsp_empty        (rsp_empty)
  );

  // APB master
  apb_master_simple_noid
  #(
    .APB_ADDR_W (APB_ADDR_W),
    .REQ_W      (REQ_W),
    .RSP_W      (RSP_W)
  )
  u_apb_m
  (
    .pclk        (pclk),
    .presetn     (presetn),

    .psel        (psel),
    .penable     (penable),
    .pwrite      (pwrite),
    .paddr       (paddr),
    .pwdata      (pwdata),
    .pready      (pready),
    .prdata      (prdata),

    .req_rdata   (req_rdata),
    .req_re      (req_re),
    .req_empty   (req_empty),

    .rsp_wdata   (rsp_wdata),
    .rsp_we      (rsp_we),
    .rsp_full    (rsp_full)
  );

  // FIFOs
  async_fifo_v #(.W(REQ_W), .A(REQ_FIFO_AW)) u_req_fifo (
    .wclk  (s_axi_aclk), .wrstn (s_axi_aresetn),
    .we    (req_we),     .wdata (req_wdata), .wfull (req_full),
    .rclk  (pclk),       .rrstn (presetn),
    .re    (req_re),     .rdata (req_rdata), .rempty(req_empty)
  );

  async_fifo_v #(.W(RSP_W), .A(RSP_FIFO_AW)) u_rsp_fifo (
    .wclk  (pclk),       .wrstn (presetn),
    .we    (rsp_we),     .wdata (rsp_wdata), .wfull (rsp_full),
    .rclk  (s_axi_aclk), .rrstn (s_axi_aresetn),
    .re    (rsp_re),     .rdata (rsp_rdata), .rempty(rsp_empty)
  );

endmodule

// -----------------------------------------------------------------------------
// AXI FRONTEND
// -----------------------------------------------------------------------------
module axi_frontend_simple_noid
#(
  parameter AXI_ADDR_W = 32,
  parameter APB_ADDR_W = 32,
  parameter REQ_W      = 1 + 1 + APB_ADDR_W + 32,
  parameter RSP_W      = 2 + 1 + 32
)
(
  input  wire                     clk,
  input  wire                     rstn,

  // AXI write address
  input  wire                     s_axi_awvalid,
  output wire                     s_axi_awready,
  input  wire [AXI_ADDR_W-1:0]    s_axi_awaddr,
  input  wire [7:0]               s_axi_awlen,
  input  wire [2:0]               s_axi_awsize,
  input  wire [1:0]               s_axi_awburst,

  // AXI write data
  input  wire                     s_axi_wvalid,
  output wire                     s_axi_wready,
  input  wire [31:0]              s_axi_wdata,
  input  wire [3:0]               s_axi_wstrb,
  input  wire                     s_axi_wlast,

  // AXI write response
  output wire                     s_axi_bvalid,
  input  wire                     s_axi_bready,
  output wire [1:0]               s_axi_bresp,

  // AXI read address
  input  wire                     s_axi_arvalid,
  output wire                     s_axi_arready,
  input  wire [AXI_ADDR_W-1:0]    s_axi_araddr,
  input  wire [7:0]               s_axi_arlen,
  input  wire [2:0]               s_axi_arsize,
  input  wire [1:0]               s_axi_arburst,

  // AXI read data
  output wire                     s_axi_rvalid,
  input  wire                     s_axi_rready,
  output wire [31:0]              s_axi_rdata,
  output wire                     s_axi_rlast,
  output wire [1:0]               s_axi_rresp,

  // REQ FIFO (write side)
  output reg  [REQ_W-1:0]         req_wdata,
  output reg                      req_we,
  input  wire                     req_full,

  // RSP FIFO (read side)
  input  wire [RSP_W-1:0]         rsp_rdata,
  output wire                     rsp_re,
  input  wire                     rsp_empty
);

  wire [1:0]  head_rtype;
  wire        head_last;
  wire [31:0] head_data;
  assign {head_rtype, head_last, head_data} = rsp_rdata;

  wire head_is_b = (!rsp_empty) && (head_rtype == 2'b00);
  wire head_is_r = (!rsp_empty) && (head_rtype == 2'b01);

  assign s_axi_bvalid = head_is_b;
  assign s_axi_bresp  = 2'b00; // OKAY

  assign s_axi_rvalid = head_is_r;
  assign s_axi_rdata  = head_data;
  assign s_axi_rlast  = head_last;
  assign s_axi_rresp  = 2'b00; // OKAY

  assign rsp_re = (head_is_b && s_axi_bready) || (head_is_r && s_axi_rready);

  localparam S_IDLE       = 2'd0;
  localparam S_WRITE      = 2'd1;
  localparam S_PUSH_READS = 2'd2;

  reg [1:0] state, nstate;

  reg [AXI_ADDR_W-1:0] awaddr_q, awcurr_q;
  reg [7:0]            awlen_q, awcnt_q;
  reg [2:0]            awsize_q;
  reg [1:0]            awburst_q;

  reg [AXI_ADDR_W-1:0] araddr_q, arcurr_q;
  reg [7:0]            arlen_q, arcnt_q;
  reg [2:0]            arsize_q;
  reg [1:0]            arburst_q;

  wire aw_fire = s_axi_awvalid & s_axi_awready;
  wire w_fire  = s_axi_wvalid  & s_axi_wready;
  wire ar_fire = s_axi_arvalid & s_axi_arready;

  assign s_axi_awready = (state == S_IDLE)       & (~req_full);
  assign s_axi_wready  = (state == S_WRITE)      & (~req_full);
  assign s_axi_arready = (state == S_IDLE)       & (~req_full);

  wire [APB_ADDR_W-1:0] aw_word = awcurr_q[APB_ADDR_W-1:0];
  wire [APB_ADDR_W-1:0] ar_word = arcurr_q[APB_ADDR_W-1:0];

  always @(posedge clk or negedge rstn) begin
    if (!rstn) state <= S_IDLE; else state <= nstate;
  end

  always @* begin
    nstate = state;
    case (state)
      S_IDLE: begin
        if (s_axi_awvalid && !req_full)      nstate = S_WRITE;
        else if (s_axi_arvalid && !req_full) nstate = S_PUSH_READS;
      end
      S_WRITE: begin
        if (w_fire && s_axi_wlast) nstate = S_IDLE;
      end
      S_PUSH_READS: begin
        if (!req_full && (arcnt_q == 8'd0)) nstate = S_IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      awaddr_q <= {AXI_ADDR_W{1'b0}}; awcurr_q <= {AXI_ADDR_W{1'b0}};
      awlen_q  <= 8'd0; awcnt_q <= 8'd0; awsize_q <= 3'b010; awburst_q <= 2'b01;

      araddr_q <= {AXI_ADDR_W{1'b0}}; arcurr_q <= {AXI_ADDR_W{1'b0}};
      arlen_q  <= 8'd0; arcnt_q <= 8'd0; arsize_q <= 3'b010; arburst_q <= 2'b01;

      req_wdata <= {REQ_W{1'b0}}; req_we <= 1'b0;
    end else begin
      req_we <= 1'b0;

      if (aw_fire) begin
        awaddr_q <= s_axi_awaddr; awcurr_q <= s_axi_awaddr;
        awlen_q  <= s_axi_awlen;  awcnt_q  <= s_axi_awlen;
        awsize_q <= s_axi_awsize; awburst_q<= s_axi_awburst;
      end
      if (ar_fire) begin
        araddr_q <= s_axi_araddr; arcurr_q <= s_axi_araddr;
        arlen_q  <= s_axi_arlen;  arcnt_q  <= s_axi_arlen;
        arsize_q <= s_axi_arsize; arburst_q<= s_axi_arburst;
      end

      if (state == S_WRITE && w_fire) begin
        req_wdata <= {1'b1, s_axi_wlast, aw_word, s_axi_wdata};
        req_we    <= 1'b1;
        if (!s_axi_wlast) begin
          awcurr_q <= next_addr_v(awburst_q, awcurr_q, awaddr_q, awsize_q, awlen_q);
          awcnt_q  <= awcnt_q - 8'd1;
        end
      end

      if (state == S_PUSH_READS && !req_full) begin
        req_wdata <= {1'b0, (arcnt_q==8'd0), ar_word, 32'h0};
        req_we    <= 1'b1;
        if (arcnt_q != 8'd0) begin
          arcurr_q <= next_addr_v(arburst_q, arcurr_q, araddr_q, arsize_q, arlen_q);
          arcnt_q  <= arcnt_q - 8'd1;
        end
      end
    end
  end

  // ------- Address Calculation Helper -------
  function [AXI_ADDR_W-1:0] next_addr_v;
    input [1:0]              burst;
    input [AXI_ADDR_W-1:0]   curr;
    input [AXI_ADDR_W-1:0]   start;
    input [2:0]              size;
    input [7:0]              len;
    reg   [AXI_ADDR_W-1:0]   xfer_v, len_p1_v, bnd_v, nxt, base, upper;
  begin
    xfer_v   = ({{(AXI_ADDR_W-1){1'b0}},1'b1}) << size;
    len_p1_v = {{(AXI_ADDR_W-8){1'b0}}, (len + 8'd1)};
    bnd_v    = len_p1_v * xfer_v;
    nxt      = curr + xfer_v;
    case (burst)
      2'b00: next_addr_v = curr;
      2'b01: next_addr_v = nxt;
      2'b10: begin
        base        = start & ~(bnd_v - 1'b1);
        upper       = base + bnd_v;
        next_addr_v = (nxt >= upper) ? base : nxt;
      end
      default: next_addr_v = nxt;
    endcase
  end
  endfunction
endmodule

// -----------------------------------------------------------------------------
// APB MASTER
// -----------------------------------------------------------------------------
module apb_master_simple_noid
#(
  parameter APB_ADDR_W = 32,
  parameter REQ_W      = 1 + 1 + APB_ADDR_W + 32,
  parameter RSP_W      = 2 + 1 + 32
)
(
  input  wire                     pclk,
  input  wire                     presetn,

  output reg                      psel,
  output reg                      penable,
  output reg                      pwrite,
  output reg  [APB_ADDR_W-1:0]    paddr,
  output reg  [31:0]              pwdata,
  input  wire                     pready,
  input  wire [31:0]              prdata,

  input  wire [REQ_W-1:0]         req_rdata,
  output wire                     req_re,
  input  wire                     req_empty,

  output reg  [RSP_W-1:0]         rsp_wdata,
  output reg                      rsp_we,
  input  wire                     rsp_full
);
  wire                  head_write;
  wire                  head_last;
  wire [APB_ADDR_W-1:0] head_addr;
  wire [31:0]           head_data;
  assign {head_write, head_last, head_addr, head_data} = req_rdata;

  wire can_start = (!req_empty) & (!rsp_full);

  localparam P_IDLE   = 2'd0;
  localparam P_SETUP  = 2'd1;
  localparam P_ACCESS = 2'd2;
  reg [1:0] state, nstate;

  reg                   op_write_q, op_last_q;
  reg [APB_ADDR_W-1:0]  op_addr_q;
  reg [31:0]            op_data_q;

  assign req_re = (state == P_SETUP) & (!req_empty) & (!rsp_full);

  always @(posedge pclk or negedge presetn) begin
    if (!presetn) state <= P_IDLE; else state <= nstate;
  end

  always @* begin
    nstate = state;
    case (state)
      P_IDLE:   nstate = can_start ? P_SETUP : P_IDLE;
      P_SETUP:  nstate = P_ACCESS;
      P_ACCESS: nstate = pready ? P_IDLE : P_ACCESS;
    endcase
  end

  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      psel <= 1'b0; penable <= 1'b0; pwrite <= 1'b0;
      paddr <= {APB_ADDR_W{1'b0}}; pwdata <= 32'h0;
      rsp_wdata <= {RSP_W{1'b0}}; rsp_we <= 1'b0;
      op_write_q <= 1'b0; op_last_q <= 1'b0; op_addr_q <= {APB_ADDR_W{1'b0}}; op_data_q <= 32'h0;
    end else begin
      rsp_we <= 1'b0;

      case (state)
        P_IDLE: begin
          psel <= 1'b0; penable <= 1'b0;
          if (can_start) begin
            pwrite     <= head_write;
            paddr      <= head_addr;
            pwdata     <= head_data;
            op_write_q <= head_write;
            op_last_q  <= head_last;
            op_addr_q  <= head_addr;
            op_data_q  <= head_data;
            psel       <= 1'b1;
          end
        end
        P_SETUP: begin
          psel    <= 1'b1;
          penable <= 1'b1;
        end
        P_ACCESS: begin
          psel <= 1'b1; penable <= 1'b1;
          if (pready) begin
            if (op_write_q) begin
              if (op_last_q && !rsp_full) begin
                rsp_wdata <= {2'b00, 1'b1, 32'h0};
                rsp_we    <= 1'b1;
              end
            end else begin
              if (!rsp_full) begin
                rsp_wdata <= {2'b01, op_last_q, prdata};
                rsp_we    <= 1'b1;
              end
            end
            psel <= 1'b0; penable <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule

// -----------------------------------------------------------------------------
// FWFT Dual-clock Asynchronous FIFO 
// -----------------------------------------------------------------------------
module async_fifo_v
#(
  parameter W = 64,
  parameter A = 4
)
(
  input  wire         wclk,
  input  wire         wrstn,
  input  wire         we,
  input  wire [W-1:0] wdata,
  output wire         wfull,

  input  wire         rclk,
  input  wire         rrstn,
  input  wire         re,
  output wire [W-1:0] rdata, // Changed from reg to wire for FWFT
  output wire         rempty
);
  localparam DEPTH = (1<<A);
  reg [W-1:0] mem [0:DEPTH-1];

  reg [A:0] wbin, wgray;
  reg [A:0] rbin, rgray;
  reg [A:0] rgray_w1, rgray_w2;
  reg [A:0] wgray_r1, wgray_r2;

  wire winc = we & ~wfull;
  wire rinc = re & ~rempty;

  wire [A:0] wbin_n  = wbin + winc;
  wire [A:0] rbin_n  = rbin + rinc;
  wire [A:0] wgray_n = (wbin_n>>1) ^ wbin_n;
  wire [A:0] rgray_n = (rbin_n>>1) ^ rbin_n;

  // Write Domain
  always @(posedge wclk or negedge wrstn) begin
    if (!wrstn) begin
      wbin <= {A+1{1'b0}}; wgray <= {A+1{1'b0}};
    end else begin
      wbin <= wbin_n; wgray <= wgray_n;
      if (winc) mem[wbin[A-1:0]] <= wdata;
    end
  end

  // Read Domain (Pointers only)
  always @(posedge rclk or negedge rrstn) begin
    if (!rrstn) begin
      rbin <= {A+1{1'b0}}; rgray <= {A+1{1'b0}};
    end else begin
      rbin <= rbin_n; rgray <= rgray_n;
    end
  end

  assign rdata = mem[rbin[A-1:0]];

  // Sync logic
  always @(posedge wclk or negedge wrstn) begin
    if (!wrstn) begin rgray_w1 <= {A+1{1'b0}}; rgray_w2 <= {A+1{1'b0}}; end
    else begin rgray_w1 <= rgray; rgray_w2 <= rgray_w1; end
  end

  always @(posedge rclk or negedge rrstn) begin
    if (!rrstn) begin wgray_r1 <= {A+1{1'b0}}; wgray_r2 <= {A+1{1'b0}}; end
    else begin wgray_r1 <= wgray; wgray_r2 <= wgray_r1; end
  end

  assign wfull  = (wgray == {~rgray_w2[A:A-1], rgray_w2[A-2:0]});
  assign rempty = (rgray == wgray_r2);
endmodule
