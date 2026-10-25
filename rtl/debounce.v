`timescale 1ns/1ps
`default_nettype none

module debounce #(
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1khz,
    input  wire key_in,
    output reg  key_pulse
);
    localparam integer COUNT_WIDTH = (DEBOUNCE_MS > 1) ? $clog2(DEBOUNCE_MS) : 1;
    reg [1:0] sync;
    reg [COUNT_WIDTH-1:0] count;
    reg key_stable;

    // Synchronize on the full-rate clock, then sample the synchronized level.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sync <= 2'b11;
        else sync <= {sync[0], key_in};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            key_stable <= 1'b1;
            key_pulse <= 1'b0;
        end else begin
            // The pulse lasts one board-clock cycle, even between samples.
            key_pulse <= 1'b0;
            if (sync[1] == key_stable) begin
                count <= 0;
            end else if (tick_1khz) begin
                if (count == DEBOUNCE_MS - 1) begin
                    key_stable <= sync[1];
                    key_pulse <= !sync[1];
                    count <= 0;
                end else count <= count + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
