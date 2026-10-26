package uz.metrx.app.share

import uz.metrx.app.geo.Part
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.TEXTURES
import uz.metrx.app.geo.V3
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Base64
import java.util.zip.CRC32
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt

/*
 * "Mijozga 3D yuborish", the client's 3D file (Joylan ideas, founder 26 Oct 2026; the approved mockup's share sheet and
 * client viewer). Two files made on the phone, no server, no account:
 *  - an HTML page with everything inside (a small WebGL viewer and the model as base64 arrays: positions in mm as int16,
 *    normals as int8, one flat colour per look), opened offline in any phone's browser; no http(s) address in it;
 *  - a USDZ for iPhone's Quick Look and AR: a zip, stored, each file 64-byte aligned, with one ASCII .usda in it (a mesh a
 *    look, UsdPreviewSurface materials).
 * Pure Kotlin, unit-tested (Client3DTest); ui/furniture/Share3D.kt builds the scene and opens the share sheet.
 */

/** One look of the model: its sRGB colour, opacity, roughness and metalness. */
data class C3Mat(val rgb: Int, val alpha: Float, val rough: Float, val metal: Float)

/** The triangles of one look (and of one wall, [wall], hidden when the eye is behind it): xyz in metres, a normal each corner. */
class C3Group(val mat: Int, val wall: String?, val pos: FloatArray, val nrm: FloatArray) { val verts: Int get() = pos.size / 3 }

/** A wall's inner face: a point on it and the way into the room (the viewer hides the walls the eye is behind). */
data class C3Wall(val id: String, val ox: Double, val oz: Double, val nx: Double, val nz: Double)

/** A dimension line from [a] to [b] with its text. */
data class C3Dim(val a: V3, val b: V3, val text: String)

class C3Mesh(val mats: List<C3Mat>, val groups: List<C3Group>) {
    val triangles: Int get() = groups.sumOf { it.verts } / 3
    /** The bounds of what is not a wall or the floor (the furniture), metres: min x, y, z, max x, y, z. */
    var focus: DoubleArray = doubleArrayOf(0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
}

/** A part's colour as a flat look: its decor picture's average colour, else its own. */
private fun flatRgb(p: Part): Int = p.look?.let { l -> l.tex?.takeIf { !l.tint }?.let { TEXTURES[it]?.avg } ?: l.rgb } ?: p.rgb

/**
 * The triangles of [parts] by look (furniture) and by wall (the room's walls, its openings and glass). Every triangle
 * is wound counter-clockwise seen from where its normal points, so both files draw one side only (as the iPhone's);
 * of a wall ([inward]: each wall's way into the room) only its inside faces are kept.
 */
fun meshOf(parts: List<Part>, inward: Map<String, Pair<Double, Double>> = emptyMap()): C3Mesh {
    val mats = ArrayList<C3Mat>(); val idx = HashMap<C3Mat, Int>()
    class Acc(val mat: Int, val wall: String?) { val p = ArrayList<Float>(); val n = ArrayList<Float>() }
    val accs = LinkedHashMap<Pair<Int, String?>, Acc>()
    var x0 = Double.MAX_VALUE; var y0 = Double.MAX_VALUE; var z0 = Double.MAX_VALUE; var x1 = -Double.MAX_VALUE; var y1 = -Double.MAX_VALUE; var z1 = -Double.MAX_VALUE
    for (part in parts) {
        val l = part.look
        val alpha = ((l?.alpha ?: 1f) * part.op).coerceIn(.05f, 1f)
        val m = C3Mat(flatRgb(part), (alpha * 20).roundToInt() / 20f, ((l?.rough ?: .8f) * 10).roundToInt() / 10f, ((l?.metal ?: 0f) * 10).roundToInt() / 10f)
        val mi = idx.getOrPut(m) { mats += m; mats.size - 1 }
        val wall = if (part.role == Role.FURN || part.role == Role.FLOOR) null else part.wall
        val acc = accs.getOrPut(mi to wall) { Acc(mi, wall) }
        val furn = part.role == Role.FURN
        val inn = if (part.role == Role.WALL) part.wall?.let { inward[it] } else null
        for (f in part.faces) {
            if (inn != null && f.n.x * inn.first + f.n.z * inn.second < .5) continue
            val tris = f.tris ?: (1 until f.pts.size - 1).flatMap { listOf(0, it, it + 1) }
            for (t in 0 until tris.size / 3) {
                val a = f.pts.getOrNull(tris[t * 3]) ?: continue; var b = f.pts.getOrNull(tris[t * 3 + 1]) ?: continue; var c = f.pts.getOrNull(tris[t * 3 + 2]) ?: continue
                val e1 = b - a; val e2 = c - a
                val cr = V3(e1.y * e2.z - e1.z * e2.y, e1.z * e2.x - e1.x * e2.z, e1.x * e2.y - e1.y * e2.x)
                if (cr.dot(f.n) < 0) { val s = b; b = c; c = s }
                for (q in listOf(a, b, c)) {
                    acc.p += q.x.toFloat(); acc.p += q.y.toFloat(); acc.p += q.z.toFloat()
                    acc.n += f.n.x.toFloat(); acc.n += f.n.y.toFloat(); acc.n += f.n.z.toFloat()
                    if (furn) { x0 = minOf(x0, q.x); y0 = minOf(y0, q.y); z0 = minOf(z0, q.z); x1 = max(x1, q.x); y1 = max(y1, q.y); z1 = max(z1, q.z) }
                }
            }
        }
    }
    val mesh = C3Mesh(mats, accs.values.filter { it.p.isNotEmpty() }.map { C3Group(it.mat, it.wall, it.p.toFloatArray(), it.n.toFloatArray()) })
    if (x0 <= x1) mesh.focus = doubleArrayOf(x0, y0, z0, x1, y1, z1)
    return mesh
}

/* ---------------- the HTML page ---------------- */

/**
 * What the page says round the model: the [order]'s name, the [title] (layout and units) and [sub] (the room and the
 * date), the price line (null: not shown), the maker's name and phone (null: not shown), the dimension lines (none:
 * not shown), the hint and the line for a phone without WebGL; [az] the angle the camera starts from (radians, as
 * ui/three/CardCache.kt cardBack), [lang] the page's language code.
 */
class C3Info(
    val order: String, val title: String, val sub: String, val price: String?, val maker: String, val phone: String?,
    val dims: List<C3Dim>, val walls: List<C3Wall>, val hint: String, val noGl: String, val makerWord: String,
    val az: Double = .6, val lang: String = "uz"
)

private fun esc(s: String) = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
private fun jsStr(s: String) = buildString {
    append('"')
    for (c in s) when (c) {
        '"' -> append("\\\""); '\\' -> append("\\\\"); '\n' -> append("\\n"); '<' -> append("\\u003c"); '>' -> append("\\u003e")
        else -> if (c.code < 0x20) append("\\u%04x".format(c.code)) else append(c)
    }
    append('"')
}
private fun f3(v: Double) = String.format(java.util.Locale.ROOT, "%.3f", v)

private fun b64(b: ByteArray): String = Base64.getEncoder().encodeToString(b)

/** Positions in mm as little-endian int16. */
private fun posBytes(p: FloatArray): ByteArray {
    val bb = ByteBuffer.allocate(p.size * 2).order(ByteOrder.LITTLE_ENDIAN)
    for (v in p) bb.putShort((v * 1000).roundToInt().coerceIn(-32767, 32767).toShort())
    return bb.array()
}

/** Normals as int8 (×127). */
private fun nrmBytes(n: FloatArray): ByteArray = ByteArray(n.size) { (n[it] * 127).roundToInt().coerceIn(-127, 127).toByte() }

/** The model as the page's script reads it (JSON). */
private fun modelJson(mesh: C3Mesh, info: C3Info): String = buildString {
    append("{\"m\":[")
    append(mesh.mats.joinToString(",") { m -> "[${(m.rgb shr 16) and 255},${(m.rgb shr 8) and 255},${m.rgb and 255},${m.alpha},${m.rough},${m.metal}]" })
    append("],\"g\":[")
    append(mesh.groups.joinToString(",") { g -> "[${g.mat},${g.wall?.let(::jsStr) ?: "null"},${g.verts},\"${b64(posBytes(g.pos))}\",\"${b64(nrmBytes(g.nrm))}\"]" })
    append("],\"w\":{")
    append(info.walls.joinToString(",") { w -> "${jsStr(w.id)}:[${f3(w.ox)},${f3(w.oz)},${f3(w.nx)},${f3(w.nz)}]" })
    append("},\"f\":[").append(mesh.focus.joinToString(",") { f3(it) }).append("]")
    append(",\"az\":").append(f3(info.az))
    append(",\"d\":[")
    append(info.dims.joinToString(",") { d -> "[${f3(d.a.x)},${f3(d.a.y)},${f3(d.a.z)},${f3(d.b.x)},${f3(d.b.y)},${f3(d.b.z)},${jsStr(d.text)}]" })
    append("],\"nogl\":").append(jsStr(info.noGl))
    append("}")
}

/** The viewer: WebGL 1, orbit by a finger, pinch or the wheel to zoom, a double tap back to the start; walls the eye is behind are hidden. */
private const val VIEWER = """(function(){
var M=window.MODEL,cv=document.getElementById('c'),ov=document.getElementById('o'),cx=ov.getContext('2d');
var gl=cv.getContext('webgl',{antialias:true})||cv.getContext('experimental-webgl');
if(!gl){document.getElementById('hint').textContent=M.nogl;return;}
function bytes(s){var b=atob(s),u=new Uint8Array(b.length);for(var i=0;i<b.length;i++)u[i]=b.charCodeAt(i);return u.buffer;}
function sh(t,src){var s=gl.createShader(t);gl.shaderSource(s,src);gl.compileShader(s);return s;}
var pg=gl.createProgram();
gl.attachShader(pg,sh(gl.VERTEX_SHADER,'attribute vec3 p;attribute vec3 n;uniform mat4 vp;varying vec3 vn;varying vec3 vw;void main(){vec3 q=p*0.001;vw=q;vn=n;gl_Position=vp*vec4(q,1.0);}'));
gl.attachShader(pg,sh(gl.FRAGMENT_SHADER,'precision mediump float;uniform vec4 col;uniform vec3 eye;uniform vec3 ld;uniform vec2 rm;varying vec3 vn;varying vec3 vw;void main(){vec3 N=normalize(vn);vec3 V=normalize(eye-vw);if(dot(N,V)<0.0)N=-N;float d=max(dot(N,ld),0.0);float h=0.5+0.5*N.y;vec3 amb=mix(vec3(0.62,0.58,0.54),vec3(1.0,1.0,1.02),h)*0.62;vec3 H=normalize(ld+V);float g=1.0-rm.x;float sp=pow(max(dot(N,H),0.0),mix(6.0,90.0,g))*g*0.45;float fr=pow(1.0-max(dot(N,V),0.0),4.0)*0.18*g;vec3 c=col.rgb*mix(vec3(1.0),vec3(0.75),rm.y);vec3 o=c*(amb+vec3(1.0,0.97,0.92)*d*0.5+0.12*max(dot(N,V),0.0))+vec3(sp+fr);gl_FragColor=vec4(min(o,vec3(1.0)),col.a);}'));
gl.linkProgram(pg);gl.useProgram(pg);
var aP=gl.getAttribLocation(pg,'p'),aN=gl.getAttribLocation(pg,'n'),uVP=gl.getUniformLocation(pg,'vp'),uC=gl.getUniformLocation(pg,'col'),uE=gl.getUniformLocation(pg,'eye'),uL=gl.getUniformLocation(pg,'ld'),uR=gl.getUniformLocation(pg,'rm');
gl.enableVertexAttribArray(aP);gl.enableVertexAttribArray(aN);
var G=M.g.map(function(g){var pb=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,pb);gl.bufferData(gl.ARRAY_BUFFER,new Int16Array(bytes(g[3])),gl.STATIC_DRAW);var nb=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,nb);gl.bufferData(gl.ARRAY_BUFFER,new Int8Array(bytes(g[4])),gl.STATIC_DRAW);var m=M.m[g[0]];return {m:m,w:g[1],n:g[2],pb:pb,nb:nb,t:m[3]<0.99};});
var F=M.f,T=[(F[0]+F[3])/2,(F[1]+F[4])/2,(F[2]+F[5])/2],R=Math.max(0.6,Math.sqrt(Math.pow(F[3]-F[0],2)+Math.pow(F[4]-F[1],2)+Math.pow(F[5]-F[2],2))/2);
var FOV=0.75,S0={az:M.az,el:0.42,d:R/Math.sin(FOV/2)*1.08,t:T.slice()},S={az:S0.az,el:S0.el,d:S0.d,t:T.slice()};
function eyeOf(){return [S.t[0]+S.d*Math.sin(S.az)*Math.cos(S.el),S.t[1]+S.d*Math.sin(S.el),S.t[2]+S.d*Math.cos(S.az)*Math.cos(S.el)];}
function mul(a,b){var o=new Float32Array(16);for(var i=0;i<4;i++)for(var j=0;j<4;j++){var s=0;for(var k=0;k<4;k++)s+=a[k*4+j]*b[i*4+k];o[i*4+j]=s;}return o;}
function look(e,t){var f=[t[0]-e[0],t[1]-e[1],t[2]-e[2]],l=Math.hypot(f[0],f[1],f[2]);f=[f[0]/l,f[1]/l,f[2]/l];var s=[f[1]*0-f[2]*1,f[2]*0-f[0]*0,f[0]*1-f[1]*0];l=Math.hypot(s[0],s[1],s[2]);s=[s[0]/l,s[1]/l,s[2]/l];var u=[s[1]*f[2]-s[2]*f[1],s[2]*f[0]-s[0]*f[2],s[0]*f[1]-s[1]*f[0]];
return new Float32Array([s[0],u[0],-f[0],0,s[1],u[1],-f[1],0,s[2],u[2],-f[2],0,-(s[0]*e[0]+s[1]*e[1]+s[2]*e[2]),-(u[0]*e[0]+u[1]*e[1]+u[2]*e[2]),f[0]*e[0]+f[1]*e[1]+f[2]*e[2],1]);}
function persp(a,n,fa){var f=1/Math.tan(FOV/2);return new Float32Array([f/a,0,0,0,0,f,0,0,0,0,(fa+n)/(n-fa),-1,0,0,2*fa*n/(n-fa),0]);}
var VP=null,W=0,H=0,dpr=Math.min(window.devicePixelRatio||1,2),raf=0;
var moved=false;function fit(){var a=W/Math.max(H,1),h=Math.atan(Math.tan(FOV/2)*Math.min(1,a));return R/Math.sin(h)*1.04;}
function size(){W=cv.clientWidth;H=cv.clientHeight;if(!moved){S0.d=fit();S.d=S0.d;}cv.width=W*dpr;cv.height=H*dpr;ov.width=W*dpr;ov.height=H*dpr;kick();}
function hidden(w,e){var q=M.w[w];if(!q)return false;return (e[0]-q[0])*q[2]+(e[2]-q[1])*q[3]<-0.05;}
function proj(p){var x=VP[0]*p[0]+VP[4]*p[1]+VP[8]*p[2]+VP[12],y=VP[1]*p[0]+VP[5]*p[1]+VP[9]*p[2]+VP[13],w=VP[3]*p[0]+VP[7]*p[1]+VP[11]*p[2]+VP[15];if(w<0.01)return null;return [(x/w+1)/2*W,(1-y/w)/2*H];}
function dims(){cx.setTransform(dpr,0,0,dpr,0,0);cx.clearRect(0,0,W,H);cx.font='700 12px system-ui,sans-serif';cx.textAlign='center';cx.textBaseline='middle';
M.d.forEach(function(d){var a=proj([d[0],d[1],d[2]]),b=proj([d[3],d[4],d[5]]);if(!a||!b)return;cx.strokeStyle='#3550E0';cx.lineWidth=1.6;cx.beginPath();cx.moveTo(a[0],a[1]);cx.lineTo(b[0],b[1]);cx.stroke();
var dx=b[0]-a[0],dy=b[1]-a[1],l=Math.hypot(dx,dy)||1,nx=-dy/l*5,ny=dx/l*5;cx.beginPath();cx.moveTo(a[0]-nx,a[1]-ny);cx.lineTo(a[0]+nx,a[1]+ny);cx.moveTo(b[0]-nx,b[1]-ny);cx.lineTo(b[0]+nx,b[1]+ny);cx.stroke();
var mx=(a[0]+b[0])/2,my=(a[1]+b[1])/2,tw=cx.measureText(d[6]).width+12;cx.fillStyle='rgba(255,255,255,.92)';cx.fillRect(mx-tw/2,my-10,tw,20);cx.fillStyle='#2B47D9';cx.fillText(d[6],mx,my);});}
function draw(){raf=0;var e=eyeOf();VP=mul(persp(W/Math.max(H,1),0.05,R*30+20),look(e,S.t));gl.viewport(0,0,cv.width,cv.height);gl.clearColor(0.91,0.925,0.95,1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.enable(gl.DEPTH_TEST);gl.enable(gl.CULL_FACE);
gl.uniformMatrix4fv(uVP,false,VP);gl.uniform3f(uE,e[0],e[1],e[2]);var ll=[0.45,0.8,0.4],lq=Math.hypot(ll[0],ll[1],ll[2]);gl.uniform3f(uL,ll[0]/lq,ll[1]/lq,ll[2]/lq);
[false,true].forEach(function(tr){if(tr){gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(false);}else{gl.disable(gl.BLEND);gl.depthMask(true);}
G.forEach(function(g){if(g.t!==tr)return;if(g.w&&hidden(g.w,e))return;gl.uniform4f(uC,g.m[0]/255,g.m[1]/255,g.m[2]/255,g.m[3]);gl.uniform2f(uR,g.m[4],g.m[5]);gl.bindBuffer(gl.ARRAY_BUFFER,g.pb);gl.vertexAttribPointer(aP,3,gl.SHORT,false,0,0);gl.bindBuffer(gl.ARRAY_BUFFER,g.nb);gl.vertexAttribPointer(aN,3,gl.BYTE,true,0,0);gl.drawArrays(gl.TRIANGLES,0,g.n);});});
gl.depthMask(true);dims();}
function kick(){if(!raf)raf=requestAnimationFrame(draw);}
var pts={},last=null,pinch=0,tap=0;
cv.addEventListener('pointerdown',function(ev){moved=true;cv.setPointerCapture(ev.pointerId);pts[ev.pointerId]=[ev.clientX,ev.clientY];document.getElementById('hint').style.opacity=0;var now=Date.now();if(Object.keys(pts).length===1){if(now-tap<300){S.az=S0.az;S.el=S0.el;S.d=S0.d;S.t=S0.t.slice();kick();}tap=now;}});
cv.addEventListener('pointermove',function(ev){var p=pts[ev.pointerId];if(!p)return;var k=Object.keys(pts);if(k.length===1){S.az-=(ev.clientX-p[0])*0.008;S.el=Math.max(0.03,Math.min(1.5,S.el+(ev.clientY-p[1])*0.006));}
pts[ev.pointerId]=[ev.clientX,ev.clientY];if(k.length===2){var a=pts[k[0]],b=pts[k[1]],dd=Math.hypot(a[0]-b[0],a[1]-b[1]);if(pinch)S.d=Math.max(R*0.35,Math.min(R*6,S.d*pinch/dd));pinch=dd;}kick();});
function up(ev){delete pts[ev.pointerId];pinch=0;}
cv.addEventListener('pointerup',up);cv.addEventListener('pointercancel',up);
cv.addEventListener('wheel',function(ev){ev.preventDefault();moved=true;S.d=Math.max(R*0.35,Math.min(R*6,S.d*Math.exp(ev.deltaY*0.001)));kick();},{passive:false});
window.addEventListener('resize',size);size();
setTimeout(function(){document.getElementById('hint').style.opacity=0;},7000);
})();"""

private const val STYLE = """*{box-sizing:border-box}html,body{margin:0;height:100%;overflow:hidden;background:#E8ECF2;font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;color:#0F172A;-webkit-tap-highlight-color:transparent}
#c,#o{position:fixed;inset:0;width:100%;height:100%;display:block;touch-action:none}#o{pointer-events:none}
.top{position:fixed;z-index:4;top:0;left:0;right:0;display:flex;align-items:center;gap:10px;padding:12px 14px 10px;background:linear-gradient(180deg,rgba(255,255,255,.94),rgba(255,255,255,.6));-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);border-bottom:1px solid rgba(255,255,255,.8)}
.lg{flex:none;width:32px;height:32px;border-radius:10px;background:#3550E0;color:#fff;display:grid;place-items:center;font:800 13px system-ui,sans-serif}
.tx{min-width:0;flex:1}.tx b{display:block;font:800 11px/1.1 system-ui,sans-serif;letter-spacing:.18em}.tx small{display:block;font:700 13px/1.25 system-ui,sans-serif;color:#334155;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.hint{position:fixed;z-index:3;top:70px;left:50%;transform:translateX(-50%);padding:6px 12px;border-radius:99px;background:rgba(255,255,255,.85);font:600 12px system-ui,sans-serif;color:#334155;transition:opacity .6s;white-space:nowrap}
.bot{position:fixed;z-index:4;left:10px;right:10px;bottom:10px;padding:11px 14px;border-radius:20px;background:rgba(255,255,255,.9);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);box-shadow:0 8px 22px rgba(20,30,80,.18);font-size:12.5px;line-height:1.35;max-width:560px;margin:0 auto}
.c1{font:800 13.5px system-ui,sans-serif}.c2{color:#475569;margin-top:1px}.pr{margin-top:5px;font:800 13.5px system-ui,sans-serif;color:#2B47D9}
.c3{display:flex;align-items:center;gap:8px;margin-top:8px;padding-top:8px;border-top:1px solid rgba(15,23,42,.08);font-weight:700}.c3 span{flex:1;min-width:0}
.call{flex:none;width:34px;height:34px;border-radius:50%;background:#16A34A;display:grid;place-items:center;text-decoration:none}.call svg{width:16px;height:16px;stroke:#fff;fill:none;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}"""

/** The client's page: one file, everything inside, nothing fetched (no http or https address anywhere in it). */
fun clientHtml(mesh: C3Mesh, info: C3Info): String = buildString {
    append("<!doctype html><html lang=\"").append(esc(info.lang)).append("\"><head><meta charset=\"utf-8\">")
    append("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,viewport-fit=cover\">")
    append("<title>").append(esc(info.order)).append(" · METRX</title><style>").append(STYLE).append("</style></head><body>")
    append("<canvas id=\"c\"></canvas><canvas id=\"o\"></canvas>")
    append("<div class=\"top\"><span class=\"lg\">M</span><div class=\"tx\"><b>METRX</b><small>").append(esc(info.order)).append("</small></div></div>")
    append("<div class=\"hint\" id=\"hint\">").append(esc(info.hint)).append("</div>")
    append("<div class=\"bot\"><div class=\"c1\">").append(esc(info.title)).append("</div><div class=\"c2\">").append(esc(info.sub)).append("</div>")
    if (info.price != null) append("<div class=\"pr\">").append(esc(info.price)).append("</div>")
    append("<div class=\"c3\"><span>").append(esc(info.makerWord))
    if (info.phone != null) append(", <span style=\"white-space:nowrap\">").append(esc(info.phone)).append("</span>")
    append("</span>")
    if (info.phone != null) append("<a class=\"call\" href=\"tel:").append(esc(info.phone.filter { it.isDigit() || it == '+' }))
        .append("\" aria-label=\"").append(esc(info.phone)).append("\"><svg viewBox=\"0 0 24 24\"><path d=\"M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2\"/></svg></a>")
    append("</div></div>")
    append("<script>window.MODEL=").append(modelJson(mesh, info)).append(";</script>")
    append("<script>").append(VIEWER).append("</script></body></html>")
}

/* ---------------- the USDZ ---------------- */

private fun lin(c: Int): Double { val v = c / 255.0; return if (v <= .04045) v / 12.92 else ((v + .055) / 1.055).pow(2.4) }
private fun n4(v: Double) = String.format(java.util.Locale.ROOT, "%.4f", v).trimEnd('0').trimEnd('.').let { if (it == "-0" || it.isEmpty()) "0" else it }
private fun n3(v: Float): String {
    val r = (v * 1000).roundToInt()
    if (r == 0) return "0"
    val s = abs(r).toString().padStart(4, '0')
    val txt = (s.dropLast(3) + "." + s.takeLast(3)).trimEnd('0').trimEnd('.')
    return if (r < 0) "-$txt" else txt
}

/** The model as ASCII USD: Y up, metres; a mesh a look with its UsdPreviewSurface (colour in linear light, roughness, metalness, opacity). */
fun usda(mesh: C3Mesh, name: String = "METRX"): String = buildString {
    append("#usda 1.0\n(\n    defaultPrim = \"Root\"\n    metersPerUnit = 1\n    upAxis = \"Y\"\n    doc = \"").append(name.replace("\"", "'").replace("\n", " ")).append("\"\n)\n\n")
    append("def Xform \"Root\" (\n    kind = \"component\"\n)\n{\n")
    append("    def Scope \"Looks\"\n    {\n")
    mesh.mats.forEachIndexed { i, m ->
        append("        def Material \"M$i\"\n        {\n")
        append("            token outputs:surface.connect = </Root/Looks/M$i/PBR.outputs:surface>\n")
        append("            def Shader \"PBR\"\n            {\n                uniform token info:id = \"UsdPreviewSurface\"\n")
        append("                color3f inputs:diffuseColor = (").append(n4(lin((m.rgb shr 16) and 255))).append(", ").append(n4(lin((m.rgb shr 8) and 255))).append(", ").append(n4(lin(m.rgb and 255))).append(")\n")
        append("                float inputs:roughness = ").append(n4(m.rough.toDouble().coerceIn(.05, 1.0))).append("\n")
        append("                float inputs:metallic = ").append(n4(m.metal.toDouble())).append("\n")
        if (m.alpha < .99f) append("                float inputs:opacity = ").append(n4(m.alpha.toDouble())).append("\n")
        append("                token outputs:surface\n            }\n        }\n")
    }
    append("    }\n")
    mesh.groups.forEachIndexed { gi, g ->
        val n = g.verts
        append("    def Mesh \"G$gi\" (\n        prepend apiSchemas = [\"MaterialBindingAPI\"]\n    )\n    {\n")
        append("        uniform bool doubleSided = 0\n        uniform token subdivisionScheme = \"none\"\n")
        append("        int[] faceVertexCounts = [")
        for (t in 0 until n / 3) { if (t > 0) append(','); append('3') }
        append("]\n        int[] faceVertexIndices = [")
        for (i in 0 until n) { if (i > 0) append(','); append(i) }
        append("]\n        point3f[] points = [")
        for (i in 0 until n) { if (i > 0) append(','); append('(').append(n3(g.pos[i * 3])).append(',').append(n3(g.pos[i * 3 + 1])).append(',').append(n3(g.pos[i * 3 + 2])).append(')') }
        append("]\n        normal3f[] normals = [")
        for (i in 0 until n) { if (i > 0) append(','); append('(').append(n3(g.nrm[i * 3])).append(',').append(n3(g.nrm[i * 3 + 1])).append(',').append(n3(g.nrm[i * 3 + 2])).append(')') }
        append("] (\n            interpolation = \"faceVarying\"\n        )\n")
        append("        rel material:binding = </Root/Looks/M${g.mat}>\n    }\n")
    }
    append("}\n")
}

/** A file in a USDZ: its name in the archive and its bytes. */
class ZipFile(val name: String, val data: ByteArray)

/**
 * A USDZ package (the USDZ file format: a zip archive, nothing compressed or encrypted, each file's data starting at a
 * multiple of 64 bytes from the archive's start, padded with an extra field; the first file the root layer).
 */
fun usdz(files: List<ZipFile>): ByteArray {
    val out = ByteArrayOutputStream()
    class Entry(val name: ByteArray, val crc: Long, val size: Int, val off: Int, val extra: Int)
    val entries = ArrayList<Entry>()
    fun le16(v: Int) { out.write(v and 255); out.write((v shr 8) and 255) }
    fun le32(v: Long) { for (i in 0 until 4) out.write(((v shr (8 * i)) and 255).toInt()) }
    for (f in files) {
        val name = f.name.toByteArray(Charsets.UTF_8)
        val crc = CRC32().apply { update(f.data) }.value
        val off = out.size()
        // the data starts after the 30-byte header, the name and the extra field: pad that field to 64
        var pad = (64 - (off + 30 + name.size) % 64) % 64
        if (pad in 1..3) pad += 64
        le32(0x04034b50); le16(10); le16(0); le16(0); le16(0); le16(0x21)   // version, flags, stored, time, date (1980-01-01)
        le32(crc); le32(f.data.size.toLong()); le32(f.data.size.toLong()); le16(name.size); le16(pad)
        out.write(name)
        if (pad > 0) { le16(0x1986); le16(pad - 4); repeat(pad - 4) { out.write(0) } }
        out.write(f.data)
        entries += Entry(name, crc, f.data.size, off, pad)
    }
    val cd = out.size()
    for (e in entries) {
        le32(0x02014b50); le16(10); le16(10); le16(0); le16(0); le16(0); le16(0x21)
        le32(e.crc); le32(e.size.toLong()); le32(e.size.toLong()); le16(e.name.size); le16(0); le16(0); le16(0); le16(0); le32(0); le32(e.off.toLong())
        out.write(e.name)
    }
    val cdSize = out.size() - cd
    le32(0x06054b50); le16(0); le16(0); le16(entries.size); le16(entries.size); le32(cdSize.toLong()); le32(cd.toLong()); le16(0)
    return out.toByteArray()
}

/** The model as a USDZ with one root layer, "model.usda". */
fun usdzOf(mesh: C3Mesh, name: String): ByteArray = usdz(listOf(ZipFile("model.usda", usda(mesh, name).toByteArray(Charsets.UTF_8))))
