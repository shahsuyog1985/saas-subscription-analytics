from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for directory in (ROOT / "reports" / "figures", ROOT / "reports" / "tables"):
    for path in directory.glob("*"):
        if path.name != ".gitkeep" and path.is_file():
            path.unlink()

