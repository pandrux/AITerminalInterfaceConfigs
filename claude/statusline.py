import sys
import os
import json
from pathlib import Path

os.environ["PYTHONIOENCODING"] = "utf-8"
sys.stdout.reconfigure(encoding="utf-8")

try:
    data = json.load(sys.stdin)
except Exception:
    print("[Claude Code]")
    sys.exit(0)

model = data.get("model", {}).get("display_name", "?")
pct = int(float(data.get("context_window", {}).get("used_percentage") or 0))
cost = float(data.get("cost", {}).get("total_cost_usd") or 0)
duration_ms = int(data.get("cost", {}).get("total_duration_ms") or 0)
cwd = data.get("workspace", {}).get("current_dir", "?")

mins, secs = duration_ms // 60000, (duration_ms % 60000) // 1000

try:
    home = str(Path.home())
    if cwd.startswith(home):
        cwd = "~" + cwd[len(home):]
except Exception:
    pass
cwd = cwd.replace("\\", "/")
if len(cwd) > 50:
    cwd = "..." + cwd[-47:]

GREEN, YELLOW, RED, RESET = "\033[32m", "\033[33m", "\033[31m", "\033[0m"
color = RED if pct >= 90 else YELLOW if pct >= 70 else GREEN

filled = pct // 10
bar = "\u2588" * filled + "\u2591" * (10 - filled)

print(f"[{model}] {color}{bar}{RESET} {pct}% | ${cost:.2f} | {mins}m {secs}s | {cwd}")
