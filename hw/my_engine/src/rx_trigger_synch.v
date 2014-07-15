//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`default_nettype none
`include "includes.v"

module rx_trigger_synch (

    input    clk_out,
    input    reset_n_clk_out,

    input    clk_in,
    input    reset_n_clk_in,

    input                     trigger_tlp_in,
    output reg                trigger_tlp_out,

    input                     trigger_tlp_ack_in,
    output reg                trigger_tlp_ack_out,

    input                     change_huge_page_in,
    output reg                change_huge_page_out,

    input                     change_huge_page_ack_in,
    output reg                change_huge_page_ack_out,

    input                     send_last_tlp_in,
    output reg                send_last_tlp_out,

    input         [4:0]       qwords_to_send_in,
    output reg    [4:0]       qwords_to_send_out
    );

    // localparam
    localparam s0  = 10'b0000000000;
    localparam s1  = 10'b0000000001;
    localparam s2  = 10'b0000000010;
    localparam s3  = 10'b0000000100;
    localparam s4  = 10'b0000001000;
    localparam s5  = 10'b0000010000;
    localparam s6  = 10'b0000100000;
    localparam s7  = 10'b0001000000;
    localparam s8  = 10'b0010000000;
    localparam s9  = 10'b0100000000;
    localparam s10 = 10'b1000000000;

    //-------------------------------------------------------
    // Local clk_in - trigger_tlp & send_last_tlp & qwords_to_send
    //-------------------------------------------------------
    reg     [9:0]    fsm_clk_in;
    reg              trigger_tlp_internal;
    reg              send_last_tlp_internal;
    reg              change_huge_page_internal;
    reg              trigger_tlp_internal_ack_reg0;
    reg              trigger_tlp_internal_ack_reg1;
    reg              send_last_tlp_internal_ack_reg0;
    reg              send_last_tlp_internal_ack_reg1;
    reg     [4:0]    qwords_to_send_internal;

    //-------------------------------------------------------
    // Local clk_out - trigger_tlp & send_last_tlp & qwords_to_send
    //-------------------------------------------------------
    reg     [9:0]    fsm_clk_out;
    reg              trigger_tlp_internal_reg0;
    reg              trigger_tlp_internal_reg1;
    reg              trigger_tlp_internal_ack;
    reg              send_last_tlp_internal_reg0;
    reg              send_last_tlp_internal_reg1;
    reg              send_last_tlp_internal_ack;
    reg     [4:0]    qwords_to_send_internal_reg0;

    ////////////////////////////////////////////////
    // clk_in - trigger_tlp & send_last_tlp & qwords_to_send
    ////////////////////////////////////////////////
    always @( posedge clk_in or negedge reset_n_clk_in ) begin

        if (!reset_n_clk_in ) begin  // reset
            trigger_tlp_ack_out <= 1'b0;
            change_huge_page_ack_out <= 1'b0;
            change_huge_page_out <= 1'b0;

            trigger_tlp_internal <= 1'b0;
            send_last_tlp_internal <= 1'b0;
            change_huge_page_internal <= 1'b0;

            trigger_tlp_internal_ack_reg0 <= 1'b0;
            trigger_tlp_internal_ack_reg1 <= 1'b0;
            send_last_tlp_internal_ack_reg0 <= 1'b0;
            send_last_tlp_internal_ack_reg1 <= 1'b0;

            fsm_clk_in <= s0;
        end
        
        else begin  // not reset

            trigger_tlp_internal_ack_reg0 <= trigger_tlp_internal_ack;
            trigger_tlp_internal_ack_reg1 <= trigger_tlp_internal_ack_reg0;

            send_last_tlp_internal_ack_reg0 <= send_last_tlp_internal_ack;
            send_last_tlp_internal_ack_reg1 <= send_last_tlp_internal_ack_reg0;

            case (fsm_clk_in)

                s0 : begin
                    if (trigger_tlp_in) begin
                        trigger_tlp_ack_out <= 1'b1;
                        qwords_to_send_internal <= qwords_to_send_in;
                        fsm_clk_in <= s1;
                    end
                    else if (send_last_tlp_in) begin
                        change_huge_page_ack_out <= 1'b1;
                        qwords_to_send_internal <= qwords_to_send_in;
                        fsm_clk_in <= s7;
                    end
                    else if (change_huge_page_in) begin
                        change_huge_page_ack_out <= 1'b1;
                        change_huge_page_out <= 1'b1;
                        fsm_clk_in <= s9;
                    end
                end

                s1 : begin
                    trigger_tlp_ack_out <= 1'b0;
                    trigger_tlp_internal <= 1'b1;
                    fsm_clk_in <= s2;
                end

                s2 : begin
                    if (trigger_tlp_internal_ack_reg1) begin
                        trigger_tlp_internal <= 1'b0;
                        fsm_clk_in <= s3;
                    end
                end

                s3 : fsm_clk_in <= s4;
                s4 : fsm_clk_in <= s5;
                s5 : fsm_clk_in <= s6;
                s6 : fsm_clk_in <= s0;

                s7 : begin
                    change_huge_page_ack_out <= 1'b0;
                    send_last_tlp_internal <= 1'b1;
                    fsm_clk_in <= s8;
                end

                s8 : begin
                    if (send_last_tlp_internal_ack_reg1) begin
                        send_last_tlp_internal <= 1'b0;
                        fsm_clk_in <= s3;
                    end
                end

                s9 : begin
                    change_huge_page_ack_out <= 1'b0;
                    if (change_huge_page_ack_in) begin
                        change_huge_page_out <= 1'b0;
                        fsm_clk_in <= s0;
                    end
                end

                default : begin 
                    fsm_clk_in <= s0;
                end

            endcase
        end     // not reset
    end  //always

    ////////////////////////////////////////////////
    // clk_out - trigger_tlp & send_last_tlp & qwords_to_send
    ////////////////////////////////////////////////
    always @( posedge clk_out or negedge reset_n_clk_out ) begin

        if (!reset_n_clk_out ) begin  // reset
            trigger_tlp_out <= 1'b0;
            send_last_tlp_out <= 1'b0;

            trigger_tlp_internal_reg0 <= 1'b0;
            trigger_tlp_internal_reg1 <= 1'b0;
            trigger_tlp_internal_ack <= 1'b0;

            send_last_tlp_internal_reg0 <= 1'b0;
            send_last_tlp_internal_reg1 <= 1'b0;
            send_last_tlp_internal_ack <= 1'b0;

            fsm_clk_out <= s0;
        end
        
        else begin  // not reset

            qwords_to_send_internal_reg0 <= qwords_to_send_internal;
            
            trigger_tlp_internal_reg0 <= trigger_tlp_internal;
            trigger_tlp_internal_reg1 <= trigger_tlp_internal_reg0;

            send_last_tlp_internal_reg0 <= send_last_tlp_internal;
            send_last_tlp_internal_reg1 <= send_last_tlp_internal_reg0;

            case (fsm_clk_out)

                s0 : begin
                    if (trigger_tlp_internal_reg1) begin
                        trigger_tlp_out <= 1'b1;
                        qwords_to_send_out <= qwords_to_send_internal_reg0;
                        fsm_clk_out <= s1;
                    end
                    else if (send_last_tlp_internal_reg1) begin
                        send_last_tlp_out <= 1'b1;
                        qwords_to_send_out <= qwords_to_send_internal_reg0;
                        fsm_clk_out <= s4;
                    end
                end

                s1 : begin
                    if (trigger_tlp_ack_in) begin
                        trigger_tlp_out <= 1'b0;
                        trigger_tlp_internal_ack <= 1'b1;
                        fsm_clk_out <= s2;
                    end
                end

                s2 : fsm_clk_out <= s3;

                s3 : begin
                    trigger_tlp_internal_ack <= 1'b0;
                    send_last_tlp_internal_ack <= 1'b0;
                    fsm_clk_out <= s0;
                end

                s4 : begin
                    if (change_huge_page_ack_in) begin
                        send_last_tlp_out <= 1'b0;
                        send_last_tlp_internal_ack <= 1'b1;
                        fsm_clk_out <= s2;
                    end
                end

                default : begin 
                    fsm_clk_out <= s0;
                end

            endcase

        end     // not reset
    end  //always

endmodule // rx_trigger_synch

//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
