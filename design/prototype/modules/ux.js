/* ============================== ux: founder's review of 13 Oct 2026 ==============================
   - 3D: many rooms are laid out in rows instead of one long line; two fingers move the view, inside limits, so the
     rooms can't be lost; tapping a room's name goes to that room; no "drag to orbit" text.
   - The 3D "save view" button is now "Add to report" on the picture itself, and the added views are listed under it.
   - Toasts appear at the top of the screen. */
Object.assign(D,{
'3d.save':['Hisobotga qo‘shish','В отчёт','Add to report'],
'3d.saved':['3D ko‘rinish hisobotga qo‘shildi.','3D-вид добавлен в отчёт.','3D view added to the report.'],
'3d.max':['Hisobotda ko‘pi bilan 4 ta 3D ko‘rinish. Avval bittasini olib tashlang.','В отчёте не больше 4 3D-видов. Сначала уберите один.','A report holds at most 4 3D views. Remove one first.'],
'3d.inRep':['Hisobotdagi 3D ko‘rinishlar: {n}/4','3D-виды в отчёте: {n}/4','3D views in the report: {n}/4'],
'3d.del':['Hisobotdan olib tashlash','Убрать из отчёта','Remove from the report'],
'3d.deleted':['3D ko‘rinish hisobotdan olib tashlandi.','3D-вид убран из отчёта.','3D view removed from the report.'],
'3d.all':['Hammasi','Все','All'],
'v3d.note':['{n} ta xona. Xona nomini bossangiz, o‘sha xona yaqinlashadi. To‘liq o‘lchanmagan xonalar ko‘rinmaydi.','Помещений: {n}. Нажмите название, чтобы приблизить помещение. Неизмеренные не показаны.','{n} {n:room|rooms}. Tap a name to zoom to that room. Rooms that aren’t fully measured aren’t shown.'],
'rpt.noViews':['3D ko‘rinish yo‘q. Xonaning 3D sahifasida «Hisobotga qo‘shish» ni bosing.','3D-видов нет. В 3D помещения нажмите «В отчёт».','No 3D views. Tap Add to report in a room’s 3D view.']
});

/* ---------- 3D: where the camera may go ---------- */
const V3_FOV=Math.PI/9;                                   // half of the camera's 40° field of view
function v3Fit(w,d,h){ const a=(T3.cam&&T3.cam.aspect)||1, hh=Math.atan(Math.tan(V3_FOV)*a); return Math.max(3.5,0.5*Math.hypot(w,d,h)/Math.sin(Math.min(V3_FOV,hh))*0.9) }
function v3Clamp(){ const b=T3.bounds; if(!b) return;
  T3.tgt[0]=Math.max(b.x0,Math.min(b.x1,T3.tgt[0])); T3.tgt[2]=Math.max(b.z0,Math.min(b.z1,T3.tgt[2]));
  if(T3.rMax) T3.r=Math.max(T3.rMin||3,Math.min(T3.rMax,T3.r)) }
function v3Pan(dx,dy){ const h=(T3.host&&T3.host.clientHeight)||400, k=2*T3.r*Math.tan(V3_FOV)/h, kf=k/Math.max(0.35,Math.cos(T3.phi)), th=T3.theta;
  T3.tgt[0]+=-Math.sin(th)*dx*k-Math.cos(th)*dy*kf; T3.tgt[2]+=Math.cos(th)*dx*k-Math.sin(th)*dy*kf; draw3D() }
function v3Go(to){ cancelAnimationFrame(T3.raf);
  const from={t:T3.tgt.slice(),r:T3.r,th:T3.theta,ph:T3.phi}, t0=performance.now(), still=window.matchMedia&&matchMedia('(prefers-reduced-motion:reduce)').matches;
  const step=now=>{ const k=still?1:Math.min(1,(now-t0)/340), e=1-Math.pow(1-k,3), mix=(a,b)=>a+(b-a)*e;
    T3.tgt=[0,1,2].map(i=>mix(from.t[i],to.t[i])); T3.r=mix(from.r,to.r); if(to.th!=null){ T3.theta=mix(from.th,to.th); T3.phi=mix(from.ph,to.ph) }
    draw3D(); if(k<1) T3.raf=requestAnimationFrame(step) };
  T3.raf=requestAnimationFrame(step) }

/* ---------- 3D: several rooms stand in rows, like on a sheet of paper, not in one long line ---------- */
{ const b0=build3D;
  build3D=function(rooms,single){
    const THREE=window.THREE; T3.rooms3=null; T3.focus=null; T3.fit=null; T3.rFit=null; cancelAnimationFrame(T3.raf);
    if(single||rooms.length<2){ b0(rooms,single); const d=T3.dims;
      T3.bounds={x0:d.L*0.15,x1:d.L*0.85,z0:d.W*0.15,z1:d.W*0.85}; T3.rMin=2.5; T3.rMax=null; T3.fit=[d.L,d.W,d.H,1.25,1.6]; return }
    const GAP=1.4;
    const parts=rooms.map(room=>{ b0([room],false); const sc=T3.scene; sc.updateMatrixWorld(true);
      const bx=new THREE.Box3(); sc.traverse(o=>{ if(o.isMesh) bx.expandByObject(o) });
      const g=new THREE.Group(); sc.children.slice().forEach(o=>{ if(!o.isLight&&o.type!=='GridHelper') g.add(o) });
      return {room,g,bx,groups:T3.groups||[],w:bx.max.x-bx.min.x,d:bx.max.z-bx.min.z,h:bx.max.y} });
    // rows: as wide as a square of the same area, so the whole set fits a phone screen
    const area=parts.reduce((a,p)=>a+(p.w+GAP)*(p.d+GAP),0), rowW=Math.max(...parts.map(p=>p.w),Math.sqrt(area)*1.2);
    const rows=[]; let cur=null;
    parts.forEach(p=>{ if(!cur||cur.w+GAP+p.w>rowW){ cur={w:p.w,d:p.d,it:[p]}; rows.push(cur) } else { cur.w+=GAP+p.w; cur.d=Math.max(cur.d,p.d); cur.it.push(p) } });
    const W=Math.max(...rows.map(r=>r.w)), Dp=rows.reduce((a,r)=>a+r.d,0)+GAP*(rows.length-1), H=Math.max(...parts.map(p=>p.h));
    const sc=new THREE.Scene(); sc.background=new THREE.Color(0xF3F6FA);
    sc.add(new THREE.HemisphereLight(0xffffff,0xC9D3E0,0.5)); sc.add(new THREE.AmbientLight(0xffffff,0.3));
    const dl=new THREE.DirectionalLight(0xffffff,0.55); dl.position.set(W*0.7+3,H*3+4,Dp*1.6+3); sc.add(dl);
    const gs=Math.max(W,Dp)+4, grid=new THREE.GridHelper(gs,Math.round(gs*2),0xC3CEDF,0xDCE4F0); grid.position.set(W/2,-0.002,Dp/2); sc.add(grid);
    const groups=[], list=[]; let z=0;
    rows.forEach(row=>{ let x=(W-row.w)/2;
      row.it.forEach(p=>{ const dx=x-p.bx.min.x, dz=z-p.bx.min.z; p.g.position.set(dx,0,dz); sc.add(p.g);
        p.groups.forEach(gp=>{ gp.cx+=dx; gp.cz+=dz; groups.push(gp) });
        list.push({id:p.room.id,name:dn(p.room.name),cx:x+p.w/2,cz:z+p.d/2,w:p.w,d:p.d,h:p.h}); x+=p.w+GAP });
      z+=row.d+GAP });
    T3.scene=sc; T3.groups=groups; T3.labels=[]; T3.rooms3=list; T3.dims={L:W,W:Dp,H};
    /* the view's centre stays between the middles of the outermost rooms, so some room is always in the picture */
    T3.bounds={x0:Math.min(...list.map(r=>r.cx)),x1:Math.max(...list.map(r=>r.cx)),z0:Math.min(...list.map(r=>r.cz)),z1:Math.max(...list.map(r=>r.cz))}; T3.tgt=[W/2,H*0.3,Dp/2]; T3.theta=Math.PI/2+0.45; T3.phi=0.9;
    T3.r=Math.max(W,Dp)*1.5+2.5; T3.rMin=3; T3.rMax=null; T3.fit=[W,Dp,H,1,1.35];
    T3.cam=new THREE.PerspectiveCamera(40,1,0.1,400);
  }; }
/* the distance that shows every room depends on the shape of the picture, which is known only once it is on screen */
{ const r0=resize3D; resize3D=function(){ r0(); if(T3.fit&&T3.cam&&T3.host&&T3.host.clientWidth){ const f=T3.fit; T3.r=T3.rFit=v3Fit(f[0],f[1],f[2])*f[3]; T3.rMax=T3.r*f[4]; T3.fit=null } } }
/* every drawing keeps the camera inside its limits; room names are buttons */
{ const d0=draw3D;
  draw3D=function(){ v3Clamp(); d0();
    const host=T3.host, rs=T3.rooms3; if(!host||!rs||!T3.cam||!window.THREE) return;
    const w=host.clientWidth, h=host.clientHeight; let html='';
    rs.forEach(r=>{ const v=new window.THREE.Vector3(r.cx,r.h+0.45,r.cz).project(T3.cam); if(v.z>1) return;
      html+=`<button class="lbl go ${T3.focus===r.id?'on':''}" data-a="v3Room" data-id="${esc(r.id)}" style="left:${((v.x+1)/2*w).toFixed(0)}px;top:${((1-v.y)/2*h).toFixed(0)}px">${esc(r.name)}</button>` });
    host.insertAdjacentHTML('beforeend',html) }; }
/* two fingers move the view (and pinch still zooms) */
{ const m0=mount3D;
  mount3D=function(host,rooms,single){ m0(host,rooms,single);
    const c=T3.renderer&&T3.renderer.domElement; if(!c||c.__v3) return; c.__v3=true; const pt=new Map();
    const mid=()=>{ const a=[...pt.values()]; return [(a[0][0]+a[1][0])/2,(a[0][1]+a[1][1])/2] };
    c.addEventListener('pointerdown',e=>{ cancelAnimationFrame(T3.raf); pt.set(e.pointerId,[e.clientX,e.clientY]) });
    c.addEventListener('pointermove',e=>{ if(!pt.has(e.pointerId)) return;
      if(pt.size===2){ const a=mid(); pt.set(e.pointerId,[e.clientX,e.clientY]); const b=mid(); v3Pan(b[0]-a[0],b[1]-a[1]) }
      else pt.set(e.pointerId,[e.clientX,e.clientY]) });
    const up=e=>pt.delete(e.pointerId); c.addEventListener('pointerup',up); c.addEventListener('pointercancel',up);
  }; }
A.v3Room=d=>{ const r=(T3.rooms3||[]).find(x=>x.id===d.id); if(!r) return;
  if(T3.focus===r.id){ A.v3All(); return }
  T3.focus=r.id; v3Go({t:[r.cx,r.h*0.3,r.cz],r:Math.min(T3.rMax||99,v3Fit(r.w,r.d,r.h)*1.6)}) };
A.v3All=()=>{ const d=T3.dims; if(!d) return; T3.focus=null; v3Go({t:[d.L/2,d.H*0.3,d.W/2],r:T3.rFit||T3.r,th:Math.PI/2+0.45,ph:0.9}) };
/* "From above" and "From the corner" also bring the room back to the middle */
{ const p0=A.preset; A.preset=d=>{ const dm=T3.dims; cancelAnimationFrame(T3.raf); if(dm) T3.tgt=[dm.L/2,dm.H*0.3,dm.W/2]; p0(d); if(T3.rFit){ T3.r=T3.rFit; draw3D() } } }

/* ---------- the two 3D screens: no instruction text; the report button sits on the picture ---------- */
{ const pe=PAGES.editor; PAGES.editor=rt=>{ let html=pe(rt); if(rt.mode!=='3d') return html;
    const p=P(rt.pid), r=p&&R(p,rt.rid); if(!r) return html;
    const shot=`<button class="v3-shot" data-a="saveView">${ic('camera','i s')}<span>${esc(t('3d.save'))}</span></button>`;
    const strip=r.views.length?`<div class="v3-rep"><small>${esc(t('3d.inRep',{n:r.views.length}))}</small><div class="v3-shots">${r.views.map(v=>`<span class="v3-th"><img src="${v.img}" alt=""><button data-a="v3Del" data-id="${esc(v.id)}" aria-label="${esc(t('3d.del'))}">${ic('x','i xs')}</button></span>`).join('')}</div></div>`:'';
    return html.replace(/<span class="hint">[^<]*<\/span>/,shot)
      .replace(/<button class="btn pri full" data-a="saveView">[\s\S]*?<\/button><span class="fhint"[^>]*>[^<]*<\/span>/,strip) } }
A.v3Del=d=>{ if(!guard()) return; const {p,r}=edRoom(); if(!r) return; r.views=r.views.filter(v=>v.id!==d.id); if(p.report&&p.report.views) delete p.report.views[d.id]; touchRoom(p); toast(t('3d.deleted')); render() };
{ const pp=PAGES.project; PAGES.project=rt=>{ const html=pp(rt); if((rt.tab||'rooms')!=='rooms'||rt.view!=='3d') return html;
    const p=P(rt.id), n=p?floorRooms3D(p,rt).length:0;
    return html.replace(/<span class="hint">[^<]*<\/span>/,n>1?`<button class="v3-all" data-a="v3All">${ic('room','i s')}<span>${esc(t('3d.all'))}</span></button>`:'') } }
