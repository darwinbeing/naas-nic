//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
`include "includes.v"

module rx_tlp_trigger (

    input    clk,
    input    reset_n,

    // Internal logic
    input      [`BF:0]      commited_wr_address,
    output reg              trigger_tlp,
    input                   trigger_tlp_ack,
    output reg              change_huge_page,
    input                   change_huge_page_ack,
    output reg              send_last_tlp,
    output reg [4:0]        qwords_to_send
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
    // Local timeout-generation
    //-------------------------------------------------------
    reg     [15:0]   free_running;
    reg              timeout;   

    //-------------------------------------------------------
    // Local trigger-logic
    //-------------------------------------------------------
    reg     [7:0]        trigger_fsm;
    reg     [`BF:0]      diff;
    reg     [`BF:0]      diff_reg;
    reg     [`BF:0]      commited_rd_address;
    reg     [`BF:0]      look_ahead_commited_rd_address;
    reg                  huge_page_dirty;
    reg     [18:0]       huge_buffer_qword_counter;
    reg     [18:0]       aux_huge_buffer_qword_counter;
    reg     [18:0]       look_ahead_huge_buffer_qword_counter;
    reg     [3:0]        qwords_remaining;
    reg     [4:0]        number_of_tlp_sent;
    reg     [4:0]        look_ahead_number_of_tlp_sent;
    reg     [4:0]        number_of_tlp_to_send;

    ////////////////////////////////////////////////
    // timeout logic
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin
        if (!reset_n ) begin  // reset
            timeout <= 1'b0;
            free_running <= 'b0;
        end
        
        else begin  // not reset

            if (trigger_fsm == s0) begin
                free_running <= free_running +1;
                timeout <= 1'b0;
                if (free_running == 'hFFFF) begin
                    timeout <= 1'b1;
                end
            end
            else begin
                timeout <= 1'b0;
                free_running <= 'b0;
            end

        end     // not reset
    end  //always

    ////////////////////////////////////////////////
    // trigger-logic
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin
        
        if (!reset_n ) begin  // reset
            trigger_tlp <= 1'b0;
            change_huge_page <= 1'b0;
            send_last_tlp <= 1'b0;

            diff <= 'b0;
            commited_rd_address <= 'b0;
            huge_buffer_qword_counter <= 'h10;
            huge_page_dirty <= 1'b0;
            qwords_remaining <= 'b0;

            trigger_fsm <= s0;
        end

        else begin  // not reset

            diff <= commited_wr_address + (~commited_rd_address) +1;
            
            case (trigger_fsm)

                s0 : begin
                    look_ahead_huge_buffer_qword_counter <= huge_buffer_qword_counter + diff;
                    diff_reg <= diff;
                    number_of_tlp_to_send <= diff[`BF:4];

                    if (diff >= 'h10) begin
                        trigger_fsm <= s1;
                    end
                    else if ( (huge_page_dirty) && (timeout) ) begin
                        trigger_fsm <= ;
                    end
                    else if ( (diff) && (timeout) ) begin
                        trigger_fsm <= ;
                    end
                end

                s1 : begin
                    huge_page_dirty <= 1'b1;
                    number_of_tlp_sent <= 'b0;
                    if (look_ahead_huge_buffer_qword_counter[18]) begin       // 2MB
                        if (!qwords_remaining) begin
                            change_huge_page <= 1'b1;
                            trigger_fsm <= s5;
                        end
                        else begin
                            qwords_to_send <= {1'b0, qwords_remaining};
                            send_last_tlp <= 1'b1;
                            trigger_fsm <= s5;
                        end
                    end
                    else begin
                        qwords_to_send <= 'h10;
                        trigger_tlp <= 1'b1;
                        qwords_remaining <= diff_reg[3:0];
                        trigger_fsm <= s2;
                    end
                end

                s2 : begin
                    look_ahead_commited_rd_address <= commited_rd_address + qwords_to_send;
                    look_ahead_number_of_tlp_sent <= number_of_tlp_sent +1;
                    aux_huge_buffer_qword_counter <= huge_buffer_qword_counter + qwords_to_send;
                    if (trigger_tlp_ack) begin
                        trigger_tlp <= 1'b0;
                        trigger_fsm <= s3;
                    end
                end

                s3 : begin
                    commited_rd_address <= look_ahead_commited_rd_address;
                    number_of_tlp_sent <= look_ahead_number_of_tlp_sent;
                    huge_buffer_qword_counter <= aux_huge_buffer_qword_counter;
                    trigger_fsm <= s4;
                end

                s4 : begin
                    if (number_of_tlp_sent < number_of_tlp_to_send) begin
                        trigger_tlp <= 1'b1;
                        trigger_fsm <= s2;
                    end
                    else begin
                        trigger_fsm <= s0;
                    end
                end

                s5 : begin
                    look_ahead_commited_rd_address <= commited_rd_address + qwords_to_send;
                    if (change_huge_page_ack) begin
                        change_huge_page <= 1'b1;
                        send_last_tlp <= 1'b0;
                        trigger_fsm <= s6;
                    end
                end

                s6 : begin
                    commited_rd_address <= look_ahead_commited_rd_address;
                    huge_buffer_qword_counter <= 'h10;
                    qwords_remaining <= 'b0;
                    huge_page_dirty <= 1'b0;
                    trigger_fsm <= s7;
                end

                s7 : begin
                    trigger_fsm <= s0;
                end
                
                default : begin
                    trigger_fsm <= s0;
                end

            endcase

        end     // not reset
    end  //always

endmodule // rx_tlp_trigger

//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
