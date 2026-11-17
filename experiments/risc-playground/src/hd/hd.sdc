create_clock -name clk_osc -period 37.037 [get_ports {clk}]
create_generated_clock -name cpu_clk -source [get_ports {clk}] -multiply_by 14 -divide_by 15 [get_pins {hd/u_cpu_div/clkdiv_inst/CLKOUT}]
create_generated_clock -name video_fast -source [get_ports {clk}] -multiply_by 55 -divide_by 4 [get_pins {hd/u_video_pll/rpll_inst/CLKOUT}]
create_generated_clock -name pixel_clk -source [get_pins {hd/u_video_pll/rpll_inst/CLKOUT}] -divide_by 5 [get_pins {hd/u_video_div/clkdiv_inst/CLKOUT}]
# Only the CPU/video boundary is asynchronous; pixel/serializer timing remains checked.
set_clock_groups -asynchronous -group [get_clocks {cpu_clk}] -group [get_clocks {pixel_clk video_fast}]
