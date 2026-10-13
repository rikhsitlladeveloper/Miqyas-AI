"""Paste design/prototype/modules/*.css|js into prototype.html between their markers, then rebuild index.html.

Each module sits between /*@@CSS:name@@*/ (or /*@@JS:name@@*/) and the next module's marker. The order below is
the order of the markers in prototype.html; a new module goes in with add_markers.py first, then a line here.
auth, wallview and sketch are not listed: their code lives directly in prototype.html and modules/ keeps a reference copy.
"""
import io, subprocess, sys
from pathlib import Path

D = Path(__file__).resolve().parents[1] / "prototype"
P = D / "prototype.html"
ORDER = ["openings", "workspace", "home", "projects", "project", "editor", "estimate", "measure", "board",
         "profile", "report"]
END = "auth"  # the block after the last synced module

raw = io.open(P, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
s = raw.replace("\r\n", "\n")
for ext, start, end in (("css", "/*@@CSS:%s@@*/\n", "/*@@CSS:%s@@*/\n"), ("js", "/*@@JS:%s@@*/\n", "\n/*@@JS:%s@@*/\n")):
    for k, mod in enumerate(ORDER):
        a, b = start % mod, end % (ORDER[k + 1] if k + 1 < len(ORDER) else END)
        body = io.open(D / "modules" / (mod + "." + ext), encoding="utf-8").read()
        i = s.index(a) + len(a)
        j = s.index(b, i)
        s = s[:i] + body + s[j:]
io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)
subprocess.run([sys.executable, "make_index.py"], cwd=D, check=True)
print("synced")
