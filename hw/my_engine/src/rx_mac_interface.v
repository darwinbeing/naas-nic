//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`include "includes.v"

module rx_mac_interface (

    input    clk,
    input    reset_n,

    // MAC Rx
    input    [63:0]      s_axis_tdata,
    input    [7:0]       s_axis_tstrb,
    input    [127:0]     s_axis_tuser,
    input                s_axis_tvalid,
    input                s_axis_tlast,
    output reg           s_axis_tready,

    // Internal memory driver
    output reg    [`BF:0]     wr_addr,
    output reg    [63:0]      wr_data,
    output reg                wr_en,
    
    // Internal logic
    output reg    [`BF:0]     commited_wr_address,
    input         [`BF:0]     commited_rd_address

    );

    // localparam
    localparam s0 = 8'b00000000;
    localparam s1 = 8'b00000001;
    localparam s2 = 8'b00000010;
    localparam s3 = 8'b00000100;

    //-------------------------------------------------------
    // Local ethernet frame reception and memory write
    //-------------------------------------------------------
    reg     [7:0]     state;
    reg     [15:0]    byte_counter;
    reg     [`BF:0]   aux_wr_addr;
    reg     [`BF:0]   diff;
    (* KEEP = "TRUE" *)reg     [31:0]   dropped_frames_counter;
    reg     [7:0]     src_port;
    reg     [7:0]     des_port;
    reg     [63:0]    timestamp;
    
    //-------------------------------------------------------
    // Local ts_sec-and-ts_nsec-generation
    //-------------------------------------------------------
    reg     [31:0]   ts_sec;
    reg     [31:0]   ts_nsec;
    reg     [27:0]   free_running;

    ////////////////////////////////////////////////
    // ts_sec-and-ts_nsec-generation
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin

        if (!reset_n ) begin  // reset
            ts_sec <= 32'b0;
            ts_nsec <= 32'b0;
            free_running <= 28'b0;
        end
        
        else begin  // not reset
            free_running <= free_running +1;
            ts_nsec <= ts_nsec + 6;
            if (free_running == 28'd156250000) begin
              free_running <= 28'b0;
              ts_sec <= ts_sec +1;
              ts_nsec <= 32'b0;
            end

        end     // not reset
    end  //always

    ////////////////////////////////////////////////
    // ethernet frame reception and memory write
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin

        if (!reset_n ) begin  // reset
            commited_wr_address <= 'b0;
            aux_wr_addr <= 'h2;
            dropped_frames_counter <= 'b0;
            wr_en <= 1'b1;
            s_axis_tready <= 1'b1;
            state <= s0;
        end
        
        else begin  // not reset
            
            diff <= aux_wr_addr + (~commited_rd_address) +1;
            wr_en <= 1'b1;
            
            case (state)

                s0 : begin
                    byte_counter <= s_axis_tuser[15:0];
                    src_port <= s_axis_tuser[23:16];
                    des_port <= s_axis_tuser[31:24];
                    timestamp <= s_axis_tuser[95:32];
                    
                    wr_data <= s_axis_tdata;
                    wr_addr <= aux_wr_addr;
                    if (s_axis_tvalid) begin
                        aux_wr_addr <= aux_wr_addr +1;
                        state <= s1;
                    end
                end

                s1 : begin
                    wr_data <= s_axis_tdata;
                    wr_addr <= aux_wr_addr;
                    if (s_axis_tvalid) begin
                        aux_wr_addr <= aux_wr_addr +1;
                    end

                    if (diff[`BF:0] > `MAX_DIFF) begin         // buffer is more than 90%
                        state <= s4;
                    end
                    else if (s_axis_tlast && s_axis_tvalid) begin
                        s_axis_tready <= 1'b0;
                        state <= s2;
                    end
                end

                s2 : begin
                    wr_data <= {16'b0, byte_counter, 8'b0, des_port, 8'b0, src_port};
                    wr_addr <= commited_wr_address;

                    commited_wr_address <= aux_wr_addr;                      // commit the packet
                    aux_wr_addr <= aux_wr_addr +1;
                    state <= s3;
                end

                s3 : begin
                    wr_data <= timestamp;
                    wr_addr <= wr_addr +1;
                    aux_wr_addr <= aux_wr_addr +1;
                    s_axis_tready <= 1'b1;
                    state <= s0;
                end
                
                s4 : begin                                  // drop current frame
                    aux_wr_addr <= commited_wr_address + 'h2;
                    if (s_axis_tlast && s_axis_tvalid) begin
                        dropped_frames_counter <= dropped_frames_counter +1; 
                        state <= s0;
                    end
                end

                default : begin 
                    state <= s0;
                end

            endcase
        end     // not reset
    end  //always
   

endmodule // rx_mac_interface

//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
