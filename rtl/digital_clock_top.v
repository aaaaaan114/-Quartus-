`timescale 1ns/1ps
`default_nettype none

module digital_clock_top #(
    parameter integer CLK_HZ = 50000000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire CLOCK_50,
    input  wire [3:0] KEY,
    input  wire [1:0] SW,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output wire [2:0] LEDR
);
    // KEY[0]: asynchronous assertion, two-clock synchronous reset release.
    reg [1:0] reset_sync;
    wire rst_n = reset_sync[1];
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) reset_sync <= 2'b00;
        else reset_sync <= {reset_sync[0], 1'b1};
    end

    reg [1:0] sw_meta, sw_sync;
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta <= 2'b00;
            sw_sync <= 2'b00;
        end else begin
            sw_meta <= SW;
            sw_sync <= sw_meta;
        end
    end

    wire tick_1hz, tick_1khz;
    clk_divider #(.CLK_HZ(CLK_HZ)) u_div(
        .clk(CLOCK_50), .rst_n(rst_n),
        .tick_1hz(tick_1hz), .tick_1khz(tick_1khz)
    );

    wire k1_pulse, k2_pulse;
    debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db1(
        .clk(CLOCK_50), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_in(KEY[1]), .key_pulse(k1_pulse)
    );
    debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db2(
        .clk(CLOCK_50), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_in(KEY[2]), .key_pulse(k2_pulse)
    );

    // 0: normal; 1: edit hours; 2: edit minutes. KEY[3] is reserved.
    reg [1:0] set_state;
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) set_state <= 2'd0;
        else if (k1_pulse)
            set_state <= (set_state == 2'd2) ? 2'd0 : set_state + 1'b1;
    end

    wire set_mode = (set_state != 2'd0);
    wire set_time_mode = set_mode && !sw_sync[1];
    wire show_alarm = set_mode && sw_sync[1];
    // A simultaneous mode press takes priority over an increment press.
    wire inc_hour = k2_pulse && !k1_pulse && (set_state == 2'd1);
    wire inc_min = k2_pulse && !k1_pulse && (set_state == 2'd2);
    wire [7:0] hour_bcd, min_bcd, sec_bcd, alarm_hour, alarm_min;
    wire hour_rollover, chime_en, alarm_trig;

    time_counter u_time(
        .clk(CLOCK_50), .rst_n(rst_n), .tick_1hz(tick_1hz),
        .set_mode(set_time_mode),
        .inc_hour(inc_hour && !sw_sync[1]), .inc_min(inc_min && !sw_sync[1]),
        .hour(hour_bcd), .min(min_bcd), .sec(sec_bcd),
        .hour_rollover(hour_rollover)
    );
    alarm_ctrl u_alarm(
        .clk(CLOCK_50), .rst_n(rst_n), .set_mode(set_mode),
        .inc_hour(inc_hour && sw_sync[1]), .inc_min(inc_min && sw_sync[1]),
        .alarm_en(sw_sync[0]), .cur_hour(hour_bcd), .cur_min(min_bcd),
        .alarm_hour(alarm_hour), .alarm_min(alarm_min), .alarm_trig(alarm_trig)
    );
    hourly_chime #(.CLK_HZ(CLK_HZ)) u_chime(
        .clk(CLOCK_50), .rst_n(rst_n),
        .hour_rollover(hour_rollover), .chime_en(chime_en)
    );
    wire [7:0] display_hour = show_alarm ? alarm_hour : hour_bcd;
    wire [7:0] display_min = show_alarm ? alarm_min : min_bcd;
    wire [7:0] display_sec = show_alarm ? 8'h00 : sec_bcd;

    // DE1-SoC: active-low segments [6:0] = {g,f,e,d,c,b,a}.
    function [6:0] bcd2seg;
        input [3:0] b;
        begin
            case (b)
                4'd0: bcd2seg = 7'h40;
                4'd1: bcd2seg = 7'h79;
                4'd2: bcd2seg = 7'h24;
                4'd3: bcd2seg = 7'h30;
                4'd4: bcd2seg = 7'h19;
                4'd5: bcd2seg = 7'h12;
                4'd6: bcd2seg = 7'h02;
                4'd7: bcd2seg = 7'h78;
                4'd8: bcd2seg = 7'h00;
                4'd9: bcd2seg = 7'h10;
                default: bcd2seg = 7'h7f;
            endcase
        end
    endfunction
    assign HEX0 = bcd2seg(display_sec[3:0]);
    assign HEX1 = bcd2seg(display_sec[7:4]);
    assign HEX2 = bcd2seg(display_min[3:0]);
    assign HEX3 = bcd2seg(display_min[7:4]);
    assign HEX4 = bcd2seg(display_hour[3:0]);
    assign HEX5 = bcd2seg(display_hour[7:4]);

    assign LEDR = {sw_sync[0], alarm_trig, chime_en};
endmodule

`default_nettype wire
