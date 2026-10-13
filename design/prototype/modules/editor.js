/* ============================== Room editor: big plan + bottom panel ==============================
   Option A's big plan, with one bottom panel that is
   - collapsed: B's step card for the current measurement (big number, Again / Confirm, or Take from laser / Type),
   - expanded:  C's list of every measurement with its state and button, each wall's area, and the doors/windows.
   Plan mode only; 3D mode, and the shape-edit / diagonal modes of non-rectangular rooms, keep their own screens.
   Received laser values are never applied without the builder pressing Confirm. */
Object.assign(D,{
'ed2.next':['Keyingi: {w}','Далее: {w}','Next: {w}'],
'ed2.fromLaser':['{w}, lazerdan','{w}, с лазера','{w}, from the laser'],
'ed2.fromQuick':['{w}, O‘lchash bo‘limidan','{w}, из раздела «Замер»','{w}, from the Measure tab'],
'ed2.diag':['Diagonal','Диагональ','Diagonal'],
'ed2.unconf':['Tasdiqlanmagan','Не подтверждено','Not confirmed'],
'ed2.confirmed':['Tasdiqlangan','Подтверждено','Confirmed'],
'ed2.notMeasured':['O‘lchanmagan','Не измерено','Not measured'],
'ed2.again':['Qayta','Заново','Again'],
'ed2.confirm':['Tasdiqlash','Подтвердить','Confirm'],
'ed2.getLaser':['Lazerdan olish','Взять с лазера','Take from laser'],
'ed2.manual':['Qo‘lda','Вручную','Type it'],
'ed2.remeasure':['Qayta o‘lchash','Измерить заново','Measure again'],
'ed2.edit':['Tahrirlash','Изменить','Edit'],
'ed2.noLaser':['Lazer ulanmagan. Qiymatni qo‘lda kiriting.','Лазер не подключён. Введите значение вручную.','The laser isn’t connected. Type the value.'],
'ed2.pressLaser':['Lazer tugmasini bosing yoki qo‘lda kiriting','Нажмите кнопку лазера или введите вручную','Press the laser button or type the value'],
'ed2.left':['Keyin: {w}. Yana {n} ta','Далее: {w}. Ещё {n}','Then: {w}. {n} more'],
'ed2.last':['Bu oxirgi o‘lcham','Это последний размер','This is the last one'],
'ed2.done':['Hammasi tasdiqlangan','Всё подтверждено','All confirmed'],
'ed2.sum':['Pol {f} m², devor sof {w} m²','Пол {f} м², стены чистые {w} м²','Floor {f} m², net wall {w} m²'],
'ed2.sumNoH':['Pol {f} m²','Пол {f} м²','Floor {f} m²'],
'ed2.all':['Barcha o‘lchamlar','Все размеры','All sizes'],
'ed2.hide':['Yopish','Свернуть','Collapse'],
'ed2.meas':['O‘LCHAMLAR','РАЗМЕРЫ','MEASUREMENTS'],
'ed2.walls':['DEVOR MAYDONLARI, m²','ПЛОЩАДЬ СТЕН, м²','WALL AREAS, m²'],
'ed2.ops':['ESHIK VA DERAZALAR','ДВЕРИ И ОКНА','DOORS AND WINDOWS'],
'ed2.needH':['Maydonlar uchun balandlikni o‘lchang.','Для площадей измерьте высоту.','Measure the height to get the areas.'],
'ed2.colWall':['Devor','Стена','Wall'],
'ed2.colGross':['Umumiy','Общая','Gross'],
'ed2.colOpen':['Ochiq','Проёмы','Openings'],
'ed2.colNet':['Sof','Чистая','Net'],
'ed2.total':['Jami','Итого','Total'],
'ed2.add':['Eshik yoki deraza qo‘shish','Добавить дверь или окно','Add a door or window'],
'ed2.plan':['Reja','План','Plan'],
'ed2.shape':['Shakl','Форма','Shape'],
'ed2.diag':['Diagonal','Диагональ','Diagonal'],
'ed2.dev':['Lazer','Лазер','Laser'],
'ed2.calc':['hisoblangan','вычислено','calculated'],
'ed2.measure':['O‘lchash','Измерить','Measure'],
'ed2.re':['Qayta o‘lchash: {w}','Повторный замер: {w}','Measuring again: {w}'],
'ed2.cur':['Hozirgi: {v} m. Yangisi tasdiqlanmaguncha o‘zgarmaydi.','Сейчас: {v} м. Не изменится, пока не подтвердите новое.','Now: {v} m. It stays until you confirm a new one.'],
'ed2.st.recv':['lazerdan, tasdiqlanmagan','с лазера, не подтверждено','from the laser, not confirmed']
});
const ed2Name=k=>k==='H'?t('ed.Hs'):k==='T'?t('ed.T'):/^X\d/.test(k)?t('ed2.diag')+' '+k:t('op.wall')+' '+k;
const ed2Keys=r=>{ const ks=hmDimKeys(r); if(r.dims.T&&!ks.includes('T')) ks.push('T'); return ks };
function ed2Focus(r){
  const ks=ed2Keys(r), st=k=>dimStatus(r.dims[k]);
  if(U.edFocus&&U.edFocusRid===r.id&&r.dims[U.edFocus]){ const kd=st(U.edFocus); return {k:U.edFocus,kind:kd==='conf'&&U.edRe===r.id+':'+U.edFocus?'again':kd} }
  const recv=ks.find(k=>st(k)==='recv'); if(recv) return {k:recv,kind:'recv'};
  const unset=hmDimKeys(r).find(k=>st(k)==='unset'); if(unset) return {k:unset,kind:'unset'};
  const iss=roomIssues(r); if(iss.length) return {kind:'bad',iss:iss[0]};
  return {kind:'ok'};
}
function ed2Card(p,r){
  const f=ed2Focus(r), lk=isLocked(), bt=S.demo.bt==='connected';
  const ks=hmDimKeys(r), open=ks.filter(k=>dimStatus(r.dims[k])!=='conf'&&k!==f.k);
  const foot=f.k?`<div class="ed2-foot"><span>${esc(open.length?t('ed2.left',{w:ed2Name(open[0]),n:open.length}):(f.kind==='unset'||f.kind==='recv')?t('ed2.last'):'')}</span><button data-a="edPanel">${ic('chev','i s')}${esc(t(U.edPanel?'ed2.hide':'ed2.all'))}</button></div>`
    :`<div class="ed2-foot"><span></span><button data-a="edPanel">${ic('chev','i s')}${esc(t(U.edPanel?'ed2.hide':'ed2.all'))}</button></div>`;
  if(f.kind==='recv'){ const pd=r.dims[f.k].pending;
    return `<div class="ed2-card"><div class="ed2-q"><span class="tx"><small>${esc(t(pd.from==='quick'?'ed2.fromQuick':'ed2.fromLaser',{w:ed2Name(f.k)}))}</small><span class="ed2-v recv">${fmtLen(pd.mm,null,true)}<small>${esc(M())}</small></span></span><span class="ed2-st recv">${ic('clock','i xs')}${esc(t('ed2.unconf'))}</span></div>
      <div class="ed2-acts"><button class="btn sec" data-a="edAgain" data-k="${f.k}">${ic('laser','i s')}<span>${esc(t('ed2.again'))}</span></button><button class="btn pri" data-a="edConfirm" data-k="${f.k}">${ic('check','i s')}<span>${esc(t('ed2.confirm'))}</span></button></div>${foot}</div>` }
  if(f.kind==='unset'||f.kind==='again'){ const again=f.kind==='again';
    return `<div class="ed2-card"><div class="ed2-q"><span class="tx"><small>${esc(t(again?'ed2.re':'ed2.next',{w:ed2Name(f.k)}))}</small><span class="ed2-v unset">?<small>${esc(M())}</small></span></span>${again?`<button class="ed2-st unset" data-a="edCancelRe">${ic('x','i xs')}${esc(t('common.cancel'))}</button>`:`<span class="ed2-st unset">${esc(t('ed2.notMeasured'))}</span>`}</div>${again?`<p class="fhint">${esc(t('ed2.cur',{v:fmtLen(r.dims[f.k].v)}))}</p>`:''}
      ${bt?`<p class="fhint">${esc(t('ed2.pressLaser'))} ${simtag()}</p>`:`<p class="fhint">${ic('btoff','i xs')} ${esc(t('ed2.noLaser'))}</p>`}
      <div class="ed2-acts"><button class="btn sec" data-a="edManual" data-k="${f.k}">${ic('kbd','i s')}<span>${esc(t('ed2.manual'))}</span></button>${bt?`<button class="btn ${lk?'locked':'pri'}" data-a="edLaser" data-k="${f.k}">${ic(lk?'lock':'laser','i s')}<span>${esc(t('ed2.getLaser'))}</span></button>`:`<button class="btn pri" data-a="device">${ic('bt','i s')}<span>${esc(t('ed2.dev'))}</span></button>`}</div>${foot}</div>` }
  if(f.kind==='conf'){ const d=r.dims[f.k];
    return `<div class="ed2-card"><div class="ed2-q"><span class="tx"><small>${esc(ed2Name(f.k))}${D['src.'+(d.src||'manual')]?', '+esc(t('src.'+(d.src||'manual'))):''}</small><span class="ed2-v">${fmtLen(d.v)}<small>${esc(M())}</small></span></span><span class="ed2-st conf">${ic('check','i xs')}${esc(t('ed2.confirmed'))}</span></div>
      <div class="ed2-acts"><button class="btn sec" data-a="edManual" data-k="${f.k}">${ic('edit','i s')}<span>${esc(t('ed2.edit'))}</span></button><button class="btn pri" data-a="edRemeasure" data-k="${f.k}">${ic('laser','i s')}<span>${esc(t('ed2.remeasure'))}</span></button></div>${foot}</div>` }
  if(f.kind==='bad') return `<div class="ed2-card"><div class="banner err" style="margin:0">${ic('alert','i s')}<span class="tx">${esc(f.iss.iss.msg)}</span><button class="act" data-a="editOpening" data-id="${f.iss.o.id}">${esc(t('ed.fix'))}</button></div>${foot}</div>`;
  const a=areas(r);
  return `<div class="ed2-card"><div class="ed2-ok"><span class="ic">${ic('check')}</span><span class="tx"><b>${esc(t('ed2.done'))}</b><small>${a?esc(a.net!=null?t('ed2.sum',{f:fmtArea(a.floor),w:fmtArea(a.net)}):t('ed2.sumNoH',{f:fmtArea(a.floor)})):''}</small></span></div>
    <div class="ed2-acts"><button class="btn sec" data-a="wallView">${ic('walls','i s')}<span>${esc(t('ed.tb.walls'))}</span></button><button class="btn pri" data-a="mode" data-v="3d">${ic('cube','i s')}<span>3D</span></button></div>${foot}</div>`;
}
function ed2List(p,r){
  const f=ed2Focus(r), lk=isLocked();
  const rows=ed2Keys(r).map(k=>{ const d=r.dims[k], st=dimStatus(d);
    const v=st==='recv'?fmtLen(d.pending.mm,null,true):st==='unset'?'?':fmtLen(d.v);
    const sub=st==='recv'?t('ed2.st.recv'):st==='unset'?t('ed2.notMeasured'):t('ed2.confirmed')+(D['src.'+(d.src||'manual')]?', '+t('src.'+(d.src||'manual')):'');
    const act=st==='recv'?`<button class="act" data-a="edConfirm" data-k="${k}">${esc(t('ed2.confirm'))}</button>`:st==='unset'?`<button class="act sec" data-a="edFocusK" data-k="${k}">${esc(t('ed2.measure'))}</button>`:`<span class="ok">${ic('check','i s')}</span>`;
    return `<div class="ed2-row" ${st==='conf'?`data-a="edFocusK" data-k="${k}" role="button"`:''}><span class="ed2-k ${f.k===k?'sel':''}">${esc(k)}</span><span class="tx"><b>${esc(ed2Name(k))}</b><small>${esc(sub)}</small></span><span class="val ${st}">${v}</span>${act}</div>` }).join('');
  // wall areas (confirmed height only; values never guessed)
  const H=r.dims.H.v, walls=roomWalls(r); let wa='';
  if(H==null) wa=`<p class="ed2-need">${esc(t('ed2.needH'))}</p>`;
  else { let tg=0,to=0,tn=0,ok=true;
    const rs=walls.map(w=>{ const ops=r.openings.filter(o=>o.wall===w.id), s=wvWallStats(w.len,H,ops); if(s.gross==null) ok=false; else { tg+=s.gross; tn+=s.net } to+=s.open;
      return `<div class="r"><span>${esc(w.id)}${w.derived?` <small style="color:var(--ink3)">=</small>`:''}</span><span>${s.gross==null?'?':fmtArea(s.gross)}</span><span>${s.open?fmtArea(s.open):'—'}</span><span><b>${s.net==null?'?':fmtArea(s.net)}</b></span></div>` }).join('');
    wa=`<div class="ed2-wa"><div class="h"><span>${esc(t('ed2.colWall'))}</span><span>${esc(t('ed2.colGross'))}</span><span>${esc(t('ed2.colOpen'))}</span><span>${esc(t('ed2.colNet'))}</span></div>${rs}${ok?`<div class="r tot"><span>${esc(t('ed2.total'))}</span><span>${fmtArea(tg)}</span><span>${to?fmtArea(to):'—'}</span><span><b>${fmtArea(tn)}</b></span></div>`:''}</div>` }
  const ops=r.openings.map(o=>{ const nm=t(o.type==='door'?'op.door':'op.window'), apx=o.offDrag||o.sillDrag;
    return `<button class="ed2-row" data-a="editOpening" data-id="${o.id}"><span class="ed2-k">${ic(o.type==='door'?'door':'window','i s')}</span><span class="tx"><b>${esc(nm)}, ${esc(t('op.wall'))} ${esc(o.wall)}</b><small>${esc(t('wv.off',{c:wallCorner(r,o.wall),v:(apx?'≈ ':'')+fmtLen(o.off)+' '+M()}))}</small></span><span class="val">${fmtLen(o.w)} × ${fmtLen(o.h)}</span>${ic('chev','i s')}</button>` }).join('');
  return `<div class="ed2-sec"><h4>${esc(t('ed2.meas'))}</h4>${rows}</div><div class="ed2-sec"><h4>${esc(t('ed2.walls'))}</h4>${wa}</div><div class="ed2-sec"><h4>${esc(t('ed2.ops'))}</h4>${ops}<button class="ed2-add" data-a="edOpenings">${ic(lk?'lock':'plus','i s')}${esc(t('ed2.add'))}</button></div>`;
}
{ const base=PAGES.editor; PAGES.editor=rt=>{
  const p=P(rt.pid), r=R(p,rt.rid); if(!r) return base(rt);
  const poly=typeof skIsPoly==='function'&&skIsPoly(r);
  if((rt.mode||'plan')!=='plan'||(poly&&(U.skEdit===r.id||(U.skDiag&&U.skDiag.rid===r.id)))) return base(rt);
  const w=WSP(p,r.floorId), h=U.hist[r.id]||{u:[],r:[]}, lk=isLocked(), bt=S.demo.bt;
  const f=ed2Focus(r), msSel=U.sheet&&U.sheet.type==='measure'?U.sheet.dim:f.k||null, opSel=U.sheet&&U.sheet.type==='opening'?U.sheet.oid:null;
  const right=`<button class="ed2-dev ${bt==='connected'?'on':'off'}" data-a="device" aria-label="${esc(t(bt==='connected'?'dev.conn':'dev.disc'))}">${ic(bt==='connected'?'bt':'btoff')}<i></i></button><button class="ib" data-a="undo" ${h.u.length?'':'disabled'} aria-label="${esc(t('common.undo'))}">${ic('undo')}</button><button class="ib" data-a="redo" ${h.r.length?'':'disabled'} aria-label="redo">${ic('redo')}</button><button class="ib" data-a="roomInfo" aria-label="menu">${ic('more')}</button>`;
  const crumb=[dn(p.name),w?floorName(w):''].filter(Boolean).join(' › ');
  const fl=poly?`<div class="ed2-fl"><button data-a="skEdit">${ic('edit','i s')}${esc(t('ed2.shape'))}</button><button data-a="skDiagMode">${ic('dim','i s')}${esc(t('ed2.diag'))}</button></div>`:'';
  const polyHint=poly&&typeof skHint==='function'?skHint(r,skGeo(r)):'';
  const canvas=`<div class="canvas ${U.sheet?'top':''}">${planSVG(r,{sel:msSel,selOp:opSel})}${fl}${trayBtn()}</div>`;
  const exp=!!U.edPanel;
  /* one sheet: the step card is always on top, every measurement is underneath and comes up when the sheet is pulled */
  const panel=`<div class="ed2-panel ${exp?'open':''}" data-rid="${r.id}"><button class="ed2-grab" data-a="edPanel" aria-label="${esc(t(exp?'ed2.hide':'ed2.all'))}" aria-expanded="${exp}"></button><div class="ed2-body" data-scroll="ed2-${r.id}"><div class="ed2-peek">${polyHint.includes('banner')?polyHint:''}${ed2Card(p,r)}</div><div class="ed2-more" ${exp?'':'inert aria-hidden="true"'}>${ed2List(p,r)}</div></div></div>`;
  const tools=`<nav class="tools"><button class="on" data-a="noop">${ic('room')}<span>${esc(t('ed2.plan'))}</span></button><button data-a="wallView">${ic('walls')}<span>${esc(t('ed.tb.walls'))}</span></button><button class="${lk?'lk':''}" data-a="edOpenings">${ic('door')}<span>${esc(t('ed.tb.openings'))}</span></button><button data-a="mode" data-v="3d">${ic('cube')}<span>3D</span></button></nav>`;
  return `<section class="page ed2 ${U.anim||''}">${bar({backIcon:true,title:dn(r.name),sub:crumb,right})}${canvas}${panel}${tools}</section>`;
} }
/* tapping a wall or chip in the plan (or a new room, or a tray reading) focuses the step card instead of opening the sheet */
{ const om=openMeasure; openMeasure=function(pid,rid,dim){ const rt=top();
  if(!U.edSheet&&rt&&rt.s==='editor'&&(rt.mode||'plan')==='plan'&&rt.rid===rid&&U.skEdit!==rid){ closeSheet(true); blur(); U.edFocus=dim; U.edFocusRid=rid; U.edPanel=false; render(); return }
  om(pid,rid,dim) } }
const ed2Room=()=>edRoom();
function ed2Sheet(k,manual){ const {p,r}=ed2Room(); U.edSheet=true; try{ openMeasure(p.id,r.id,k); if(manual) A.msPhase({v:'manual'}) } finally { U.edSheet=false } }
A.edPanel=()=>{ U.edPanel=!U.edPanel; render() };
A.edFocusK=d=>{ const {r}=ed2Room(); U.edFocus=d.k; U.edFocusRid=r.id; U.edPanel=false; render() };
A.edConfirm=d=>{ if(!guard()) return; const {p,r}=ed2Room(), pd=r.dims[d.k]&&r.dims[d.k].pending; if(!pd) return; U.edFocus=null; U.edRe=null; applyDim(p,r,d.k,pd.mm,pd.src) };
A.edAgain=d=>{ const {r}=ed2Room(); if(r.dims[d.k]){ delete r.dims[d.k].pending; if(r.dims[d.k].v!=null) U.edRe=r.id+':'+d.k } U.edFocus=d.k; U.edFocusRid=r.id; render() };
A.edLaser=d=>{ if(!guard()) return; const {r}=ed2Room(); const target=simTarget(r,d.k), n=(U.simCount=(U.simCount||0)+1), mm=n%3===0?target+[2,-3,1][n%3]:target; r.dims[d.k].pending={mm,src:'sim'}; U.edFocus=d.k; U.edFocusRid=r.id; commit(); render() };
A.edManual=d=>{ if(!guard()) return; ed2Sheet(d.k,true) };
A.edRemeasure=d=>{ if(!guard()) return; const {r}=ed2Room(); if(r.dims[d.k]) delete r.dims[d.k].pending; U.edFocus=d.k; U.edFocusRid=r.id; U.edRe=r.id+':'+d.k; render() };
A.edCancelRe=()=>{ U.edRe=null; render() };
/* any confirmed value (typed in the sheet included) ends "measure again" for that dimension and moves the card on */
{ const ad=applyDim; applyDim=function(p,r,dim,mm,src){ if(U.edRe===r.id+':'+dim) U.edRe=null; if(U.edFocus===dim&&U.edFocusRid===r.id) U.edFocus=null; return ad.apply(this,arguments) } }
/* The panel's height: closed, it shows the step card; open, up to two thirds of the screen. Set after every redraw, so it
   can glide from where it was (or from where the finger left it). */
function ed2Fit(){
  const pn=appEl.querySelector('.ed2-panel'); if(!pn){ U.edH=null; U.edHFor=null; return }
  const grab=pn.querySelector('.ed2-grab'), peekEl=pn.querySelector('.ed2-peek'), body=pn.querySelector('.ed2-body'), page=pn.closest('.page');
  const peek=grab.offsetHeight+peekEl.offsetHeight, full=Math.max(peek,Math.min(Math.round(page.clientHeight*0.6),grab.offsetHeight+body.scrollHeight));
  const target=U.edPanel?full:peek, from=U.edHFor===pn.dataset.rid?U.edH:null;
  pn.dataset.peek=peek; pn.dataset.full=full; U.edH=target; U.edHFor=pn.dataset.rid;
  if(from!=null&&Math.abs(from-target)>2){ pn.style.transition='none'; pn.style.height=from+'px'; void pn.offsetHeight; pn.style.transition='' }
  pn.style.height=target+'px'; if(!U.edPanel) body.scrollTop=0;
}
{ const base=render; render=function(){ base(); ed2Fit() } }
/* drag the handle, or swipe the card up: the sheet follows the finger, then settles open or closed */
{ let gp=null; const pn=()=>appEl.querySelector('.ed2-panel');
  appEl.addEventListener('pointerdown',e=>{ gp=null; if(U.sheet||e.button>0||!e.target.closest) return; const el=pn(); if(!el||!el.contains(e.target)) return;
    if(!e.target.closest('.ed2-grab')&&(U.edPanel||!e.target.closest('.ed2-peek'))) return;
    gp={id:e.pointerId,y:e.clientY,h0:el.offsetHeight,peek:Number(el.dataset.peek)||el.offsetHeight,full:Number(el.dataset.full)||el.offsetHeight,moved:false,ly:e.clientY,lt:e.timeStamp,v:0} });
  appEl.addEventListener('pointermove',e=>{ if(!gp||gp.id!==e.pointerId) return; const dy=e.clientY-gp.y;
    if(!gp.moved){ if(Math.abs(dy)<8) return; gp.moved=true; U.gesture=true }
    const el=pn(); if(!el){ gp=null; U.gesture=false; return }
    const dt=e.timeStamp-gp.lt; if(dt>0){ gp.v=(e.clientY-gp.ly)/dt; gp.ly=e.clientY; gp.lt=e.timeStamp }
    const h=Math.max(gp.peek,Math.min(gp.full,gp.h0-dy)); el.classList.add('drag'); el.style.height=h+'px'; U.edH=h });
  const end=e=>{ if(!gp||gp.id!==e.pointerId) return; const s=gp; gp=null; if(!s.moved) return; U.gesture=false; U.edSwipe=Date.now();
    const el=pn(); if(el) el.classList.remove('drag');
    /* a flick decides by its direction; a slow pull of more than a thumb's width goes where it was pulled; less than that springs back */
    const pulled=(U.edH||s.h0)-s.h0;
    if(e.type!=='pointercancel'){ if(Math.abs(s.v)>0.25) U.edPanel=s.v<0; else if(Math.abs(pulled)>56) U.edPanel=pulled>0 }
    render() };
  appEl.addEventListener('pointerup',end); appEl.addEventListener('pointercancel',end);
  appEl.addEventListener('click',e=>{ if(U.edSwipe&&Date.now()-U.edSwipe<350&&e.target.closest&&e.target.closest('.ed2-panel')){ e.stopImmediatePropagation(); e.preventDefault() } },true); }
