/* ============================== camera: measured pictures on the Measure tab ==============================
   Three things, confirmed by the founder on 13 Oct 2026:
   - "Kamera" on the Measure tab opens a choice: live camera, or take a photo and draw on it;
   - saved pictures ("Suratlar") live on the Measure tab without a project, open in the existing photo editor,
     can be shared as one image with their lines and numbers, and can be moved into a project's workspace;
   - the live camera: draw a line on the live view, take the value from the laser or type it, then save the frame.
   The app never works a distance out from the picture: the number is the laser's or typed, the line says what it belongs to.
   The line stays where it was drawn on the screen (no AR tracking), so the frame is saved as the lasting record. */
Object.assign(D,{
'cm.btn':['Kamera','Камера','Camera'],
'cm.pickT':['Kamera bilan o‘lchash','Замер с камерой','Measure with the camera'],
'cm.live':['Jonli kamera','Живая камера','Live camera'],
'cm.liveD':['Ekranda chiziq torting, o‘lchang va saqlang','Проведите линию на экране, измерьте и сохраните','Draw a line on the screen, measure and save'],
'cm.photo':['Surat olish','Сделать фото','Take a photo'],
'cm.photoD':['Suratga chiziq chizing va o‘lchamini yozing','Нарисуйте линию на фото и укажите размер','Draw a line on the photo and give it a size'],
'cm.shots':['Suratlar','Снимки','Pictures'],
'cm.shotN':['Surat {n}','Снимок {n}','Picture {n}'],
'cm.noVal':['o‘lchamsiz','без размера','no size'],
'cm.hint':['Devorda chiziq torting','Проведите линию по стене','Draw a line on the wall'],
'cm.s0':['Chiziq hali yo‘q.','Линии пока нет.','No line yet.'],
'cm.s1':['Chiziq tayyor. O‘lchash yoki Qo‘lda tugmasini bosing.','Линия готова. Нажмите «Измерить» или «Вручную».','The line is ready. Press Measure or Type.'],
'cm.s1off':['Chiziq tayyor. Lazer ulanmagan: qiymatni Qo‘lda kiriting.','Линия готова. Лазер не подключён: введите значение вручную.','The line is ready. The laser is not connected: type the value.'],
'cm.s2l':['Lazerdan qabul qilindi. Saqlash tugmasini bosing.','Получено с лазера. Нажмите «Сохранить».','Received from the laser. Press Save.'],
'cm.s2m':['Qiymat kiritildi. Saqlash tugmasini bosing.','Значение введено. Нажмите «Сохранить».','Value entered. Press Save.'],
'cm.steady':['Chiziq ekranda qoladi, devorda emas. Telefonni qimirlatmay o‘lchang va saqlang.','Линия остаётся на экране, а не на стене. Держите телефон неподвижно, измерьте и сохраните.','The line stays on the screen, not on the wall. Hold the phone still, measure and save.'],
'cm.starting':['Kamera ochilmoqda…','Открываем камеру…','Opening the camera…'],
'cm.errT':['Kamera ochilmadi','Камера не открылась','The camera did not open'],
'cm.errDenied':['Kameraga ruxsat berilmagan. Telefon sozlamalarida ⟦METRX⟧ uchun kamerani yoqing yoki surat oling.','Нет доступа к камере. Разрешите камеру для METRX в настройках телефона или сделайте фото.','Camera access is off. Allow the camera for METRX in the phone’s settings, or take a photo instead.'],
'cm.errNone':['Bu qurilmada jonli kamera ishlamaydi. Surat olib, ustiga chizing.','Живая камера на этом устройстве недоступна. Сделайте фото и рисуйте на нём.','Live camera is not available on this device. Take a photo and draw on it.'],
'cm.manT':['Chiziq uzunligi','Длина линии','Length of the line'],
'cm.saved':['Suratlar ichida saqlandi','Сохранено в «Снимках»','Saved under Pictures'],
'cm.share':['Ulashish','Поделиться','Share'],
'cm.toProj':['Loyihaga qo‘shish','Добавить в проект','Add to a project'],
'cm.del':['Suratni o‘chirish','Удалить снимок','Delete picture'],
'cm.delQ':['Surat o‘chirilsinmi?','Удалить снимок?','Delete this picture?'],
'cm.delB':['Surat chiziqlari va o‘lchamlari bilan birga o‘chadi.','Снимок удалится вместе с линиями и размерами.','The picture is deleted with its lines and sizes.'],
'cm.deleted':['Surat o‘chirildi','Снимок удалён','Picture deleted'],
'cm.toT':['Qaysi ish joyiga?','В какую рабочую зону?','Which workspace?'],
'cm.toNone':['Avval loyiha va ish joyini yarating.','Сначала создайте проект и рабочую зону.','Create a project and a workspace first.'],
'cm.moved':['“{w}” ga qo‘shildi','Добавлено в «{w}»','Added to “{w}”'],
'cm.shareOnly':['Ulashish faqat telefondagi ilovada ishlaydi','Поделиться можно только из приложения на телефоне','Sharing works only in the app on a phone'],
'cm.shareErr':['Suratni tayyorlab bo‘lmadi','Не удалось подготовить снимок','Could not prepare the picture']
});
const shots=()=>S.shots||(S.shots=[]);
const SHOTS_WS=()=>({id:'shots',name:'@cm.shots',items:shots()});
/* the photo editor finds its item through itemOf; a picture from the Measure tab has no project around it */
{ const io=itemOf; itemOf=function(rt){ if(rt&&rt.shot) return {p:null,w:SHOTS_WS(),it:shots().find(x=>x.id===rt.iid)}; return io(rt) } }
const shotVal=it=>{ const e=(it.els||[]).find(x=>x.t==='dim'&&x.v!=null); return e?fmtLen(e.v)+' '+M():null };
function camStrip(){
  const ss=shots(); if(!ss.length) return '';
  return `<div class="qm-sech"><b>${esc(t('cm.shots'))}</b><span class="cm-n">${ss.length}</span></div><div class="cm-strip" data-scroll="cmshots">${ss.map(it=>{ const v=shotVal(it); return `<button class="cm-shot" data-a="shotOpen" data-id="${it.id}" aria-label="${esc(dn(it.name))}"><span class="th">${mkSVG(it,{thumb:true}).replace('preserveAspectRatio="xMidYMid meet"','preserveAspectRatio="xMidYMid slice"')}</span><b class="${v?'':'none'}">${esc(v||t('cm.noVal'))}</b><small>${esc(dn(it.name))}</small></button>` }).join('')}</div>`;
}
const camBtn=()=>`<button class="btn sec qm-cam" data-a="camOpen" aria-label="${esc(t('cm.btn'))}">${ic('camera')}</button>`;

/* ---------- Kamera: the two ways in ---------- */
SHEETS.camPick=()=>{ const big=(a,icn,l,d)=>`<button class="bigrow" data-a="${a}"><span class="ai">${ic(icn)}</span><span class="tx"><b>${esc(t(l))}</b><small>${esc(t(d))}</small></span>${ic('chev','i s')}</button>`;
  return sheetWrap(t('cm.pickT'),`<div class="bigrows">${big('camLive','laser','cm.live','cm.liveD')}${big('camShot','camera','cm.photo','cm.photoD')}</div>`,'') };
A.camOpen=()=>{ if(!guard()) return; openSheet({type:'camPick'}) };
A.shotOpen=d=>{ push({s:'photo',shot:true,iid:d.id}) };
function camNewShot(o){ const it=Object.assign({id:uid(),kind:'photo',name:t('cm.shotN',{n:shots().length+1}),caption:'',created:Date.now(),edited:Date.now(),els:[],rep:false},o); shots().unshift(it); commit(); return it }
/* take a photo with the phone's camera app, then draw on it */
function camFileInput(){ let el=document.getElementById('camFile'); if(el) return el;
  el=document.createElement('input'); el.type='file'; el.accept='image/*'; el.setAttribute('capture','environment'); el.id='camFile'; el.className='wsfile'; document.body.appendChild(el);
  el.addEventListener('change',()=>{ const f=el.files&&el.files[0]; el.value=''; if(!f) return;
    const rd=new FileReader(); rd.onerror=()=>{ toast(t('mk.photoErr')); render() };
    rd.onload=()=>{ const img=new Image(); img.onerror=()=>{ toast(t('mk.photoErr')); render() };
      img.onload=()=>{ const k=Math.min(1,1280/Math.max(img.width,img.height)), cw=Math.round(img.width*k), ch=Math.round(img.height*k); const cv=document.createElement('canvas'); cv.width=cw; cv.height=ch; cv.getContext('2d').drawImage(img,0,0,cw,ch);
        let src; try{ src=cv.toDataURL('image/jpeg',.72) }catch(e){ toast(t('mk.photoErr')); render(); return }
        const it=camNewShot({src,W:1000,H:Math.round(1000*ch/cw)}); if(top().s==='liveCam') stack().pop(); push({s:'photo',shot:true,iid:it.id}) };
      img.src=rd.result };
    rd.readAsDataURL(f) });
  return el;
}
A.camShot=()=>{ closeSheet(true); render(); camFileInput().click() };

/* ---------- a saved picture in the photo editor: its own menu instead of the workspace one ---------- */
{ const ph=PAGES.photo; PAGES.photo=rt=>{ if(!rt.shot) return ph(rt); const {it}=itemOf(rt); if(!it) return PAGES.measure(rt);
    return ph(rt).replace(`<button class="ib" data-a="itemMenu" data-k="photo" data-id="${it.id}" aria-label="menu">`,`<button class="ib" data-a="shotShare" aria-label="${esc(t('cm.share'))}">${ic('share')}</button><button class="ib" data-a="shotMenu" aria-label="menu">`) } }
const shotCur=()=>{ const r=top(); return r&&r.shot?shots().find(x=>x.id===r.iid):null };
SHEETS.shotMenu=()=>{ const it=shotCur(); if(!it) return '';
  const row=(a,icn,k,red)=>`<button class="listrow" style="padding-left:4px;${red?'color:#B42318':''}" data-a="${a}">${ic(icn)}<span class="tx"><b>${esc(t(k))}</b></span></button>`;
  return sheetWrap(dn(it.name),`<div>${row('shotShare','share','cm.share')}${row('shotTo','layers','cm.toProj')}${row('shotDelAsk','trash','cm.del',true)}</div>`,'') };
A.shotMenu=()=>openSheet({type:'shotMenu'});
SHEETS.shotDel=()=>sheetWrap(t('cm.delQ'),`<p>${esc(t('cm.delB'))}</p>`,`<div class="btnrow"><button class="btn sec" data-a="closeSheet">${esc(t('common.cancel'))}</button><button class="btn danger" data-a="shotDel">${esc(t('cm.del'))}</button></div>`);
A.shotDelAsk=()=>{ U.sheet={type:'shotDel'}; render() };
A.shotDel=()=>{ const it=shotCur(); if(!it) return; S.shots=shots().filter(x=>x.id!==it.id); commit(); closeSheet(true); stack().pop(); U.anim='pop'; toast(t('cm.deleted')); render() };
/* into a project: the picture becomes an ordinary photo of that workspace, so it can also go into the PDF */
SHEETS.shotTo=()=>{ const rows=S.projects.flatMap(p=>p.floors.map(w=>`<button class="listrow" style="padding-left:4px" data-a="shotMove" data-pid="${p.id}" data-id="${w.id}">${ic('layers')}<span class="tx"><b>${esc(floorName(w))}</b><small>${esc(dn(p.name))}</small></span>${ic('chev','i s')}</button>`));
  return sheetWrap(t('cm.toT'),rows.length?`<div>${rows.join('')}</div>`:`<p class="note">${ic('info','i s')}<span>${esc(t('cm.toNone'))}</span></p>`,'') };
A.shotTo=()=>{ if(!guard()) return; U.sheet={type:'shotTo'}; render() };
A.shotMove=d=>{ const it=shotCur(), p=P(d.pid), w=p&&WSP(p,d.id); if(!it||!w) return; S.shots=shots().filter(x=>x.id!==it.id); it.edited=Date.now(); wsItems(w).push(it); p.edited=Date.now(); commit();
  closeSheet(true); stack().pop(); U.anim='pop'; toast(t('cm.moved',{w:floorName(w)})); render() };
/* share: the photo with its lines and numbers as one JPEG, through the phone's share sheet */
function shotImage(it,done){
  const W=it.W||1000, H=it.H||750, k=Math.min(2,1600/Math.max(W,H));
  const svg=mkSVG(it).replace('<svg class="mk-svg"',`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" font-family="Arial, Helvetica, sans-serif"`).replace(/font-family="[^"]*IBM Plex[^"]*"/g,'');
  const img=new Image(); img.onerror=()=>done(null);
  img.onload=()=>{ try{ const cv=document.createElement('canvas'); cv.width=Math.round(W*k); cv.height=Math.round(H*k); const g=cv.getContext('2d'); g.fillStyle='#fff'; g.fillRect(0,0,cv.width,cv.height); g.drawImage(img,0,0,cv.width,cv.height); done(cv.toDataURL('image/jpeg',.9)) }catch(e){ done(null) } };
  img.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(svg);
}
A.shotShare=()=>{ const it=shotCur(); if(!it) return; closeSheet(true);
  const name='METRX_'+String(dn(it.name)).replace(/[\s,№.\/\\:*?"<>|]+/g,'_')+'.jpg';
  shotImage(it,url=>{ if(!url){ toast(t('cm.shareErr')); render(); return }
    const n=window.MetrxNative;
    if(n&&n.shareImage){ try{ n.shareImage(name,url.split(',')[1]) }catch(e){ toast(t('cm.shareErr')); render() } return }
    try{ fetch(url).then(r=>r.blob()).then(b=>{ const f=new File([b],name,{type:'image/jpeg'});
        if(navigator.canShare&&navigator.canShare({files:[f]})) return navigator.share({files:[f],title:dn(it.name)}); toast(t('cm.shareOnly')); render() }).catch(()=>{}) }catch(e){ toast(t('cm.shareOnly')); render() } });
  render() };

/* ---------- live camera ---------- */
const lc=()=>U.lc||(U.lc={line:null,val:null,src:null,err:null,on:false});
A.camLive=()=>{ closeSheet(true); U.lc={line:null,val:null,src:null,err:null,on:false}; push({s:'liveCam'}) };
const lcState=()=>{ const s=lc(); return s.val!=null?t(s.src==='laser'?'cm.s2l':'cm.s2m'):s.line?t(S.demo.bt==='connected'?'cm.s1':'cm.s1off'):t('cm.s0') };
function lcLineSVG(){
  const s=lc(); if(!s.line) return '';
  const v=document.getElementById('lcView'), w=v?v.clientWidth:320, h=v?v.clientHeight:420;
  const x1=s.line[0]*w, y1=s.line[1]*h, x2=s.line[2]*w, y2=s.line[3]*h, dx=x2-x1, dy=y2-y1, L=Math.hypot(dx,dy)||1, nx=-dy/L*9, ny=dx/L*9, mx=(x1+x2)/2, my=(y1+y2)/2, F=n=>n.toFixed(1);
  const d=`M${F(x1)} ${F(y1)}L${F(x2)} ${F(y2)}M${F(x1-nx)} ${F(y1-ny)}L${F(x1+nx)} ${F(y1+ny)}M${F(x2-nx)} ${F(y2-ny)}L${F(x2+nx)} ${F(y2+ny)}`;
  const txt=s.val!=null?fmtLen(s.val,null,true)+' '+M():'?', tw=txt.length*9.5+24, ly=Math.max(18,my-26);
  return `<path d="${d}" stroke="#fff" stroke-width="6" stroke-linecap="round" opacity=".85" fill="none"/><path d="${d}" stroke="#D92D20" stroke-width="3" stroke-linecap="round" fill="none"/><rect x="${F(mx-tw/2)}" y="${F(ly-15)}" width="${F(tw)}" height="30" rx="15" fill="${s.val!=null?'#D92D20':'#fff'}" stroke="#D92D20" stroke-width="1.5"/><text x="${F(mx)}" y="${F(ly+1)}" text-anchor="middle" dominant-baseline="middle" font-family="${F_NUM}" font-weight="700" font-size="17" fill="${s.val!=null?'#fff':'#B42318'}">${esc(txt)}</text>`;
}
/* the live view is not re-rendered while a line is drawn or a value arrives: only these parts are repainted */
function lcPaint(){
  const s=lc(), g=document.getElementById('lcLine'); if(!g) return;
  g.innerHTML=lcLineSVG();
  const st=document.getElementById('lcState'); if(st) st.textContent=lcState();
  const hint=document.getElementById('lcHint'); if(hint) hint.hidden=!!s.line||!s.on;
  const dis=(id,v)=>{ const b=document.getElementById(id); if(b) b.classList.toggle('dis',v) };
  dis('lcBtnM',!s.line||S.demo.bt!=='connected'); dis('lcBtnT',!s.line); dis('lcBtnS',s.val==null||!s.on);
}
PAGES.liveCam=()=>{
  const s=lc(), bt=S.demo.bt==='connected';
  const body=s.err?`<div class="lc-err"><span class="ill">${ic('camera','i l')}</span><h3>${esc(t('cm.errT'))}</h3><p>${esc(t(s.err==='denied'?'cm.errDenied':'cm.errNone'))}</p><button class="btn pri" data-a="camShot">${ic('camera','i s')}${esc(t('cm.photo'))}</button></div>`
    :`<div class="lc-view" id="lcView"><video id="lcVideo" autoplay playsinline muted poster="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="></video><svg class="lc-svg" aria-hidden="true"><g id="lcLine"></g></svg><div class="lc-hint" id="lcHint" ${s.line||!s.on?'hidden':''}>${esc(t('cm.hint'))}</div>${s.on?'':`<div class="lc-wait">${esc(t('cm.starting'))}</div>`}</div>`;
  return `<section class="page lc ${U.anim||''}"><div class="lc-top"><button class="ib" data-a="back" aria-label="${esc(t('common.close'))}">${ic('x')}</button><b>${esc(t('cm.live'))}</b><span class="lc-dev ${bt?'on':''}">${ic(bt?'bt':'btoff','i s')}<span>${esc(t(bt?'dev.conn':'dev.disc'))}</span></span></div>
    ${body}${s.err?'':`<p class="lc-state" id="lcState" role="status">${esc(lcState())}</p><p class="lc-note">${ic('info','i s')}<span>${esc(t('cm.steady'))}</span></p>
    <div class="lc-bar"><button class="btn ${s.line?'':'dis'}" id="lcBtnT" data-a="lcManual">${ic('kbd','i s')}${esc(t('ed2.manual'))}</button><button class="btn pri ${s.line&&bt?'':'dis'}" id="lcBtnM" data-a="lcMeasure">${ic('laser','i s')}${esc(t('qc.measure'))}</button><button class="btn ${s.val!=null&&s.on?'':'dis'}" id="lcBtnS" data-a="lcSave">${ic('save','i s')}${esc(t('common.save'))}</button></div>`}</section>`;
};
function lcStop(){ const st=U.lcStream; U.lcStream=null; if(st){ try{ st.getTracks().forEach(x=>x.stop()) }catch(e){} } if(U.lc) U.lc.on=false }
function lcAttach(){
  const v=document.getElementById('lcVideo'); if(!v) return;
  if(U.lcStream){ if(v.srcObject!==U.lcStream){ v.srcObject=U.lcStream; const p=v.play(); if(p&&p.catch) p.catch(()=>{}) } return }
  if(U.lcStarting) return;
  const md=navigator.mediaDevices;
  if(!md||!md.getUserMedia){ lc().err='none'; render(); return }
  U.lcStarting=true;
  md.getUserMedia({audio:false,video:{facingMode:{ideal:'environment'},width:{ideal:1280},height:{ideal:960}}}).then(st=>{
    U.lcStarting=false;
    if(top().s!=='liveCam'){ try{ st.getTracks().forEach(x=>x.stop()) }catch(e){} return }
    U.lcStream=st; lc().on=true; lc().err=null; render();
  }).catch(e=>{ U.lcStarting=false; if(top().s!=='liveCam') return; lc().err=e&&(e.name==='NotAllowedError'||e.name==='SecurityError')?'denied':'none'; render() });
}
/* after every render: give the stream to the fresh <video>, or let the camera go when the screen is left */
{ const base=render; render=function(){ base(); const r=!S.firstRun&&top(); if(r&&r.s==='liveCam'){ if(!lc().err) lcAttach(); lcPaint() } else if(U.lcStream||U.lcStarting) lcStop() } }
document.addEventListener('visibilitychange',()=>{ if(document.hidden){ if(U.lcStream){ lcStop(); } } else if(!S.firstRun&&top().s==='liveCam'){ render() } });
/* drawing the line */
{ let drag=null;
  const at=(v,e)=>{ const r=v.getBoundingClientRect(); return [Math.min(.985,Math.max(.015,(e.clientX-r.left)/r.width)),Math.min(.985,Math.max(.015,(e.clientY-r.top)/r.height))] };
  appEl.addEventListener('pointerdown',e=>{ const v=e.target.closest&&e.target.closest('#lcView'); if(!v||U.sheet||!lc().on) return; const p=at(v,e); drag={v,id:e.pointerId}; const s=lc(); s.line=[p[0],p[1],p[0],p[1]]; s.val=null; s.src=null; try{ v.setPointerCapture(e.pointerId) }catch(x){} lcPaint(); e.preventDefault() });
  appEl.addEventListener('pointermove',e=>{ if(!drag||e.pointerId!==drag.id) return; const p=at(drag.v,e), s=lc(); if(!s.line) return; s.line[2]=p[0]; s.line[3]=p[1]; lcPaint() });
  const end=e=>{ if(!drag||e.pointerId!==drag.id) return; const v=drag.v, s=lc(); drag=null; if(s.line&&Math.hypot((s.line[2]-s.line[0])*v.clientWidth,(s.line[3]-s.line[1])*v.clientHeight)<18) s.line=null; lcPaint() };
  appEl.addEventListener('pointerup',end); appEl.addEventListener('pointercancel',end); }
A.lcMeasure=()=>{ const s=lc(); if(!s.line||S.demo.bt!=='connected') return; s.val=600+Math.round(Math.random()*7600); s.src='laser'; lcPaint() };
A.lcManual=()=>{ const s=lc(); if(!s.line) return; initForm({'lc.val':s.val!=null?fmtLen(s.val,null,true):''}); openSheet({type:'lcManual'}); setFocus('lc.val','num',''); render() };
SHEETS.lcManual=()=>sheetWrap(t('cm.manT'),field('lc.val',t('mk.value'),{num:true,suf:M(),err:U.form['lc.val']?lenFieldErr('lc.val',DIM_MAX.A):null,hint:msHint()}),`<button class="btn pri full" data-a="lcManualSave">${esc(t('common.save'))}</button>`);
A.lcManualSave=()=>{ const v=U.form['lc.val'], r=lenErr(v,DIM_MAX.A); if(!v||r.err){ U.touched['lc.val']=true; U.submitTry=true; render(); return } const s=lc(); s.val=r.mm; s.src='manual'; closeSheet(true); render() };
/* save: the visible part of the frame becomes a photo, the line becomes a measured dimension on it */
A.lcSave=()=>{ const s=lc(), v=document.getElementById('lcVideo'), box=document.getElementById('lcView'); if(!s.line||s.val==null||!v||!box||!v.videoWidth) return;
  const vw=box.clientWidth, vh=box.clientHeight, iw=v.videoWidth, ih=v.videoHeight, sc=Math.max(vw/iw,vh/ih), sw=vw/sc, sh=vh/sc, sx=(iw-sw)/2, sy=(ih-sh)/2;
  const k=Math.min(1,1280/Math.max(sw,sh)), cw=Math.round(sw*k), ch=Math.round(sh*k); let src;
  try{ const cv=document.createElement('canvas'); cv.width=cw; cv.height=ch; cv.getContext('2d').drawImage(v,sx,sy,sw,sh,0,0,cw,ch); src=cv.toDataURL('image/jpeg',.78) }catch(e){ toast(t('mk.photoErr')); render(); return }
  const W=1000, H=Math.round(1000*ch/cw), R=n=>Math.round(n);
  const it=camNewShot({src,W,H,els:[{id:uid(),t:'dim',pts:[[R(s.line[0]*W),R(s.line[1]*H)],[R(s.line[2]*W),R(s.line[3]*H)]],v:s.val,src:s.src==='laser'?'laser':'manual',c:'red'}]});
  lcStop(); U.lc=null; stack().pop(); toast(t('cm.saved')); push({s:'photo',shot:true,iid:it.id}) };
