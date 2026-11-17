open_project hd.gprj
set_option -top_module top_1080p30
set_option -synthesis_tool gowinsynthesis
set_option -include_path {src src/hd src/hdmi src/vendor}
set_option -output_base_name hd-1080p30
run all
