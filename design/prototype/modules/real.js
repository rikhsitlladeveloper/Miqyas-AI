/* ============================== real: the app without its demo parts ==============================
   Founder's decisions of 13 Oct 2026:
   - fields use the phone's own keyboard (iPhone and Android);
   - no "Saqlandi" label; logo A (folding rule) next to the name;
   - "Take from laser" gives a random reading until the real meter is supported, with no simulation label;
   - Create account, Log in and Google stay on the welcome screen and go straight to Home;
   - the Demo panel, simulation labels, sample values and simulated buttons are gone. Camera, location,
     PDF sharing and backup files use the phone (through the MetrxNative bridge in the two app shells). */

/* ---------- texts ---------- */
Object.assign(D,{
'common.sim':['','',''],
'src.sim':['Lazer','Лазер','Laser'],
'dev.conn':['Lazer ulangan','Лазер подключён','Laser connected'],
'dv.connected':['Lazer ulandi','Лазер подключён','Laser connected'],
'dv.simDev':['Lazer o‘lchagich','Лазерный дальномер','Laser meter'],
'dv.simBody':['','',''],
'ms.simPress':['Lazerdan olish','Снять с лазера','Take from laser'],
'ms.simNote':['','',''],
'hm.q.measSim':['Lazer bilan yoki qo‘lda','Лазером или вручную','With the laser or by hand'],
'loc.note':['GPS internetsiz ham ishlaydi.','GPS работает и без интернета.','GPS works without internet.'],
'real.roomN':['Xona {n}','Комната {n}','Room {n}'],
'loc.fail':['Joylashuvni aniqlab bo‘lmadi. Ruxsatni tekshiring.','Не удалось определить местоположение. Проверьте разрешение.','Couldn’t get the location. Check the permission.'],
're.sample':['','',''],
'sh.simNote':['','',''],
'sh.onlyPhone':['PDF ulashish telefondagi ilovada ishlaydi.','Отправка PDF работает в приложении на телефоне.','Sharing a PDF works in the app on a phone.'],
'sh.making':['PDF tayyorlanmoqda…','Готовим PDF…','Preparing the PDF…'],
'add.cameraD':['Telefon kamerasi bilan','Камерой телефона','With the phone camera'],
'add.galleryD':['Telefondagi suratlardan','Из фото на телефоне','From the photos on your phone'],
'se.aboutBody':['METRX: ustalar uchun o‘lchash, chizma va smeta ilovasi.','METRX — приложение для замеров, чертежей и смет.','METRX: measuring, plans and estimates for builders.'],
'col.body':['Ustun va nishalar keyingi versiyada qo‘shiladi.','Колонны и ниши появятся в следующей версии.','Columns and recesses come in a later version.'],
'nr.later':['Keyinroq','Позже','Later'],
'vc.sim':['','',''],
'li.demo':['','',''],
'bk.badFile':['Bu METRX zaxira fayli emas yoki u buzilgan. Hozirgi ma’lumotlar o‘zgarmadi.','Это не резервная копия METRX или файл повреждён. Текущие данные не изменились.','This isn’t a METRX backup, or the file is damaged. Your current data is unchanged.']
});

/* ---------- logo A: a folding rule opened into the letter M ---------- */
const LOGO_SVG=`<svg viewBox="0 0 64 64" aria-hidden="true"><rect width="64" height="64" rx="15" fill="#374FDD"/><path d="M15 47V19l17 19 17-19v28" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><g fill="#374FDD"><circle cx="15" cy="19" r="1.9"/><circle cx="32" cy="38" r="1.9"/><circle cx="49" cy="19" r="1.9"/></g><path d="M11.5 28h3M11.5 34h3M11.5 40h3M49.5 28h3M49.5 34h3M49.5 40h3" stroke="#374FDD" stroke-width="1.4"/></svg>`;
{ const rp=reportPages; reportPages=function(){ return rp.apply(this,arguments).map(h=>h.split('<span class="wm">METRX</span>').join('<span class="wm">'+LOGO_SVG+'METRX</span>')) } }

/* ---------- header: no saved-time label; a bar with nothing in it takes no room ---------- */
savedChip=function(){ return '' };
{ const b0=bar; bar=function(o){ const h=b0(o); return (o.back||o.close||o.backIcon||o.title||o.right)?h:h.replace('<header class="bar">','<header class="bar bar0">') } }

/* ---------- no Demo panel ---------- */
renderPanel=function(){};

/* ============================== native text fields ============================== */
const isNin=el=>!!(el&&el.classList&&el.classList.contains('nin'));
const ninAttr=(kind,next)=>{
  const hint=`enterkeyhint="${next?'next':'done'}"`;
  if(kind==='num') return `type="text" inputmode="decimal" ${hint}`;
  if(kind==='tel') return `type="tel" inputmode="numeric" maxlength="12" ${hint}`;
  if(kind==='code') return `type="text" inputmode="numeric" maxlength="6" autocomplete="one-time-code" ${hint}`;
  if(kind==='pw') return `type="${U.showPw?'text':'password'}" autocapitalize="off" ${hint}`;
  return `type="text" autocapitalize="sentences" ${hint}`;
};
const ninCommon=(id,kind,next,label,ph,ro)=>`class="nin" data-in="${esc(id)}" data-k="${kind}" data-n="${esc(next||'')}" aria-label="${esc(label||id)}" placeholder="${esc(ph||'')}" autocomplete="off" autocorrect="off" spellcheck="false"${ro?' readonly tabindex="-1"':''}`;

field=function(id,label,o={}){
  const v=U.form[id]??''; const f=U.focus&&U.focus.id===id;
  const err=(U.touched[id]||U.submitTry)&&o.err?o.err:null;
  const kind=o.tel?'tel':o.num?'num':o.pw?'pw':o.area?'area':'text';
  const val=o.tel?fmtPh(v):String(v);
  const c=ninCommon(id,kind,o.next,label,o.ph,o.ro);
  const inp=o.area?`<textarea ${c} rows="5" autocapitalize="sentences">${esc(val)}</textarea>`:`<input ${c} ${ninAttr(kind,o.next)} value="${esc(val)}">`;
  return `<div class="fld" data-key="f:${esc(id)}">${label?`<label>${esc(label)}${o.opt?` <small>${esc(t('common.optional'))}</small>`:''}${o.right||''}</label>`:''}
  <div class="box ${o.num||o.tel?'num':''} ${o.area?'area':''} ${f?'f':''} ${err?'bad':''} ${o.ro?'ro':''}" data-f="${esc(id)}" data-k="${kind}" data-n="${esc(o.next||'')}">${o.tel?'<span class="pre">+998</span>':''}${inp}${o.suf?`<span class="suf">${esc(o.suf)}</span>`:''}</div>
  ${err?`<div class="ferr"><svg class="i s"><use href="#i-alert"/></svg><span>${esc(err)}</span></div>`:o.hint?`<div class="fhint">${esc(o.hint)}</div>`:''}</div>`;
};
auField=function(id,label,o={}){
  const v=String(U.form[id]??''), f=!!(U.focus&&U.focus.id===id);
  const err=(U.touched[id]||U.submitTry)&&o.err?o.err:null;
  const kind=o.tel?'tel':o.pw?'pw':'text';
  const left=o.tel?`<span class="au-cc">${AU_FLAG}<span>+998</span></span>`:ic(o.pw?'lock':'user');
  const right=o.pw?pwTgl():(!o.tel&&v?`<button type="button" class="au-clr" data-a="auClr" data-f="${id}" data-n="${o.next||''}" aria-label="${esc(t('akb.clear'))}">${AUI.clear}</button>`:'');
  return `<div class="fld auf" data-key="f:${esc(id)}"><label>${esc(label)}</label><div class="aubox ${o.tel?'tel':''} ${f?'f':''} ${err?'bad':''}" data-f="${esc(id)}" data-k="${kind}" data-n="${esc(o.next||'')}">${left}<input ${ninCommon(id,kind,o.next,label,o.ph)} ${ninAttr(kind,o.next)} value="${esc(o.tel?fmtPh(v):v)}">${right}</div>${err?`<div class="ferr">${ic('alert','i s')}<span>${esc(err)}</span></div>`:''}</div>`;
};
codeBoxes=function(id,bad){
  const v=String(U.form[id]||''), f=U.focus&&U.focus.id===id;
  return `<div class="otp ${bad?'bad':''}" data-f="${esc(id)}" data-k="code" data-n="" data-key="f:${esc(id)}">${[0,1,2,3,4,5].map(i=>{ const cur=f&&i===Math.min(v.length,5)&&v.length<6; return `<span class="${cur?'cur':''} ${v[i]?'fill':''}">${esc(v[i]||'')}</span>` }).join('')}<input ${ninCommon(id,'code','',t('vc.title'),'')} ${ninAttr('code','')} value="${esc(v)}"></div>`;
};
/* the drawn keyboard is gone */
keyboard=function(){ return '' };

/* Re-rendering replaces the whole screen. While a field is being typed in, the screen is updated in place instead,
   so the field keeps the focus, its caret and the phone's keyboard. */
const keyOf=el=>el.nodeType===1?(el.getAttribute('data-key')||el.getAttribute('data-in')||el.id||''):'';
function syncAttrs(a,b){
  for(const at of [...a.attributes]) if(!b.hasAttribute(at.name)) a.removeAttribute(at.name);
  for(const at of [...b.attributes]) if(a.getAttribute(at.name)!==at.value) a.setAttribute(at.name,at.value);
}
function morph(a,b,act){
  syncAttrs(a,b);
  if(a.tagName==='INPUT'||a.tagName==='TEXTAREA'){ if(a.value!==b.value) a.value=b.value; return }
  if(a.id==='three') return;                       // the 3D canvas is mounted by script, not by the markup
  let x=a.firstChild, y=b.firstChild;
  while(y){
    const ny=y.nextSibling;
    if(!x){ a.appendChild(y) }
    else if(x.nodeType===y.nodeType&&(x.nodeType!==1||(x.tagName===y.tagName&&keyOf(x)===keyOf(y)))){
      if(x.nodeType===1) morph(x,y,act); else if(x.nodeValue!==y.nodeValue) x.nodeValue=y.nodeValue;
      x=x.nextSibling }
    else {
      const ky=keyOf(y); let m=null;
      if(ky){ for(let c=x;c;c=c.nextSibling){ if(c.nodeType===1&&c.tagName===y.tagName&&keyOf(c)===ky){ m=c; break } } }
      if(m){ while(x!==m){ const nx=x.nextSibling; a.removeChild(x); x=nx } morph(x,y,act); x=x.nextSibling }
      else if(x.nodeType===1&&x.contains(act)) a.insertBefore(y,x);
      else { const nx=x.nextSibling; a.replaceChild(y,x); x=nx } }
    y=ny }
  while(x){ const nx=x.nextSibling; if(!(x.nodeType===1&&x.contains(act))) a.removeChild(x); x=nx }
}
setAppHTML=function(html){
  const act=document.activeElement, cur=appEl.firstElementChild;
  if(isNin(act)&&cur&&appEl.contains(act)){
    const tpl=document.createElement('template'); tpl.innerHTML=html; const nw=tpl.content.firstElementChild;
    if(nw&&[...nw.querySelectorAll('.nin')].some(e=>e.dataset.in===act.dataset.in)){ morph(cur,nw,act); return } }
  appEl.innerHTML=html;
};
/* after every render: the field the app says is active has the phone's focus, and no other one does */
function ninSync(){
  const act=document.activeElement, cur=isNin(act)?act:null;
  if(U.focus){
    if(cur&&cur.dataset.in===U.focus.id) return;
    const el=[...appEl.querySelectorAll('.nin')].find(e=>e.dataset.in===U.focus.id);
    if(el&&!el.readOnly){ el.focus(); try{ const n=el.value.length; el.setSelectionRange(n,n) }catch(e){} }
    else if(!ninSync.busy){ U.focus=null; ninSync.busy=true; try{ render() } finally { ninSync.busy=false } } }
  else if(cur) cur.blur();
}
{ const base=render; render=function(){ base(); ninSync() } }

appEl.addEventListener('focusin',e=>{ const el=e.target; if(!isNin(el)) return;
  if(!U.focus||U.focus.id!==el.dataset.in){ setFocus(el.dataset.in,el.dataset.k,el.dataset.n); render() } });
appEl.addEventListener('focusout',e=>{ const el=e.target; if(!isNin(el)) return; const id=el.dataset.in;
  setTimeout(()=>{ if(isNin(document.activeElement)) return; if(U.focus&&U.focus.id===id){ blur(); render() } },0) });
appEl.addEventListener('input',e=>{ const el=e.target; if(!isNin(el)) return;
  const id=el.dataset.in, kind=el.dataset.k; let v=el.value;
  if(kind==='tel'){ v=digits(v).slice(0,9); const shown=fmtPh(v); if(el.value!==shown){ el.value=shown; try{ el.setSelectionRange(shown.length,shown.length) }catch(x){} } }
  else if(kind==='code'){ v=v.replace(/\D/g,'').slice(0,6); if(el.value!==v) el.value=v }
  U.form[id]=v; U.touched[id]=true;
  if(!U.focus||U.focus.id!==id) setFocus(id,kind,el.dataset.n);
  if(kind==='code'){ U.codeErr=null; if(v.length===6){ blur(); A.auVerify(); return } }
  if(U.auErr==='wrong'||U.auErr==='exists'||U.auErr==='unknown') U.auErr=null;
  if(S.firstRun&&kind==='tel'&&el.dataset.n&&v.length===9){ const nx=document.querySelector(`[data-f="${el.dataset.n}"]`); setFocus(el.dataset.n,nx?nx.dataset.k:'text',nx?nx.dataset.n:'') }
  render() });
appEl.addEventListener('keydown',e=>{ const el=e.target; if(!isNin(el)) return;
  e.stopPropagation();                               // the old page-level typing handler must not see real fields
  if(e.key==='Enter'&&el.dataset.k!=='area'&&!e.isComposing){ e.preventDefault(); if(!U.focus||U.focus.id!==el.dataset.in) setFocus(el.dataset.in,el.dataset.k,el.dataset.n); typeKey('enter') }
  else if(e.key==='Escape') el.blur() });
/* a tap anywhere on a field's box goes to its field */
appEl.addEventListener('click',e=>{ if(isNin(e.target)||e.target.closest('[data-a]')) return; const b=e.target.closest('.box,.aubox,.otp'); const i=b&&b.querySelector('.nin'); if(i&&!i.readOnly&&document.activeElement!==i) i.focus() });
/* a wrong SMS code empties the boxes, so the next digit starts a new code */
{ const av=A.auVerify; A.auVerify=function(){ av.apply(this,arguments); if(U.codeErr&&String(U.form.code||'').length===6){ U.form.code=''; render() } } }

/* iPhone: the keyboard covers the bottom of the page instead of resizing it. Keep the app above the keyboard. */
if(window.visualViewport){ const vv=window.visualViewport, root=document.documentElement;
  const fit=()=>{ const open=window.innerHeight-vv.height>120; root.classList.toggle('kb-open',open); document.body.style.height=open?Math.round(vv.height)+'px':''; if(open) window.scrollTo(0,0) };
  vv.addEventListener('resize',fit); vv.addEventListener('scroll',()=>{ if(root.classList.contains('kb-open')) window.scrollTo(0,0) }) }

/* ============================== laser: a random reading until the real meter is supported ============================== */
const rnd=(a,b)=>a+Math.round(Math.random()*(b-a));
simTarget=function(r,dim){ return dim==='H'?rnd(2500,3200):dim==='T'?200:/^[A-Z]$|^W\d/.test(dim)?rnd(2400,6400):rnd(300,1500) };
A.measSim=()=>{ U.meas.val=rnd(600,8200); render() };
SHEETS.device=()=>{
  const b=S.demo.bt, dev=`<div class="listrow" style="padding-left:0">${ic('laser')}<span class="tx"><b>${esc(t('dv.simDev'))}</b>`;
  let body=`<div class="kv"><div><span>${esc(t('dv.status'))}</span><b style="font-family:inherit;font-weight:600">${esc(t(U.scan===true?'dev.scan':b==='connected'?'dev.conn':b==='off'?'dev.off':b==='denied'?'dev.denied':'dev.disc'))}</b></div></div>`, foot='';
  if(b==='connected'){ body+=dev+`<small>${esc(t('dev.conn'))}</small></span></div>`; foot=`<button class="btn sec full" data-a="btSet" data-v="disconnected">${esc(t('dv.disconnect'))}</button>` }
  else if(b==='off'||b==='denied'){ body+=`<p>${esc(t(b==='off'?'dv.offBody':'dv.deniedBody'))}</p>`; foot=`<button class="btn sec full" data-a="btSet" data-v="disconnected">${esc(t('dv.openSettings'))}</button>` }
  else if(U.scan==='done'){ body+=`<div class="grouph" style="padding-left:0">${esc(t('dv.found'))}</div>`+dev+`</span></div>`; foot=`<button class="btn pri full" data-a="btSet" data-v="connected">${esc(t('dv.connect'))}</button>` }
  else if(U.scan){ body+=`<div class="wait"><span class="pulse">${ic('search','i l')}</span><b>${esc(t('dev.scan'))}</b></div>` }
  else { foot=`<button class="btn pri full" data-a="btScan">${ic('search','i s')}${esc(t('dv.search'))}</button>` }
  body+=`<p class="note">${ic('kbd','i s')}<span>${esc(t('dv.always'))}</span></p>`;
  return sheetWrap(t('dv.title'),body,foot);
};

/* ============================== sign-in buttons go straight to Home ============================== */
{ const to=A.auTo; A.auTo=d=>{ if(d.v==='su1'||d.v==='li'){ auExit(); return } to(d) } }
A.auGoogle=()=>auExit();

/* ============================== no sample values ============================== */
A.addRow=d=>{ if(!guard()) return; const p=P(top().id), mat=d.k==='mat';
  initForm(mat?{ename:'',eunit:'@u.pcs',eqty:'',eprice:''}:{ename:'',eamount:''});
  openSheet({type:'row',pid:p.id,kind:d.k,id:null,sample:false}); setFocus('ename','text',mat?'eqty':'eamount'); render() };
/* a new room starts with a neutral name (Xona 1, Xona 2 ...), not a sample one */
{ const fix=base=>d=>{ base(d); const sh=U.sheet, p=sh&&sh.type==='newRoom'&&P(sh.pid); if(!p) return;
    if(!U.form.rname||U.form.rname===t('smp.living')){ U.form.rname=t('real.roomN',{n:p.rooms.length+1}); render() } };
  A.addRoom=fix(A.addRoom); A.addPlan=fix(A.addPlan) }
{ const sub=PAGES.sub; PAGES.sub=r=>sub(r).replace(/<button class="opt[^"]*"[^>]*data-a="toggleExpired">[\s\S]*?<\/button>/,'') }
{ const sk=PAGES.sketch; if(sk) PAGES.sketch=r=>sk(r).replace(/<button class="simbtn" data-a="skDemo">[\s\S]*?<\/button>/,'') }

/* ============================== the phone's camera, location, share sheet and files ============================== */
const NATIVE=()=>window.MetrxNative||null;
const extOpen=url=>{ try{ window.location.href=url }catch(e){} };
/* camera: the same picker as the gallery, asked to open the camera */
{ const cam=A.addGallery; A.addGallery=function(){ wsFileInput().removeAttribute('capture'); return cam.apply(this,arguments) };
  A.addCamera=function(){ wsFileInput().setAttribute('capture','environment'); return cam.apply(this,arguments) } }
/* location */
A.locate=()=>{ U.locating=true; render();
  const here=()=>top().s==='newProject';
  const ok=(lat,lng,acc)=>{ U.locating=false; U.form.loc={lat:Number(lat),lng:Number(lng),acc:Math.max(1,Math.round(Number(acc)||0)),ts:Date.now()}; if(here()) render() };
  const fail=()=>{ U.locating=false; toast(t('loc.fail')); render() };
  const n=NATIVE();
  if(n&&n.getLocation){ window.__metrxLoc=(lat,lng,acc)=>{ lat==null?fail():ok(lat,lng,acc) }; try{ n.getLocation() }catch(e){ fail() } }
  else if(navigator.geolocation) navigator.geolocation.getCurrentPosition(p=>ok(p.coords.latitude,p.coords.longitude,p.coords.accuracy),fail,{enableHighAccuracy:true,timeout:15000,maximumAge:30000});
  else fail() };
A.openMap=()=>{ const r=top(), p=P(r.id||r.pid), l=p&&p.location; if(!l) return; extOpen('https://www.google.com/maps/search/?api=1&query='+l.lat+','+l.lng) };
/* PDF: the report pages as one print document, handed to the phone */
function pdfDocument(){
  const css=[...document.querySelectorAll('style')].map(s=>s.textContent).join('\n');
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=595"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Condensed:wght@400;500;600;700&family=IBM+Plex+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap"><style>${css}
@page{size:595px 842px;margin:0}
html,body{margin:0!important;padding:0!important;height:auto!important;overflow:visible!important;background:#fff!important;display:block!important}
.pdfdoc{position:static!important;display:block!important;overflow:visible!important;background:#fff!important;inset:auto!important}
.pdfdoc .a4{transform:none!important;margin:0!important;border:0!important;box-shadow:none!important;page-break-after:always;break-after:page;-webkit-print-color-adjust:exact;print-color-adjust:exact}
</style></head><body><div class="app pdfdoc">${(U.pages||[]).join('')}</div></body></html>`;
}
A.share=d=>{ const p=P(top().pid); if(!p||!U.pages||!U.pages.length) return;
  const fname=(dn(p.name)+(d.ctx==='quote'?'_'+t('q.no',{n:top().no}):'_'+t('es.draft'))).replace(/[\s,№.\/\\:*?"<>|]+/g,'_')+'.pdf';
  const n=NATIVE();
  if(n&&n.sharePdf){ toast(t('sh.making')); render(); try{ n.sharePdf(pdfDocument(),fname,U.pages.length) }catch(e){ toast(t('sh.onlyPhone')); render() } }
  else { toast(t('sh.onlyPhone')); render() } };
/* backup: a real file out, a real file in */
const backupName=()=>{ const d=new Date(); return 'metrx-zaxira-'+d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate())+'.metrx' };
A.backupNow=()=>{
  const text=JSON.stringify({app:'metrx',kind:'backup',v:1,exported:Date.now(),settings:S.settings,projects:S.projects,readings:S.readings});
  const n=NATIVE(), name=backupName();
  if(n&&n.shareFile){ try{ n.shareFile(name,text,'application/octet-stream') }catch(e){} }
  else { try{ const a=document.createElement('a'); a.href=URL.createObjectURL(new Blob([text],{type:'application/json'})); a.download=name; document.body.appendChild(a); a.click(); a.remove() }catch(e){} }
  S.settings.lastBackup=Date.now(); commit(); toast(t('bk.created')); render() };
function readBackup(text){
  let o; try{ o=JSON.parse(text) }catch(e){ return null }
  if(!o||o.app!=='metrx'||!Array.isArray(o.projects)) return null;
  const ok=p=>p&&typeof p.id==='string'&&p.name!=null&&Array.isArray(p.rooms)&&p.estimate&&Array.isArray(p.estimate.materials)&&Array.isArray(p.estimate.labor)&&Array.isArray(p.quotes);
  return o.projects.every(ok)?o:null;
}
function restoreInput(){ let el=document.getElementById('bkFile'); if(el) return el;
  el=document.createElement('input'); el.type='file'; el.id='bkFile'; el.className='wsfile'; document.body.appendChild(el);
  el.addEventListener('change',()=>{ const f=el.files&&el.files[0]; el.value=''; if(!f) return;
    const rd=new FileReader(); const bad=()=>{ U.restore=null; openSheet({type:'restore',step:'bad'}) };
    rd.onerror=bad; rd.onload=()=>{ const o=readBackup(String(rd.result||'')); if(!o){ bad(); return } U.restore=o; initForm({conflict:'keep'}); openSheet({type:'restore',step:'summary'}) };
    rd.readAsText(f) });
  return el }
A.restorePick=()=>{ closeSheet(true); render(); restoreInput().click() };
SHEETS.restore=sh=>{
  if(sh.step==='bad'||!U.restore) return sheetWrap(t('bk.restore'),`<div class="banner err" style="margin:0">${ic('alert','i s')}<span class="tx">${esc(t('bk.badFile'))}</span></div>`,`<button class="btn sec full" data-a="restorePick">${esc(t('bk.pick'))}</button>`);
  const ps=U.restore.projects, c=ps.filter(p=>S.projects.some(x=>x.id===p.id)).length;
  return sheetWrap(t('bk.restore'),`<p>${esc(t('bk.summary',{n:ps.length,c}))}</p>${c?`<div class="fld"><span class="lab">${esc(t('bk.conflict'))}</span><div class="optlist">${['keep','replace','skip'].map(k=>`<button class="opt ${(U.form.conflict||'keep')===k?'on':''}" data-a="setForm" data-k="conflict" data-v="${k}">${esc(t('bk.'+k))}</button>`).join('')}</div></div>`:''}`,`<button class="btn pri full ${ps.length?'':'dis'}" data-a="doRestore">${esc(t('bk.go'))}</button>`);
};
A.doRestore=()=>{ const o=U.restore; if(!o) return; const mode=U.form.conflict||'keep'; let n=0;
  o.projects.forEach(src=>{ const p=clone(src), i=S.projects.findIndex(x=>x.id===p.id);
    if(i<0){ S.projects.push(p); n++ }
    else if(mode==='replace'){ S.projects[i]=p; n++ }
    else if(mode==='keep'){ p.id=uid(); p.name=dn(p.name)+' (2)'; S.projects.push(p); n++ } });
  U.restore=null; commit(); closeSheet(true); toast(t('bk.done',{n})); render() };
