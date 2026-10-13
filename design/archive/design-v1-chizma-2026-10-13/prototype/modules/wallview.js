/* ============================== wall view (Devor ko‘rinishi) ==============================
   Route {s:'wallView', pid, rid, wall}. Elevation of one wall seen from inside the room, start corner on the left.
   Works for any number of walls: everything comes from roomWalls(r). */
Object.assign(D,{
'wv.title':['Devor {w}','Стена {w}','Wall {w}'],
'wv.prev':['Oldingi devor','Предыдущая стена','Previous wall'],
'wv.next':['Keyingi devor','Следующая стена','Next wall'],
'wv.pos':['{n} tadan {i}-devor','Стена {i} из {n}','Wall {i} of {n}'],
'wv.toPlan':['Rejaga qaytish','Вернуться к плану','Back to plan'],
'wv.inside':['Xona ichidan ko‘rinish','Вид изнутри','View from inside'],
'wv.gross':['Devor, umumiy','Стена, всего','Wall, gross'],
'wv.net':['Devor, sof','Стена, чистая','Wall, net'],
'wv.prov':['Taxminiy: o‘lcham hali tasdiqlanmagan.','Предварительно: размер не подтверждён.','Provisional: a size isn’t confirmed yet.'],
'wv.missing':['Maydon uchun devor uzunligi va xona balandligi kerak.','Для площади нужны длина стены и высота.','The area needs the wall length and room height.'],
'wv.openings':['Bu devordagi ochiq joylar','Проёмы на этой стене','Openings on this wall'],
'wv.none':['Bu devorda ochiq joy yo‘q.','На этой стене проёмов нет.','No openings on this wall.'],
'wv.add':['Ochiq joy qo‘shish','Добавить проём','Add opening'],
'wv.onWall':['{w} devorga qo‘shiladi. O‘lchamlar sozlamalardan olinadi.','Добавится на стену {w}. Размеры из настроек.','Goes on wall {w}. Sizes come from your settings.'],
'wv.off':['{c}-burchakdan {v}','от угла {c}: {v}','{v} from corner {c}'],
'wv.sill':['tokcha {v}','подоконник {v}','sill {v}'],
'wv.derived':['{w} devor uzunligi {s} devordan olinadi. {s} ni o‘lchang.','Длина стены {w} берётся со стены {s}. Измерьте {s}.','Wall {w} takes its length from wall {s}. Measure {s}.'],
'wv.computed':['{w} devor uzunligi boshqa devorlardan hisoblanadi.','Длина стены {w} вычисляется по другим стенам.','Wall {w} is calculated from the other walls.'],
'wv.st.unset':['o‘lchanmagan','не измерено','not measured'],
'wv.st.recv':['tasdiqlanmagan','не подтверждено','not confirmed'],
'wv.st.conf':['tasdiqlangan','подтверждено','confirmed'],
});

/*wv:pure-start*/
// Pure geometry helpers (unit-tested in node).
function wvNorm(a,b){ const dx=b[0]-a[0], dy=b[1]-a[1], l=Math.hypot(dx,dy)||1; return [dx/l,dy/l] }
// Signed area in plan coordinates (y down). Positive = clockwise on screen, which puts the room interior on the right of each wall.
function wvSignedArea(walls){ let s=0; walls.forEach(w=>{ s+=w.p0[0]*w.p1[1]-w.p1[0]*w.p0[1] }); return s/2 }
// Mini plan locator: outline fitted into W×H, current wall endpoints, and a triangle inside the room pointing at the wall.
function wvMiniGeo(walls,idx,W,H,pad){
  let mnx=Infinity,mny=Infinity,mxx=-Infinity,mxy=-Infinity;
  walls.forEach(w=>[w.p0,w.p1].forEach(p=>{ mnx=Math.min(mnx,p[0]); mny=Math.min(mny,p[1]); mxx=Math.max(mxx,p[0]); mxy=Math.max(mxy,p[1]) }));
  const bw=Math.max(mxx-mnx,1), bh=Math.max(mxy-mny,1);
  const s=Math.min((W-2*pad)/bw,(H-2*pad)/bh);
  const ox=(W-bw*s)/2, oy=(H-bh*s)/2;
  const m=p=>[ox+(p[0]-mnx)*s, oy+(p[1]-mny)*s];
  const w=walls[idx]; const a=m(w.p0), b=m(w.p1); const u=wvNorm(w.p0,w.p1);
  const k=wvSignedArea(walls)>=0?1:-1; const n=[-u[1]*k,u[0]*k]; // inward normal
  const mid=[(a[0]+b[0])/2,(a[1]+b[1])/2];
  const tip=[mid[0]+n[0]*3.5,mid[1]+n[1]*3.5], c=[mid[0]+n[0]*10,mid[1]+n[1]*10];
  const tri=[tip,[c[0]+u[0]*4.5,c[1]+u[1]*4.5],[c[0]-u[0]*4.5,c[1]-u[1]*4.5]];
  return {poly:walls.map(x=>m(x.p0)),a,b,tri,n,s};
}
// Chain dimension along the wall: corner → opening edges → end. len null → last segment unknown (mm:null, b:null).
function wvChain(ops,len){
  const lim=x=>Math.max(0,len!=null?Math.min(len,x):x);
  const pts=[0]; ops.forEach(o=>{ pts.push(lim(o.off),lim(o.off+o.w)) }); if(len!=null) pts.push(len);
  const u=[...new Set(pts)].sort((a,b)=>a-b); const segs=[];
  for(let i=0;i<u.length-1;i++) segs.push({a:u[i],b:u[i+1],mm:u[i+1]-u[i]});
  if(len==null) segs.push({a:u[u.length-1],b:null,mm:null});
  return segs;
}
// Window offset that centres it on the wall, rounded to 10 mm, never negative.
function wvCentre(len,w){ return Math.max(0,Math.round((len-w)/20)*10) }
function wvFit(Lx,Hx,availW,availH){ return Math.min(availW/Math.max(Lx,1),availH/Math.max(Hx,1)) }
function wvWallStats(lenMM,hMM,ops){ const open=ops.reduce((a,o)=>a+o.w*o.h,0); if(lenMM==null||hMM==null) return {gross:null,open,net:null}; const gross=lenMM*hMM; return {gross,open,net:gross-open} }
/*wv:pure-end*/

const wvF=n=>n.toFixed(1);
function wvLenInfo(r,wall){
  const dd=wall.dimKey&&r.dims[wall.dimKey]; let st,mm;
  if(dd){ st=dimStatus(dd); mm=st==='recv'?dd.pending.mm:st==='conf'?(wall.len!=null?wall.len:dd.v):null }
  else { st=wall.len!=null?'conf':'unset'; mm=wall.len }
  return {st,mm,key:dd?wall.dimKey:null};
}
function wvHInfo(r){ const d=r.dims.H; const st=dimStatus(d); return {st,mm:st==='recv'?d.pending.mm:st==='conf'?d.v:null} }
const wvTxt=(st,mm)=>st==='unset'||mm==null?'?':st==='recv'?fmtLen(mm,null,true):fmtLen(mm);
// Measurement label box, same states as the plan: unset "?" dashed, received amber with clock, confirmed with check.
function wvTag(cx,cy,st,txt,sel){
  const ink='#0E1C36',amb='#9A4D00',grey='#5F6B82',cob='#1C4BD1';
  const icon=st!=='unset'; const wd=16+txt.length*8+(icon?15:0);
  const bg=st==='recv'?'#FFF1DF':'#FFFFFF', bc=sel?cob:st==='recv'?amb:st==='unset'?grey:'#C3CEDF';
  let h=`<rect x="${wvF(cx-wd/2)}" y="${wvF(cy-13)}" width="${wvF(wd)}" height="26" rx="4" fill="${bg}" stroke="${bc}" stroke-width="${sel?2.2:1.2}" ${st==='unset'?'stroke-dasharray="3 2"':''}/>`;
  let tx=cx-(icon?7:0);
  if(st==='recv'){ const kx=cx-wd/2+11; h+=`<circle cx="${wvF(kx)}" cy="${wvF(cy)}" r="4.8" fill="none" stroke="${amb}" stroke-width="1.4"/><path d="M${wvF(kx)} ${wvF(cy-2.6)}V${wvF(cy)}l1.8 1.2" stroke="${amb}" stroke-width="1.3" fill="none"/>`; tx=cx+7 }
  h+=`<text x="${wvF(tx)}" y="${wvF(cy+5)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-weight="600" font-size="15" fill="${st==='unset'?'#3E4A61':ink}">${esc(txt)}</text>`;
  if(st==='conf'){ const kx=cx+wd/2-14; h+=`<path d="M${wvF(kx)} ${wvF(cy)}l3 3 5.5-5.5" stroke="${ink}" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` }
  return {h,wd};
}
const wvTick=(x,y,col)=>`<path d="M${wvF(x-4)} ${wvF(y+4)}L${wvF(x+4)} ${wvF(y-4)}" stroke="${col}" stroke-width="1.6"/>`;

function wvMiniSVG(walls,i){
  const g=wvMiniGeo(walls,i,72,54,8); const P_=p=>wvF(p[0])+' '+wvF(p[1]);
  return `<svg viewBox="0 0 72 54" width="72" height="54" aria-hidden="true"><polygon points="${g.poly.map(P_).join(' ')}" fill="#F4F5F7" stroke="#47536A" stroke-width="1.2" stroke-dasharray="2.2 1.6"/><path d="M${P_(g.a)}L${P_(g.b)}" stroke="#1C4BD1" stroke-width="3.2" stroke-linecap="round"/><polygon points="${g.tri.map(P_).join(' ')}" fill="#1C4BD1"/></svg>`;
}

function wvElevSVG(r,walls,i){
  const wall=walls[i], endCorner=walls[(i+1)%walls.length].corner;
  const ink='#0E1C36',ink2='#3E4A61',cob='#1C4BD1',err='#B42318';
  const li=wvLenInfo(r,wall), hi=wvHInfo(r);
  const ops=r.openings.filter(x=>x.wall===wall.id).slice().sort((a,b)=>a.off-b.off);
  const ext=ops.reduce((m,x)=>Math.max(m,x.off+x.w),0), hTop=ops.reduce((m,x)=>Math.max(m,(x.sill||0)+x.h),0);
  const geoLen=Math.hypot(wall.p1[0]-wall.p0[0],wall.p1[1]-wall.p0[1]);
  // placeholder proportions when a value is unknown, never smaller than what the openings need
  const L=li.mm!=null?li.mm:Math.max(geoLen||4000,ext+600);
  const H=hi.mm!=null?hi.mm:Math.max(2700,hTop+300);
  const Lx=Math.max(L,ext), Hx=Math.max(H,hTop);
  const VW=360,ML=52,MR=24,MT=30,chainH=ops.length?30:0,MB=chainH+50;
  const s=wvFit(Lx,Hx,VW-ML-MR,170);
  const x0=ML+((VW-ML-MR)-Lx*s)/2, ww=L*s, wh=H*s, yF=MT+Hx*s, yT=yF-wh, VH=yF+MB, xE=x0+Lx*s;
  const sh=U.sheet; const msSel=sh&&sh.type==='measure'&&sh.pid&&sh.rid===r.id?sh.dim:null; const opSel=sh&&sh.type==='opening'?sh.oid:null;
  let g='';
  // floor + wall face
  g+=`<rect x="${wvF(x0-14)}" y="${wvF(yF)}" width="${wvF(xE-x0+28)}" height="7" fill="url(#wvHatch)"/>`;
  g+=`<rect x="${wvF(x0)}" y="${wvF(yT)}" width="${wvF(ww)}" height="${wvF(wh)}" fill="#FFFFFF"/>`;
  const dl=li.st!=='conf'?'stroke-dasharray="5 4"':'', dh=hi.st!=='conf'?'stroke-dasharray="5 4"':'';
  g+=`<path d="M${wvF(x0)} ${wvF(yF)}V${wvF(yT)}M${wvF(x0+ww)} ${wvF(yF)}V${wvF(yT)}" stroke="${ink}" stroke-width="1.6" ${dl}/><path d="M${wvF(x0)} ${wvF(yT)}H${wvF(x0+ww)}" stroke="${ink}" stroke-width="1.6" ${dh}/>`;
  g+=`<path d="M${wvF(x0-14)} ${wvF(yF)}H${wvF(xE+14)}" stroke="${ink}" stroke-width="2.4"/>`;
  // corner numbers: start corner left, end corner right
  [[x0,wall.corner],[x0+ww,endCorner]].forEach(([x,c])=>{ g+=`<circle cx="${wvF(x)}" cy="${wvF(yT-14)}" r="9" fill="#FFFFFF" stroke="${ink2}"/><text x="${wvF(x)}" y="${wvF(yT-10)}" text-anchor="middle" font-size="11" font-weight="600" fill="${ink}">${esc(c)}</text>` });
  // openings
  ops.forEach(o=>{
    const iss=openingIssue(r,o,r.openings), sel=opSel===o.id, col=iss?err:sel?cob:ink;
    const ox=x0+o.off*s, ow=Math.max(2,o.w*s), oh=Math.max(2,o.h*s), oy=yF-((o.sill||0)+o.h)*s;
    const nm=t(o.type==='door'?'op.door':'op.window');
    if(o.type==='door'){
      g+=`<rect x="${wvF(ox)}" y="${wvF(oy)}" width="${wvF(ow)}" height="${wvF(oh)}" fill="#F3F6FA" stroke="${col}" stroke-width="${sel?2.2:1.4}"/>`;
      if(ow>10&&oh>16) g+=`<rect x="${wvF(ox+3)}" y="${wvF(oy+3)}" width="${wvF(ow-6)}" height="${wvF(oh-3)}" fill="none" stroke="${col}" stroke-width="0.8"/><circle cx="${wvF(ox+ow-7)}" cy="${wvF(oy+oh*0.54)}" r="2" fill="${col}"/>`;
    } else {
      g+=`<rect x="${wvF(ox)}" y="${wvF(oy)}" width="${wvF(ow)}" height="${wvF(oh)}" fill="#E7EEFD" stroke="${col}" stroke-width="${sel?2.2:1.4}"/><path d="M${wvF(ox+ow/2)} ${wvF(oy)}V${wvF(oy+oh)}" stroke="${col}" stroke-width="0.9"/><path d="M${wvF(ox-3)} ${wvF(oy+oh+1.5)}H${wvF(ox+ow+3)}" stroke="${col}" stroke-width="2.2"/>`;
    }
    if(ow>30&&oh>26) g+=`<text x="${wvF(ox+ow/2)}" y="${wvF(oy+oh/2+4)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-size="11" fill="${ink2}" ${o.type==='window'?`paint-order="stroke" stroke="#E7EEFD" stroke-width="3"`:''}>${fmtLen(o.h)}</text>`;
    if(iss){ g+=`<rect x="${wvF(ox)}" y="${wvF(oy)}" width="${wvF(ow)}" height="${wvF(oh)}" fill="none" stroke="${err}" stroke-width="2.6" stroke-dasharray="4 3"/><circle cx="${wvF(ox+ow)}" cy="${wvF(oy)}" r="8" fill="${err}"/><text x="${wvF(ox+ow)}" y="${wvF(oy+4)}" text-anchor="middle" font-size="12" font-weight="700" fill="#FFFFFF">!</text>` }
    g+=`<rect x="${wvF(ox-4)}" y="${wvF(oy-4)}" width="${wvF(ow+8)}" height="${wvF(oh+8)}" fill="transparent" data-a="editOpening" data-id="${esc(o.id)}" role="button" aria-label="${esc(nm+', '+fmtLen(o.w)+' × '+fmtLen(o.h)+' '+M()+(iss?'. '+iss.msg:''))}"/>`;
  });
  // chain dims: corner → opening edges → end
  if(ops.length){
    const yC=yF+18, segs=wvChain(ops,li.mm), xs=new Set();
    let lastX=x0;
    segs.forEach((sg,k)=>{
      const xa=x0+sg.a*s, xb=sg.b!=null?x0+sg.b*s:x0+ww; if(xb-xa<0.5) return;
      xs.add(xa); xs.add(xb); lastX=Math.max(lastX,xb);
      const txt=sg.mm!=null?fmtLen(sg.mm):'?'; const tw=txt.length*6.3+6; const narrow=xb-xa<tw;
      g+=`<text x="${wvF((xa+xb)/2)}" y="${wvF(narrow&&k%2?yC+14:yC-4)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-size="11.5" fill="${ink2}">${txt}</text>`;
    });
    g+=`<path d="M${wvF(x0)} ${wvF(yC)}H${wvF(lastX)}" stroke="${ink2}" stroke-width="0.9" ${li.mm==null?'stroke-dasharray="4 3"':''}/>`;
    xs.forEach(x=>{ g+=`<path d="M${wvF(x)} ${wvF(yF+7)}V${wvF(yC+4)}" stroke="${ink2}" stroke-width="0.8"/>`+wvTick(x,yC,ink2) });
  }
  // overall length (tap = measure; derived wall measures its source)
  { const yO=yF+chainH+30, col=li.st==='recv'?'#9A4D00':li.st==='unset'?'#5F6B82':ink, xb=x0+ww;
    g+=`<path d="M${wvF(x0)} ${wvF(yF+7)}V${wvF(yO+6)}M${wvF(xb)} ${wvF(yF+7)}V${wvF(yO+6)}" stroke="${col}" stroke-width="0.9"/><path d="M${wvF(x0)} ${wvF(yO)}H${wvF(xb)}" stroke="${col}" stroke-width="1.1" ${li.st!=='conf'?'stroke-dasharray="5 4"':''}/>${wvTick(x0,yO,col)}${wvTick(xb,yO,col)}`;
    const txt=wvTxt(li.st,li.mm), cx=(x0+xb)/2, tg=wvTag(cx,yO,li.st,txt,!!li.key&&msSel===li.key);
    const src=wall.derived&&li.key?walls.find(x=>x.dimKey===li.key&&!x.derived):null;
    const lab=t('ed.wallLen',{w:wall.id})+': '+(txt==='?'?'?':txt+' '+M())+', '+t('wv.st.'+li.st);
    g+=`<g data-a="wvDim" data-w="${esc(wall.id)}" role="button" aria-label="${esc(lab)}"><rect x="${wvF(cx-tg.wd/2-8)}" y="${wvF(yO-21)}" width="${wvF(tg.wd+16)}" height="42" fill="transparent"/>${tg.h}${src?`<text x="${wvF(cx+tg.wd/2+6)}" y="${wvF(yO+4)}" font-size="12" fill="${ink2}">= ${esc(src.id)}</text>`:''}</g>`;
  }
  // room height on the left (tap = measure H)
  { const xH=x0-26, col=hi.st==='recv'?'#9A4D00':hi.st==='unset'?'#5F6B82':ink, my=(yT+yF)/2;
    g+=`<path d="M${wvF(x0-5)} ${wvF(yT)}H${wvF(xH-6)}M${wvF(x0-5)} ${wvF(yF)}H${wvF(xH-6)}" stroke="${col}" stroke-width="0.9"/><path d="M${wvF(xH)} ${wvF(yT)}V${wvF(yF)}" stroke="${col}" stroke-width="1.1" ${hi.st!=='conf'?'stroke-dasharray="5 4"':''}/>${wvTick(xH,yT,col)}${wvTick(xH,yF,col)}`;
    const txt=wvTxt(hi.st,hi.mm), tg=wvTag(xH,my,hi.st,txt,msSel==='H');
    const lab=DIMNAME('H')+': '+(txt==='?'?'?':txt+' '+M())+', '+t('wv.st.'+hi.st);
    g+=`<g data-a="wvDim" data-k="H" role="button" aria-label="${esc(lab)}" transform="rotate(-90 ${wvF(xH)} ${wvF(my)})"><rect x="${wvF(xH-tg.wd/2-8)}" y="${wvF(my-21)}" width="${wvF(tg.wd+16)}" height="42" fill="transparent"/>${tg.h}</g>`;
  }
  const hatch=`<pattern id="wvHatch" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="5" height="5" fill="#FFFFFF"/><rect width="1.1" height="5" fill="${ink}"/></pattern>`;
  return `<svg viewBox="0 0 ${VW} ${wvF(VH)}" font-family="IBM Plex Sans, sans-serif" role="group" aria-label="${esc(t('wv.title',{w:wall.id}))}"><defs>${hatch}</defs>${g}</svg>`;
}

/* ---------- page ---------- */
PAGES.wallView=(rt)=>{
  const p=P(rt.pid), r=R(p,rt.rid); if(!r) return PAGES.projects();
  const walls=roomWalls(r); if(!walls.length) return PAGES.projects();
  let i=walls.findIndex(w=>w.id===rt.wall); if(i<0){ i=0; rt.wall=walls[0].id }
  const wall=walls[i], n=walls.length, lk=isLocked();
  const anim=U.wvAnim; U.wvAnim=null;
  const h=U.hist[r.id]||{u:[],r:[]};
  const right=`<button class="ib" data-a="undo" ${h.u.length?'':'disabled'} aria-label="${esc(t('common.undo'))}">${ic('undo')}</button><button class="ib" data-a="redo" ${h.r.length?'':'disabled'} aria-label="redo">${ic('redo')}</button>`;
  const pager=`<div class="wv-pager"><button class="ib" data-a="wvStep" data-v="-1" ${n<2?'disabled':''} aria-label="${esc(t('wv.prev'))}">${ic('back')}</button><div class="wv-dots" aria-hidden="true">${walls.map((w,j)=>`<i class="${j===i?'on':''}"></i>`).join('')}</div><span class="wv-sr" aria-live="polite">${esc(t('wv.pos',{i:i+1,n}))}</span><button class="ib" data-a="wvStep" data-v="1" ${n<2?'disabled':''} aria-label="${esc(t('wv.next'))}">${ic('chev')}</button></div>`;
  const elev=`<div class="wv-elev"><div class="wv-top"><button class="wv-loc" data-a="wvToPlan" aria-label="${esc(t('wv.toPlan'))}">${wvMiniSVG(walls,i)}</button><span class="wv-cap">${esc(t('wv.inside'))}</span></div><div class="wv-draw ${anim?'wv-in-'+anim:''}">${wvElevSVG(r,walls,i)}</div></div>`;
  const ops=r.openings.filter(o=>o.wall===wall.id).slice().sort((a,b)=>a.off-b.off);
  const issues=ops.map(o=>({o,iss:openingIssue(r,o,r.openings)})).filter(x=>x.iss);
  const ban=issues.map(x=>`<div class="banner err wv-ban">${ic('alert','i s')}<span class="tx">${esc(x.iss.msg)}</span><button class="act" data-a="editOpening" data-id="${esc(x.o.id)}">${esc(t('ed.fix'))}</button></div>`).join('');
  // stats: confirmed values, else received (pending) values marked provisional, else "—"
  const li=wvLenInfo(r,wall), hi=wvHInfo(r);
  // a received reading never replaces a confirmed value in the totals; it only fills in when nothing is confirmed yet
  const cL=wall.len!=null?wall.len:(li.st==='recv'?li.mm:null), cH=r.dims.H.v!=null?r.dims.H.v:(hi.st==='recv'?hi.mm:null);
  const st=wvWallStats(cL,cH,ops); const prov=st.gross!=null&&((wall.len==null&&li.st==='recv')||(r.dims.H.v==null&&hi.st==='recv'));
  const av=v=>v==null?'—':fmtArea(v)+' '+M2();
  const stats=`<div class="wv-stats"><div class="kv"><div><span>${esc(t('wv.gross'))}</span><b>${av(st.gross)}</b></div><div><span>${esc(t('rp.openings'))}</span><b>${av(st.open)}</b></div><div class="tot"><span>${esc(t('wv.net'))}</span><b>${av(st.net)}</b></div></div>
    ${prov?`<div class="state">${ic('clock','i s')}<span>${esc(t('wv.prov'))}</span></div>`:st.gross==null?`<p class="fhint">${esc(t('wv.missing'))}</p>`:''}</div>`;
  const opSel=U.sheet&&U.sheet.type==='opening'?U.sheet.oid:null;
  const card=o=>{ const iss=openingIssue(r,o,r.openings); const nm=t(o.type==='door'?'op.door':'op.window');
    return `<button class="wv-op ${iss?'bad':''} ${opSel===o.id?'sel':''}" data-a="editOpening" data-id="${esc(o.id)}"><span class="wv-ot">${ic(o.type==='door'?'door':'window','i s')}<span>${esc(nm)}</span></span><span class="wv-sz">${fmtLen(o.w)} × ${fmtLen(o.h)} ${esc(M())}</span><small>${esc(t('wv.off',{c:wall.corner,v:fmtLen(o.off)+' '+M()}))}</small>${o.type==='window'?`<small class="${o.sillDrag?'wv-approx':''}">${esc(t('wv.sill',{v:(o.sillDrag?'≈ ':'')+fmtLen(o.sill||0)+' '+M()}))}</small>`:''}${iss?`<small class="wv-badtx">${ic('alert','i xs')}${esc(t('room.bad'))}</small>`:''}</button>` };
  const strip=`<div class="sech"><b>${esc(t('wv.openings'))}</b><span class="wv-cnt">${ops.length}</span></div>${ops.length?`<div class="wv-strip" data-scroll="wvs-${esc(wall.id)}">${ops.map(card).join('')}</div>`:`<p class="fhint wv-none">${esc(t('wv.none'))}</p>`}
    <div class="wv-addrow"><button class="btn ${lk?'locked':'pri'} wv-add" data-a="wvAdd">${ic(lk?'lock':'plus','i s')}${esc(t('wv.add'))}</button></div>`;
  return `<section class="page ${U.anim||''}">${bar({backIcon:true,title:t('wv.title',{w:wall.id}),sub:dn(r.name),right})}${banners()}<div class="scroll" data-scroll="wv">${pager}${elev}${ban}${stats}${strip}</div></section>`;
};

/* ---------- sheet: pick opening type ---------- */
SHEETS.wvAdd=(sh)=>{
  const df=S.settings.defaults||{};
  const row=(ty)=>{ const d=df[ty]||{}; return `<button class="opt" data-a="wvAddType" data-v="${ty}"><span class="wv-opl">${ic(ty==='door'?'door':'window')}<span>${esc(t('op.'+ty))}</span></span><small class="cd">${fmtLen(d.w??null)} × ${fmtLen(d.h??null)} ${esc(M())}</small></button>` };
  return sheetWrap(t('wv.add'),`<p class="fhint">${esc(t('wv.onWall',{w:sh.wall}))}</p><div class="optlist">${row('door')}${row('window')}</div>`,'');
};

/* ---------- actions ---------- */
function wvStep(dir){
  const rt=top(); if(!rt||rt.s!=='wallView') return; const r=R(P(rt.pid),rt.rid); if(!r) return;
  const ws=roomWalls(r); if(ws.length<2) return; let i=ws.findIndex(w=>w.id===rt.wall); if(i<0) i=0;
  rt.wall=ws[(i+dir+ws.length)%ws.length].id; U.wvAnim=dir>0?'next':'prev'; closeSheet(true); U.anim=null; render();
}
A.wallView=d=>{
  const rt=top(); if(!rt||!rt.pid||!rt.rid) return; const r=R(P(rt.pid),rt.rid); if(!r) return;
  const ws=roomWalls(r); if(!ws.length) return;
  let want=d&&d.w; if(!want&&U.sheet&&U.sheet.type==='measure') want=(ws.find(x=>x.id===U.sheet.dim)||{}).id;
  const w=want&&ws.some(x=>x.id===want)?want:ws[0].id;
  if(rt.s==='wallView'){ if(rt.wall!==w){ rt.wall=w; render() } return }
  push({s:'wallView',pid:rt.pid,rid:rt.rid,wall:w});
};
A.wvStep=d=>wvStep(Number(d.v)||1);
A.wvToPlan=()=>{ const st=stack(); if(st.length>1){ const prev=st[st.length-2]; if(prev.s==='editor') prev.mode='plan' } pop() };
A.wvDim=d=>{
  if(!guard()) return; const rt=top(); const p=P(rt.pid), r=R(p,rt.rid); if(!r) return;
  if(d.k==='H'){ openMeasure(p.id,r.id,'H'); return }
  const ws=roomWalls(r); const w=ws.find(x=>x.id===d.w); if(!w) return;
  const key=w.dimKey; if(!key||!r.dims[key]){ toast(t('wv.computed',{w:w.id})); render(); return }
  if(w.derived){ const src=ws.find(x=>x.dimKey===key&&!x.derived); toast(t('wv.derived',{w:w.id,s:src?src.id:key})) }
  openMeasure(p.id,r.id,key);
};
A.wvAdd=()=>{ if(!guard()) return; const rt=top(); openSheet({type:'wvAdd',pid:rt.pid,rid:rt.rid,wall:rt.wall}) };
A.wvAddType=d=>{
  if(!guard()) return; const sh=U.sheet; if(!sh||sh.type!=='wvAdd') return; const p=P(sh.pid), r=R(p,sh.rid); if(!r) return;
  const w=roomWalls(r).find(x=>x.id===sh.wall); if(!w) return;
  const door=d.v==='door'; const def=(S.settings.defaults||{})[d.v]||{};
  const dw=def.w??(door?900:1200), dh=def.h??(door?2100:1500), sill=door?0:(def.sill??900);
  const off=door?500:(w.len!=null?wvCentre(w.len,dw):500);
  const fm=mm=>fmtLen(mm,null,mm%10!==0);
  initForm({otype:door?'door':'window',owall:w.id,ow:fm(dw),oh:fm(dh),ooff:fm(off),osill:fm(sill)});
  U.sheet={type:'opening',pid:p.id,rid:r.id,oid:null}; U.sheetAnim=true; render();
};
// A.undo only acts on the 'editor' route; on the wall view, run it as if on the editor (same pid/rid), then re-render.
{ const wvUndo0=A.undo;
  A.undo=d=>{ const rt=top(); if(!rt||rt.s!=='wallView') return wvUndo0(d);
    const keep=render; rt.s='editor'; render=()=>{}; try{ wvUndo0(d) } finally { render=keep; rt.s='wallView' } render() };
}

/* ---------- swipe + arrow keys ---------- */
let wvPtr=null, wvSwipeAt=0;
appEl.addEventListener('pointerdown',e=>{ const el=e.target.closest&&e.target.closest('.wv-elev'); wvPtr=el&&!U.sheet&&!S.firstRun&&top().s==='wallView'?{id:e.pointerId,x:e.clientX,y:e.clientY}:null });
appEl.addEventListener('pointerup',e=>{ const s=wvPtr; wvPtr=null; if(!s||s.id!==e.pointerId) return; const dx=e.clientX-s.x, dy=e.clientY-s.y; if(Math.abs(dx)<48||Math.abs(dx)<Math.abs(dy)*1.5) return; wvSwipeAt=Date.now(); wvStep(dx<0?1:-1) });
appEl.addEventListener('pointercancel',()=>{ wvPtr=null });
appEl.addEventListener('click',e=>{ if(Date.now()-wvSwipeAt<400){ e.stopImmediatePropagation(); e.preventDefault() } },true);
document.addEventListener('keydown',e=>{ if(S.firstRun||U.focus||U.sheet||U.compare||e.ctrlKey||e.metaKey||e.altKey) return; if(e.target.closest&&e.target.closest('#panel')) return; if(top().s!=='wallView') return; if(e.key==='ArrowLeft'){ e.preventDefault(); wvStep(-1) } else if(e.key==='ArrowRight'){ e.preventDefault(); wvStep(1) } });
