// Pull the translation dictionary out of prototype.html without running the app.
// node extractD.js <prototype.html> <out.json>   ->  { key: [uz, uzCyrl, ru, en] }
const fs = require('fs');
const src = fs.readFileSync(process.argv[2], 'utf8');
const BS = String.fromCharCode(92);
function grab(from) {
  let d = 0, q = null;
  for (let i = from; i < src.length; i++) {
    const c = src[i];
    if (q) { if (c === BS) { i++; continue } if (c === q) q = null; continue }
    if (c === "'" || c === '"' || c === '`') { q = c; continue }
    if (c === '/' && src[i + 1] === '*') { i = src.indexOf('*/', i + 2) + 1; continue }
    if (c === '/' && src[i + 1] === '/') { i = src.indexOf('\n', i); continue }
    if (c === '{') d++;
    else if (c === '}') { d--; if (!d) return src.slice(from, i + 1) }
  }
}
const D = {}; let fails = 0;
const take = (lit, tag) => { try { Object.assign(D, (0, eval)('(' + lit + ')')) } catch (e) { fails++; console.error('FAIL', tag, e.message.slice(0, 80)) } };
take(grab(src.indexOf('{', src.indexOf('const D = {'))), 'main');
let p = 0;
while ((p = src.indexOf('Object.assign(D,{', p)) >= 0) { take(grab(p + 16), '@' + p); p += 17 }
const m = src.match(/D\['bd2\.tickDone'\]=(\[[^\]]*\])/);
if (m) D['bd2.tickDone'] = (0, eval)(m[1]);
const fnStart = src.indexOf("const OK=/["), fnEnd = src.indexOf('function plural(');
(0, eval)(src.slice(fnStart, fnEnd).replace(/const /g, 'var ') + ';globalThis.cyr=cyr;');
const s = x => String(x ?? '').replace(/[⟦⟧]/g, '');
const out = {};
for (const k of Object.keys(D)) {
  const e = D[k];
  if (!Array.isArray(e)) { console.error('NOTARRAY', k); continue }
  out[k] = [s(e[0]), s(e[3] || cyr(e[0])), s(e[1]), s(e[2])];
}
fs.writeFileSync(process.argv[3], JSON.stringify(out));
console.log('keys', Object.keys(out).length, 'fails', fails);
