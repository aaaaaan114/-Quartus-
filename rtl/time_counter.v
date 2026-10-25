`timescale 1ns/1ps
`default_nettype none

module time_counter(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1hz,
    input  wire set_mode,
    input  wire inc_hour,
    input  wire inc_min,
    output reg [7:0] sec,
    output reg [7:0] min,
    output reg [7:0] hour,
    output wire hour_rollover
);
    function [7:0] next_60;
        input [7:0] value;
        begin
            if (value == 8'h59) next_60 = 8'h00;
            else if (value[3:0] == 4'd9) next_60 = {value[7:4] + 4'd1, 4'd0};
            else next_60 = value + 8'd1;
        end
    endfunction

    function [7:0] next_24;
        input [7:0] value;
        begin
            if (value == 8'h23) next_24 = 8'h00;
            else if (value[3:0] == 4'd9) next_24 = {value[7:4] + 4'd1, 4'd0};
            else next_24 = value + 8'd1;
        end
    endfunction

    // This event is consumed on exactly the edge that advances to xx:00:00.
    // Setting the clock and resetting it can never generate this event.
    assign hour_rollover = rst_n && tick_1hz && !set_mode &&
                           (min == 8'h59) && (sec == 8'h59);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec <= 8'h00;
            min <= 8'h00;
            hour <= 8'h00;
        end else if (set_mode) begin
            // A button event is processed immediately, independently of tick_1hz.
            if (inc_hour) hour <= next_24(hour);
            if (inc_min) min <= next_60(min);
        end else if (tick_1hz) begin
            sec <= next_60(sec);
            if (sec == 8'h59) begin
                min <= next_60(min);
                if (min == 8'h59) hour <= next_24(hour);
            end
        end
    end
endmodule

`default_nettype wire
