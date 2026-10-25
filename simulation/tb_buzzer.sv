`timescale 1ns/1ps
module tb_buzzer;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst_n = 0, sound_en = 0;
    wire passive_hi, passive_lo, active_hi, active_lo;
    buzzer_driver ph(.clk(clk), .rst_n(rst_n), .sound_en(sound_en), .buzzer(passive_hi));
    buzzer_driver #(.BUZZER_ACTIVE_LOW(1)) pl(
        .clk(clk), .rst_n(rst_n), .sound_en(sound_en), .buzzer(passive_lo));
    buzzer_driver #(.ACTIVE_BUZZER(1)) ah(
        .clk(clk), .rst_n(rst_n), .sound_en(sound_en), .buzzer(active_hi));
    buzzer_driver #(.ACTIVE_BUZZER(1), .BUZZER_ACTIVE_LOW(1)) al(
        .clk(clk), .rst_n(rst_n), .sound_en(sound_en), .buzzer(active_lo));

    task silent_check;
        #1;
        if ({passive_hi,passive_lo,active_hi,active_lo} !== 4'b0101)
            $fatal(1, "Wrong idle/reset polarity");
    endtask
    integer i;
    initial begin
        repeat (2) @(negedge clk);
        silent_check(); rst_n = 1; silent_check();
        @(negedge clk); sound_en = 1;
        for (i=1; i<=100000; i=i+1) begin
            @(posedge clk); #1;
            if (passive_hi !== ((i/12500)%2)) $fatal(1, "Default tone is not 2kHz at cycle %0d",i);
            if (passive_lo !== !passive_hi) $fatal(1, "Passive polarity mismatch");
            if (active_hi !== 1 || active_lo !== 0) $fatal(1, "Active module received a tone instead of a level");
        end
        @(negedge clk); sound_en = 0; silent_check();
        repeat (10) @(negedge clk);
        sound_en = 1;
        repeat (12500) @(posedge clk);
        #1;
        if (passive_hi !== 1) $fatal(1, "Tone phase did not restart");
        // Assert reset in the middle of an audible half-period.
        #2; rst_n = 0; silent_check();
        $display("PASS tb_buzzer: real 50MHz/2kHz tone, active/passive, both polarities, stop/reset/restart");
        $finish;
    end
    initial begin
        #3000000;
        $fatal(1, "Buzzer timeout");
    end
endmodule
