"""Run the standalone Lua 5.1 fixtures with Python's lupa package."""
import os
from pathlib import Path
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parents[1])
for fixture in ("test_scoring.lua", "test_bonuses.lua", "test_comparison.lua", "test_tooltip.lua", "test_gear_totals.lua",
                "test_regressions_018.lua", "test_dynamic_profiles.lua", "test_forever_traits.lua", "test_enchantments.lua", "test_minimap.lua"):
    LuaRuntime().execute(f"assert(loadfile('tests/{fixture}'))()")
