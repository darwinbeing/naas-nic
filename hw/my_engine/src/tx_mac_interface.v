//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`default_nettype none
`include "includes.v"

module tx_mac_interface (

    input    clk,
    input    reset_n,

    // MAC Tx
    output reg    [63:0]      m_axis_tdata,
    output reg    [7:0]       m_axis_tstrb,
    output reg    [127:0]     m_axis_tuser,
    output reg                m_axis_tvalid,
    output reg                m_axis_tlast,
    input                     m_axis_tready,

    // Internal memory driver
    output reg    [`BF:0]     rd_addr,
    input         [63:0]      rd_data,
    
    
    // Internal logic
    output reg    [`BF:0]     commited_rd_addr,
    input         [`BF:0]     commited_wr_addr

    );

    // localparam
    localparam s0 = 8'b00000000;
    localparam s1 = 8'b00000001;
    localparam s2 = 8'b00000010;
    localparam s3 = 8'b00000100;
    localparam s4 = 8'b00001000;
    localparam s5 = 8'b00010000;
    localparam s6 = 8'b00100000;
    localparam s7 = 8'b01000000;
    localparam s8 = 8'b10000000;

    //-------------------------------------------------------
    // Local trigger_eth_frame
    //-------------------------------------------------------
    reg     [7:0]     trigger_frame_fsm;
    reg     [15:0]    internal_pkt_len;
    reg     [9:0]     qwords_in_eth;
    reg     [`BF:0]   diff;
    reg               trigger_tx_frame;
    reg     [7:0]     last_tstrb;

    //-------------------------------------------------------
    // Local ethernet frame transmition and memory read
    //-------------------------------------------------------
    reg     [7:0]     tx_frame_fsm;
    reg     [15:0]    pkt_len;
    reg     [7:0]     src_port;
    reg     [7:0]     des_port;
    reg     [9:0]     qwords_sent;
    reg               synch;
    reg     [`BF:0]   rd_addr_prev0;

    ////////////////////////////////////////////////
    // trigger_eth_frame
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin

        if (!reset_n ) begin  // reset
            take_your_chances <= 1'b0;
            diff <= 'b0;
            trigger_tx_frame <= 1'b0;
            trigger_frame_fsm <= s0;
        end
        
        else begin  // not reset

            diff <= commited_wr_addr + (~rd_addr) +1;
            
            case (trigger_frame_fsm)

                s0 : begin
                    internal_pkt_len <= rd_data[47:32];
                    if (diff) begin
                        qwords_in_eth <= rd_data[44:35];
                        trigger_frame_fsm <= s1;
                    end
                end

                s1 : begin
                    if (internal_pkt_len[2:0]) begin
                        qwords_in_eth <= internal_pkt_len[12:3] +1;
                    end

                    case (internal_pkt_len[2:0])                    // my deco
                        3'b000 : begin
                            last_tstrb <= 8'b11111111;
                        end
                        3'b001 : begin
                            last_tstrb <= 8'b00000001;
                        end
                        3'b010 : begin
                            last_tstrb <= 8'b00000011;
                        end
                        3'b011 : begin
                            last_tstrb <= 8'b00000111;
                        end
                        3'b100 : begin
                            last_tstrb <= 8'b00001111;
                        end
                        3'b101 : begin
                            last_tstrb <= 8'b00011111;
                        end
                        3'b110 : begin
                            last_tstrb <= 8'b00111111;
                        end
                        3'b111 : begin
                            last_tstrb <= 8'b01111111;
                        end
                    endcase

                    if (!diff) begin
                        trigger_frame_fsm <= s0;
                    end
                    else if (diff >= qwords_in_eth) begin
                        trigger_tx_frame <= 1'b1;
                        trigger_frame_fsm <= s2;
                    end
                end

                s2 : begin
                    trigger_tx_frame <= 1'b0;
                    internal_pkt_len <= rd_data[47:32];
                    if (synch) begin
                        qwords_in_eth <= rd_data[44:35];
                        trigger_frame_fsm <= s1;
                    end
                end

                default : begin 
                    trigger_frame_fsm <= s0;
                end

            endcase
        end     // not reset
    end  //always

    ////////////////////////////////////////////////
    // ethernet frame transmition and memory read
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin

        if (!reset_n ) begin  // reset
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            rd_addr <= 'b0;
            commited_rd_addr <= 'b0;
            synch <= 1'b0;
            tx_frame_fsm <= s0;
        end
        
        else begin  // not reset
            
            synch <= 1'b0;
            rd_addr_prev0 <= rd_addr;
            m_axis_tlast <= 1'b0;

            case (tx_frame_fsm)

                s0: begin
                    pkt_len <= rd_data[47:32];
                    src_port <= rd_data[7:0];
                    des_port <= rd_data[23:16];

                    if (trigger_tx_frame) begin
                        rd_addr <= rd_addr +1;
                        tx_frame_fsm <= s1;
                    end
                end

                s1 : begin
                    rd_addr <= rd_addr +1;
                    tx_frame_fsm <= s2;
                end

                s2 : begin
                    m_axis_tdata <= rd_data;
                    m_axis_tstrb <= 'hFF;
                    m_axis_tuser[31:0] <= {des_port, src_port, pkt_len};
                    m_axis_tvalid <= 1'b1;
                    rd_addr <= rd_addr +1;
                    qwords_sent <= 'h001;
                    tx_frame_fsm <= s3;
                end

                s3 : begin
                    if (m_axis_tready) begin
                        rd_addr <= rd_addr +1;
                        m_axis_tdata <= rd_data;
                        qwords_sent <= qwords_sent +1;
                        if (qwords_in_eth == qwords_sent) begin
                            synch <= 1'b1;
                            m_axis_tstrb <= last_tstrb;
                            m_axis_tlast <= 1'b1;
                            tx_frame_fsm <= s7;
                        end
                    end
                    else begin
                        rd_addr <= rd_addr_prev0;
                        tx_frame_fsm <= s4;
                    end
                end

                s4 : begin
                    if (m_axis_tready) begin
                        rd_addr <= rd_addr +1;
                        qwords_sent <= qwords_sent +1;
                        m_axis_tvalid <= 1'b0;
                        tx_frame_fsm <= s5;
                    end
                end

                s5 : begin
                    rd_addr <= rd_addr +1;
                    m_axis_tdata <= rd_data;
                    m_axis_tvalid <= 1'b1;
                    qwords_sent <= qwords_sent +1;
                    m_axis_tstrb <= 'hFF;
                    if (qwords_in_eth == qwords_sent) begin
                        synch <= 1'b1;
                        m_axis_tstrb <= last_tstrb;
                        m_axis_tlast <= 1'b1;
                        tx_frame_fsm <= s7;
                    end
                    else begin
                        tx_frame_fsm <= s3;
                    end
                end

                s7 : begin
                    rd_addr <= rd_addr_prev0;
                    commited_rd_addr <= rd_addr_prev0;
                    tx_frame_fsm <= s0;
                end

                default : begin 
                    tx_frame_fsm <= s0;
                end

            endcase

        end     // not reset
    end  //always

endmodule // tx_mac_interface

//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
