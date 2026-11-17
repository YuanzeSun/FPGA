import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name("build_stock.py")),run_name="__main__")
