`timescale 1ns/1ps
module tb_top;
    localparam integer CLK_HZ = 20000;
    reg clk = 0;
    always #10 clk = !clk;
    reg [3:0] keys = 4'b1110;
    reg [1:0] switches = 0;
    wire [6:0] hex0, hex1, hex2, hex3, hex4, hex5;
    wire [2:0] leds;
    wire buzzer;
    digital_clock_top #(.CLK_HZ(CLK_HZ), .ACTIVE_BUZZER(1)) dut(
        .CLOCK_50(clk), .KEY(keys), .SW(switches),
        .HEX0(hex0), .HEX1(hex1), .HEX2(hex2),
        .HEX3(hex3), .HEX4(hex4), .HEX5(hex5), .LEDR(leds), .BUZZER(buzzer));

    // Fail if any accepted press stretches beyond one master-clock cycle.
    reg last_k1 = 0, last_k2 = 0;
    always @(posedge clk) begin
        if (dut.rst_n) begin
            if ((last_k1 && dut.k1_pulse) || (last_k2 && dut.k2_pulse))
                $fatal(1, "Debounced key pulse lasted multiple master clocks");
            last_k1 <= dut.k1_pulse;
            last_k2 <= dut.k2_pulse;
        end else begin last_k1 <= 0; last_k2 <= 0; end
    end

    task cycles(input integer n);
        repeat(n) begin @(posedge clk); #1; end
        @(negedge clk);
    endtask
    task press(input integer k);
        keys[k] = 0; cycles(600); // 30 ms: exceeds the real 20 ms filter
        keys[k] = 1; cycles(600);
    endtask
    task reset_all;
        keys = 4'b1110; switches = 0; cycles(3);
        if (buzzer !== 0 || leds[1:0] !== 0) $fatal(1, "Reset did not silence top");
        keys[0] = 1;
        cycles(1);
        if (dut.rst_n !== 0) $fatal(1, "Reset release was not synchronized");
        cycles(5);
        if (dut.rst_n !== 1 || dut.set_state !== 0) $fatal(1, "Reset did not release");
    endtask
    function [6:0] seg(input [3:0] d);
        case(d)
            0: seg=7'h40; 1: seg=7'h79; 2: seg=7'h24; 3: seg=7'h30;
            4: seg=7'h19; 5: seg=7'h12; 6: seg=7'h02; 7: seg=7'h78;
            8: seg=7'h00; 9: seg=7'h10; default: seg=7'h7f;
        endcase
    endfunction
    task display_is(input [23:0] value);
        if ({hex5,hex4,hex3,hex2,hex1,hex0} !==
            {seg(value[23:20]),seg(value[19:16]),seg(value[15:12]),
             seg(value[11:8]),seg(value[7:4]),seg(value[3:0])})
            $fatal(1, "Wrong displayed HHMMSS; expected %h", value);
    endtask
    integer i;
    reg [7:0] saved_sec;
    initial begin
        @(negedge clk); reset_all(); display_is(24'h000000);
        if (buzzer !== 0 || leds !== 0) $fatal(1, "False power-on chime");

        // Bounce shorter than the filter cannot change mode.
        repeat(8) begin keys[1]=0; cycles(5); keys[1]=1; cycles(5); end
        cycles(500);
        if (dut.set_state !== 0) $fatal(1, "Mode key bounce was accepted");
        press(1);
        if (dut.set_state !== 1) $fatal(1, "Mode key was lost");
        repeat(8) begin keys[2]=0; cycles(5); keys[2]=1; cycles(5); end
        cycles(500); display_is(24'h000000);

        // Long hold generates just one increment; a short valid press also works.
        keys[2]=0; cycles(3000); keys[2]=1; cycles(600);
        display_is(24'h010000);
        keys[2]=0; cycles(480); keys[2]=1; cycles(600);
        display_is(24'h020000);
        press(1); press(2); display_is(24'h020100);
        cycles(CLK_HZ + 1000); display_is(24'h020100);
        if (buzzer !== 0) $fatal(1, "Manual setting triggered sound");
        press(1);
        if (dut.set_state !== 0) $fatal(1, "Could not leave time setting");

        switches[1]=1; cycles(5); press(1); display_is(24'h000000);
        saved_sec = dut.sec_bcd;
        cycles(CLK_HZ + 1000);
        if (dut.sec_bcd === saved_sec) $fatal(1, "Setting alarm paused real time");
        display_is(24'h000000);
        press(2); display_is(24'h010000);
        press(1); press(2); display_is(24'h010100);
        switches[0]=1; cycles(5);
        if (buzzer !== 0 || leds[1] !== 0) $fatal(1, "Alarm sounded while editing");
        press(1);
        display_is({dut.hour_bcd,dut.min_bcd,dut.sec_bcd});
        if (dut.hour_bcd !== 8'h02 || dut.alarm_hour !== 8'h01 || leds[2] !== 1)
            $fatal(1, "Alarm edit changed current time or enable LED");

        // Adjust 02:01 back around to 01:01; all 23 presses must be retained.
        switches[1]=0; cycles(5); press(1);
        repeat(23) press(2);
        display_is({8'h01,8'h01,dut.sec_bcd});
        if (buzzer !== 0) $fatal(1, "Alarm was not muted in time setting");
        press(1); press(1);
        if (buzzer !== 1 || leds[1] !== 1) $fatal(1, "Alarm match did not drive buzzer");
        switches[0]=0; cycles(5);
        if (buzzer !== 0) $fatal(1, "SW0 did not stop alarm");
        switches[0]=1; cycles(5);
        if (buzzer !== 1) $fatal(1, "Alarm enable did not resume matching minute");
        cycles(61*CLK_HZ);
        if (buzzer !== 0 || leds[1] !== 0) $fatal(1, "Alarm exceeded matching minute");

        // End-to-end overlap: alarm 01:00, current time 00:59:00.
        reset_all(); switches[1]=1; cycles(5);
        press(1); press(2); press(1); press(1);
        switches=2'b01; cycles(5); press(1); press(1);
        repeat(59) press(2);
        display_is(24'h005900);
        press(1);
        if (leds[1:0] !== 0) $fatal(1, "Sound before natural hour");
        wait ({dut.hour_bcd,dut.min_bcd,dut.sec_bcd} === 24'h010000);
        @(negedge clk);
        if (leds[1:0] !== 2'b11 || buzzer !== 1)
            $fatal(1, "Chime and alarm did not start on hour boundary");
        switches[0]=0; cycles(5);
        if (leds[1:0] !== 2'b01 || buzzer !== 1)
            $fatal(1, "SW0 incorrectly silenced the independent hourly chime");
        switches[0]=1; cycles(5);
        for(i=0; i<2*CLK_HZ+5; i=i+1) begin
            @(posedge clk); #1;
            if (buzzer !== 1) $fatal(1, "Gap while overlapping sounds hand over");
        end
        @(negedge clk);
        if (leds[0] !== 0 || leds[1] !== 1) $fatal(1, "Chime did not expire independently");
        switches[0]=0; cycles(5);
        if (buzzer !== 0) $fatal(1, "Alarm remained after overlap/disable");
        switches[0]=1; cycles(5);
        wait(dut.min_bcd === 8'h01);
        @(negedge clk);
        if (buzzer !== 0 || leds[1:0] !== 0) $fatal(1, "Sound did not end at 01:01");
        $display("PASS tb_top: reset, bounce/short/held keys, time/alarm editing and display, SW0, natural-hour overlap");
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1, "Top-level timeout");
    end
endmodule
