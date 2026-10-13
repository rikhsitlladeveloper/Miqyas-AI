/* ============================== Board (option A): stage list, top to bottom ==============================
   A five-step strip with counts, then one short list per stage: job, customer, next open task and a one-tap
   "next stage" button (Undo in the toast). Quotes show days waiting and a call button. Done jobs fold away. */
Object.assign(D,{
'bd2.go.estimate':['Smetaga','В смету','To estimate'],
'bd2.go.quote':['Taklifga','В КП','To quote'],
'bd2.go.work':['Ishga','В работу','Start work'],
'bd2.go.done':['Tugatish','Завершить','Finish'],
'bd2.short.measure':['O‘lchash','Замер','Measure'],
'bd2.short.estimate':['Smeta','Смета','Estimate'],
'bd2.short.quote':['Taklif','КП','Quote'],
'bd2.short.work':['Ishda','В работе','Work'],
'bd2.short.done':['Tugadi','Готово','Done'],
'bd2.wait':['Javob kutilmoqda: {n} kun','Ждём ответа: {n} {n:день|дня|дней}','Waiting for reply: {n} {n:day|days}'],
'bd2.waitToday':['Taklif bugun yuborildi','КП отправлено сегодня','Quote sent today'],
'bd2.waitNone':['Javob kutilmoqda','Ждём ответа','Waiting for reply'],
'bd2.allDone':['Vazifalar bajarildi','Задачи выполнены','Tasks done'],
'bd2.noTask':['Vazifa yo‘q','Задач нет','No tasks'],
'bd2.showDone':['Ko‘rsatish','Показать','Show'],
'bd2.hideDone':['Yashirish','Скрыть','Hide'],
'bd2.tick':['Bajarildi deb belgilash','Отметить выполненной','Mark as done']
});
const bdNextStage=st=>STAGES[STAGES.indexOf(st)+1]||null;
function bdWait(p){ const q=p.quotes&&p.quotes[p.quotes.length-1]; if(!q) return {txt:t('bd2.waitNone'),n:0}; const n=Math.floor((Date.now()-q.ts)/864e5); return {txt:n<1?t('bd2.waitToday'):t('bd2.wait',{n}),n} }
function bdRow(p){
  const st=stageOf(p), b=p.board, tasks=b.tasks, open=tasks.find(x=>!x.done), done=tasks.filter(x=>x.done).length, nx=bdNextStage(st);
  const sub=[dn(p.customer),dn(p.address)].filter(Boolean).join(', ');
  const tot=st==='quote'&&p.quotes&&p.quotes.length?money(BigInt(p.quotes[p.quotes.length-1].total||'0'),p,null,true):'';
  let line;
  if(st==='quote'){ const w=bdWait(p); line=`<span class="bd-wt ${w.n>=2?'late':''}">${ic('clock','i s')}<span>${esc(w.txt)}</span></span>` }
  else if(open) line=`<button class="bd-tk" data-a="bdTick" data-id="${p.id}" data-t="${open.id}" aria-label="${esc(t('bd2.tick')+': '+dn(open.text))}">${ic('box','i s')}<span>${esc(dn(open.text))}</span>${tasks.length>1?`<small>${done}/${tasks.length}</small>`:''}</button>`;
  else line=`<span class="bd-tk muted">${ic(tasks.length?'boxok':'box','i s')}<span>${esc(t(tasks.length?'bd2.allDone':'bd2.noTask'))}</span></span>`;
  const call=st==='quote'&&p.phone?`<a class="bd-call" href="tel:+998${esc(digits(p.phone))}" aria-label="${esc(t('pl.call')+' '+fmtPhone(p.phone))}">${ic('phone','i s')}</a>`:'';
  const go=nx?`<button class="bd-go" data-a="bdNext" data-id="${p.id}">${esc(t('bd2.go.'+nx))}${ic('chev','i xs')}</button>`:'';
  return `<div class="bd-row"><button class="bd-main" data-a="boardItem" data-id="${p.id}"><b class="trunc">${esc(dn(p.name))}</b><span class="trunc">${esc(tot?tot+(sub?', '+sub:''):sub||'—')}</span></button><div class="bd-lr">${line}<span class="bd-acts">${call}${go}</span></div></div>`;
}
PAGES.board=()=>{
  const ps=S.projects.slice().sort((a,b)=>b.edited-a.edited);
  if(!ps.length) return `<section class="page ${U.anim||''}">${bar({right:savedChip()})}<div class="h1">${esc(t('tab.board'))}</div><div class="scroll"><div class="empty"><h3>${esc(t('bd.emptyTitle'))}</h3><p>${esc(t('bd.emptyBody'))}</p><button class="btn ${isLocked()?'locked':'pri'}" data-a="newProject">${ic('plus','i s')}${esc(t('pl.new'))}</button></div></div></section>`;
  const by=st=>ps.filter(p=>stageOf(p)===st);
  const strip=`<div class="bd-pipe" role="list">${STAGES.map(st=>{ const n=by(st).length; return `<button role="listitem" class="st-${st} ${n?'':'zero'}" data-a="bdJump" data-v="${st}" aria-label="${esc(t('stage.'+st)+': '+n)}"><b>${n}</b><em>${esc(t('bd2.short.'+st))}</em></button>` }).join('')}</div>`;
  const secs=STAGES.map(st=>{ const items=by(st); if(!items.length) return '';
    if(st==='done'){ const open=!!U.bdDone; return `<section class="bd-sec" id="col-done"><button class="bd-h fold" data-a="bdDone" aria-expanded="${open}"><i class="dot st-done"></i>${esc(t('stage.done'))}<span class="n">${items.length}</span><span class="sp"></span><span class="lk">${esc(t(open?'bd2.hideDone':'bd2.showDone'))}</span>${ic('chev','i xs'+(open?' rot':''))}</button>${open?`<div class="bd-card">${items.map(bdRow).join('')}</div>`:''}</section>` }
    return `<section class="bd-sec" id="col-${st}"><div class="bd-h"><i class="dot st-${st}"></i>${esc(t('stage.'+st))}<span class="n">${items.length}</span></div><div class="bd-card">${items.map(bdRow).join('')}</div></section>` }).join('');
  return `<section class="page ${U.anim||''}">${bar({right:savedChip()})}<div class="h1">${esc(t('tab.board'))}</div>${banners()}<div class="scroll" data-scroll="board"><div class="bd">${strip}${secs}<p class="note bd-local">${ic('info','i s')}<span>${esc(t('bd.local'))}</span></p></div></div></section>`;
};
A.bdJump=d=>{ U.boardJump=d.v; if(d.v==='done') U.bdDone=true; render() };
A.bdDone=()=>{ U.bdDone=!U.bdDone; render() };
A.bdNext=d=>{ const p=P(d.id); if(!p) return; const prev=stageOf(p), nx=bdNextStage(prev); if(!nx) return; p.board.stage=nx; U.bdUndo={id:p.id,prev}; commit(); seen('board'); toast(t('bd.moved',{p:dn(p.name),s:t('stage.'+nx)}),{label:t('common.undo'),a:'bdUndo'}); render() };
A.bdUndo=()=>{ const u=U.bdUndo, p=u&&P(u.id); if(!p) return; p.board.stage=u.prev; U.bdUndo=null; U.toast=null; commit(); render() };
A.bdTick=d=>{ const p=P(d.id); const x=p&&p.board.tasks.find(k=>k.id===d.t); if(!x) return; x.done=true; commit(); seen('board'); toast(t('bd2.tickDone',{x:dn(x.text)}),{label:t('common.undo'),a:'bdUntick'}); U.bdUntick={id:p.id,t:x.id}; render() };
A.bdUntick=()=>{ const u=U.bdUntick, p=u&&P(u.id), x=p&&p.board.tasks.find(k=>k.id===u.t); if(x) x.done=false; U.bdUntick=null; U.toast=null; commit(); render() };
D['bd2.tickDone']=['Bajarildi: {x}','Выполнено: {x}','Done: {x}'];
