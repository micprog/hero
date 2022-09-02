// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "axi/assign.svh"
`include "axi/typedef.svh"

`define wait_for(signal) \
  do \
    @(posedge clk); \
  while (!signal);

module pulp_tb #(
  // TB Parameters
  parameter time          CLK_PERIOD = 1000ps,
  // SoC Parameters
  parameter int unsigned  N_CLUSTERS = 2,
  parameter int unsigned  AXI_DW = 128,
  parameter int unsigned  L2_N_AXI_PORTS = 1
);

  timeunit 1ps;
  timeprecision 1ps;

  localparam int unsigned AXI_IW = pulp_pkg::axi_iw_sb_oup(N_CLUSTERS);
  localparam int unsigned AXI_SW = AXI_DW/8;  // width of strobe
  typedef pulp_pkg::addr_t      axi_addr_t;
  typedef logic [AXI_DW-1:0]    axi_data_t;
  typedef logic [AXI_IW-1:0]    axi_id_t;
  typedef logic [AXI_SW-1:0]    axi_strb_t;
  typedef pulp_pkg::user_t      axi_user_t;
  `AXI_TYPEDEF_AW_CHAN_T(       axi_aw_t,     axi_addr_t, axi_id_t, axi_user_t);
  `AXI_TYPEDEF_W_CHAN_T(        axi_w_t,      axi_data_t, axi_strb_t, axi_user_t);
  `AXI_TYPEDEF_B_CHAN_T(        axi_b_t,      axi_id_t, axi_user_t);
  `AXI_TYPEDEF_AR_CHAN_T(       axi_ar_t,     axi_addr_t, axi_id_t, axi_user_t);
  `AXI_TYPEDEF_R_CHAN_T(        axi_r_t,      axi_data_t, axi_id_t, axi_user_t);
  `AXI_TYPEDEF_REQ_T(           axi_req_t,    axi_aw_t, axi_w_t, axi_ar_t);
  `AXI_TYPEDEF_RESP_T(          axi_resp_t,   axi_b_t, axi_r_t);

  typedef pulp_pkg::lite_addr_t axi_lite_addr_t;
  typedef pulp_pkg::lite_data_t axi_lite_data_t;
  typedef pulp_pkg::lite_strb_t axi_lite_strb_t;
  `AXI_LITE_TYPEDEF_AW_CHAN_T(  axi_lite_aw_t,    axi_lite_addr_t);
  `AXI_LITE_TYPEDEF_W_CHAN_T(   axi_lite_w_t,     axi_lite_data_t, axi_lite_strb_t);
  `AXI_LITE_TYPEDEF_B_CHAN_T(   axi_lite_b_t);
  `AXI_LITE_TYPEDEF_AR_CHAN_T(  axi_lite_ar_t,    axi_lite_addr_t);
  `AXI_LITE_TYPEDEF_R_CHAN_T(   axi_lite_r_t,     axi_lite_data_t);
  `AXI_LITE_TYPEDEF_REQ_T(      axi_lite_req_t,   axi_lite_aw_t, axi_lite_w_t, axi_lite_ar_t);
  `AXI_LITE_TYPEDEF_RESP_T(     axi_lite_resp_t,  axi_lite_b_t, axi_lite_r_t);

  logic clk,
        rst_n;

  logic [N_CLUSTERS-1:0]  cl_busy,
                          cl_eoc,
                          cl_fetch_en;

  axi_req_t   from_pulp_req,
              to_pulp_req;
  axi_resp_t  from_pulp_resp,
              to_pulp_resp;

  axi_lite_req_t  rab_conf_req;
  axi_lite_resp_t rab_conf_resp;

  clk_rst_gen #(
    .ClkPeriod    (CLK_PERIOD),
    .RstClkCycles (10)
  ) i_clk_gen (
    .clk_o  (clk),
    .rst_no (rst_n)
  );

  pulp #(
    .N_CLUSTERS     (N_CLUSTERS),
    .AXI_DW         (AXI_DW),
    .L2_N_AXI_PORTS (L2_N_AXI_PORTS),
    .axi_req_t      (axi_req_t),
    .axi_resp_t     (axi_resp_t),
    .axi_lite_req_t (axi_lite_req_t),
    .axi_lite_resp_t(axi_lite_resp_t)
  ) dut (
    .clk_i          (clk),
    .rst_ni         (rst_n),

    .cl_fetch_en_i  (cl_fetch_en),
    .cl_eoc_o       (cl_eoc),
    .cl_busy_o      (cl_busy),

    .rab_from_pulp_miss_irq_o   (/* unused */),
    .rab_from_pulp_multi_irq_o  (/* unused */),
    .rab_from_pulp_prot_irq_o   (/* unused */),
    .rab_from_host_miss_irq_o   (/* unused */),
    .rab_from_host_multi_irq_o  (/* unused */),
    .rab_from_host_prot_irq_o   (/* unused */),
    .rab_miss_fifo_full_irq_o   (/* unused */),
    .mbox_irq_o                 (/* unused */),

    .ext_req_o      (from_pulp_req),
    .ext_resp_i     (from_pulp_resp),
    .ext_req_i      (to_pulp_req),
    .ext_resp_o     (to_pulp_resp),
    .rab_conf_req_i (rab_conf_req),
    .rab_conf_resp_o(rab_conf_resp)
  );

  // AXI Node for Memory (slave 0) and Peripherals (slave 1)
  AXI_BUS #(
    .AXI_ADDR_WIDTH (pulp_pkg::AXI_AW),
    .AXI_DATA_WIDTH (AXI_DW),
    .AXI_ID_WIDTH   (AXI_IW),
    .AXI_USER_WIDTH (pulp_pkg::AXI_UW)
  ) from_pulp[0:0] ();
  AXI_BUS #(
    .AXI_ADDR_WIDTH (pulp_pkg::AXI_AW),
    .AXI_DATA_WIDTH (AXI_DW),
    .AXI_ID_WIDTH   (AXI_IW+1),
    .AXI_USER_WIDTH (pulp_pkg::AXI_UW)
  ) from_xbar[1:0] ();
  AXI_BUS #(
    .AXI_ADDR_WIDTH (pulp_pkg::AXI_AW),
    .AXI_DATA_WIDTH (64),
    .AXI_ID_WIDTH   (AXI_IW+1),
    .AXI_USER_WIDTH (pulp_pkg::AXI_UW)
  ) to_periphs ();
  `AXI_ASSIGN_FROM_REQ(from_pulp[0], from_pulp_req);
  `AXI_ASSIGN_TO_RESP (from_pulp_resp, from_pulp[0]);
  // Address Map
  typedef axi_pkg::xbar_rule_64_t rule_t;
  localparam int unsigned NumRules = 1;
  rule_t [NumRules-1:0] addr_map;
  assign addr_map[0] = '{
    idx:        1,
    start_addr: 64'h0000_0000_1a10_0000,
    end_addr:   64'h0000_0000_1a10_ffff
  };
  // Crossbar Configuration and Instantiation
  localparam axi_pkg::xbar_cfg_t XbarCfg = '{
    NoSlvPorts:         1,
    NoMstPorts:         2,
    MaxMstTrans:        8,
    MaxSlvTrans:        8,
    FallThrough:        1'b1,
    LatencyMode:        axi_pkg::NO_LATENCY,
    AxiIdWidthSlvPorts: AXI_IW,
    AxiIdUsedSlvPorts:  AXI_IW,
    UniqueIds:          1'b0,
    AxiAddrWidth:       pulp_pkg::AXI_AW,
    AxiDataWidth:       AXI_DW,
    NoAddrRules:        NumRules
  };
  axi_xbar_intf #(
    .AXI_USER_WIDTH (pulp_pkg::AXI_UW),
    .Cfg            (XbarCfg),
    .rule_t         (rule_t)
  ) i_xbar (
    .clk_i                  (clk),
    .rst_ni                 (rst_n),
    .test_i                 (1'b0),
    .slv_ports              (from_pulp),
    .mst_ports              (from_xbar),
    .addr_map_i             (addr_map),
    .en_default_mst_port_i  ('1), // default all slave ports to master port 0
    .default_mst_port_i     ('0)
  );

  // Peripherals
  axi_dw_converter_intf #(
    .AXI_ID_WIDTH             (AXI_IW+1),
    .AXI_ADDR_WIDTH           (pulp_pkg::AXI_AW),
    .AXI_SLV_PORT_DATA_WIDTH  (AXI_DW),
    .AXI_MST_PORT_DATA_WIDTH  (64),
    .AXI_USER_WIDTH           (pulp_pkg::AXI_UW),
    .AXI_MAX_READS            (4)
  ) i_dwc_periph_mst (
    .clk_i  (clk),
    .rst_ni (rst_n),
    .slv    (from_xbar[1]),
    .mst    (to_periphs)
  );
  soc_peripherals #(
    .AXI_AW     (pulp_pkg::AXI_AW),
    .AXI_IW     (AXI_IW+1),
    .AXI_UW     (pulp_pkg::AXI_UW),
    .N_CORES    (8),
    .N_CLUSTERS (N_CLUSTERS)
  ) i_peripherals (
    .clk_i      (clk),
    .rst_ni     (rst_n),
    .test_en_i  (1'b0),
    .axi        (to_periphs)
  );

  // Emulate infinite memory with AXI slave port.
  axi_sim_mem_intf #(
    .AXI_ADDR_WIDTH      (pulp_pkg::AXI_AW),
    .AXI_DATA_WIDTH      (AXI_DW),
    .AXI_ID_WIDTH        (AXI_IW + 1),
    .AXI_USER_WIDTH      (pulp_pkg::AXI_UW),
    .WARN_UNINITIALIZED  (1'b0),
    .APPL_DELAY          (CLK_PERIOD / 5 * 1),
    .ACQ_DELAY           (CLK_PERIOD / 5 * 4)
  ) i_sim_mem (
    .clk_i    (clk),
    .rst_ni   (rst_n),
    .axi_slv  (from_xbar[0])
  );

  task write_rab(input axi_lite_addr_t addr, input axi_lite_data_t data);
    rab_conf_req.aw.addr = addr;
    rab_conf_req.aw_valid = 1'b1;
    `wait_for(rab_conf_resp.aw_ready)
    rab_conf_req.aw_valid = 1'b0;
    rab_conf_req.w.data = data;
    rab_conf_req.w.strb = '1;
    rab_conf_req.w_valid = 1'b1;
    `wait_for(rab_conf_resp.w_ready)
    rab_conf_req.w_valid = 1'b0;
    rab_conf_req.b_ready = 1'b1;
    `wait_for(rab_conf_resp.b_valid)
    rab_conf_req.b_ready = 1'b0;
  endtask

  task write_rab_slice(input axi_lite_addr_t slice_addr, input axi_addr_t first,
      input axi_addr_t last, input axi_addr_t base);
    automatic axi_lite_addr_t slice_base_addr = 32'hA800_0000 + slice_addr;
    write_rab(slice_base_addr+8'h00, first);
    if (pulp_pkg::AXI_LITE_DW < pulp_pkg::AXI_AW) begin
      write_rab(slice_base_addr+8'h04, first[$left(first)-:pulp_pkg::AXI_AW-pulp_pkg::AXI_LITE_DW]);
    end
    write_rab(slice_base_addr+8'h08, last);
    if (pulp_pkg::AXI_LITE_DW < pulp_pkg::AXI_AW) begin
      write_rab(slice_base_addr+8'h0C, last[$left(last)-:pulp_pkg::AXI_AW-pulp_pkg::AXI_LITE_DW]);
    end
    write_rab(slice_base_addr+8'h10, base);
    if (pulp_pkg::AXI_LITE_DW < pulp_pkg::AXI_AW) begin
      write_rab(slice_base_addr+8'h14, base[$left(base)-:pulp_pkg::AXI_AW-pulp_pkg::AXI_LITE_DW]);
    end
    write_rab(slice_base_addr+8'h18, 64'b111);
  endtask

  task write_to_pulp(input axi_addr_t addr, input axi_data_t data, output axi_pkg::resp_t resp);
    to_pulp_req.aw.id = '0;
    to_pulp_req.aw.addr = addr;
    to_pulp_req.aw.len = '0;
    to_pulp_req.aw.size = $clog2(AXI_SW);
    to_pulp_req.aw.burst = axi_pkg::BURST_INCR;
    to_pulp_req.aw.lock = 1'b0;
    to_pulp_req.aw.cache = '0;
    to_pulp_req.aw.prot = '0;
    to_pulp_req.aw.qos = '0;
    to_pulp_req.aw.region = '0;
    to_pulp_req.aw.atop = '0;
    to_pulp_req.aw.user = '0;
    to_pulp_req.aw_valid = 1'b1;
    `wait_for(to_pulp_resp.aw_ready)
    to_pulp_req.aw_valid = 1'b0;
    to_pulp_req.w.data = data;
    to_pulp_req.w.strb = '1;
    to_pulp_req.w.last = 1'b1;
    to_pulp_req.w.user = '0;
    to_pulp_req.w_valid = 1'b1;
    `wait_for(to_pulp_resp.w_ready)
    to_pulp_req.w_valid = 1'b0;
    to_pulp_req.b_ready = 1'b1;
    `wait_for(to_pulp_resp.b_valid)
    resp = to_pulp_resp.b.resp;
    to_pulp_req.b_ready = 1'b0;
  endtask

  task read_from_pulp(input axi_addr_t addr, output axi_data_t data, output axi_pkg::resp_t resp);
    to_pulp_req.ar.id = '0;
    to_pulp_req.ar.addr = addr;
    to_pulp_req.ar.len = '0;
    to_pulp_req.ar.size = $clog2(AXI_SW);
    to_pulp_req.ar.burst = axi_pkg::BURST_INCR;
    to_pulp_req.ar.lock = 1'b0;
    to_pulp_req.ar.cache = '0;
    to_pulp_req.ar.prot = '0;
    to_pulp_req.ar.qos = '0;
    to_pulp_req.ar.region = '0;
    to_pulp_req.ar.user = '0;
    to_pulp_req.ar_valid = 1'b1;
    `wait_for(to_pulp_resp.ar_ready)
    to_pulp_req.ar_valid = 1'b0;
    to_pulp_req.r_ready = 1'b1;
    `wait_for(to_pulp_resp.r_valid)
    data = to_pulp_resp.r.data;
    resp = to_pulp_resp.r.resp;
    to_pulp_req.r_ready = 1'b0;
  endtask

  // Simulation control
  initial begin
    axi_data_t data;
    axi_pkg::resp_t resp;
    cl_fetch_en = '0;
    rab_conf_req = '{default: '0};
    to_pulp_req = '{default: '0};
    // Wait for reset.
    wait (rst_n);
    @(posedge clk);

    // Set up RAB slice from PULP to external devices: all addresses (that the interconnect routes
    // through the RAB) except zero page.
    write_rab_slice(32'h1000, 52'h1, 52'hFFFF_FFFF_FFFF_F, 52'h1);

    // Set up RAB slice from external/Host to mailbox.
    write_rab_slice(32'h0, 52'hA600_0, 52'hA600_0, 52'h1B80_1); // Host mbox IF
    write_rab_slice(32'h1C, 52'hA600_1, 52'hA600_1, 52'h1B80_0); // PULP mbox IF

    // Write word to mailbox.
    write_to_pulp(64'h0000_0000_A600_0000, 32'h5000_600D, resp);
    assert(resp == axi_pkg::RESP_OKAY);

    // Read status of mailbox via Host interface.
    read_from_pulp(64'h0000_0000_A600_0020, data, resp);
    assert(resp == axi_pkg::RESP_OKAY);

    // Read status of mailbox via PULP interface.
    read_from_pulp(64'h0000_0000_A600_1020, data, resp);
    assert(resp == axi_pkg::RESP_OKAY);

    // Start cluster 0.
    cl_fetch_en[0] = 1'b1;
    // Wait for EOC of cluster 0 before terminating the simulation.
    wait (cl_eoc[0]);
    #1us;
    $finish();
  end

  // Fill TCDM memory.
  for (genvar iCluster = 0; iCluster < N_CLUSTERS; iCluster++) begin: gen_fill_tcdm_cluster
    for (genvar iBank = 0; iBank < 16; iBank++) begin: gen_fill_tcdm_bank
      initial begin
        $readmemh($sformatf("../test/slm_files/l1_0_%01d.slm", iBank),
          dut.gen_clusters[iCluster].gen_cluster_sync.i_cluster.i_ooc.i_bound.gen_tcdm_banks[iBank].i_tc_sram.sram);
      end
    end
  end

  // Fill L2 memory.
  localparam N_SER_CUTS = dut.gen_l2_ports[0].i_l2_mem.N_SER_CUTS; // both same on all ports
  localparam N_PAR_CUTS = dut.gen_l2_ports[0].i_l2_mem.N_PAR_CUTS;
  for (genvar iPort = 0; iPort < L2_N_AXI_PORTS; iPort++) begin: gen_fill_l2_ports
    for (genvar iRow = 0; iRow < N_SER_CUTS; iRow++) begin: gen_fill_l2_rows
      for (genvar iCol = 0; iCol < N_PAR_CUTS; iCol++) begin: gen_fill_l2_cols
        int unsigned file_ser_idx = iPort*N_SER_CUTS + iRow;
        initial begin
          $readmemh($sformatf("../test/slm_files/l2_%01d_%01d.slm", file_ser_idx, iCol),
            dut.gen_l2_ports[iPort].i_l2_mem.gen_rows[iRow].gen_cols[iCol].i_tc_sram_cut.sram);
        end
      end
    end
  end

  // Observe SoC bus for errors.
  for (genvar iCluster = 0; iCluster < N_CLUSTERS; iCluster++) begin: gen_assert_cluster
    assert property (@(posedge dut.clk_i) dut.rst_ni && dut.cl_oup[iCluster].r_valid
        |-> dut.cl_oup[iCluster].r_resp != 2'b11)
      else $warning("R resp decode error at cl_oup[%01d]", iCluster);

    assert property (@(posedge dut.clk_i) dut.rst_ni && dut.cl_oup[iCluster].b_valid
        |-> dut.cl_oup[iCluster].b_resp != 2'b11)
      else $warning("B resp decode error at cl_oup[%01d]", iCluster);
  end

endmodule
