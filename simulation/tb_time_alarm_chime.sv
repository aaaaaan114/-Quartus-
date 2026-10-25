`timescale 1ns/1ps
module tb_time_alarm_chime;
    reg clk = 0;
    always #5 clk = !clk;
    reg rst_n = 0, tick = 0, set_mode = 0;
    reg inc_hour = 0, inc_min = 0;
    wire [7:0] hour, min, sec;
    wire rollover, chime;
    time_counter counter(.clk(clk), .rst_n(rst_n), .tick_1hz(tick),
        .set_mode(set_mode), .inc_hour(inc_hour), .inc_min(inc_min),
        .hour(hour), .min(min), .sec(sec), .hour_rollover(rollover));
    // Keep the actual two-second duration, using a shorter simulated clock rate.
    hourly_chime #(.CLK_HZ(1000)) chimer(.clk(clk), .rst_n(rst_n),
        .hour_rollover(rollover), .chime_en(chime));

    reg alarm_set = 0, alarm_inc_hour = 0, alarm_inc_min = 0, alarm_en = 0;
    wire [7:0] alarm_hour, alarm_min;
    wire alarm_trig;
    alarm_ctrl alarm(.clk(clk), .rst_n(rst_n), .set_mode(alarm_set),
        .inc_hour(alarm_inc_hour), .inc_min(alarm_inc_min), .alarm_en(alarm_en),
        .cur_hour(hour), .cur_min(min), .alarm_hour(alarm_hour),
        .alarm_min(alarm_min), .alarm_trig(alarm_trig));

    function [7:0] bcd(input integer v);
        bcd = ((v / 10) << 4) | (v % 10);
    endfunction
    task step;
        @(posedge clk); #1; @(negedge clk);
    endtask
    task reset_all;
        rst_n = 0; tick = 0; set_mode = 0; inc_hour = 0; inc_min = 0;
        alarm_set = 0; alarm_en = 0; alarm_inc_hour = 0; alarm_inc_min = 0;
        step(); rst_n = 1; step();
    endtask
    integer t, i, expected_age, event_count;
    initial begin
        @(negedge clk); reset_all();
        if ({hour,min,sec} !== 24'h000000 || chime !== 0 || alarm_trig !== 0)
            $fatal(1, "Bad reset state");

        // Manual increments must work even when no second tick ever occurs.
        set_mode = 1; inc_hour = 1;
        for (i=1; i<=24; i=i+1) begin
            step();
            if (hour !== bcd(i % 24) || rollover !== 0)
                $fatal(1, "Manual hour wrap or tick-independent input failed");
        end
        inc_hour = 0; inc_min = 1;
        for (i=1; i<=60; i=i+1) begin
            step();
            if (min !== bcd(i % 60) || chime !== 0)
                $fatal(1, "Manual minute wrap triggered chime or failed");
        end
        inc_min = 0; tick = 1;
        repeat (3000) begin
            step();
            if ({hour,min,sec} !== 24'h000000 || chime !== 0)
                $fatal(1, "Frozen xx:00:00 advanced or retriggered chime");
        end

        // Exhaustive, independent wall-clock expectation for a complete day.
        set_mode = 0;
        event_count = 0;
        for (t=1; t<=86400; t=t+1) begin
            step();
            if (hour !== bcd((t/3600)%24) || min !== bcd((t/60)%60) || sec !== bcd(t%60))
                $fatal(1, "BCD time mismatch at second %0d: %h:%h:%h",t,hour,min,sec);
            expected_age = t % 3600;
            if ((t >= 3600) && (chime !== (expected_age < 2000)))
                $fatal(1, "Chime start/duration mismatch at second %0d",t);
            if (t < 3600 && chime !== 0) $fatal(1, "Chime before first natural hour");
            if ((t % 3600) == 0) event_count = event_count + 1;
        end
        if (event_count != 24 || {hour,min,sec} !== 24'h000000)
            $fatal(1, "Midnight wrap failed");
        // Duration uses master-clock cycles and expires even if time is paused.
        tick = 0; set_mode = 1;
        for (i=1; i<=2000; i=i+1) begin
            step();
            if (chime !== (i < 2000)) $fatal(1, "Paused clock extended the chime");
        end
        repeat (100) step();
        if (chime !== 0) $fatal(1, "Zero time retriggered the chime");

        reset_all();
        alarm_set = 1; alarm_inc_hour = 1;
        for (i=1; i<=24; i=i+1) begin
            step();
            if (alarm_hour !== bcd(i%24)) $fatal(1, "Alarm hour wrap failed");
        end
        alarm_inc_hour = 0; alarm_inc_min = 1;
        for (i=1; i<=60; i=i+1) begin
            step();
            if (alarm_min !== bcd(i%60)) $fatal(1, "Alarm minute wrap failed");
        end
        alarm_inc_min = 0; alarm_en = 1;
        step();
        if (alarm_trig !== 0) $fatal(1, "Alarm sounded while editing");
        alarm_set = 0; step();
        if (alarm_trig !== 1) $fatal(1, "Alarm did not match 00:00");
        tick = 1;
        repeat (59) begin
            step();
            if (alarm_trig !== 1) $fatal(1, "Alarm did not cover matching minute");
        end
        step();
        if (alarm_trig !== 0) $fatal(1, "Alarm did not stop at next minute");
        tick = 0; alarm_set = 1; alarm_inc_min = 1; step();
        alarm_inc_min = 0; alarm_set = 0; step();
        if (alarm_trig !== 1) $fatal(1, "Edited alarm did not match");
        alarm_en = 0; step();
        if (alarm_trig !== 0) $fatal(1, "Disabled alarm remained on");
        alarm_en = 1; step();
        rst_n = 0; #1;
        if (alarm_trig !== 0 || chime !== 0) $fatal(1, "Reset did not silence sound");
        $display("PASS tb_time_alarm_chime: full 24-hour BCD day, setting wraps, event timing, alarm match/disable");
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Time/alarm/chime timeout");
    end
endmodule
