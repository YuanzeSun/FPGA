"""Default build: RTL verification followed by Gowin Education compilation."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('build_stock.py')),run_name='__main__')
