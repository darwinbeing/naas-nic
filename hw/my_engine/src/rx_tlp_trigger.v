//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
`include "includes.v"

module rx_tlp_trigger (

    input    clk,
    input    reset_n,

    // Internal logic
    input      [`BF:0]      commited_wr_address,     // this domain driven
    input      [`BF:0]      commited_rd_address,     // this domain driven
    
    output reg              trigger_tlp,
    input                   trigger_tlp_ack,         // other domain driven

    output reg              change_huge_page,
    input                   change_huge_page_ack,    // other domain driven
    
    output reg              send_last_tlp_change_huge_page,
    output reg [4:0]        qwords_to_send           // must be valid one cycle before "trigger_tlp" or "send_last_tlp_change_huge_page"
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
    reg     [7:0]        main_fsm;
    reg     [`BF:0]      diff;
    reg     [`BF:0]      last_diff;
    reg     [3:0]        qwords_remaining;
    reg     [18:0]       huge_buffer_qword_counter;
    reg     [18:0]       aux_huge_buffer_qword_counter;
    reg     [18:0]       look_ahead_huge_buffer_qword_counter;
    reg     [4:0]        number_of_tlp_to_send;
    reg     [4:0]        number_of_tlp_sent;
    reg                  huge_page_dirty;
    reg     [2:0]        wait_counter;

    //-------------------------------------------------------
    // Local signal synch
    //-------------------------------------------------------
    reg              trigger_tlp_ack_reg0;
    reg              trigger_tlp_ack_reg1;
    reg              change_huge_page_ack_reg0;
    reg              change_huge_page_ack_reg1;

    ////////////////////////////////////////////////
    // signal synch
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin

        if (!reset_n ) begin  // reset
            trigger_tlp_ack_reg0 <= 1'b0;
            trigger_tlp_ack_reg1 <= 1'b0;
            change_huge_page_ack_reg0 <= 1'b0;
            change_huge_page_ack_reg1 <= 1'b0;
        end
        
        else begin  // not reset
            trigger_tlp_ack_reg0 <= trigger_tlp_ack;
            trigger_tlp_ack_reg1 <= trigger_tlp_ack_reg0;

            change_huge_page_ack_reg0 <= change_huge_page_ack;
            change_huge_page_ack_reg1 <= change_huge_page_ack_reg0;

        end     // not reset
    end  //always

    ////////////////////////////////////////////////
    // timeout logic
    ////////////////////////////////////////////////
    always @( posedge clk or negedge reset_n ) begin
        if (!reset_n ) begin  // reset
            timeout <= 1'b0;
            free_running <= 'b0;
        end
        
        else begin  // not reset

            if (main_fsm == s0) begin
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
            send_last_tlp_change_huge_page <= 1'b0;

            diff <= 'b0;
            last_diff <= 'b0;
            qwords_remaining <= 'b0;
            huge_page_dirty <= 1'b0;

            huge_buffer_qword_counter <= 'h10;

            number_of_tlp_to_send <= 'b0;
            number_of_tlp_sent <= 'b0;

            main_fsm <= s0;
        end

        else begin  // not reset
            
            diff <= commited_wr_address + (~commited_rd_address) +1;

            case (main_fsm)
                
                s0 : begin

                    last_diff <= diff;
                    look_ahead_huge_buffer_qword_counter <= huge_buffer_qword_counter + diff;
                    number_of_tlp_to_send <= diff[`BF:4];
                    qwords_to_send <= 'h10;

                    if (diff >= 'h10) begin
                        main_fsm <= s1;
                    end
                    else if ( (huge_page_dirty) && (timeout) ) begin
                        main_fsm <= s6;
                    end
                    else if ( (diff) && (timeout) ) begin
                        qwords_to_send <= {1'b0, diff[3:0]};
                        main_fsm <= s4;
                    end
                end

                s1 : begin
                    huge_page_dirty <= 1'b1;

                    if ( look_ahead_huge_buffer_qword_counter[18] ) begin       // 2MB
                        if (qwords_remaining == 4'b0) begin
                            change_huge_page <= 1'b1;
                            main_fsm <= s5;
                        end
                        else begin
                            qwords_to_send <= {1'b0, qwords_remaining};
                            main_fsm <= s4;
                        end
                    end
                    else begin
                        qwords_remaining <= last_diff[3:0];
                        trigger_tlp <= 1'b1;
                        number_of_tlp_sent <= 'b0;
                        main_fsm <= s2;
                    end
                end

                s2 : begin
                    aux_huge_buffer_qword_counter <= huge_buffer_qword_counter + 'h10;
                    if (trigger_tlp_ack_reg1) begin
                        trigger_tlp <= 1'b0;
                        number_of_tlp_sent <= number_of_tlp_sent +1;
                        main_fsm <= s3;
                    end
                end

                s3 : begin
                    huge_buffer_qword_counter <= aux_huge_buffer_qword_counter;
                    if (number_of_tlp_sent < number_of_tlp_to_send) begin
                        trigger_tlp <= 1'b1;
                        main_fsm <= s2;
                    end
                    else begin
                        main_fsm <= s7;
                    end
                end

                s4 : begin
                    send_last_tlp_change_huge_page <= 1'b1;
                    main_fsm <= s5;
                end

                s5 : begin
                    huge_buffer_qword_counter <= 19'h10;        // the initial offset of a huge page is 32 DWs which are reserved
                    qwords_remaining <= 4'b0;
                    huge_page_dirty <= 1'b0;
                    if (change_huge_page_ack_reg1) begin
                        send_last_tlp_change_huge_page <= 1'b0;
                        change_huge_page <= 1'b0;
                        main_fsm <= s0;
                    end
                end

                s6 : begin
                    if (qwords_remaining == 4'b0) begin
                        change_huge_page <= 1'b1;
                        main_fsm <= s5;
                    end
                    else begin
                        qwords_to_send <= {1'b0, qwords_remaining};
                        main_fsm <= s4;
                    end
                end

                s7 : begin  // wait synch
                    wait_counter <= wait_counter +1;
                    if (wait_counter == 'b011) begin
                        main_fsm <= s0;
                    end
                end

                default : begin
                    main_fsm <= s0;
                end

            endcase

        end     // not reset
    end  //always

endmodule // rx_tlp_trigger

//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
