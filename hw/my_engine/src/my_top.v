`timescale 1ns / 1ps
//`default_nettype none
`include "includes.v"

module naas_dma ( 
    // PCI Express Fabric Interface
    // Tx
    output    [7:0]           pci_exp_txp,
    output    [7:0]           pci_exp_txn,
    // Rx
    input     [7:0]           pci_exp_rxp,
    input     [7:0]           pci_exp_rxn,
    // System (SYS) Interface
    input                     sys_clk_p,
    input                     sys_clk_n,
    //input                   sys_reset_n,    // MF: no reset available

    // MAC Rx
    input                s_axis_aclk,           // 250MHz
    input                s_axis_aresetn,
    input    [63:0]      s_axis_tdata,
    input    [7:0]       s_axis_tstrb,
    input    [127:0]     s_axis_tuser,
    input                s_axis_tvalid,
    input                s_axis_tlast,
    output reg           s_axis_tready,

    // MAC Tx
    input                     m_axis_aclk,           // 250MHz
    input                     m_axis_aresetn,
    output reg    [63:0]      m_axis_tdata,
    output reg    [7:0]       m_axis_tstrb,
    output reg    [127:0]     m_axis_tuser,
    output reg                m_axis_tvalid,
    output reg                m_axis_tlast,
    input                     m_axis_tready

    );//synthesis syn_noclockbuf=1


    //-------------------------------------------------------
    // Local Wires  PCIe
    //-------------------------------------------------------

    wire                                              sys_clk_c;
    wire                                              refclkout;
    wire                                              sys_reset_n_c = 1'b1;  // MF: no reset available
    wire                                              trn_clk_c;//synthesis attribute max_fanout of trn_clk_c is "100000"
    wire                                              trn_reset_n_c;
    wire                                              trn_lnk_up_n_c;
    wire                                              cfg_trn_pending_n_c;
    wire [(64 - 1):0]             cfg_dsn_n_c;
    wire                                              trn_tsof_n_c;
    wire                                              trn_teof_n_c;
    wire                                              trn_tsrc_rdy_n_c;
    wire                                              trn_tdst_rdy_n_c;
    wire                                              trn_tsrc_dsc_n_c;
    wire                                              trn_terrfwd_n_c;
    wire                                              trn_tdst_dsc_n_c;
    wire    [(64 - 1):0]         trn_td_c;
    wire    [7:0]          trn_trem_n_c;
    wire    [( 4 -1 ):0]       trn_tbuf_av_c;

    wire                                              trn_rsof_n_c;
    wire                                              trn_reof_n_c;
    wire                                              trn_rsrc_rdy_n_c;
    wire                                              trn_rsrc_dsc_n_c;
    wire                                              trn_rdst_rdy_n_c;
    wire                                              trn_rerrfwd_n_c;
    wire                                              trn_rnp_ok_n_c;

    wire    [(64 - 1):0]         trn_rd_c;
    wire    [7:0]                trn_rrem_n_c;
    wire    [6:0]                trn_rbar_hit_n_c;
    wire    [7:0]                trn_rfc_nph_av_c;
    wire    [11:0]               trn_rfc_npd_av_c;
    wire    [7:0]                trn_rfc_ph_av_c;
    wire    [11:0]               trn_rfc_pd_av_c;
    wire                                              trn_rcpl_streaming_n_c;

    wire    [31:0]         cfg_do_c;
    wire    [31:0]         cfg_di_c;
    wire    [9:0]          cfg_dwaddr_c;
    wire    [3:0]          cfg_byte_en_n_c;
    wire    [47:0]         cfg_err_tlp_cpl_header_c;

    wire                                              cfg_wr_en_n_c;
    wire                                              cfg_rd_en_n_c;
    wire                                              cfg_rd_wr_done_n_c;
    wire                                              cfg_err_cor_n_c;
    wire                                              cfg_err_ur_n_c;
    wire                                              cfg_err_cpl_rdy_n_c;
    wire                                              cfg_err_ecrc_n_c;
    wire                                              cfg_err_cpl_timeout_n_c;
    wire                                              cfg_err_cpl_abort_n_c;
    wire                                              cfg_err_cpl_unexpect_n_c;
    wire                                              cfg_err_posted_n_c;
    wire                                              cfg_err_locked_n_c;
    wire                                              cfg_interrupt_n_c;
    wire                                              cfg_interrupt_rdy_n_c;

    wire                                              cfg_interrupt_assert_n_c;
    wire [7 : 0]                                      cfg_interrupt_di_c;
    wire [7 : 0]                                      cfg_interrupt_do_c;
    wire [2 : 0]                                      cfg_interrupt_mmenable_c;
    wire                                              cfg_interrupt_msienable_c;

    wire                                              cfg_turnoff_ok_n_c;
    wire                                              cfg_to_turnoff_n;
    wire                                              cfg_pm_wake_n_c;
    wire    [2:0]           cfg_pcie_link_state_n_c;
    wire    [7:0]           cfg_bus_number_c;
    wire    [4:0]           cfg_device_number_c;
    wire    [2:0]           cfg_function_number_c;
    wire    [15:0]          cfg_status_c;
    wire    [15:0]          cfg_command_c;
    wire    [15:0]          cfg_dstatus_c;
    wire    [15:0]          cfg_dcommand_c;
    wire    [15:0]          cfg_lstatus_c;
    wire    [15:0]          cfg_lcommand_c;
    
    //-------------------------------------------------------
    // Local Wires 
    //-------------------------------------------------------
    wire                                              RST_IN;
    wire                                              dcm_for_xaui_locked_out;
    wire                                              clk_50_Mhz_for_xaui;
    wire                                              xaui_reset;
    wire                                              xaui_clk_156_25_out;
    wire                                              reset_n;
    
    //////////////////////////////////////////////////////////////////////////////////////////
    // Reception side of the NIC signal declaration
    //////////////////////////////////////////////////////////////////////////////////////////
    //-------------------------------------------------------
    // Local Wires internal_true_dual_port_ram rx
    //-------------------------------------------------------
    wire   [`BF:0]                                    rx_wr_addr;
    wire   [63:0]                                     rx_wr_data;
    wire   [`BF:0]                                    rx_rd_addr;
    wire   [63:0]                                     rx_rd_data;
    wire                                              rx_wr_clk;
    wire                                              rx_wr_en;
    wire                                              rx_rd_clk;
    wire   [63:0]                                     rx_qspo;
    
    //-------------------------------------------------------
    // Local Wires rx_tlp_trigger
    //-------------------------------------------------------
    wire   [`BF:0]                                    rx_commited_wr_address;
    wire   [`BF:0]                                    rx_commited_rd_address;
    wire                                              rx_trigger_tlp_ack;
    wire                                              rx_trigger_tlp;
    wire                                              rx_change_huge_page_ack;
    wire                                              rx_change_huge_page;
    wire                                              rx_send_last_tlp_change_huge_page;
    wire   [4:0]                                      rx_qwords_to_send;

    //-------------------------------------------------------
    // Local Wires rx_mac_interface
    //-------------------------------------------------------
    wire   [`BF:0]                                    rx_commited_rd_address_to_mac;
    wire                                              rx_commited_rd_address_to_mac_change;

    //////////////////////////////////////////////////////////////////////////////////////////
    // Transmition side of the NIC signal declaration
    //////////////////////////////////////////////////////////////////////////////////////////
    //-------------------------------------------------------
    // Local Wires internal_true_dual_port_ram tx
    //-------------------------------------------------------
    wire   [`BF:0]                                    tx_wr_addr;
    wire   [63:0]                                     tx_wr_data;
    wire   [`BF:0]                                    tx_rd_addr;
    wire   [63:0]                                     tx_rd_data;
    wire                                              tx_wr_clk;
    wire                                              tx_wr_en;
    wire                                              tx_rd_clk;
    wire   [63:0]                                     tx_qspo;

    //-------------------------------------------------------
    // Local Wires tx_mac_interface tx
    //-------------------------------------------------------
    wire   [`BF:0]                                    tx_commited_rd_addr;
    wire                                              tx_commited_rd_addr_change;
    wire                                              tx_commited_wr_addr_change;
    wire   [`BF:0]                                    tx_commited_wr_addr;

    //-------------------------------------------------------
    // Virtex5-FX Global Clock Buffer
    //-------------------------------------------------------
    IBUFDS refclk_ibuf (.O(sys_clk_c), .I(sys_clk_p), .IB(sys_clk_n));  // 100 MHz


    //////////////////////////////////////////////////////////////////////////////////////////
    // Reception side of the NIC (START)
    //////////////////////////////////////////////////////////////////////////////////////////
    //-------------------------------------------------------
    // internal_true_dual_port_ram rx
    //-------------------------------------------------------
    rx_buffer rx_buffer_mod (
        .a(rx_wr_addr),             // I [`BF:0]
        .d(rx_wr_data),             // I [63:0]
        .dpra(rx_rd_addr),          // I [`BF:0]
        .clk(rx_wr_clk),            // I 
        .we(rx_wr_en),              // I
        .qdpo_clk(rx_rd_clk),       // I
        .qspo(rx_qspo),             // O [63:0]
        .qdpo(rx_rd_data)           // O [63:0]
        );  //see pg063

    assign rx_wr_clk = s_axis_aclk;          // 250 MHz
    assign rx_rd_clk = trn_clk_c;            // 250 MHz
    
    //-------------------------------------------------------
    // rx_tlp_trigger
    //-------------------------------------------------------
    rx_tlp_trigger rx_tlp_trigger_mod (
        .clk(s_axis_aclk),                           // I
        .reset_n(s_axis_aresetn),                                      // I
        .commited_wr_address(rx_commited_wr_address),           // I [`BF:0]
        .commited_rd_address(rx_commited_rd_address),              // I [`BF:0]
        .trigger_tlp_ack(rx_trigger_tlp_ack),                      // I
        .trigger_tlp(rx_trigger_tlp),                              // O
        .change_huge_page_ack(rx_change_huge_page_ack),            // I
        .change_huge_page(rx_change_huge_page),                    // O
        .send_last_tlp_change_huge_page(rx_send_last_tlp_change_huge_page),        // O
        .qwords_to_send(rx_qwords_to_send)                         // O [4:0]
        );

    //-------------------------------------------------------
    // rx_mac_interface
    //-------------------------------------------------------
    rx_mac_interface rx_mac_interface_mod (
        .clk(s_axis_aclk),             // I
        .reset_n(s_axis_aresetn),                     // I
        .s_axis_tdata(s_axis_tdata),                 // I [63:0]
        .s_axis_tstrb(s_axis_tstrb),     // I [7:0]
        .s_axis_tuser(s_axis_tuser),     // I [127:0]
        .s_axis_tvalid(s_axis_tvalid),     // I
        .s_axis_tlast(s_axis_tlast),       // I
        .s_axis_tready(s_axis_tready),       // O
        .wr_addr(rx_wr_addr),                  // O [`BF:0]
        .wr_data(rx_wr_data),                  // O [63:0]
        .wr_en(rx_wr_en),                      // O
        .commited_wr_address(rx_commited_wr_address),  // O [`BF:0]
        .commited_rd_address_change(rx_commited_rd_address_to_mac_change),        // I
        .commited_rd_address(rx_commited_rd_address_to_mac)    // I [`BF:0]
        );

    //////////////////////////////////////////////////////////////////////////////////////////
    // Reception side of the NIC (END)
    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////
    // Transmition side of the NIC (START)
    //////////////////////////////////////////////////////////////////////////////////////////
    //-------------------------------------------------------
    // internal_true_dual_port_ram tx
    //-------------------------------------------------------
    tx_buffer tx_buffer_mod (
        .a(tx_wr_addr),                // I [`BF:0]
        .d(tx_wr_data),                // I [63:0]
        .dpra(tx_rd_addr),             // I [`BF:0]
        .clk(tx_wr_clk),               // I 
        .we(tx_wr_en),                 // I
        .qdpo_clk(tx_rd_clk),          // I
        .spo(tx_qspo),                // O [63:0]
        .dpo(tx_rd_data)              // O [63:0]
        );  //see pg063

    assign tx_rd_clk = xaui_clk_156_25_out;  //156.25 MHz
    assign tx_wr_clk = trn_clk_c;            // 250 MHz

    //-------------------------------------------------------
    // tx_mac_interface
    //-------------------------------------------------------
    tx_mac_interface tx_mac_interface_mod (
        .clk(xaui_clk_156_25_out),                       // I
        .reset_n(reset_n),                     // I
        .tx_underrun(mac_tx_underrun),         // O
        .tx_data(mac_tx_data),                 // O [63:0]
        .tx_data_valid(mac_tx_data_valid),     // O [7:0]
        .tx_start(mac_tx_start),               // O
        .tx_ack(mac_tx_ack),                   // I
        .rd_addr(tx_rd_addr),                  // O [`BF:0]
        .rd_data(tx_rd_data),                  // I [63:0]
        .commited_rd_addr(tx_commited_rd_addr),  // O [`BF:0]
        .commited_rd_addr_change(tx_commited_rd_addr_change),  // O
        .commited_wr_addr_change(tx_commited_wr_addr_change),   // I
        .commited_wr_addr(tx_commited_wr_addr)  // I [`BF:0]
        );
    //////////////////////////////////////////////////////////////////////////////////////////
    // Transmition side of the NIC (END)
    //////////////////////////////////////////////////////////////////////////////////////////


    //-------------------------------------------------------
    // Endpoint Implementation Application
    //-------------------------------------------------------
    pci_exp_64b_app app (
        //
        // Transaction ( TRN ) Interface
        //

        .trn_clk( trn_clk_c ),                   // I
        .trn_reset_n( trn_reset_n_c ),           // I
        .trn_lnk_up_n( trn_lnk_up_n_c ),         // I

        // Tx Local-Link

        .trn_td( trn_td_c ),                     // O [63/31:0]
        .trn_trem_n( trn_trem_n_c ),             // O [7:0]
        .trn_tsof_n( trn_tsof_n_c ),             // O
        .trn_teof_n( trn_teof_n_c ),             // O
        .trn_tsrc_rdy_n( trn_tsrc_rdy_n_c ),     // O
        .trn_tsrc_dsc_n( trn_tsrc_dsc_n_c ),     // O
        .trn_tdst_rdy_n( trn_tdst_rdy_n_c ),     // I
        .trn_tdst_dsc_n( trn_tdst_dsc_n_c ),     // I
        .trn_terrfwd_n( trn_terrfwd_n_c ),       // O
        .trn_tbuf_av( trn_tbuf_av_c ),           // I [4/3:0]

        //-------------------------------------------------------
        // To rx_tlp_trigger
        //-------------------------------------------------------
        .rx_trigger_tlp_ack(rx_trigger_tlp_ack),                  // O
        .rx_trigger_tlp(rx_trigger_tlp),                          // I
        .rx_change_huge_page_ack(rx_change_huge_page_ack),        // O
        .rx_change_huge_page(rx_change_huge_page),                // I
        .rx_send_last_tlp_change_huge_page(rx_send_last_tlp_change_huge_page),        // I
        .rx_commited_rd_address(rx_commited_rd_address),          // O [`BF:0]
        .rx_qwords_to_send(rx_qwords_to_send),                    // I [4:0]
        
        //-------------------------------------------------------
        // To rx_mac_interface
        //-------------------------------------------------------
        .rx_commited_rd_address_to_mac_change(rx_commited_rd_address_to_mac_change),                    // O
        .rx_commited_rd_address_to_mac(rx_commited_rd_address_to_mac),                // O [`BF:0]

        //-------------------------------------------------------
        // To mac_host_configuration_interface
        //-------------------------------------------------------
        .host_clk(clk_50_Mhz_for_xaui),                     // I 
        .host_reset_n(dcm_for_xaui_locked_out),             // I
        .host_opcode(mac_host_opcode),                      // O [1:0] 
        .host_addr(mac_host_addr),                          // O [9:0] 
        .host_wr_data(mac_host_wr_data),                    // O [31:0] 
        .host_rd_data(mac_host_rd_data),                    // I [31:0] 
        .host_miim_sel(mac_host_miim_sel),                  // O 
        .host_req(mac_host_req),                            // O 
        .host_miim_rdy(mac_host_miim_rdy),                  // I 
        
        //-------------------------------------------------------
        // To internal_true_dual_port_ram RX
        //-------------------------------------------------------
        .rx_rd_addr(rx_rd_addr),                       // O [`BF:0]
        .rx_rd_data(rx_rd_data),                       // I [63:0]

        //-------------------------------------------------------
        // To internal_true_dual_port_ram TX
        //-------------------------------------------------------
        .tx_wr_addr(tx_wr_addr),                            // O [`BF:0]
        .tx_wr_data(tx_wr_data),                            // O [63:0]
        .tx_wr_en(tx_wr_en),                                // O

        //-------------------------------------------------------
        // To tx_mac_interface
        //-------------------------------------------------------
        .tx_commited_rd_addr(tx_commited_rd_addr),    // I [`BF:0]
        .tx_commited_rd_addr_change(tx_commited_rd_addr_change),    // I 
        .tx_commited_wr_addr_change(tx_commited_wr_addr_change),            // O 
        .tx_commited_wr_addr(tx_commited_wr_addr),          // O [`BF:0]

        // Rx Local-Link

        .trn_rd( trn_rd_c ),                     // I [63/31:0]
        .trn_rrem( trn_rrem_n_c ),               // I [7:0]
        .trn_rsof_n( trn_rsof_n_c ),             // I
        .trn_reof_n( trn_reof_n_c ),             // I
        .trn_rsrc_rdy_n( trn_rsrc_rdy_n_c ),     // I
        .trn_rsrc_dsc_n( trn_rsrc_dsc_n_c ),     // I
        .trn_rdst_rdy_n( trn_rdst_rdy_n_c ),     // O
        .trn_rerrfwd_n( trn_rerrfwd_n_c ),       // I
        .trn_rnp_ok_n( trn_rnp_ok_n_c ),         // O
        .trn_rbar_hit_n( trn_rbar_hit_n_c ),     // I [6:0]
        .trn_rfc_npd_av( trn_rfc_npd_av_c ),     // I [11:0]
        .trn_rfc_nph_av( trn_rfc_nph_av_c ),     // I [7:0]
        .trn_rfc_pd_av( trn_rfc_pd_av_c ),       // I [11:0]
        .trn_rfc_ph_av( trn_rfc_ph_av_c ),       // I [7:0]
        .trn_rcpl_streaming_n( trn_rcpl_streaming_n_c ),  // O

        //
        // Host ( CFG ) Interface
        //

        .cfg_do( cfg_do_c ),                                   // I [31:0]
        .cfg_rd_wr_done_n( cfg_rd_wr_done_n_c ),               // I
        .cfg_di( cfg_di_c ),                                   // O [31:0]
        .cfg_byte_en_n( cfg_byte_en_n_c ),                     // O
        .cfg_dwaddr( cfg_dwaddr_c ),                           // O
        .cfg_wr_en_n( cfg_wr_en_n_c ),                         // O
        .cfg_rd_en_n( cfg_rd_en_n_c ),                         // O
        .cfg_err_cor_n( cfg_err_cor_n_c ),                     // O
        .cfg_err_ur_n( cfg_err_ur_n_c ),                       // O
        .cfg_err_cpl_rdy_n( cfg_err_cpl_rdy_n_c ),             // I
        .cfg_err_ecrc_n( cfg_err_ecrc_n_c ),                   // O
        .cfg_err_cpl_timeout_n( cfg_err_cpl_timeout_n_c ),     // O
        .cfg_err_cpl_abort_n( cfg_err_cpl_abort_n_c ),         // O
        .cfg_err_cpl_unexpect_n( cfg_err_cpl_unexpect_n_c ),   // O
        .cfg_err_posted_n( cfg_err_posted_n_c ),               // O
        .cfg_err_tlp_cpl_header( cfg_err_tlp_cpl_header_c ),   // O [47:0]
        .cfg_interrupt_n( cfg_interrupt_n_c ),                 // O
        .cfg_interrupt_rdy_n( cfg_interrupt_rdy_n_c ),         // I

        .cfg_interrupt_assert_n(cfg_interrupt_assert_n_c),     // O
        .cfg_interrupt_di(cfg_interrupt_di_c),                 // O [7:0]
        .cfg_interrupt_do(cfg_interrupt_do_c),                 // I [7:0]
        .cfg_interrupt_mmenable(cfg_interrupt_mmenable_c),     // I [2:0]
        .cfg_interrupt_msienable(cfg_interrupt_msienable_c),   // I
        .cfg_to_turnoff_n( cfg_to_turnoff_n_c ),               // I
        .cfg_pm_wake_n( cfg_pm_wake_n_c ),                     // O
        .cfg_pcie_link_state_n( cfg_pcie_link_state_n_c ),     // I [2:0]
        .cfg_trn_pending_n( cfg_trn_pending_n_c ),             // O
        .cfg_dsn( cfg_dsn_n_c),                                // O [63:0]

        .cfg_bus_number( cfg_bus_number_c ),                   // I [7:0]
        .cfg_device_number( cfg_device_number_c ),             // I [4:0]
        .cfg_function_number( cfg_function_number_c ),         // I [2:0]
        .cfg_status( cfg_status_c ),                           // I [15:0]
        .cfg_command( cfg_command_c ),                         // I [15:0]
        .cfg_dstatus( cfg_dstatus_c ),                         // I [15:0]
        .cfg_dcommand( cfg_dcommand_c ),                       // I [15:0]
        .cfg_lstatus( cfg_lstatus_c ),                         // I [15:0]
        .cfg_lcommand( cfg_lcommand_c )                        // I [15:0]
        );

    //-------------------------------------------------------
    // endpoint_blk_plus_v1_15
    //-------------------------------------------------------
    endpoint_blk_plus_v1_15 ep  (

        //
        // PCI Express Fabric Interface
        //
        .pci_exp_txp( pci_exp_txp ),             // O [7/3/0:0]
        .pci_exp_txn( pci_exp_txn ),             // O [7/3/0:0]
        .pci_exp_rxp( pci_exp_rxp ),             // O [7/3/0:0]
        .pci_exp_rxn( pci_exp_rxn ),             // O [7/3/0:0]

        //
        // System ( SYS ) Interface
        //
        .sys_clk( sys_clk_c ),                                 // I
        .sys_reset_n( sys_reset_n_c ),                         // I
        .refclkout( refclkout ),                               // O

        //
        // Transaction ( TRN ) Interface
        //

        .trn_clk( trn_clk_c ),                   // O
        .trn_reset_n( trn_reset_n_c ),           // O
        .trn_lnk_up_n( trn_lnk_up_n_c ),         // O

        // Tx Local-Link

        .trn_td( trn_td_c ),                     // I [63/31:0]
        .trn_trem_n( trn_trem_n_c ),             // I [7:0]
        .trn_tsof_n( trn_tsof_n_c ),             // I
        .trn_teof_n( trn_teof_n_c ),             // I
        .trn_tsrc_rdy_n( trn_tsrc_rdy_n_c ),     // I
        .trn_tsrc_dsc_n( trn_tsrc_dsc_n_c ),     // I
        .trn_tdst_rdy_n( trn_tdst_rdy_n_c ),     // O
        .trn_tdst_dsc_n( trn_tdst_dsc_n_c ),     // O
        .trn_terrfwd_n( trn_terrfwd_n_c ),       // I
        .trn_tbuf_av( trn_tbuf_av_c ),           // O [4/3:0]

        // Rx Local-Link

        .trn_rd( trn_rd_c ),                     // O [63/31:0]
        .trn_rrem_n( trn_rrem_n_c ),             // O [7:0]
        .trn_rsof_n( trn_rsof_n_c ),             // O
        .trn_reof_n( trn_reof_n_c ),             // O
        .trn_rsrc_rdy_n( trn_rsrc_rdy_n_c ),     // O
        .trn_rsrc_dsc_n( trn_rsrc_dsc_n_c ),     // O
        .trn_rdst_rdy_n( trn_rdst_rdy_n_c ),     // I
        .trn_rerrfwd_n( trn_rerrfwd_n_c ),       // O
        .trn_rnp_ok_n( trn_rnp_ok_n_c ),         // I
        .trn_rbar_hit_n( trn_rbar_hit_n_c ),     // O [6:0]
        .trn_rfc_nph_av( trn_rfc_nph_av_c ),     // O [11:0]
        .trn_rfc_npd_av( trn_rfc_npd_av_c ),     // O [7:0]
        .trn_rfc_ph_av( trn_rfc_ph_av_c ),       // O [11:0]
        .trn_rfc_pd_av( trn_rfc_pd_av_c ),       // O [7:0]
        .trn_rcpl_streaming_n( trn_rcpl_streaming_n_c ),       // I

        //
        // Host ( CFG ) Interface
        //

        .cfg_do( cfg_do_c ),                                    // O [31:0]
        .cfg_rd_wr_done_n( cfg_rd_wr_done_n_c ),                // O
        .cfg_di( cfg_di_c ),                                    // I [31:0]
        .cfg_byte_en_n( cfg_byte_en_n_c ),                      // I [3:0]
        .cfg_dwaddr( cfg_dwaddr_c ),                            // I [9:0]
        .cfg_wr_en_n( cfg_wr_en_n_c ),                          // I
        .cfg_rd_en_n( cfg_rd_en_n_c ),                          // I

        .cfg_err_cor_n( cfg_err_cor_n_c ),                      // I
        .cfg_err_ur_n( cfg_err_ur_n_c ),                        // I
        .cfg_err_cpl_rdy_n( cfg_err_cpl_rdy_n_c ),              // O
        .cfg_err_ecrc_n( cfg_err_ecrc_n_c ),                    // I
        .cfg_err_cpl_timeout_n( cfg_err_cpl_timeout_n_c ),      // I
        .cfg_err_cpl_abort_n( cfg_err_cpl_abort_n_c ),          // I
        .cfg_err_cpl_unexpect_n( cfg_err_cpl_unexpect_n_c ),    // I
        .cfg_err_posted_n( cfg_err_posted_n_c ),                // I
        .cfg_err_tlp_cpl_header( cfg_err_tlp_cpl_header_c ),    // I [47:0]
        .cfg_err_locked_n( 1'b1 ),                // I
        .cfg_interrupt_n( cfg_interrupt_n_c ),                  // I
        .cfg_interrupt_rdy_n( cfg_interrupt_rdy_n_c ),          // O

        .cfg_interrupt_assert_n(cfg_interrupt_assert_n_c),      // I
        .cfg_interrupt_di(cfg_interrupt_di_c),                  // I [7:0]
        .cfg_interrupt_do(cfg_interrupt_do_c),                  // O [7:0]
        .cfg_interrupt_mmenable(cfg_interrupt_mmenable_c),      // O [2:0]
        .cfg_interrupt_msienable(cfg_interrupt_msienable_c),    // O
        .cfg_to_turnoff_n( cfg_to_turnoff_n_c ),                // I
        .cfg_pm_wake_n( cfg_pm_wake_n_c ),                      // I
        .cfg_pcie_link_state_n( cfg_pcie_link_state_n_c ),      // O [2:0]
        .cfg_trn_pending_n( cfg_trn_pending_n_c ),              // I
        .cfg_bus_number( cfg_bus_number_c ),                    // O [7:0]
        .cfg_device_number( cfg_device_number_c ),              // O [4:0]
        .cfg_function_number( cfg_function_number_c ),          // O [2:0]
        .cfg_status( cfg_status_c ),                            // O [15:0]
        .cfg_command( cfg_command_c ),                          // O [15:0]
        .cfg_dstatus( cfg_dstatus_c ),                          // O [15:0]
        .cfg_dcommand( cfg_dcommand_c ),                        // O [15:0]
        .cfg_lstatus( cfg_lstatus_c ),                          // O [15:0]
        .cfg_lcommand( cfg_lcommand_c ),                        // O [15:0]
        .cfg_dsn( cfg_dsn_n_c),                                 // I [63:0]


        // The following is used for simulation only.  Setting
        // the following core input to 1 will result in a fast
        // train simulation to happen.  This bit should not be set
        // during synthesis or the core may not operate properly.
        `ifdef SIMULATION
        .fast_train_simulation_only(1'b1)
        `else
        .fast_train_simulation_only(1'b0)
        `endif
        );


endmodule // XILINX_PCI_EXP_EP
