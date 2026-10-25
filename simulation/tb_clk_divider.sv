`timescale 1ns/1ps
module tb_clk_divider;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst_n = 0;
    wire tick_sec, tick_ms;
    clk_divider dut(.clk(clk), .rst_n(rst_n),
                    .tick_1hz(tick_sec), .tick_1khz(tick_ms));
    integer cycle, seconds_seen = 0, ms_seen = 0;

    initial begin
        // Exercise the real 50 MHz defaults for two whole seconds. No forces.
        repeat (3) @(negedge clk);
        rst_n = 1;
        for (cycle = 1; cycle <= 100000000; cycle = cycle + 1) begin
            @(posedge clk);
            if (tick_sec !== ((cycle % 50000000) == 0))
                $fatal(1, "1Hz tick at wrong cycle %0d", cycle);
            if (tick_ms !== ((cycle % 50000) == 0))
                $fatal(1, "1kHz tick at wrong cycle %0d", cycle);
            if (tick_sec) seconds_seen = seconds_seen + 1;
            if (tick_ms) ms_seen = ms_seen + 1;
        end
        if (seconds_seen != 2 || ms_seen != 2000) $fatal(1, "Wrong tick totals");
        @(negedge clk); rst_n = 0;
        #1;
        if (tick_sec !== 0 || tick_ms !== 0) $fatal(1, "Reset did not gate ticks");
        @(negedge clk); rst_n = 1;
        @(posedge clk);
        if (tick_sec !== 0 || tick_ms !== 0) $fatal(1, "Reset did not restart divider");
        $display("PASS tb_clk_divider: 100000000 real-default cycles, 2 seconds, 2000 ms ticks");
        $finish;
    end
    initial begin
        #2000000100;
        $fatal(1, "Divider timeout");
    end
endmodule
