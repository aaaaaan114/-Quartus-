`timescale 1ns/1ps
`default_nettype none

module buzzer_driver #(
    parameter integer CLK_HZ = 50000000,
    parameter integer TONE_HZ = 2000,
    parameter integer ACTIVE_BUZZER = 0,
    parameter integer BUZZER_ACTIVE_LOW = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire sound_en,
    output wire buzzer
);
    localparam integer HALF_PERIOD = CLK_HZ / (2 * TONE_HZ);
    localparam integer COUNT_WIDTH = (HALF_PERIOD > 1) ? $clog2(HALF_PERIOD) : 1;
    reg [COUNT_WIDTH-1:0] tone_count;
    reg tone;
    wire drive_on;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_count <= 0;
            tone <= 1'b0;
        end else if (!sound_en) begin
            tone_count <= 0;
            tone <= 1'b0;
        end else if (tone_count == HALF_PERIOD - 1) begin
            tone_count <= 0;
            tone <= !tone;
        end else tone_count <= tone_count + 1'b1;
    end

    assign drive_on = rst_n && sound_en && ((ACTIVE_BUZZER != 0) || tone);
    assign buzzer = (BUZZER_ACTIVE_LOW != 0) ? !drive_on : drive_on;
endmodule

`default_nettype wire
