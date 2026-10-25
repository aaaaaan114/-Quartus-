`timescale 1ns/1ps
`default_nettype none

module alarm_ctrl(
    input  wire clk,
    input  wire rst_n,
    input  wire set_mode,
    input  wire inc_hour,
    input  wire inc_min,
    input  wire alarm_en,
    input  wire [7:0] cur_hour,
    input  wire [7:0] cur_min,
    output reg  [7:0] alarm_hour,
    output reg  [7:0] alarm_min,
    output wire alarm_trig
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alarm_hour <= 8'h00;
            alarm_min <= 8'h00;
        end else if (set_mode) begin
            if (inc_hour) alarm_hour <= next_24(alarm_hour);
            if (inc_min) alarm_min <= next_60(alarm_min);
        end
    end

    // Preserve the original level-match alarm: it rings for the matching minute.
    assign alarm_trig = rst_n && alarm_en && !set_mode &&
                        (cur_hour == alarm_hour) && (cur_min == alarm_min);
endmodule

`default_nettype wire
