"""Add empty /*@@CSS:name@@*/ and /*@@JS:name@@*/ markers for a new module, just before the auth block.

Usage: python add_markers.py <name>   then add <name> to ORDER in sync_modules.py and run it.
"""
import io, sys
from pathlib import Path

name = sys.argv[1]
P = Path(__file__).resolve().parents[1] / "prototype" / "prototype.html"
raw = io.open(P, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
s = raw.replace("\r\n", "\n")
css, js = "/*@@CSS:%s@@*/" % name, "/*@@JS:%s@@*/" % name
if css not in s:
    s = s.replace("/*@@CSS:auth@@*/\n", css + "\n/*@@CSS:auth@@*/\n")
if js not in s:
    s = s.replace("\n/*@@JS:auth@@*/\n", "\n" + js + "\n\n/*@@JS:auth@@*/\n")
io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)
print("markers", s.count(css), s.count(js))
