open_project hdmi.gprj
set_option -top_module top
set_option -synthesis_tool gowinsynthesis
set_option -include_path {src src/hdmi src/vendor}
set_option -output_base_name risc-playground
run all
