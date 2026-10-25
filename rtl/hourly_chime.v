`timescale 1ns/1ps
`default_nettype none

module hourly_chime #(
    parameter integer CLK_HZ = 50000000,
    parameter integer CHIME_SECONDS = 2
)(
    input  wire clk,
    input  wire rst_n,
    input  wire hour_rollover,
    output reg  chime_en
);
    localparam integer DURATION = CLK_HZ * CHIME_SECONDS;
    localparam integer COUNT_WIDTH = (DURATION > 1) ? $clog2(DURATION) : 1;
    reg [COUNT_WIDTH-1:0] remaining;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remaining <= 0;
            chime_en <= 1'b0;
        end else if (hour_rollover) begin
            remaining <= DURATION - 1;
            chime_en <= 1'b1;
        end else if (remaining != 0) begin
            remaining <= remaining - 1'b1;
        end else chime_en <= 1'b0;
    end
endmodule

`default_nettype wire
