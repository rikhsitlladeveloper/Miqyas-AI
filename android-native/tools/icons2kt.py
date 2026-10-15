"""Turn the prototype's <symbol id="i-..."> icon sprite into Kotlin path data.
python icons2kt.py <prototype.html> <out Icons.kt>
Every shape becomes SVG path data; attributes that differ from the default stroke style are kept."""
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
syms = re.findall(r'<symbol id="i-([a-z0-9-]+)" viewBox="([^"]+)">(.*?)</symbol>', src, re.S)
num = lambda s: float(s)
def f(v): return ('%g' % v)
def shape_to_d(tag, a):
    if tag == 'path': return a.get('d', '')
    if tag == 'circle':
        cx, cy, r = num(a.get('cx', 0)), num(a.get('cy', 0)), num(a['r'])
        return f'M{f(cx-r)} {f(cy)}a{f(r)} {f(r)} 0 1 0 {f(2*r)} 0a{f(r)} {f(r)} 0 1 0 {f(-2*r)} 0z'
    if tag == 'ellipse':
        cx, cy, rx, ry = num(a.get('cx', 0)), num(a.get('cy', 0)), num(a['rx']), num(a['ry'])
        return f'M{f(cx-rx)} {f(cy)}a{f(rx)} {f(ry)} 0 1 0 {f(2*rx)} 0a{f(rx)} {f(ry)} 0 1 0 {f(-2*rx)} 0z'
    if tag == 'rect':
        x, y, w, h = num(a.get('x', 0)), num(a.get('y', 0)), num(a['width']), num(a['height'])
        rx = num(a.get('rx', a.get('ry', 0))); rx = min(rx, w/2, h/2)
        if not rx: return f'M{f(x)} {f(y)}h{f(w)}v{f(h)}h{f(-w)}z'
        return (f'M{f(x+rx)} {f(y)}h{f(w-2*rx)}a{f(rx)} {f(rx)} 0 0 1 {f(rx)} {f(rx)}v{f(h-2*rx)}'
                f'a{f(rx)} {f(rx)} 0 0 1 {f(-rx)} {f(rx)}h{f(-(w-2*rx))}a{f(rx)} {f(rx)} 0 0 1 {f(-rx)} {f(-rx)}'
                f'v{f(-(h-2*rx))}a{f(rx)} {f(rx)} 0 0 1 {f(rx)} {f(-rx)}z')
    if tag == 'line':
        return f'M{a.get("x1",0)} {a.get("y1",0)}L{a.get("x2",0)} {a.get("y2",0)}'
    if tag in ('polyline', 'polygon'):
        pts = re.findall(r'-?[\d.]+', a['points'])
        pairs = [f'{pts[i]} {pts[i+1]}' for i in range(0, len(pts) - 1, 2)]
        return 'M' + 'L'.join(pairs) + ('z' if tag == 'polygon' else '')
    return None
out = ['// Generated from the prototype icon sprite by design tools/icons2kt.py. Do not edit by hand.',
       'package uz.metrx.app.ui.icons', '',
       '/** One shape of an icon: SVG path data plus the few style attributes that differ from the default stroke. */',
       'data class IconPart(val d: String, val fill: String? = null, val stroke: String? = null, val strokeWidth: Float? = null, val opacity: Float? = null)',
       'data class IconDef(val w: Float, val h: Float, val parts: List<IconPart>)', '',
       'val ICONS: Map<String, IconDef> = mapOf(']
skipped = []
for name, vb, body in syms:
    _, _, w, h = vb.split()
    parts = []
    for tag, attrs in re.findall(r'<(path|circle|ellipse|rect|line|polyline|polygon)\b([^>]*)/?>', body):
        a = dict(re.findall(r'([\w:-]+)="([^"]*)"', attrs))
        d = shape_to_d(tag, a)
        if not d: skipped.append(name); continue
        extra = []
        if 'fill' in a: extra.append(f'fill = "{a["fill"]}"')
        if 'stroke' in a: extra.append(f'stroke = "{a["stroke"]}"')
        if 'stroke-width' in a: extra.append(f'strokeWidth = {a["stroke-width"]}f')
        if 'opacity' in a: extra.append(f'opacity = {a["opacity"]}f')
        parts.append('IconPart("' + d.replace('"', '') + '"' + ''.join(', ' + e for e in extra) + ')')
    out.append(f'    "{name}" to IconDef({w}f, {h}f, listOf(' + ', '.join(parts) + ')),')
out.append(')')
open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print(len(syms), 'icons; skipped shapes in', sorted(set(skipped)))
