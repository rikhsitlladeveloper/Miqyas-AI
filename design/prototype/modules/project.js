/* ============================== Project page (option A) ==============================
   Compact header (name, customer and address, stage, Call / Map / menu), the three numbers a brickmason
   prices by, then four tabs: Workspaces, Estimate, Quotes, Details. Customer details live in the Details tab. */
Object.assign(D,{
'pj.info':['Ma’lumot','Детали','Details'],
'pj.t.rooms':['Ish joylari','Зоны','Workspaces'],
'pj.t.quotes':['Takliflar','КП','Quotes'],
'pj.wsNet':['devor, sof','стены, чистые','net wall'],
'pj.addWs':['Ish joyi','Зона','Workspace'],
'pj.v2d':['2D reja','2D план','2D plan'],
'pj.v3d':['3D','3D','3D'],
'pj.edit':['Ma’lumotlarni tahrirlash','Изменить данные','Edit details'],
'pj.noPhone':['Telefon kiritilmagan','Телефон не указан','No phone number']
});
function pjNums(p){ const st=pcStats(p), wall=st.nets?`${fmtArea(st.net)} <small>${esc(M2())}</small>${st.nets<p.rooms.length?' <small>+?</small>':''}`:p.rooms.length?'?':'—';
  return `<div class="pj-nums"><div><span>${esc(t('pl.wall'))}</span><b>${wall}</b></div><div><span>${esc(t('pl.meas'))}</span><b>${st.need?st.conf+'/'+st.need:'—'}</b></div><div><span>${esc(t('pl.est'))}</span><b>${pcMoney(p,st.g)}</b></div></div>` }
PAGES.project=(r)=>{
  const p=P(r.id); if(!p) return PAGES.projects();
  const tab=['rooms','estimate','quotes','info'].includes(r.tab)?r.tab:'rooms', tt=totals(p), stage=stageOf(p), lk=isLocked();
  const sub=[dn(p.customer),dn(p.address)].filter(Boolean).join(', ')||'—';
  const head=`<div class="pj-hd"><div class="nm"><h1>${esc(dn(p.name))}</h1>${p.phone?`<a class="pj-ic" href="tel:+998${esc(digits(p.phone))}" aria-label="${esc(t('pl.call')+' '+fmtPhone(p.phone))}">${ic('phone','i s')}</a>`:''}${p.location?`<button class="pj-ic" data-a="openMap" aria-label="${esc(t('loc.open'))}">${ic('pin','i s')}</button>`:''}<button class="pj-ic" data-a="projectMenu" aria-label="menu">${ic('more','i s')}</button></div><div class="sub"><span>${esc(sub)}</span><span class="pc-st ${stage}">${esc(t('stage.'+stage))}</span></div></div>${tab==='rooms'?pjNums(p):''}`;
  const tabs=`<nav class="ptabs pj-tabs">${['rooms','estimate','quotes','info'].map(k=>`<button class="${tab===k?'on':''}" data-a="ptab" data-v="${k}">${esc(t(k==='rooms'?'pj.t.rooms':k==='info'?'pj.info':k==='quotes'?'pj.t.quotes':'pr.'+k))}${k==='quotes'&&p.quotes.length?`<span class="cnt">${p.quotes.length}</span>`:''}</button>`).join('')}</nav>`;
  let body='', foot='';
  if(tab==='rooms'){ body=roomsTab(p,r); if(p.floors.length&&((r.view||'list')==='list'||!p.rooms.length)) foot=`<button class="pj-fab ${lk?'locked':''}" data-a="newSpace">${ic(lk?'lock':'plus')}${esc(t('pj.addWs'))}</button>` }
  if(tab==='estimate'){ body=estimateTab(p,tt); foot=`<div class="footer"><div class="tot"><span>${esc(t('es.grand'))}</span><b>${money(tt.g,p,null,true)}</b></div><button class="btn pri full" data-a="preview">${ic('doc','i s')}${esc(t('es.preview'))}</button></div>` }
  if(tab==='quotes'){ body=quotesTab(p); seen('quotes') }
  if(tab==='info') body=pjInfo(p);
  return `<section class="page ${U.anim||''}">${bar({back:t('tab.projects'),right:savedChip()})}${banners()}${head}${tabs}<div class="scroll" data-scroll="p-${tab}">${body}</div>${foot}</section>`;
};
/* workspace rows: a small plan of the first room, counts, and the workspace's own net wall area */
wsList=function(p){
  if(!p.floors.length) return `<div class="ws-empty"><svg width="120" height="84" viewBox="0 0 120 84" aria-hidden="true"><rect x="8" y="10" width="64" height="48" rx="6" fill="#EAF0FE" stroke="#1C4BD1" stroke-width="2"/><rect x="48" y="26" width="64" height="48" rx="6" fill="#fff" stroke="#0E1C36" stroke-width="2"/><path d="M60 44h40M60 54h26" stroke="#5F6B82" stroke-width="2" stroke-linecap="round"/><circle cx="98" cy="68" r="13" fill="#1C4BD1"/><path d="M98 62v12M92 68h12" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/></svg><h3>${esc(t('ws.emptyT'))}</h3><p>${esc(t('ws.emptyB'))}</p><button class="btn ${isLocked()?'locked':'pri'} full" data-a="newSpace">${ic(isLocked()?'lock':'plus','i s')}${esc(t('ws.create'))}</button></div>`;
  const rows=p.floors.map(w=>{ const rs=wsRooms(p,w); let net=0, n=0; rs.forEach(r=>{ const a=areas(r); if(a&&a.net!=null){ net+=a.net; n++ } });
    const r0=rs.find(x=>x.shape!=='poly'&&x.dims.A.v!=null&&x.dims.B.v!=null)||rs[0];
    const th=r0?(r0.shape==='poly'?thumbSVG(r0,60,46):miniPlan(r0,54/Math.max(r0.dims.A.v||4000,r0.dims.B.v||3000))):ic(wsIcon(w));
    return `<button class="pj-wsr" data-a="openSpace" data-id="${w.id}"><span class="th">${th}</span><span class="tx"><b>${esc(floorName(w))}</b><small>${esc(wsCounts(p,w)||t('ws.empty'))}</small></span>${n?`<span class="ar">${fmtArea(net)} ${esc(M2())}<small>${esc(t('pj.wsNet'))}</small></span>`:''}${ic('chev','i s')}</button>` }).join('');
  const views=p.rooms.length?`<div class="pj-views"><button class="btn sec" data-a="pview" data-v="2d">${ic('room','i s')}${esc(t('pj.v2d'))}</button><button class="btn sec" data-a="pview" data-v="3d">${ic('cube','i s')}${esc(t('pj.v3d'))}</button></div>`:'';
  return `<div class="pj-ws">${rows}${views}</div>`;
};
function pjInfo(p){
  const kv=(label,val,extra)=>`<div class="pj-kv"><span class="tx"><small>${esc(label)}</small><b>${val}</b></span>${extra||''}</div>`;
  const prec=p.precision?t('es.pN',{n:p.precision}):t('es.p0');
  return `<div class="pj-info"><div class="lgroup">
    ${kv(t('pr.customer'),esc(dn(p.customer)||'—'))}
    ${kv(t('pr.phone'),p.phone?esc(fmtPhone(p.phone)):esc(t('pj.noPhone')),p.phone?`<a class="btn sec" href="tel:+998${esc(digits(p.phone))}">${ic('phone','i s')}${esc(t('pl.call'))}</a>`:'')}
    ${kv(t('pr.address'),esc(dn(p.address)||'—'))}
    ${kv(t('pr.location'),p.location?`<span class="cd">${p.location.lat.toFixed(5)}, ${p.location.lng.toFixed(5)}</span>`:esc(t('loc.none')),p.location?`<button class="btn sec" data-a="openMap">${ic('pin','i s')}${esc(t('loc.open'))}</button>`:'')}
    ${kv(t('se.curPrec'),esc(p.currency+', '+prec))}
    ${kv(t('rpt.lang'),esc(LNAME[p.report.lang]||p.report.lang))}
  </div><button class="btn sec full" data-a="editProject">${ic(isLocked()?'lock':'edit','i s')}${esc(t('pj.edit'))}</button></div>`;
}
