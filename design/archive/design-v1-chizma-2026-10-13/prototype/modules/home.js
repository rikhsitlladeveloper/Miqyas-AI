/* ============================== Home: today's work ==============================
   Greeting + laser state, "Continue" with the exact next step, a "Needs attention" list built from the data
   (unconfirmed measurements, opening errors, dragged openings, unanswered quotes, unfinished estimate rows,
   missing builder details), four big action tiles, then a short list of recent projects. */
Object.assign(D,{
'hm.hi':['Salom, {n}','Здравствуйте, {n}','Hello, {n}'],
'hm.hi0':['Salom!','Здравствуйте!','Hello!'],
'hm.next.recv':['{w}: tasdiqlang','{w}: подтвердите','{w}: confirm'],
'hm.next.unset':['{w}: o‘lchang','{w}: измерьте','{w}: measure'],
'hm.next.bad':['Eshik yoki derazani tuzating','Исправьте дверь или окно','Fix a door or window'],
'hm.next.ok':['Hammasi tasdiqlangan','Всё подтверждено','All confirmed'],
'hm.cont':['Davom ettirish','Продолжить','Continue'],
'hm.openProject':['Loyihani ochish','Открыть проект','Open project'],
'hm.noRoom':['Hali xona yo‘q','Комнат пока нет','No rooms yet'],
'hm.att':['E’tibor bering','Требует внимания','Needs attention'],
'hm.allOk':['Hammasi joyida. Kutilayotgan ish yo‘q.','Всё в порядке. Срочных дел нет.','All clear. Nothing is waiting.'],
'hm.a.unconf':['{n} ta o‘lcham tasdiqlanmagan','Не подтверждено размеров: {n}','{n} {n:measurement|measurements} not confirmed'],
'hm.a.bad':['Eshik yoki derazada xato','Ошибка в двери или окне','A door or window needs fixing'],
'hm.a.approx':['{n} ta eshik/deraza joyi taxminiy','Примерное положение проёмов: {n}','{n} {n:opening|openings} placed roughly'],
'hm.a.quote':['Taklif javobini kutyapti, {d} kun','Ждёт ответа на предложение, дней: {d}','Waiting for a reply to the quote, {d} {d:day|days}'],
'hm.a.quote0':['Taklif bugun yuborildi','Предложение отправлено сегодня','Quote sent today'],
'hm.a.rows':['Smetada {n} ta qator to‘ldirilmagan','В смете не заполнено строк: {n}','{n} estimate {n:row|rows} not filled in'],
'hm.a.builder':['Hisobot uchun ismingiz va telefoningizni kiriting','Укажите имя и телефон для отчётов','Add your name and phone for reports'],
'hm.a.builderS':['Profil','Профиль','Profile'],
'hm.more':['Yana {n} ta','Ещё {n}','{n} more'],
'hm.less':['Kamroq ko‘rsatish','Свернуть','Show less'],
'hm.t.new':['Yangi loyiha','Новый проект','New project'],
'hm.t.newS':['Mijoz va manzil','Клиент и адрес','Customer and address'],
'hm.t.measure':['O‘lchash','Измерить','Measure'],
'hm.t.photo':['Surat','Фото','Photo'],
'hm.t.note':['Eslatma','Заметка','Note'],
'hm.to':['“{w}” uchun','в «{w}»','to “{w}”'],
'hm.toNone':['Avval ish joyi kerak','Нужна рабочая зона','Needs a workspace first'],
'hm.needWs':['Avval loyiha va ish joyini yarating','Сначала создайте проект и рабочую зону','Create a project and a workspace first'],
'hm.wd':['Yakshanba|Dushanba|Seshanba|Chorshanba|Payshanba|Juma|Shanba','Воскресенье|Понедельник|Вторник|Среда|Четверг|Пятница|Суббота','Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday'],
'hm.mo':['yanvar|fevral|mart|aprel|may|iyun|iyul|avgust|sentabr|oktabr|noyabr|dekabr','января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря','January|February|March|April|May|June|July|August|September|October|November|December']
});
function hmDate(){ const d=new Date(), wd=t('hm.wd').split('|')[d.getDay()], mo=t('hm.mo').split('|')[d.getMonth()];
  return CUR==='en'?`${wd}, ${d.getDate()} ${mo}`:CUR==='ru'?`${wd}, ${d.getDate()} ${mo}`:`${wd}, ${d.getDate()}-${mo}` }
/* every measured value the room needs, in order: wall lengths (not computed ones), then height */
function hmDimKeys(r){ const ks=[]; roomWalls(r).forEach(w=>{ if(!w.derived&&w.dimKey&&r.dims[w.dimKey]&&!ks.includes(w.dimKey)) ks.push(w.dimKey) }); if(r.dims.H) ks.push('H'); return ks }
const hmDimName=k=>k==='H'?t('ed.Hs'):k==='T'?t('ed.Ts'):t('op.wall')+' '+k;
function hmNext(r){
  const ks=hmDimKeys(r), recv=ks.find(k=>dimStatus(r.dims[k])==='recv'), unset=ks.find(k=>dimStatus(r.dims[k])==='unset');
  if(recv) return {cls:'recv',ic:'clock',txt:t('hm.next.recv',{w:hmDimName(recv)})};
  if(unset) return {cls:'unset',ic:'dim',txt:t('hm.next.unset',{w:hmDimName(unset)})};
  if(roomIssues(r).length) return {cls:'bad',ic:'alert',txt:t('hm.next.bad')};
  return {cls:'ok',ic:'check',txt:t('hm.next.ok')};
}
function hmAttention(){
  const out=[], ps=S.projects.slice().sort((a,b)=>b.edited-a.edited);
  ps.forEach(p=>{
    let un=0, unRoom=null, bad=null, apx=0, apxRoom=null;
    p.rooms.forEach(r=>{ const n=hmDimKeys(r).filter(k=>dimStatus(r.dims[k])!=='conf').length; if(n){ un+=n; unRoom=unRoom||r } if(!bad&&roomIssues(r).length) bad=r; const a=r.openings.filter(o=>o.offDrag||o.sillDrag).length; if(a){ apx+=a; apxRoom=apxRoom||r } });
    if(bad) out.push({ic:'alert',cls:'err',b:t('hm.a.bad'),s:dn(p.name)+', '+dn(bad.name),a:'hmRoom',pid:p.id,id:bad.id,w:4});
    if(un) out.push({ic:'clock',cls:'amb',b:t('hm.a.unconf',{n:un}),s:dn(p.name)+(unRoom?', '+dn(unRoom.name):''),a:'hmRoom',pid:p.id,id:unRoom.id,w:3});
    if(apx) out.push({ic:'dim',cls:'amb',b:t('hm.a.approx',{n:apx}),s:dn(p.name)+', '+dn(apxRoom.name),a:'hmRoom',pid:p.id,id:apxRoom.id,w:2});
    if(stageOf(p)==='quote'&&p.quotes.length){ const q=p.quotes[p.quotes.length-1], d=Math.floor((Date.now()-q.ts)/86400e3); out.push({ic:'send',cls:'cob',b:d<1?t('hm.a.quote0'):t('hm.a.quote',{d}),s:dn(p.name)+', '+money(BigInt(q.total||'0'),p,null,true),a:'hmProj',pid:p.id,tab:'quotes',w:1}) }
    const est=p.estimate||{materials:[],labor:[]}, blank=v=>String(v??'').trim()==='';
    const rows=est.materials.filter(m=>blank(m.qty)||blank(m.price)).length+est.labor.filter(l=>blank(l.amount)).length;
    if(rows) out.push({ic:'doc',cls:'gry',b:t('hm.a.rows',{n:rows}),s:dn(p.name),a:'hmProj',pid:p.id,tab:'estimate',w:1});
  });
  const b=S.settings.builder; if(S.projects.length&&(!b.name||!b.phone)) out.push({ic:'user',cls:'gry',b:t('hm.a.builder'),s:t('hm.a.builderS'),a:'goBuilderHome',w:0});
  return out.sort((x,y)=>y.w-x.w);
}
/* where Photo / Note go: the last room's workspace, else the newest project's first workspace */
function hmTarget(){
  const lp=S.lastOpen&&P(S.lastOpen.pid), lr=lp&&R(lp,S.lastOpen.rid);
  if(lr&&WSP(lp,lr.floorId)) return {pid:lp.id,wid:lr.floorId,w:WSP(lp,lr.floorId)};
  const p=S.projects.slice().sort((a,b)=>b.edited-a.edited).find(x=>x.floors.length); return p?{pid:p.id,wid:p.floors[0].id,w:p.floors[0]}:null;
}
PAGES.home=()=>{
  const ps=S.projects.slice().sort((a,b)=>b.edited-a.edited), lk=isLocked();
  const b=S.settings.builder, first=String(b.name||'').trim().split(/\s+/)[0];
  const bt=S.demo.bt, devLab=t(bt==='connected'?'dev.conn':bt==='off'?'dev.off':bt==='denied'?'dev.denied':'dev.disc');
  const hi=`<div class="hm-hi"><div class="r1"><small>${esc(hmDate())}</small><button class="hm-dev ${bt==='connected'?'on':bt==='disconnected'?'':'bad'}" data-a="device"><i></i><span>${esc(devLab)}</span></button></div><h2>${esc(first?t('hm.hi',{n:first}):t('hm.hi0'))}</h2></div>`;
  const tile=(a,icn,ti,sub,cls,extra)=>`<button class="hm-tile ${cls||''}" data-a="${a}" ${extra||''}><span class="ic">${ic(icn)}</span><b>${esc(t(ti))}</b><small>${esc(sub)}</small></button>`;
  const tg=hmTarget();
  const tiles=`<div class="hm-tiles">${tile('newProject',lk?'lock':'plus','hm.t.new',t('hm.t.newS'),lk?'locked':'pri')}${tile('tab','laser','hm.t.measure',devLab,'','data-v="measure"')}${tile('hmPhoto','camera','hm.t.photo',tg?t('hm.to',{w:floorName(tg.w)}):t('hm.toNone'))}${tile('hmNote','note','hm.t.note',tg?t('hm.to',{w:floorName(tg.w)}):t('hm.toNone'))}</div>`;
  if(!ps.length){ seen('empty');
    return `<section class="page ${U.anim||''}">${bar({right:savedChip()}).replace('<span class="sp"></span>','<span class="wordmark">METRX</span><span class="sp"></span>')}${banners()}<div class="scroll" data-scroll="home"><div class="hm">${hi}<div class="hm-empty"><h3>${esc(t('home.emptyTitle'))}</h3><p>${esc(t('home.emptyBody'))}</p><button class="btn ghost" data-a="goBackup">${ic('restore','i s')}${esc(t('pl.restore'))}</button></div><div class="hm-tiles">${tile('newProject',lk?'lock':'plus','hm.t.new',t('hm.t.newS'),lk?'locked':'pri')}${tile('tab','laser','hm.t.measure',devLab,'','data-v="measure"')}</div></div></div></section>` }
  // continue
  const lp=S.lastOpen&&P(S.lastOpen.pid), lr=lp&&R(lp,S.lastOpen.rid);
  let cont='';
  if(lr){ const nx=hmNext(lr), w=WSP(lp,lr.floorId), sc=78/Math.max(lr.dims.A.v||4000,lr.dims.B.v||3000);
    cont=`<div class="hm-cont"><button class="top" data-a="resume"><span class="pl">${lr.shape==='poly'?thumbSVG(lr,84,66):miniPlan(lr,sc)}</span><span class="tx"><span class="crumb">${esc(dn(lp.name))}${w?' › '+esc(floorName(w)):''}</span><b>${esc(dn(lr.name))}</b><span class="hm-next ${nx.cls}">${ic(nx.ic,'i xs')}${esc(nx.txt)}</span></span></button><button class="btn pri full" data-a="resume">${ic(nx.cls==='ok'?'room':'laser','i s')}${esc(t('hm.cont'))}</button></div>` }
  else { const p=ps[0]; cont=`<div class="hm-cont"><button class="top" data-a="openProject" data-id="${p.id}"><span class="pl">${ic('folder','i l')}</span><span class="tx"><span class="crumb">${esc(t('stage.'+stageOf(p)))}</span><b>${esc(dn(p.name))}</b><span class="hm-next unset">${ic('room','i xs')}${esc(t('hm.noRoom'))}</span></span></button><button class="btn pri full" data-a="openProject" data-id="${p.id}">${esc(t('hm.openProject'))}</button></div>` }
  // needs attention
  const att=hmAttention(), shown=U.hmAll?att:att.slice(0,3);
  const attH=att.length?`<div class="hm-sech"><b>${esc(t('hm.att'))}</b><span class="n">${att.length}</span></div><div class="hm-att">${shown.map(x=>`<button class="it" data-a="${x.a}" data-pid="${x.pid||''}" data-id="${x.id||''}" data-tab="${x.tab||''}"><span class="ic ${x.cls}">${ic(x.ic,'i s')}</span><span class="tx"><b>${esc(x.b)}</b><small>${esc(x.s)}</small></span>${ic('chev','i s')}</button>`).join('')}${att.length>3?`<button class="more" data-a="hmAll">${esc(U.hmAll?t('hm.less'):t('hm.more',{n:att.length-3}))}</button>`:''}</div>`
    :`<div class="hm-ok">${ic('check','i s')}<span>${esc(t('hm.allOk'))}</span></div>`;
  // recent
  const rec=`<div class="hm-sech"><b>${esc(t('home.recent'))}</b><button data-a="tab" data-v="projects">${esc(t('home.all'))}</button></div><div class="hm-recent">${ps.slice(0,3).map(p=>`<button class="it" data-a="openProjectHome" data-id="${p.id}"><span class="tx"><b>${esc(dn(p.name))}</b><small>${esc([dn(p.customer),dn(p.address)].filter(Boolean).join(', ')||'—')}</small></span><span class="stg ${stageOf(p)==='done'?'done':''}">${esc(t('stage.'+stageOf(p)))}</span></button>`).join('')}</div>`;
  return `<section class="page ${U.anim||''}">${bar({right:savedChip()}).replace('<span class="sp"></span>','<span class="wordmark">METRX</span><span class="sp"></span>')}${banners()}<div class="scroll" data-scroll="home"><div class="hm">${hi}${cont}${attH}${tiles}${rec}</div></div></section>`;
};
function hmGo(routes){ closeSheet(true); blur(); S.nav.tab='projects'; S.nav.stacks.projects=[{s:'projects'},...routes]; U.anim='push'; render() }
function hmRoomRoutes(p,r){ const w=WSP(p,r.floorId); return [{s:'project',id:p.id,tab:'rooms'},...(w?[{s:'space',pid:p.id,wid:w.id}]:[]),{s:'editor',pid:p.id,rid:r.id,mode:'plan'}] }
A.resume=()=>{ const p=S.lastOpen&&P(S.lastOpen.pid), r=p&&R(p,S.lastOpen.rid); if(!r) return; hmGo(hmRoomRoutes(p,r)) };
A.hmRoom=d=>{ const p=P(d.pid), r=p&&R(p,d.id); if(!r) return; S.lastOpen={pid:p.id,rid:r.id}; commit(); hmGo(hmRoomRoutes(p,r)) };
A.hmProj=d=>{ const p=P(d.pid); if(!p) return; hmGo([{s:'project',id:p.id,tab:d.tab||'rooms'}]) };
A.openProjectHome=d=>hmGo([{s:'project',id:d.id,tab:'rooms'}]);
A.goBuilderHome=()=>{ closeSheet(true); S.nav.tab='profile'; S.nav.stacks.profile=[{s:'profile'}]; A.goBuilder() };
A.hmAll=()=>{ U.hmAll=!U.hmAll; render() };
function hmToSpace(){ const tg=hmTarget(); if(!tg){ toast(t('hm.needWs')); render(); return null } hmGo([{s:'project',id:tg.pid,tab:'rooms'},{s:'space',pid:tg.pid,wid:tg.wid}]); return tg }
A.hmPhoto=()=>{ if(!guard()) return; const tg=hmToSpace(); if(tg) openSheet({type:'addItem',pid:tg.pid,wid:tg.wid,step:'photo'}) };
A.hmNote=()=>{ if(!guard()) return; const tg=hmToSpace(); if(tg) wsNewNote(tg.pid,tg.wid) };
