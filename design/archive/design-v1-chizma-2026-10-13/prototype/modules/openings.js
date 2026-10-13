/* ============================== doors & windows: one standard look + drag to move ==============================
   The current users are brickmasons, so every door and window uses one universal design and one colour
   (wall view, plan, 3D model). Dragging an opening along a wall (wall view or plan) sets an approximate
   position (offDrag/sillDrag) until it is confirmed in the door/window sheet. */
Object.assign(D,{
'op.dragHint':['Eshik va derazani devor bo‘ylab surish mumkin','Двери и окна можно перетаскивать вдоль стены','Drag doors and windows along the wall'],
'op.dragHintW':['Derazani yuqoriga-pastga surib, tokcha balandligini o‘zgartiring','Окно можно двигать вверх-вниз, меняя высоту подоконника','Drag a window up or down to change its sill height'],
'op.moved':['{o} surildi','{o}: перемещено','{o} moved'],
'op.dragBack':['{o} boshqa ochiq joyga tegib qoldi va joyiga qaytdi','{o} пересекается с другим проёмом и возвращено на место','{o} would overlap another opening, so it went back'],
'op.approx':['Joyi surib qo‘yilgan, shuning uchun taxminiy. O‘lchab, saqlang.','Положение задано перетаскиванием, поэтому примерное. Измерьте и сохраните.','The position was set by dragging, so it’s approximate. Measure it and save.'],
'op.approxS':['taxminiy','примерно','approx.']
});
/* one universal look: a plain door leaf with a handle, a two-pane window; one colour for both */
const OP_FIN={std:'#E2E6EC'}, OP_FIN3={std:0xC5CBD4};
const opStyle=()=>'std', opFin=()=>'std';
const opApprox=o=>!!(o.offDrag||o.sillDrag);

/* front view of an opening, drawn into the box (x,y,w,h); used by the wall view, the picker and the 3D list */
function opArt(o,x,y,w,h,col,sel){
  const F=v=>(+v).toFixed(1), st=opStyle(o), fc=OP_FIN[opFin(o)], gl='#D6E5F7', lw=sel?2.2:1.4;
  const ft=Math.max(1.4,Math.min(w,h)*0.06);
  let g=`<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fc}" stroke="${col}" stroke-width="${lw}"/>`;
  const R=(a,b,c,d,fill,sw,extra)=>`<rect x="${F(a)}" y="${F(b)}" width="${F(Math.max(.5,c))}" height="${F(Math.max(.5,d))}" fill="${fill}" stroke="${col}" stroke-width="${sw||.8}" ${extra||''}/>`;
  const knob=(cx,cy)=>w>8?`<circle cx="${F(cx)}" cy="${F(cy)}" r="${F(Math.max(1.2,w*0.035))}" fill="${opFin(o)==='dark'?'#C9CED4':col}"/>`:'';
  if(o.type==='door'){
    const lx=x+ft, ly=y+ft, lw2=w-2*ft, lh=h-ft;
    if(st==='double'){ const hw=lw2/2; [0,1].forEach(k=>{ const ax=lx+k*hw; g+=R(ax,ly,hw,lh,fc); g+=R(ax+hw*0.2,ly+lh*0.08,hw*0.6,lh*0.36,'none',.6)+R(ax+hw*0.2,ly+lh*0.52,hw*0.6,lh*0.38,'none',.6) }); g+=knob(lx+hw-w*0.06,ly+lh*0.52)+knob(lx+hw+w*0.06,ly+lh*0.52) }
    else { g+=R(lx,ly,lw2,lh,fc);
      if(st==='panel'){ const px=lx+lw2*0.16, pw=lw2*0.68; g+=R(px,ly+lh*0.07,pw,lh*0.38,'none',.7)+R(px,ly+lh*0.52,pw,lh*0.4,'none',.7) }
      if(st==='glass'){ const px=lx+lw2*0.18, pw=lw2*0.64, pt=ly+lh*0.08, ph=lh*0.58; g+=R(px,pt,pw,ph,gl,.8); g+=`<path d="M${F(px)} ${F(pt+ph/3)}H${F(px+pw)}M${F(px)} ${F(pt+2*ph/3)}H${F(px+pw)}" stroke="${col}" stroke-width=".7"/>`+R(px,ly+lh*0.74,pw,lh*0.18,'none',.6) }
      if(st==='steel'){ for(let k=1;k<=4;k++){ const yy=ly+lh*k/5; g+=`<path d="M${F(lx+lw2*0.12)} ${F(yy)}H${F(lx+lw2*0.88)}" stroke="${opFin(o)==='dark'?'#6A727C':col}" stroke-width=".8"/>` } g+=`<rect x="${F(lx+lw2*0.8)}" y="${F(ly+lh*0.44)}" width="${F(Math.max(1.4,lw2*0.06))}" height="${F(lh*0.14)}" rx="1" fill="#C9CED4"/>` }
      if(st!=='steel') g+=knob(lx+lw2*0.86,ly+lh*0.53) }
  } else {
    const n=st==='single'||st==='fixed'?1:st==='three'?3:2, fw=st==='fixed'?ft*0.6:ft, ix=x+fw, iy=y+fw, iw=w-2*fw, ih=h-2*fw, sw=iw/n;
    for(let k=0;k<n;k++){ const sx=ix+k*sw, inset=st==='fixed'?0:Math.max(1,ft*0.6);
      g+=R(sx+inset,iy+inset,sw-2*inset,ih-2*inset,gl,.8);
      if(st==='grid'){ const gx=sx+inset, gy=iy+inset, gw=sw-2*inset, gh=ih-2*inset; g+=`<path d="M${F(gx+gw/2)} ${F(gy)}V${F(gy+gh)}M${F(gx)} ${F(gy+gh/3)}H${F(gx+gw)}M${F(gx)} ${F(gy+2*gh/3)}H${F(gx+gw)}" stroke="${fc}" stroke-width="${F(Math.max(1,ft*0.45))}"/>` }
      if(k>0) g+=`<path d="M${F(sx)} ${F(iy)}V${F(iy+ih)}" stroke="${col}" stroke-width=".9"/>` }
    g+=`<path d="M${F(x-3)} ${F(y+h+1.5)}H${F(x+w+3)}" stroke="${col}" stroke-width="2.2"/>`;
  }
  if(opApprox(o)) g+=`<rect x="${F(x-3)}" y="${F(y-3)}" width="${F(w+6)}" height="${F(h+6)}" fill="none" stroke="#9A4D00" stroke-width="1.4" stroke-dasharray="4 3"/>`;
  return g;
}
/* small front view (kept for list rows) */
const opThumb=(o,vw,vh)=>{ const asp=o.type==='door'?[30,62]:[54,40]; const k=Math.min((vw-8)/asp[0],(vh-8)/asp[1]); const w=asp[0]*k, h=asp[1]*k; return `<svg viewBox="0 0 ${vw} ${vh}" aria-hidden="true">${opArt(o,(vw-w)/2,(vh-h)/2-(o.type==='window'?2:0),w,h,'#0E1C36',false)}</svg>` };

/* ---------- door/window sheet: note when the position came from dragging; saving confirms it ---------- */
{ const base=SHEETS.opening; SHEETS.opening=sh=>{ const html=base(sh), r=R(P(sh.pid),sh.rid), cur=sh.oid&&r?r.openings.find(x=>x.id===sh.oid):null;
  if(!cur||!opApprox(cur)) return html; const k=html.indexOf('</div><div class="sf">');
  const note=`<div class="banner warn" style="margin:0">${ic('clock','i s')}<span class="tx">${esc(t('op.approx'))}</span></div>`;
  return k<0?html:html.slice(0,k)+note+html.slice(k) } }
{ const base=A.saveOpening; A.saveOpening=()=>{ const s=U.sheet, p=P(s.pid), r=R(p,s.rid);
  base(); if(U.sheet===s||!r||!s.oid) return; const o=r.openings.find(x=>x.id===s.oid); if(!o) return;
  delete o.style; delete o.fin; delete o.offDrag; delete o.sillDrag; T3.key=null; commit(); render() } }

/* ---------- 3D models ---------- */
function opModel3D(THREE,sc,w,ar,ctx){
  const [a,b,v0,hh,type,o]=ar; if(!o) return; const {T,L,W,X,reg}=ctx, st=opStyle(o), fin=OP_FIN3[opFin(o)];
  const M=(color,op)=>{ const m=new THREE.MeshLambertMaterial({color,transparent:true,opacity:op||1}); m.userData.op=op||1; if(reg) (reg.x=reg.x||[]).push(m); return m };
  const mF=M(fin), mG=M(0x9DB8E8,0.45), mH=M(0x6F7782), mLeaf=M(fin);
  const box=(u0,u1,y0,y1,n0,n1,m)=>{ if(u1-u0<1e-4||y1-y0<1e-4||n1-n0<1e-4) return; let g,x,z;
    if(w==='A'||w==='C'){ g=new THREE.BoxGeometry(u1-u0,y1-y0,n1-n0); x=X((u0+u1)/2); z=w==='A'?-(n0+n1)/2:W+(n0+n1)/2 }
    else { g=new THREE.BoxGeometry(n1-n0,y1-y0,u1-u0); z=(u0+u1)/2; x=w==='B'?X(L+(n0+n1)/2):X(-(n0+n1)/2) }
    const mesh=new THREE.Mesh(g,m); mesh.position.set(x,(y0+y1)/2,z); sc.add(mesh) };
  const top=v0+hh, fw=0.055;
  if(type==='door'){
    const f0=0.01, f1=Math.min(T-0.01,0.12);
    box(a,a+fw,0,top,f0,f1,mF); box(b-fw,b,0,top,f0,f1,mF); box(a,b,top-fw,top,f0,f1,mF);
    const l0=0.03, l1=0.07, la=a+fw, lb=b-fw, lt=top-fw, lw=lb-la;
    const leaf=(u0,u1,hingeLeft)=>{ const uw=u1-u0;
      if(st==='glass'){ const s1=uw*0.18; box(u0,u0+s1,0,lt,l0,l1,mLeaf); box(u1-s1,u1,0,lt,l0,l1,mLeaf); box(u0,u1,lt-0.12,lt,l0,l1,mLeaf); box(u0,u1,0,lt*0.26,l0,l1,mLeaf); box(u0,u1,lt*0.62-0.03,lt*0.62,l0,l1,mLeaf); box(u0,u1,lt*0.44-0.015,lt*0.44,l0,l1,mLeaf); box(u0+s1,u1-s1,lt*0.26,lt-0.12,0.045,0.055,mG) }
      else { box(u0,u1,0,lt,l0,l1,mLeaf);
        if(st==='panel'||st==='double'){ const pu0=u0+uw*0.16, pu1=u1-uw*0.16; [[0.08,0.45],[0.52,0.93]].forEach(([y0,y1])=>{ box(pu0,pu1,lt*y0,lt*y1,l0-0.012,l0,mLeaf); box(pu0,pu1,lt*y0,lt*y1,l1,l1+0.012,mLeaf) }) }
        if(st==='steel'){ for(let k=1;k<=4;k++) box(u0+uw*0.1,u1-uw*0.1,lt*k/5-0.006,lt*k/5+0.006,l0-0.006,l0,mH) } }
      const hu=hingeLeft?u1-0.09:u0+0.06; box(hu,hu+0.03,st==='steel'?0.9:0.98,st==='steel'?1.2:1.02,-0.03,l0,mH) };
    if(st==='double'){ leaf(la,la+lw/2-0.003,true); leaf(la+lw/2+0.003,lb,false) } else leaf(la,lb,true);
  } else {
    const f0=Math.max(0.01,T*0.3), f1=Math.min(T-0.01,f0+0.07);
    box(a,a+fw,v0,top,f0,f1,mF); box(b-fw,b,v0,top,f0,f1,mF); box(a,b,top-fw,top,f0,f1,mF); box(a,b,v0,v0+fw,f0,f1,mF);
    const n=st==='single'||st==='fixed'?1:st==='three'?3:2, ia=a+fw, ib=b-fw, iy0=v0+fw, iy1=top-fw, sw=(ib-ia)/n, sb=st==='fixed'?0.02:0.045, gm=(f0+f1)/2;
    for(let k=0;k<n;k++){ const s0=ia+k*sw, s1=s0+sw;
      box(s0,s0+sb,iy0,iy1,f0+0.01,f1-0.01,mF); box(s1-sb,s1,iy0,iy1,f0+0.01,f1-0.01,mF); box(s0,s1,iy0,iy0+sb,f0+0.01,f1-0.01,mF); box(s0,s1,iy1-sb,iy1,f0+0.01,f1-0.01,mF);
      box(s0+sb,s1-sb,iy0+sb,iy1-sb,gm-0.004,gm+0.004,mG);
      if(st==='grid'){ const gw=s1-s0, gh=iy1-iy0, mt=0.016; box(s0+gw/2-mt/2,s0+gw/2+mt/2,iy0,iy1,gm-0.008,gm+0.008,mF); [1/3,2/3].forEach(f=>box(s0,s1,iy0+gh*f-mt/2,iy0+gh*f+mt/2,gm-0.008,gm+0.008,mF)) }
      if(st!=='fixed'&&n>1&&k===0) box(s1-sb-0.03,s1-sb-0.01,iy0+(iy1-iy0)*0.48,iy0+(iy1-iy0)*0.58,f0-0.02,f0+0.01,mH) }
    if(v0>0.05) box(a-0.05,b+0.05,v0-0.03,v0,-0.1,f0,M(0xF5F5F2));
  }
}

/* ---------- dragging: wall view (along the wall, and sill height for windows) and plan (along the wall) ---------- */
{ let dg=null;
  const snapOff=(off,o,L)=>{ off=Math.round(off/10)*10; if(L!=null){ const max=Math.max(0,L-o.w), mid=Math.round((L-o.w)/2/10)*10; if(Math.abs(off-mid)<60) off=mid; if(off<40) off=0; if(max-off<40) off=max; off=Math.max(0,Math.min(max,off)) } else off=Math.max(0,off); return off };
  const snapSill=(sl,o,H)=>{ sl=Math.round(sl/10)*10; const def=(S.settings.defaults.window||{}).sill; if(def!=null&&Math.abs(sl-def)<40) sl=def; return Math.max(0,H!=null?Math.min(H-o.h,sl):sl) };
  const tip=(host,x,y,txt,bad)=>{ let el=host.querySelector('.dg-tip'); if(!el){ el=document.createElement('div'); el.className='dg-tip'; host.appendChild(el) } el.classList.toggle('bad',!!bad); el.innerHTML=txt; el.style.left=x+'px'; el.style.top=y+'px' };
  appEl.addEventListener('pointerdown',e=>{
    if(U.sheet||S.firstRun||e.button>0) return; const rt=top(); if(!rt) return;
    const hit=e.target.closest&&e.target.closest('.wv-draw [data-a="editOpening"], .canvas .ophit'); if(!hit) return;
    const p=P(rt.pid), r=R(p,rt.rid); if(!r) return; const o=r.openings.find(x=>x.id===hit.dataset.id); if(!o) return;
    const inWv=rt.s==='wallView'&&!!hit.closest('.wv-draw'), inPlan=rt.s==='editor'&&(rt.mode||'plan')==='plan'&&!!hit.closest('.canvas');
    if(!inWv&&!inPlan) return;
    const svg=hit.ownerSVGElement; const host=inWv?hit.closest('.wv-draw'):hit.closest('.canvas');
    dg={id:e.pointerId,x:e.clientX,y:e.clientY,p,r,o,rt,host,wv:inWv,off0:o.off,sill0:o.sill||0,k:1/((svg.getScreenCTM()||{a:1}).a||1),s:Number(inWv?svg.dataset.s:hit.dataset.s)||1,ux:Number(hit.dataset.ux)||1,uy:Number(hit.dataset.uy)||0,moved:false};
    if(inWv&&typeof wvPtr!=='undefined') wvPtr=null;
  });
  appEl.addEventListener('pointermove',e=>{
    if(!dg||e.pointerId!==dg.id) return; const dx=e.clientX-dg.x, dy=e.clientY-dg.y;
    if(!dg.moved){ if(Math.hypot(dx,dy)<7) return; if(isLocked()){ dg=null; openSheet({type:'locked'}); return } dg.moved=true; try{ dg.host.setPointerCapture(dg.id) }catch(_){} dg.host.classList.add('dg-on'); U.dragOp=dg.o.id }
    e.preventDefault();
    const {o,r}=dg, L=wallLen(r,o.wall), H=r.dims.H.v;
    const along=dg.wv?dx:(dx*dg.ux+dy*dg.uy);
    o.off=snapOff(dg.off0+along*dg.k/dg.s,o,L);
    if(dg.wv&&o.type==='window') o.sill=snapSill(dg.sill0-dy*dg.k/dg.s,o,H);
    const iss=openingIssue(r,o,r.openings), hr=dg.host.getBoundingClientRect();
    if(dg.wv){ const ws=roomWalls(r), i=Math.max(0,ws.findIndex(w=>w.id===dg.rt.wall)); const svgOld=dg.host.querySelector('svg'); if(svgOld) svgOld.outerHTML=wvElevSVG(r,ws,i) }
    else { const svgOld=dg.host.querySelector('svg'); if(svgOld) svgOld.outerHTML=planSVG(r,{selOp:o.id}) }
    const c=wallCorner(r,o.wall);
    tip(dg.host,e.clientX-hr.left,e.clientY-hr.top-18,`${esc(t('wv.off',{c,v:fmtLen(o.off)+' '+M()}))}${dg.wv&&o.type==='window'?'<br>'+esc(t('wv.sill',{v:fmtLen(o.sill||0)+' '+M()})):''}`,!!iss);
  });
  const end=e=>{
    if(!dg||e.pointerId!==dg.id) return; const s=dg; dg=null; U.dragOp=null; if(!s.moved) return;
    U.dragEnd=Date.now(); const {o,r,p}=s, nv={off:o.off,sill:o.sill||0}; o.off=s.off0; o.sill=s.sill0;
    const nm=t(o.type==='door'?'op.door':'op.window');
    if(e.type==='pointercancel'||(nv.off===s.off0&&nv.sill===s.sill0)){ render(); return }
    if(openingIssue(r,Object.assign({},o,nv),r.openings)){ toast(t('op.dragBack',{o:nm})); render(); return }
    pushHist(r); if(nv.off!==s.off0) o.offDrag=true; if(nv.sill!==s.sill0) o.sillDrag=true; o.off=nv.off; if(o.type==='window') o.sill=nv.sill;
    touchRoom(p); toast(t('op.moved',{o:nm}),{label:t('common.undo'),a:'undo'}); render() };
  appEl.addEventListener('pointerup',end); appEl.addEventListener('pointercancel',end);
  appEl.addEventListener('click',e=>{ if(U.dragEnd&&Date.now()-U.dragEnd<350){ e.stopImmediatePropagation(); e.preventDefault() } },true); }

/* ---------- where the designs show up ---------- */
{ const base=PAGES.wallView; PAGES.wallView=rt=>{ const html=base(rt), r=R(P(rt.pid),rt.rid); if(!r) return html;
  const ops=r.openings.filter(o=>o.wall===rt.wall); if(!ops.length) return html;
  const hint=`<p class="wv-draghint">${ic('info','i s')}<span>${esc(t(ops.some(o=>o.type==='window')?'op.dragHintW':'op.dragHint'))}</span></p>`;
  return html.replace('<div class="wv-stats">',hint+'<div class="wv-stats">') } }
