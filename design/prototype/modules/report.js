/* ============================== Report (option A): read it first ==============================
   The PDF pages fill the screen (swipe between them; tap to open the zoomable viewer). A dark strip keeps the
   total, page count and language in view. Language, rooms, drawings, 3D views and notes move into a "Set up"
   sheet. The issued quote uses the same viewer. The PDF itself is unchanged. */
Object.assign(D,{
'rp2.setup':['Sozlash','Настроить','Set up'],
'rp2.setupTitle':['Hisobotni sozlash','Настройка отчёта','Set up the report'],
'rp2.total':['Jami','Итого','Total'],
'rp2.pages':['{n} sahifa','{n} {n:страница|страницы|страниц}','{n} {n:page|pages}'],
'rp2.of':['{i} / {n}','{i} / {n}','{i} / {n}'],
'rp2.prev':['Oldingi sahifa','Предыдущая страница','Previous page'],
'rp2.next':['Keyingi sahifa','Следующая страница','Next page'],
'rp2.shareDraft':['Qoralamani ulashish','Поделиться черновиком','Share draft'],
'rp2.tapZoom':['Kattalashtirish uchun sahifani bosing','Нажмите на страницу, чтобы увеличить','Tap a page to zoom'],
'rp2.done':['Tayyor','Готово','Done']
});
function rpViewer(pages,key){
  return `<div class="rp-view" data-scroll="${key}" data-rpv>${pages.map((h,i)=>`<button class="rp-pg" data-a="viewPage" data-i="${i}" aria-label="${esc(t('rp2.of',{i:i+1,n:pages.length}))}"><div class="rp-sc">${h}</div></button>`).join('')}</div>
  <div class="rp-nav"><button class="ib" data-a="rpGo" data-v="-1" aria-label="${esc(t('rp2.prev'))}">${ic('back','i s')}</button><span id="rpN">${esc(t('rp2.of',{i:1,n:pages.length}))}</span><button class="ib rp-fw" data-a="rpGo" data-v="1" aria-label="${esc(t('rp2.next'))}">${ic('back','i s')}</button></div>
  <p class="rp-hint">${esc(t('rp2.tapZoom'))}</p>`;
}
function rpStrip(totalTxt,n,lang){ return `<div class="rp-sum"><div><span>${esc(t('rp2.total'))}</span><b>${totalTxt}</b></div><div class="r"><span>${esc(t('rp2.pages',{n}))}</span><span>${esc(LNAME[lang])}</span></div></div>` }
PAGES.report=(rt)=>{
  const p=P(rt.pid); if(!p) return PAGES.projects(); seen('report');
  const sn=snapshotOf(p); const pages=reportPages(sn,true); U.pages=pages;
  const b=S.settings.builder; const uc=sn.rooms.reduce((a,r)=>a+unconfCount(r),0);
  const tot=totals(p);
  const right=`<button class="rp-setup" data-a="rpSetup">${ic('sliders','i s')}<span>${esc(t('rp2.setup'))}</span></button>`;
  return `<section class="page ${U.anim||''}">${bar({backIcon:true,title:t('rpt.title'),sub:dn(p.name),right})}<div class="scroll rp" data-scroll="report"><div class="rp-in">
    ${!b.name?`<div class="banner warn" style="margin:0">${ic('alert','i s')}<span class="tx">${esc(t('rpt.noBuilder'))}</span><button class="act" data-a="goBuilder">${esc(t('rpt.addBuilder'))}</button></div>`:''}
    ${uc?`<div class="banner warn" style="margin:0">${ic('clock','i s')}<span class="tx">${esc(t('rpt.unconf',{n:uc}))}</span></div>`:''}
    ${rpStrip(moneyStr(tot.g,p.precision)+' '+esc(curSuffix(p.currency)),pages.length,p.report.lang)}
    ${rpViewer(pages,'rpv')}
  </div></div><div class="footer"><div class="btnrow"><button class="btn sec rp-2l" data-a="share" data-ctx="draft">${ic('share','i s')}<span>${esc(t('rp2.shareDraft'))}</span></button><button class="btn ${isLocked()?'locked':'pri'} rp-2l" data-a="issue">${ic('lock','i s')}<span>${esc(t('rpt.issue'))}</span></button></div></div></section>`;
};
PAGES.quote=(rt)=>{
  const p=P(rt.pid); const q=p&&p.quotes.find(x=>x.no===rt.no); if(!q) return PAGES.projects();
  const pages=reportPages(q.sn,false,{no:q.no,ts:q.ts}); U.pages=pages;
  return `<section class="page ${U.anim||''}">${bar({backIcon:true,title:t('q.no',{n:q.no}),sub:dn(p.name)})}<div class="scroll rp" data-scroll="quote"><div class="rp-in">
    <div class="banner lock" style="margin:0">${ic('lock','i s')}<span class="tx">${esc(t('q.frozen'))}<br><b>${esc(t('q.issued'))}: ${esc(fmtDate(q.ts)+' '+fmtTime(q.ts))}</b></span></div>
    ${rpStrip(moneyStr(BigInt(q.total),q.sn.precision)+' '+esc(curSuffix(q.sn.currency)),pages.length,q.sn.lang)}
    ${rpViewer(pages,'qv')}
  </div></div><div class="footer"><button class="btn pri full" data-a="share" data-ctx="quote">${ic('share','i s')}${esc(t('rpt.share'))}</button></div></section>`;
};
SHEETS.repSetup=()=>{
  const p=P(top().pid); const views=p.rooms.flatMap(r=>r.views);
  const its=(p.floors||[]).flatMap(w=>(typeof wsItems==='function'?wsItems(w):[]).map(it=>({it,w})));
  const extras=typeof repOf==='function'?`<div class="fld"><span class="lab">${esc(t('rpt.extras'))}</span>${its.length?`<div class="choice">${its.map(({it,w})=>{ const on=repOf(it); return `<button class="opt ${on?'on':''}" data-a="repItem" data-w="${w.id}" data-id="${it.id}">${ic(on?'check':'plus','i xs')}${ic(KIND_IC[it.kind],'i xs')}${esc(it.kind==='note'?(dn(it.name)||t('it.untitled')):dn(it.name))}</button>` }).join('')}</div>`:`<div class="fhint">${esc(t('rpt.noExtras'))}</div>`}</div>`:'';
  const body=`<div class="form" style="gap:14px">
    <div class="fld"><span class="lab">${esc(t('rpt.lang'))}</span><div class="choice">${LANGS.map(x=>`<button class="opt ${p.report.lang===x?'on':''}" data-a="repLang" data-v="${x}">${esc(LNAME[x])}</button>`).join('')}</div></div>
    <div class="fld"><span class="lab">${esc(t('rpt.rooms'))}</span><div class="choice">${p.rooms.map(r=>`<button class="opt ${p.report.rooms[r.id]!==false?'on':''}" data-a="repRoom" data-id="${r.id}">${ic(p.report.rooms[r.id]!==false?'check':'plus','i xs')}${esc(dn(r.name))}</button>`).join('')}</div></div>
    ${extras}
    <div class="fld"><span class="lab">${esc(t('rpt.views'))}</span>${views.length?`<div class="choice">${views.map(v=>`<button class="opt ${p.report.views[v.id]!==false?'on':''}" style="padding:4px" data-a="repView" data-id="${v.id}"><img src="${v.img}" alt="" style="width:72px;height:54px;object-fit:cover;display:block;opacity:${p.report.views[v.id]!==false?1:.4}"></button>`).join('')}</div>`:`<div class="fhint">${esc(t('rpt.noViews'))}</div>`}</div>
    ${field('notes',t('rpt.notes'),{opt:true,ph:t('rpt.notesPh')})}
    <p class="note">${ic('info','i s')}<span>${esc(t('rpt.draftShare'))}</span></p></div>`;
  return sheetWrap(t('rp2.setupTitle'),body,`<button class="btn pri full" data-a="rpSetupDone">${esc(t('rp2.done'))}</button>`);
};
A.rpSetup=()=>{ const p=P(top().pid); if(U.form.notes===undefined) initForm({notes:p.report.notes}); openSheet({type:'repSetup'}) };
A.rpSetupDone=()=>{ const p=P(top().pid); syncNotes(p); closeSheet() };
A.rpGo=d=>{ const v=appEl.querySelector('[data-rpv]'); if(!v) return; v.scrollBy({left:Number(d.v)*v.clientWidth,behavior:'smooth'}) };
function rpAfter(){
  const v=appEl.querySelector('[data-rpv]'); if(!v) return;
  const n=v.children.length, fit=()=>{ const w=v.clientWidth; v.querySelectorAll('.rp-sc').forEach(s=>{ s.style.transform=`scale(${(w/595).toFixed(4)})`; s.parentNode.style.height=Math.round(w*842/595)+'px' }) };
  const upd=()=>{ const i=Math.min(n-1,Math.max(0,Math.round(v.scrollLeft/Math.max(1,v.clientWidth)))); const el=appEl.querySelector('#rpN'); if(el) el.textContent=t('rp2.of',{i:i+1,n}); const bs=appEl.querySelectorAll('[data-a="rpGo"]'); if(bs[0]) bs[0].disabled=i===0; if(bs[1]) bs[1].disabled=i===n-1 };
  fit(); upd(); v.addEventListener('scroll',upd,{passive:true});
}
{ const base=render; render=function(){ base(); rpAfter() } }
