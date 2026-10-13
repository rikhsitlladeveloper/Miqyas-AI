"""Wrap prototype.html (the Artifact page body) in a full HTML document as index.html for local or LAN preview."""
from pathlib import Path
here = Path(__file__).resolve().parent
body = (here / "prototype.html").read_text(encoding="utf-8")
head = ('<!doctype html>\n<html lang="uz">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n</head>\n<body>\n')
(here / "index.html").write_text(head + body + "\n</body>\n</html>\n", encoding="utf-8")
print("index.html written")
