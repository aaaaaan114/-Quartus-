`timescale 1ns/1ps
`default_nettype none

// These are clock enables, never clocks. Every register uses the board clock.
module clk_divider #(
    parameter integer CLK_HZ = 50000000
)(
    input  wire clk,
    input  wire rst_n,
    output wire tick_1hz,
    output wire tick_1khz
);
    localparam integer MS_CYCLES = CLK_HZ / 1000;
    localparam integer SEC_WIDTH = (CLK_HZ > 1) ? $clog2(CLK_HZ) : 1;
    localparam integer MS_WIDTH = (MS_CYCLES > 1) ? $clog2(MS_CYCLES) : 1;
    reg [SEC_WIDTH-1:0] sec_count;
    reg [MS_WIDTH-1:0] ms_count;

    assign tick_1hz = rst_n && (sec_count == CLK_HZ - 1);
    assign tick_1khz = rst_n && (ms_count == MS_CYCLES - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_count <= 0;
            ms_count <= 0;
        end else begin
            if (tick_1hz) sec_count <= 0;
            else sec_count <= sec_count + 1'b1;
            if (tick_1khz) ms_count <= 0;
            else ms_count <= ms_count + 1'b1;
        end
    end
endmodule

`default_nettype wire
