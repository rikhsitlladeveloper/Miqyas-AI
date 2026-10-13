"""Build a "three options" comparison page from a body fragment.

The page head (fonts, tokens, phone frame, shared icons) is taken from design/projects/projects-options.html, so
every options page shares one look. The body fragment starts with its own <style> and ends after </div> of .wrap.

Usage: python build_options.py <body.html> <out.html> "<Page Title>"
"""
import io, os, sys
from pathlib import Path

body_path, out_path, title = sys.argv[1], sys.argv[2], sys.argv[3]
TEMPLATE = Path(__file__).resolve().parents[1] / "projects" / "projects-options.html"
src = io.open(TEMPLATE, encoding="utf-8").read()
head = src[:src.index('<div class="wrap">')].replace("<title>METRX Projects Options</title>", "<title>%s</title>" % title)
os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
io.open(out_path, "w", encoding="utf-8").write(head + io.open(body_path, encoding="utf-8").read())
print("ok")
