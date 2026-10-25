# All logic is clocked by CLOCK_50; tick signals are synchronous enables.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Only asynchronous external inputs are excluded. Register-to-register
# synchronizer paths and synchronous internal reset recovery remain timed.
set_false_path -from [get_ports {KEY* SW*}]

# Displays, indicator LEDs and the buzzer have no external capture clock.
set_false_path -to [get_ports {HEX* LEDR* BUZZER}]
