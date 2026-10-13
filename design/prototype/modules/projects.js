/* ============================== Projects: site cards ==============================
   One card per site with the numbers a brickmason prices by (net wall area, measurements confirmed, estimate),
   what is waiting, a Call button and one main button that does the next job for the project's state.
   An Active / Done / All switch replaces the six stage chips; "+ Project" floats above the tab bar. */
Object.assign(D,{
'pl.active':['Faol','Активные','Active'],
'pl.doneSeg':['Tugagan','Готовые','Done'],
'pl.allSeg':['Hammasi','Все','All'],
'pl.wall':['Devor, sof','Стены, чистые','Net wall'],
'pl.meas':['O‘lchangan','Измерено','Measured'],
'pl.est':['Smeta','Смета','Estimate'],
'pl.mln':['mln','млн','M'],
'pl.call':['Qo‘ng‘iroq','Позвонить','Call'],
'pl.open':['Ochish','Открыть','Open'],
'pl.a.measure':['O‘lchashni davom ettirish','Продолжить замер','Continue measuring'],
'pl.a.fix':['Xatoni tuzatish','Исправить ошибку','Fix the error'],
'pl.a.addRoom':['Xona qo‘shish','Добавить комнату','Add a room'],
'pl.a.estimate':['Smetani to‘ldirish','Заполнить смету','Fill in the estimate'],
'pl.a.quote':['Taklif chiqarish','Выпустить КП','Issue a quote'],
'pl.a.quotes':['Takliflar','Предложения','View quotes'],
'pl.noRooms':['Hali xona o‘lchanmagan','Комнаты ещё не измерены','No rooms measured yet'],
'pl.fab':['Loyiha','Проект','Project'],
'pl.none':['Bu bo‘limda loyiha yo‘q','В этом разделе проектов нет','No projects here'],
'pl.ey.all':['Barcha loyihalar','Все проекты','All projects'],
'pl.ey.active':['Faol loyihalar','Активные проекты','Active projects'],
'pl.ey.done':['Tugagan loyihalar','Готовые проекты','Finished projects'],
'pl.e.t':['Hali loyiha yo‘q','Проектов пока нет','No projects yet'],
'pl.e.b':['Birinchi loyihangizni yarating. Barcha o‘lchov va smetalar shu yerda saqlanadi.','Создайте первый проект. Все замеры и сметы хранятся здесь.','Create your first project. All measurements and estimates are kept here.'],
'pl.e.new':['Yangi loyiha yaratish','Создать новый проект','Create a new project'],
'pl.e.foot':['Loyihalar shu telefonda saqlanadi','Проекты хранятся на этом телефоне','Projects are kept on this phone']
});
/* no projects yet: one card that says so and offers the two ways to get one */
function plEmpty(){
  const lk=isLocked();
  return `<div class="pl pl-e"><div class="pl-ec"><span class="ill">${ic('folder','i l')}<i>${ic('plus','i xs')}</i></span><h3>${esc(t('pl.e.t'))}</h3><p>${esc(t('pl.e.b'))}</p><button class="btn ${lk?'locked':'pri'} full" data-a="newProject">${ic(lk?'lock':'plus','i s')}${esc(t('pl.e.new'))}</button><button class="btn sec full" data-a="goBackup">${ic('restore','i s')}${esc(t('pl.restore'))}</button></div><p class="pl-foot">${esc(t('pl.e.foot'))}</p></div>`;
}
function pcStats(p){
  let need=0, conf=0, net=0, nets=0, unRoom=null, bad=null;
  p.rooms.forEach(r=>{ const ks=hmDimKeys(r); need+=ks.length; const c=ks.filter(k=>dimStatus(r.dims[k])==='conf').length; conf+=c; if(c<ks.length&&!unRoom) unRoom=r; if(!bad&&roomIssues(r).length) bad=r; const a=areas(r); if(a&&a.net!=null){ net+=a.net; nets++ } });
  const est=p.estimate||{materials:[],labor:[]}, blank=v=>String(v??'').trim()==='';
  const rows=est.materials.length+est.labor.length, open=est.materials.filter(m=>blank(m.qty)||blank(m.price)).length+est.labor.filter(l=>blank(l.amount)).length;
  return {need,conf,net,nets,unRoom,bad,rows,open,g:totals(p).g};
}
function pcMoney(p,g){
  if(!g||g===0n) return '—';
  const v=Number(g)/Math.pow(10,p.precision||0);
  if(p.currency==='UZS'&&v>=1e6) return (v/1e6).toFixed(2).replace(/\.?0+$/,'').replace('.',DEC())+` <small>${esc(t('pl.mln'))}</small>`;
  return money(g,p,null,false)+` <small>${esc(p.currency)}</small>`;
}
function pcCard(p){
  const st=pcStats(p), stage=stageOf(p);
  // what's waiting (same order of importance as Home)
  let nx=null;
  if(st.bad) nx={cls:'err',ic:'alert',txt:t('hm.a.bad')};
  else if(st.need&&st.conf<st.need) nx={cls:'amb',ic:'clock',txt:t('hm.a.unconf',{n:st.need-st.conf})};
  else if(!p.rooms.length) nx={cls:'gry',ic:'room',txt:t('pl.noRooms')};
  else if(st.open) nx={cls:'gry',ic:'doc',txt:t('hm.a.rows',{n:st.open})};
  else if(stage==='quote'&&p.quotes.length){ const d=Math.floor((Date.now()-p.quotes[p.quotes.length-1].ts)/86400e3); nx={cls:'cob',ic:'send',txt:d<1?t('hm.a.quote0'):t('hm.a.quote',{d})} }
  // the one main action for this state
  let act;
  if(st.bad) act={a:'hmRoom',id:st.bad.id,ic:'alert',k:'pl.a.fix'};
  else if(st.unRoom) act={a:'hmRoom',id:st.unRoom.id,ic:'laser',k:'pl.a.measure'};
  else if(!p.rooms.length) act={a:'pcOpen',tab:'rooms',ic:'plus',k:'pl.a.addRoom'};
  else if(!st.rows||st.open) act={a:'pcOpen',tab:'estimate',ic:'doc',k:'pl.a.estimate'};
  else if(!p.quotes.length||stage==='estimate') act={a:'pcReport',ic:'lock',k:'pl.a.quote'};
  else act={a:'pcOpen',tab:'quotes',ic:'doc',k:'pl.a.quotes'};
  const wall=st.nets?`${fmtArea(st.net)} <small>${esc(M2())}</small>${st.nets<p.rooms.length?' <small>+?</small>':''}`:p.rooms.length?'?':'—';
  const meas=st.need?`${st.conf}/${st.need}`:'—';
  const call=p.phone?`<a class="btn sec pc-call" href="tel:+998${esc(digits(p.phone))}" aria-label="${esc(t('pl.call')+' '+fmtPhone(p.phone))}">${ic('phone','i s')}<span>${esc(t('pl.call'))}</span></a>`:`<button class="btn sec pc-call" data-a="pcOpen" data-id="${p.id}" data-tab="rooms">${esc(t('pl.open'))}</button>`;
  return `<div class="pc"><button class="pc-top" data-a="pcOpen" data-id="${p.id}" data-tab="rooms"><span class="tx"><b>${esc(dn(p.name))}</b><small>${esc([dn(p.customer),dn(p.address)].filter(Boolean).join(', ')||'—')}</small></span><span class="pc-st ${stage}">${esc(t('stage.'+stage))}</span></button>
    <div class="pc-nums"><div><span>${esc(t('pl.wall'))}</span><b>${wall}</b></div><div><span>${esc(t('pl.meas'))}</span><b>${meas}</b></div><div><span>${esc(t('pl.est'))}</span><b>${pcMoney(p,st.g)}</b></div></div>
    ${nx?`<span class="pc-next ${nx.cls}">${ic(nx.ic,'i xs')}<span>${esc(nx.txt)}</span></span>`:''}
    <div class="pc-acts">${call}<button class="btn ${act.ic==='alert'?'danger':'pri'} pc-main" data-a="${act.a}" data-pid="${p.id}" data-id="${act.id||p.id}" data-tab="${act.tab||''}">${ic(act.ic,'i s')}<span>${esc(t(act.k))}</span></button></div></div>`;
}
PAGES.projects=()=>{
  const ps=S.projects.slice().sort((a,b)=>b.edited-a.edited); if(!ps.length) seen('empty');
  const seg=U.plSeg||'active', q=String(U.form['pl.q']||'').trim().toLowerCase();
  const inSeg=p=>seg==='all'||(seg==='done'?stageOf(p)==='done':stageOf(p)!=='done');
  const n={active:ps.filter(p=>stageOf(p)!=='done').length,done:ps.filter(p=>stageOf(p)==='done').length,all:ps.length};
  const list=ps.filter(p=>inSeg(p)&&(!q||[dn(p.name),dn(p.customer),dn(p.address),p.phone||''].join(' ').toLowerCase().includes(q)));
  const lk=isLocked();
  const body=!ps.length?plEmpty():`<div class="pl">${field('pl.q','',{ph:t('pl.search')})}<div class="pl-seg" role="tablist">${[['active','pl.active'],['done','pl.doneSeg'],['all','pl.allSeg']].map(([k,l])=>`<button class="${seg===k?'on':''}" role="tab" aria-selected="${seg===k}" data-a="plSeg" data-v="${k}"><span class="l">${esc(t(l))}</span><span class="n">${n[k]}</span></button>`).join('')}</div>${list.map(pcCard).join('')||`<p class="pl-none">${esc(q?t('pl.noMatch'):t('pl.none'))}</p>`}</div>`;
  const fab=ps.length&&!U.focus?`<button class="pl-fab ${lk?'locked':''}" data-a="newProject">${ic(lk?'lock':'plus')}${esc(t('pl.fab'))}</button>`:'';
  return `<section class="page ${U.anim||''}">${bar({right:savedChip()}).replace('<span class="sp"></span>','<span class="wordmark">METRX</span><span class="sp"></span>')}<div class="h1-ey">${esc(t(!ps.length?'pl.ey.all':'pl.ey.'+seg))}</div><div class="h1">${esc(t('tab.projects'))}</div>${banners()}<div class="scroll" data-scroll="projects">${body}</div>${fab}</section>`;
};
A.plSeg=d=>{ U.plSeg=d.v; render() };
A.pcOpen=d=>{ push({s:'project',id:d.id||d.pid,tab:d.tab||'rooms'}) };
A.pcReport=d=>{ const id=d.pid||d.id, p=P(id); if(!p) return; stack().push({s:'project',id,tab:'estimate'}); initForm({notes:p.report.notes}); push({s:'report',pid:id}) };
