import Foundation

/*
 * "Mijozga 3D yuborish" (Joylan ideas, approved 26 Oct 2026; the mockup's share sheet and client viewer; Android
 * furniture/Client3D.kt): an order's furniture in its room as two files the maker sends from the phone, no server, no
 * account: a .usdz (iPhone Quick Look, 3D and AR) and one .html that opens offline in any phone's browser (a tiny
 * WebGL viewer with the meshes inside). This file is the pure part (Foundation only; Client3DTests): the scene's meshes
 * by colour, the HTML page, and the USDZ (a USDA layer in an uncompressed zip, its data 64-byte aligned, as the USDZ
 * spec asks). The share sheet and the ModelIO way are in Furniture/Client3DShare.swift.
 *
 * Walls keep only their inside faces and every face is wound to its normal, so with back faces culled (the viewer, and
 * Quick Look for a USD mesh that is not double-sided) a wall turned away from the eye is not drawn: the room opens like
 * a doll's house from any side.
 */

/// One colour of the scene: its polygons (metres, wound to their normals) and each one's normal.
struct C3Mesh: Equatable {
    let rgb: Int
    let op: Double
    var polys: [[V3]] = []
    var norms: [V3] = []
    var corners: Int { polys.reduce(0) { $0 + $1.count } }
}

/// A dimension the viewer can show: a line a…b with its text.
struct C3Dim: Equatable { let a: V3; let b: V3; let text: String }

/// The client's scene: the meshes, the dimensions, where the camera starts (tgt, and from where: theta round, phi up, r
/// away), the floor's middle (the USDZ is moved there).
struct C3Scene: Equatable {
    var meshes: [C3Mesh] = []
    var dims: [C3Dim] = []
    var tgt = V3(0, 1, 0)
    var theta = 0.0, phi = 0.5, r = 6.0
    var mid = V3(0, 0, 0)
}

/// The polygon's normal by Newell's rule (not normalised).
private func c3Newell(_ p: [V3]) -> V3 {
    var n = V3(0, 0, 0)
    for i in p.indices {
        let a = p[i], b = p[(i + 1) % p.count]
        n = n + V3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
    }
    return n
}

/// pts wound counter-clockwise seen from the side n points to.
func c3Wound(_ pts: [V3], _ n: V3) -> [V3] { c3Newell(pts).dot(n) < 0 ? Array(pts.reversed()) : pts }

/// The scene's meshes from parts: faces of one colour and opacity together; walls (role wall) only their faces that
/// look into the room (centre cx, cz); a triangulated face as its triangles.
func c3Meshes(_ parts: [Part3], cx: Double, cz: Double) -> [C3Mesh] {
    var order: [String] = []
    var by: [String: C3Mesh] = [:]
    for p in parts {
        let opq = (p.op * 100).rounded() / 100
        let key = "\(p.rgb)/\(opq)"
        var m = by[key] ?? C3Mesh(rgb: p.rgb, op: opq)
        if by[key] == nil { order.append(key) }
        for f in p.faces {
            guard f.pts.count >= 3, f.n.len > 1e-9 else { continue }
            if p.role == .wall {
                var c = V3(0, 0, 0)
                for q in f.pts { c = c + q }
                c = c * (1 / Double(f.pts.count))
                if f.n.x * (cx - c.x) + f.n.z * (cz - c.z) <= 1e-6 || abs(f.n.y) > 0.5 { continue }
            }
            if p.role == .floor && f.n.y < 0.5 { continue }
            let n = f.n.unit
            if let tris = f.tris {
                var i = 0
                while i + 2 < tris.count {
                    let t = [f.pts[tris[i]], f.pts[tris[i + 1]], f.pts[tris[i + 2]]]
                    m.polys.append(c3Wound(t, n)); m.norms.append(n)
                    i += 3
                }
            } else {
                m.polys.append(c3Wound(f.pts, n)); m.norms.append(n)
            }
        }
        by[key] = m
    }
    return order.compactMap { by[$0] }.filter { !$0.polys.isEmpty }
}

/// The room the order's client file shows: rid, else the room of its first kitchen, else the room with the most pieces.
func c3Room(_ p: Project, _ rid: String?) -> Room? {
    if let rid, let r = p.rooms.first(where: { $0.id == rid }) { return r }
    let built = p.furniture.filter { !$0.modules.isEmpty }
    if let k = built.first(where: { $0.kind == "kitchen" && $0.roomId != nil }), let r = p.rooms.first(where: { $0.id == k.roomId }) { return r }
    var best: (Room, Int)? = nil
    for r in p.rooms {
        let n = built.filter { $0.roomId == r.id }.count
        if n > 0 && (best == nil || n > best!.1) { best = (r, n) }
    }
    return best?.0
}

/// The client's scene of order p: room rid (c3Room) with its furniture, or a room-less piece in its made-up room; the
/// lit 3D's boxes of detail; dimensions of the walls the furniture stands on and of the room's height. nil: nothing to show.
func client3DScene(_ p: Project, rid: String?, ws: Workshop, mats: [Mat], snap: Bool, detail: Quality3 = .low) -> C3Scene? {
    let built = p.furniture.filter { !$0.modules.isEmpty }
    var room: Room
    var fs: [Furniture]
    if let r = c3Room(p, rid) {
        room = r
        fs = built.filter { $0.roomId == r.id }
    } else if let f = built.first(where: { $0.roomId == nil }) {
        room = freeRoom(f)
        fs = [f]
    } else {
        return nil
    }
    if fs.isEmpty { return nil }
    let shell = buildShell([room], single: true, snap: snap)
    let rgb: (String) -> Int = { id in rgbOf(mats.first { $0.id == id }?.rgb ?? "#F5F5F2") }
    let fur = furniture3D(fs, shell.bases, ws, rgb, [], tex: { id in mats.first { $0.id == id }?.tex }, mats: mats, detail: detail,
                          ceilH: room.dim("H").v ?? 2700)
    let g0 = shell.groups.first
    let cx = g0?.cx ?? shell.L / 2, cz = g0?.cz ?? shell.W / 2
    let roles: [Role3] = [.floor, .wall, .opening, .glass]
    let keep = shell.parts.filter { roles.contains($0.role) }
    var s = C3Scene()
    s.meshes = c3Meshes(keep + fur.parts, cx: cx, cz: cz)
    s.mid = V3(cx, 0, cz)
    // the dimensions: each wall the furniture stands on, and the room's height at the first one's start
    let H = Double(room.dim("H").v ?? 2700) / 1000
    var walls: [String] = []
    for f in fs { for w in f.walls where w != ISLAND && !walls.contains(w) { walls.append(w) } }
    var nx = 0.0, nz = 0.0
    for w in walls {
        guard let b = shell.bases[w] else { continue }
        let mm = Int((b.len * 1000).rounded())
        s.dims.append(C3Dim(a: b.at(0, 0.03, 0.04), b: b.at(b.len, 0.03, 0.04), text: "\(mm)"))
        nx += b.nx; nz += b.nz
    }
    if let w = walls.first, let b = shell.bases[w] {
        s.dims.append(C3Dim(a: b.at(0.04, 0, 0.04), b: b.at(0.04, H, 0.04), text: "\(Int((H * 1000).rounded()))"))
    }
    // the camera: inside the room, looking at the furniture's walls a little from one side and from above
    let l = hypot(nx, nz)
    let dx = l > 0.1 ? nx / l : 0, dz = l > 0.1 ? nz / l : 1
    let az = atan2(dx, dz) + (walls.count == 1 ? 0.35 : 0)
    s.theta = az
    s.phi = 0.42
    s.tgt = V3(cx, min(1.0, H * 0.4), cz)
    s.r = max(3.2, max(shell.L, shell.W) * 1.35)
    return s
}

/* ---------------- the HTML viewer ---------------- */

/// What the HTML page says (in the order's report language) and what the maker allowed in it.
struct C3Info: Equatable {
    var lang = "uz"
    var title = ""
    var line1 = ""
    var line2 = ""
    /// The price line ("Taxminiy narx: …"), nil when left out.
    var price: String? = nil
    /// "Usta: name" and the phone (digits with +998), nil when left out.
    var master = ""
    var phone: String? = nil
    var phoneShown = ""
    var hint = ""
    var noGl = ""
    var dims = true
}

/// s's text safe inside HTML.
func c3Esc(_ s: String) -> String {
    var o = ""
    for ch in s {
        switch ch {
        case "&": o += "&amp;"
        case "<": o += "&lt;"
        case ">": o += "&gt;"
        case "\"": o += "&quot;"
        case "'": o += "&#39;"
        default: o.append(ch)
        }
    }
    return o
}

/// s as a JavaScript string literal (in double quotes), safe inside a script element.
func c3Js(_ s: String) -> String {
    var o = "\""
    for u in s.unicodeScalars {
        switch u {
        case "\"": o += "\\\""
        case "\\": o += "\\\\"
        case "\n": o += "\\n"
        case "\r": o += "\\r"
        case "<": o += "\\u003c"
        case ">": o += "\\u003e"
        case "&": o += "\\u0026"
        default:
            if u.value < 0x20 || u.value == 0x2028 || u.value == 0x2029 { o += String(format: "\\u%04x", u.value) } else { o.unicodeScalars.append(u) }
        }
    }
    return o + "\""
}

/// A mesh as triangles for the viewer: positions in mm as 16-bit integers, normals as 8-bit, both little-endian and
/// base64; the floor's middle at the origin.
func c3Packed(_ m: C3Mesh, _ mid: V3) -> (pos: String, nor: String, count: Int) {
    var pos = Data(), nor = Data()
    var n = 0
    func put(_ q: V3, _ nn: V3) {
        for v in [q.x - mid.x, q.y - mid.y, q.z - mid.z] {
            let i = Int16(clamping: Int((v * 1000).rounded()))
            withUnsafeBytes(of: i.littleEndian) { pos.append(contentsOf: $0) }
        }
        for v in [nn.x, nn.y, nn.z] {
            let i = Int8(clamping: Int((v * 127).rounded()))
            nor.append(UInt8(bitPattern: i))
        }
        n += 1
    }
    for (k, poly) in m.polys.enumerated() {
        let nn = m.norms[k]
        if poly.count < 3 { continue }
        for i in 1..<(poly.count - 1) { put(poly[0], nn); put(poly[i], nn); put(poly[i + 1], nn) }
    }
    return (pos.base64EncodedString(), nor.base64EncodedString(), n)
}

private func c3Num(_ v: Double, _ d: Int = 3) -> String {
    let s = String(format: "%.\(d)f", v)
    // "-0.000" and trailing zeros are noise in the file
    var t = s
    if t.contains(".") { while t.hasSuffix("0") { t.removeLast() }; if t.hasSuffix(".") { t.removeLast() } }
    return t == "-0" ? "0" : t
}

/// The client's HTML page: one file, nothing fetched from anywhere, the scene inside.
func client3DHtml(_ s: C3Scene, _ info: C3Info) -> String {
    var groups: [String] = []
    for m in s.meshes {
        let pk = c3Packed(m, s.mid)
        if pk.count == 0 { continue }
        let r = (m.rgb >> 16) & 255, g = (m.rgb >> 8) & 255, b = m.rgb & 255
        groups.append("{c:[\(c3Num(Double(r) / 255)),\(c3Num(Double(g) / 255)),\(c3Num(Double(b) / 255))],o:\(c3Num(m.op, 2)),p:\"\(pk.pos)\",n:\"\(pk.nor)\"}")
    }
    var dims: [String] = []
    if info.dims {
        for d in s.dims {
            let a = d.a - s.mid, b = d.b - s.mid
            dims.append("{a:[\(c3Num(a.x)),\(c3Num(a.y)),\(c3Num(a.z))],b:[\(c3Num(b.x)),\(c3Num(b.y)),\(c3Num(b.z))],t:\(c3Js(d.text))}")
        }
    }
    let t = s.tgt - s.mid
    let data = "var D={g:[" + groups.joined(separator: ",") + "],d:[" + dims.joined(separator: ",") + "],cam:{t:[\(c3Num(t.x)),\(c3Num(t.y)),\(c3Num(t.z))],th:\(c3Num(s.theta, 4)),ph:\(c3Num(s.phi, 4)),r:\(c3Num(s.r))},nogl:\(c3Js(info.noGl))};"
    var bot = "<div class=\"c1\">" + c3Esc(info.line1) + "</div><div class=\"c2\">" + c3Esc(info.line2) + "</div>"
    if let p = info.price { bot += "<div class=\"pr\">" + c3Esc(p) + "</div>" }
    var who = "<span>" + c3Esc(info.master)
    if info.phone != nil { who += ", <span class=\"nw\">" + c3Esc(info.phoneShown) + "</span>" }
    who += "</span>"
    if let ph = info.phone {
        who += "<a class=\"call\" href=\"tel:" + c3Esc(ph) + "\" aria-label=\"" + c3Esc(info.phoneShown) + "\"><svg viewBox=\"0 0 24 24\" width=\"20\" height=\"20\"><path d=\"M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2\" stroke-linejoin=\"round\"/></svg></a>"
    }
    if !info.master.isEmpty { bot += "<div class=\"c3\">" + who + "</div>" }
    var out = C3_HEAD.replacingOccurrences(of: "%LANG%", with: c3Esc(info.lang))
    out = out.replacingOccurrences(of: "%TITLE%", with: c3Esc(info.title))
    out += "<canvas id=\"c\"></canvas><div id=\"lb\"></div>"
    out += "<div class=\"top\"><div class=\"lg\">M</div><div class=\"tx\"><b>METRX</b><small>" + c3Esc(info.title) + "</small></div></div>"
    out += "<div class=\"hint\" id=\"hint\">" + c3Esc(info.hint) + "</div>"
    out += "<div class=\"bot\">" + bot + "</div>"
    out += "<script>" + data + C3_VIEWER + "</script></body></html>"
    return out
}

/// The page's head and styles (the mockup's client viewer, the app's glass look).
let C3_HEAD = """
<!doctype html><html lang="%LANG%"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><title>%TITLE%</title><style>
html,body{margin:0;height:100%;overflow:hidden;background:#E4E8F0;color:#0F172A;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;-webkit-user-select:none;user-select:none}
#c{position:fixed;left:0;top:0;width:100%;height:100%;display:block;touch-action:none}
.top,.bot{position:fixed;left:12px;right:12px;border-radius:20px;background:rgba(255,255,255,.78);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);box-shadow:0 8px 28px rgba(15,23,42,.14);border:1px solid rgba(255,255,255,.9)}
.top{top:12px;display:flex;align-items:center;gap:10px;padding:10px 12px}
.lg{width:36px;height:36px;border-radius:11px;background:#3550E0;color:#fff;font-weight:800;font-size:18px;display:flex;align-items:center;justify-content:center;flex:none}
.tx{min-width:0}.tx b{display:block;font-size:12px;letter-spacing:.14em}.tx small{display:block;font-size:14px;color:#334155;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bot{bottom:12px;padding:12px 14px}
.c1{font-weight:700;font-size:15px}.c2{font-size:13px;color:#475569;margin-top:2px}.pr{font-weight:800;font-size:16px;margin-top:6px}
.c3{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:10px;font-size:14px}.nw{white-space:nowrap}
.call{width:42px;height:42px;border-radius:50%;background:#16A34A;display:flex;align-items:center;justify-content:center;flex:none}
.hint{position:fixed;left:50%;top:76px;transform:translateX(-50%);padding:6px 12px;border-radius:999px;background:rgba(15,23,42,.62);color:#fff;font-size:12.5px;white-space:nowrap;transition:opacity .6s;pointer-events:none}
#lb div{position:fixed;left:0;top:0;padding:2px 7px;border-radius:8px;background:rgba(15,23,42,.8);color:#fff;font-size:11.5px;font-weight:700;white-space:nowrap;pointer-events:none}
</style></head><body>
"""

/// The viewer: WebGL 1, flat-shaded colours, orbit by drag, zoom by pinch or wheel, the dimensions as labels.
let C3_VIEWER = """
(function(){
var cv=document.getElementById('c'),hint=document.getElementById('hint'),lb=document.getElementById('lb');
var gl=cv.getContext('webgl',{antialias:true})||cv.getContext('experimental-webgl');
if(!gl){hint.textContent=D.nogl;return;}
function b64(s){var b=atob(s),n=b.length,u=new Uint8Array(n);for(var i=0;i<n;i++)u[i]=b.charCodeAt(i);return u.buffer;}
function sh(t,s){var o=gl.createShader(t);gl.shaderSource(o,s);gl.compileShader(o);return o;}
var pr=gl.createProgram();
gl.attachShader(pr,sh(gl.VERTEX_SHADER,'attribute vec3 p;attribute vec3 n;uniform mat4 m;uniform float k;varying vec3 vn;void main(){vn=n;gl_Position=m*vec4(p*k,1.0);}'));
gl.attachShader(pr,sh(gl.FRAGMENT_SHADER,'precision mediump float;uniform vec3 c;uniform float o;uniform float f;varying vec3 vn;void main(){vec3 N=normalize(vn);float d=max(dot(N,normalize(vec3(0.45,0.85,0.3))),0.0);float h=0.5+0.5*N.y;vec3 col=mix(c*(0.5+0.22*h+0.36*d),c,f);gl_FragColor=vec4(col,o);}'));
gl.linkProgram(pr);gl.useProgram(pr);
var aP=gl.getAttribLocation(pr,'p'),aN=gl.getAttribLocation(pr,'n'),uM=gl.getUniformLocation(pr,'m'),uK=gl.getUniformLocation(pr,'k'),uC=gl.getUniformLocation(pr,'c'),uO=gl.getUniformLocation(pr,'o'),uF=gl.getUniformLocation(pr,'f');
var G=[];
for(var i=0;i<D.g.length;i++){var g=D.g[i],p=new Int16Array(b64(g.p)),n=new Int8Array(b64(g.n));
var bp=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,bp);gl.bufferData(gl.ARRAY_BUFFER,p,gl.STATIC_DRAW);
var bn=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,bn);gl.bufferData(gl.ARRAY_BUFFER,n,gl.STATIC_DRAW);
G.push({bp:bp,bn:bn,n:p.length/3,c:g.c,o:g.o});}
var L=[],lines=[];for(var j=0;j<D.d.length;j++){var d=D.d[j];lines.push(d.a[0],d.a[1],d.a[2],d.b[0],d.b[1],d.b[2]);var e=document.createElement('div');e.textContent=d.t;lb.appendChild(e);L.push({e:e,p:[(d.a[0]+d.b[0])/2,(d.a[1]+d.b[1])/2,(d.a[2]+d.b[2])/2]});}
var bl=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,bl);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(lines),gl.STATIC_DRAW);
var C=D.cam,tg=C.t.slice(),th=C.th,ph=C.ph,R=C.r,r0=C.r;
function per(f,a,n,x){var t=1/Math.tan(f/2);return [t/a,0,0,0,0,t,0,0,0,0,(x+n)/(n-x),-1,0,0,2*x*n/(n-x),0];}
function mul(a,b){var o=new Array(16);for(var c=0;c<4;c++)for(var r=0;r<4;r++){var s=0;for(var k=0;k<4;k++)s+=a[k*4+r]*b[c*4+k];o[c*4+r]=s;}return o;}
function look(e,t){var z=[e[0]-t[0],e[1]-t[1],e[2]-t[2]],l=Math.hypot(z[0],z[1],z[2]);z=[z[0]/l,z[1]/l,z[2]/l];var x=[z[2],0,-z[0]];l=Math.hypot(x[0],x[2])||1;x=[x[0]/l,0,x[2]/l];var y=[z[1]*x[2]-z[2]*x[1],z[2]*x[0]-z[0]*x[2],z[0]*x[1]-z[1]*x[0]];
return [x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-(x[0]*e[0]+x[1]*e[1]+x[2]*e[2]),-(y[0]*e[0]+y[1]*e[1]+y[2]*e[2]),-(z[0]*e[0]+z[1]*e[1]+z[2]*e[2]),1];}
var M=null,dirty=false;
function draw(){dirty=false;var w=cv.clientWidth,h=cv.clientHeight,dp=Math.min(window.devicePixelRatio||1,2);if(cv.width!==Math.round(w*dp)||cv.height!==Math.round(h*dp)){cv.width=Math.round(w*dp);cv.height=Math.round(h*dp);}
gl.viewport(0,0,cv.width,cv.height);gl.clearColor(0.894,0.910,0.941,1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
var e=[tg[0]+R*Math.cos(ph)*Math.sin(th),tg[1]+R*Math.sin(ph),tg[2]+R*Math.cos(ph)*Math.cos(th)];
M=mul(per(0.7,w/Math.max(1,h),0.05,200),look(e,tg));gl.uniformMatrix4fv(uM,false,new Float32Array(M));
gl.enable(gl.DEPTH_TEST);gl.enable(gl.CULL_FACE);gl.disable(gl.BLEND);gl.depthMask(true);gl.uniform1f(uK,0.001);gl.uniform1f(uF,0);
for(var pass=0;pass<2;pass++){if(pass===1){gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(false);}
for(var i=0;i<G.length;i++){var g=G[i];if((g.o<0.99)!==(pass===1))continue;
gl.bindBuffer(gl.ARRAY_BUFFER,g.bp);gl.enableVertexAttribArray(aP);gl.vertexAttribPointer(aP,3,gl.SHORT,false,0,0);
gl.bindBuffer(gl.ARRAY_BUFFER,g.bn);gl.enableVertexAttribArray(aN);gl.vertexAttribPointer(aN,3,gl.BYTE,true,0,0);
gl.uniform3f(uC,g.c[0],g.c[1],g.c[2]);gl.uniform1f(uO,g.o);gl.drawArrays(gl.TRIANGLES,0,g.n);}}
gl.depthMask(true);gl.disable(gl.BLEND);
if(lines.length){gl.disable(gl.DEPTH_TEST);gl.uniform1f(uK,1);gl.uniform1f(uF,1);gl.bindBuffer(gl.ARRAY_BUFFER,bl);gl.vertexAttribPointer(aP,3,gl.FLOAT,false,0,0);
gl.disableVertexAttribArray(aN);gl.vertexAttrib3f(aN,0,1,0);gl.uniform3f(uC,0.06,0.09,0.16);gl.uniform1f(uO,1);gl.drawArrays(gl.LINES,0,lines.length/3);}
for(var j=0;j<L.length;j++){var q=L[j].p,x=M[0]*q[0]+M[4]*q[1]+M[8]*q[2]+M[12],y=M[1]*q[0]+M[5]*q[1]+M[9]*q[2]+M[13],ww=M[3]*q[0]+M[7]*q[1]+M[11]*q[2]+M[15];
if(ww<=0.01){L[j].e.style.display='none';continue;}L[j].e.style.display='';L[j].e.style.transform='translate('+((x/ww+1)/2*w)+'px,'+((1-y/ww)/2*h)+'px) translate(-50%,-50%)';}}
function kick(){if(!dirty){dirty=true;requestAnimationFrame(draw);}}
var P={},pd=0,hid=false;
function hide(){if(!hid){hid=true;hint.style.opacity='0';}}
cv.addEventListener('pointerdown',function(ev){cv.setPointerCapture(ev.pointerId);P[ev.pointerId]=[ev.clientX,ev.clientY];var k=Object.keys(P);if(k.length===2){var a=P[k[0]],b=P[k[1]];pd=Math.hypot(a[0]-b[0],a[1]-b[1]);}hide();});
cv.addEventListener('pointermove',function(ev){var o=P[ev.pointerId];if(!o)return;var k=Object.keys(P);
if(k.length===1){th-=(ev.clientX-o[0])*0.008;ph=Math.max(0.05,Math.min(1.45,ph+(ev.clientY-o[1])*0.006));}
P[ev.pointerId]=[ev.clientX,ev.clientY];
if(k.length===2){var a=P[k[0]],b=P[k[1]],dd=Math.hypot(a[0]-b[0],a[1]-b[1]);if(pd>0)R=Math.max(r0*0.25,Math.min(r0*2.2,R*pd/dd));pd=dd;}kick();});
function up(ev){delete P[ev.pointerId];pd=0;}
cv.addEventListener('pointerup',up);cv.addEventListener('pointercancel',up);
cv.addEventListener('wheel',function(ev){ev.preventDefault();R=Math.max(r0*0.25,Math.min(r0*2.2,R*Math.exp(ev.deltaY*0.001)));hide();kick();},{passive:false});
window.addEventListener('resize',kick);setTimeout(hide,4500);kick();
})();
"""

/* ---------------- the USDZ ---------------- */

/// sRGB 0…255 to linear 0…1 (UsdPreviewSurface colours are linear).
private func c3Lin(_ c: Int) -> Double {
    let s = Double(c) / 255
    return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
}

/// The scene as a USDA layer: metres, Y up, one mesh a colour with a UsdPreviewSurface material, the floor's middle at
/// the origin; faces single-sided (walls turned away are not drawn).
func client3DUsda(_ s: C3Scene) -> String {
    var out = "#usda 1.0\n(\n    defaultPrim = \"Root\"\n    metersPerUnit = 1\n    upAxis = \"Y\"\n)\n\ndef Xform \"Root\" (\n    kind = \"component\"\n)\n{\n"
    out += "    def Scope \"Materials\"\n    {\n"
    for (i, m) in s.meshes.enumerated() {
        let r = c3Lin((m.rgb >> 16) & 255), g = c3Lin((m.rgb >> 8) & 255), b = c3Lin(m.rgb & 255)
        out += "        def Material \"M\(i)\"\n        {\n"
        out += "            token outputs:surface.connect = </Root/Materials/M\(i)/Surface.outputs:surface>\n\n"
        out += "            def Shader \"Surface\"\n            {\n"
        out += "                uniform token info:id = \"UsdPreviewSurface\"\n"
        out += "                color3f inputs:diffuseColor = (\(c3Num(r, 4)), \(c3Num(g, 4)), \(c3Num(b, 4)))\n"
        out += "                float inputs:metallic = 0\n"
        out += "                float inputs:opacity = \(c3Num(m.op, 2))\n"
        out += "                float inputs:roughness = 0.6\n"
        out += "                token outputs:surface\n            }\n        }\n"
    }
    out += "    }\n"
    for (i, m) in s.meshes.enumerated() {
        var counts: [String] = [], idx: [String] = [], pts: [String] = [], nrm: [String] = []
        var lo = V3(1e9, 1e9, 1e9), hi = V3(-1e9, -1e9, -1e9)
        var k = 0
        for (j, poly) in m.polys.enumerated() {
            counts.append("\(poly.count)")
            let n = m.norms[j]
            let ns = "(\(c3Num(n.x, 4)), \(c3Num(n.y, 4)), \(c3Num(n.z, 4)))"
            for q0 in poly {
                let q = q0 - s.mid
                lo = V3(min(lo.x, q.x), min(lo.y, q.y), min(lo.z, q.z)); hi = V3(max(hi.x, q.x), max(hi.y, q.y), max(hi.z, q.z))
                pts.append("(\(c3Num(q.x)), \(c3Num(q.y)), \(c3Num(q.z)))")
                nrm.append(ns)
                idx.append("\(k)"); k += 1
            }
        }
        out += "\n    def Mesh \"G\(i)\" (\n        prepend apiSchemas = [\"MaterialBindingAPI\"]\n    )\n    {\n"
        out += "        uniform bool doubleSided = 0\n"
        out += "        float3[] extent = [(\(c3Num(lo.x)), \(c3Num(lo.y)), \(c3Num(lo.z))), (\(c3Num(hi.x)), \(c3Num(hi.y)), \(c3Num(hi.z)))]\n"
        out += "        int[] faceVertexCounts = [" + counts.joined(separator: ", ") + "]\n"
        out += "        int[] faceVertexIndices = [" + idx.joined(separator: ", ") + "]\n"
        out += "        rel material:binding = </Root/Materials/M\(i)>\n"
        out += "        normal3f[] normals = [" + nrm.joined(separator: ", ") + "] (\n            interpolation = \"faceVarying\"\n        )\n"
        out += "        point3f[] points = [" + pts.joined(separator: ", ") + "]\n"
        out += "        uniform token orientation = \"rightHanded\"\n"
        out += "        uniform token subdivisionScheme = \"none\"\n    }\n"
    }
    out += "}\n"
    return out
}

/// CRC-32 (zip's).
func c3Crc32(_ d: Data) -> UInt32 {
    var table = [UInt32](repeating: 0, count: 256)
    for i in 0..<256 {
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        table[i] = c
    }
    var crc: UInt32 = 0xFFFFFFFF
    for b in d { crc = table[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8) }
    return crc ^ 0xFFFFFFFF
}

private func c3Le16(_ d: inout Data, _ v: Int) { let x = UInt16(truncatingIfNeeded: v); d.append(UInt8(x & 0xFF)); d.append(UInt8(x >> 8)) }
private func c3Le32(_ d: inout Data, _ v: UInt32) { for k in 0..<4 { d.append(UInt8((v >> (8 * UInt32(k))) & 0xFF)) } }

/// The files as an uncompressed zip whose every file's data starts on a 64-byte boundary (a USDZ package).
func c3Zip(_ files: [(String, Data)]) -> Data {
    var out = Data(), cd = Data()
    for (name, data) in files {
        let nm = Data(name.utf8)
        let crc = c3Crc32(data)
        let at = out.count
        // the data after the 30-byte header, the name and the padding field (id 0x1986, its size) lands 64-aligned
        let before = at + 30 + nm.count + 4
        let pad = (64 - before % 64) % 64
        out.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
        c3Le16(&out, 20); c3Le16(&out, 0); c3Le16(&out, 0); c3Le16(&out, 0); c3Le16(&out, 0x21)
        c3Le32(&out, crc); c3Le32(&out, UInt32(data.count)); c3Le32(&out, UInt32(data.count))
        c3Le16(&out, nm.count); c3Le16(&out, 4 + pad)
        out.append(nm)
        c3Le16(&out, 0x1986); c3Le16(&out, pad)
        out.append(Data(repeating: 0, count: pad))
        out.append(data)
        cd.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
        c3Le16(&cd, 20); c3Le16(&cd, 20); c3Le16(&cd, 0); c3Le16(&cd, 0); c3Le16(&cd, 0); c3Le16(&cd, 0x21)
        c3Le32(&cd, crc); c3Le32(&cd, UInt32(data.count)); c3Le32(&cd, UInt32(data.count))
        c3Le16(&cd, nm.count); c3Le16(&cd, 0); c3Le16(&cd, 0); c3Le16(&cd, 0); c3Le16(&cd, 0); c3Le32(&cd, 0); c3Le32(&cd, UInt32(at))
        cd.append(nm)
    }
    let cdAt = out.count
    out.append(cd)
    out.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
    c3Le16(&out, 0); c3Le16(&out, 0); c3Le16(&out, files.count); c3Le16(&out, files.count)
    c3Le32(&out, UInt32(cd.count)); c3Le32(&out, UInt32(cdAt)); c3Le16(&out, 0)
    return out
}

/// The scene as a USDZ package: its USDA layer, uncompressed and aligned.
func client3DUsdz(_ s: C3Scene) -> Data { c3Zip([("model.usda", Data(client3DUsda(s).utf8))]) }

/// The HTML must stay a size a messenger sends at once.
let C3_HTML_MAX = 2_000_000
