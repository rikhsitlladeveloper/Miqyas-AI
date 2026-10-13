/* ============================== Measure (option C): one press + quick area ==============================
   One "Measure" press takes the (simulated) laser reading and saves it. A small calculator turns readings into
   area, net wall (length × height minus one door/window), volume or a sum of lengths; tap a reading to fill the
   selected box, and new readings fill it automatically. Geometry only: estimate quantities stay typed.
   Brick tool (founder's choice B): length × height, minus an optional opening, at a wall thickness counted in
   bricks, gives bricks (with spare) and mortar. It is a stand-alone answer: nothing is written to the estimate. */
Object.assign(D,{
'qc.area':['Maydon','Площадь','Area'],
'qc.wall':['Devor','Стена','Wall'],
'qc.vol':['Hajm','Объём','Volume'],
'qc.sum':['Yig‘indi','Сумма','Sum'],
'qc.L':['uzunlik','длина','length'],
'qc.W':['eni','ширина','width'],
'qc.H':['balandlik','высота','height'],
'qc.ow':['ochiq joy eni','ширина проёма','opening width'],
'qc.oh':['ochiq joy bo‘yi','высота проёма','opening height'],
'qc.open':['Minus eshik yoki deraza (ixtiyoriy)','Минус дверь или окно (необязательно)','Minus a door or window (optional)'],
'qc.rArea':['Maydon','Площадь','Area'],
'qc.rWall':['Devor, sof','Стена, чистая','Net wall'],
'qc.rVol':['Hajm','Объём','Volume'],
'qc.rSum':['Jami uzunlik','Общая длина','Total length'],
'qc.pick':['O‘lchovni bosing yoki o‘lchang: u sariq ramkali joyga tushadi.','Нажмите на замер или измерьте: он попадёт в поле с жёлтой рамкой.','Tap a reading or measure: it goes into the box with the yellow frame.'],
'qc.opBig':['Ochiq joy devordan katta','Проём больше стены','Opening is bigger than the wall'],
'qc.dist':['Masofa','Расстояние','Distance'],
'qc.clear':['Tozalash','Очистить','Clear'],
'qc.readings':['O‘lchovlar','Замеры','Readings'],
'qc.list':['Ro‘yxat','Список','List'],
'qc.hide':['Yopish','Свернуть','Hide'],
'qc.none':['Hali o‘lchov yo‘q. “O‘lchash” tugmasini bosing.','Замеров пока нет. Нажмите «Измерить».','No readings yet. Press Measure.'],
'qc.measure':['O‘lchash','Измерить','Measure'],
'qc.saveLive':['Saqlash','Сохранить','Save'],
'qc.start':['Boshlash','Старт','Start'],
'qc.stop':['To‘xtatish','Стоп','Stop'],
'qc.connect':['Lazerni ulash','Подключить лазер','Connect laser'],
'qc.add':['+','+','+'],
'qc.brick':['G‘isht','Кирпич','Brick'],
'qc.rBrick':['G‘isht','Кирпич','Bricks'],
'qb.mortar':['Qorishma','Раствор','Mortar'],
'qb.thick':['Devor qalinligi, g‘ishtda','Толщина стены, в кирпичах','Wall thickness, in bricks'],
'qb.mm':['mm','мм','mm'],
'qb.openAdd':['Eshik yoki derazani ayirish','Вычесть дверь или окно','Take off a door or window'],
'qb.openDel':['Ochiq joysiz hisoblash','Считать без проёма','Count without the opening'],
'qb.spec':['{l}×{w}×{h}, chok {j} mm, zaxira {s} %','{l}×{w}×{h}, шов {j} мм, запас {s} %','{l}×{w}×{h}, {j} mm joint, {s}% spare'],
'qb.change':['O‘zgartirish','Изменить','Change'],
'qb.title':['G‘isht va chok','Кирпич и шов','Brick and joint'],
'qb.size':['G‘isht o‘lchami, mm','Размер кирпича, мм','Brick size, mm'],
'qb.len':['Uzunligi','Длина','Length'],
'qb.wid':['Eni','Ширина','Width'],
'qb.hei':['Balandligi','Высота','Height'],
'qb.joint':['Chok qalinligi','Толщина шва','Joint thickness'],
'qb.spare':['Zaxira','Запас','Spare'],
'qb.note':['Hisob taxminiy. G‘isht soni devor yuzasi va chokdan olinadi, qorishma esa devor hajmidan g‘isht hajmini ayirib topiladi. Smetaga o‘zi yozilmaydi.','Расчёт приблизительный. Количество кирпича считается по площади стены и шву, раствор — как объём стены минус объём кирпича. В смету само не попадает.','An approximate count. Bricks come from the wall face and the joint; mortar is the wall volume minus the bricks. Nothing is written to the estimate.'],
'qb.errRange':['{a} dan {b} gacha butun son kiriting.','Введите целое число от {a} до {b}.','Enter a whole number from {a} to {b}.']
});
const QC_SLOTS={area:['L','W'],wall:['L','H','ow','oh'],vol:['L','W','H'],sum:[],brick:['L','H','ow','oh']};
const QC_IC={area:'room',wall:'walls',vol:'cube',sum:'dim'};
const QB_ICON=c=>`<svg class="${c||'i s'}" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h8v5H3zM13 6h8v5h-8zM7 13h10v5H7z"/></svg>`;
const qcIc=k=>k==='brick'?QB_ICON('i s'):ic(QC_IC[k],'i s');
function qc(){ if(!U.qc) U.qc={tool:'area',vals:{area:[],wall:[],vol:[],sum:[]},act:null}; if(!U.qc.vals.brick) U.qc.vals.brick=[]; return U.qc }
/* brick settings are saved with the other settings: size and joint in mm, spare in %, thickness in half-bricks */
const QB_DEF={l:250,w:120,h:65,j:10,s:5,halves:2};
const QB_PRESETS=[[250,120,65],[250,120,88]];
const QB_LIM={l:[100,600],w:[50,400],h:[30,300],j:[0,30],s:[0,30]};
function qb(){ return S.settings.brick||(S.settings.brick=Object.assign({},QB_DEF)) }
const qbThick=(b,n)=>n*b.w+(n-1)*b.j;
const qbInt=n=>String(n).replace(/\B(?=(\d{3})+(?!\d))/g,GRP());
function qbCount(faceMm2){ const b=qb(), n=faceMm2*b.halves/((b.l+b.j)*(b.h+b.j));
  return {bricks:Math.ceil(n*(100+b.s)/100-1e-9), mortar:Math.max(0,faceMm2*qbThick(b,b.halves)-n*b.l*b.w*b.h)/1e9} }
function qcActive(){ const c=qc(), n=QC_SLOTS[c.tool].length, v=c.vals[c.tool];
  if(c.tool==='sum') return v.length; if(c.act!=null&&c.act<n) return c.act; for(let i=0;i<n;i++) if(!v[i]) return i; return null }
function qcFill(mm,id){ const c=qc(), v=c.vals[c.tool], i=qcActive(); if(i==null) return; v[i]={mm,id}; c.act=null }
function qcResult(){ const c=qc(), v=c.vals[c.tool], g=i=>v[i]&&v[i].mm;
  if(c.tool==='area') return g(0)&&g(1)?{k:'qc.rArea',txt:fmtArea(g(0)*g(1))+' '+M2()}:null;
  if(c.tool==='wall'){ if(!g(0)||!g(1)) return null; const op=g(2)&&g(3)?g(2)*g(3):0; const net=g(0)*g(1)-op; return net>0?{k:'qc.rWall',txt:fmtArea(net)+' '+M2()}:{k:'qc.rWall',err:t('qc.opBig')} }
  if(c.tool==='vol') return g(0)&&g(1)&&g(2)?{k:'qc.rVol',txt:(g(0)*g(1)*g(2)/1e9).toFixed(2).replace('.',DEC())+' '+M()+'³'}:null;
  if(c.tool==='sum') return v.length?{k:'qc.rSum',txt:fmtLen(v.reduce((a,x)=>a+x.mm,0))+' '+M()}:null;
  if(c.tool==='brick'){ if(!g(0)||!g(1)) return null; const op=c.bop&&g(2)&&g(3)?g(2)*g(3):0, net=g(0)*g(1)-op; if(net<=0) return {k:'qc.rBrick',err:t('qc.opBig')};
    const r=qbCount(net); return {k:'qc.rBrick',txt:qbInt(r.bricks)+' <small>'+esc(t('u.pcs'))+'</small>',sub:t('qb.mortar')+' '+r.mortar.toFixed(2).replace('.',DEC())+' '+M()+'³',area:fmtArea(net)+' '+M2()} }
}
function qcCalc(){
  const c=qc(), slots=QC_SLOTS[c.tool], v=c.vals[c.tool], act=qcActive();
  const slot=(i,lab)=>{ const x=v[i]; return `<button class="qm-slot ${x?'':'empty'} ${act===i?'act':''}" data-a="qcSlot" data-i="${i}"><b>${x?fmtLen(x.mm,null,true):'?'}</b><small>${esc(t('qc.'+lab))}</small></button>` };
  let rows='';
  if(c.tool==='sum') rows=`<div class="qm-row" style="flex-wrap:wrap">${v.map((x,i)=>`${i?'<span class="op">+</span>':''}<button class="qm-slot" style="flex:0 0 auto;padding:7px 10px" data-a="qcSlot" data-i="${i}"><b>${fmtLen(x.mm,null,true)}</b></button>`).join('')}${v.length?'<span class="op">+</span>':''}<button class="qm-slot empty act" style="flex:0 0 auto;padding:7px 14px" data-a="noop"><b>?</b></button></div>`;
  else if(c.tool==='wall') rows=`<div class="qm-row">${slot(0,'L')}<span class="op">×</span>${slot(1,'H')}</div><span class="qm-optl">${esc(t('qc.open'))}</span><div class="qm-row">${slot(2,'ow')}<span class="op">×</span>${slot(3,'oh')}</div>`;
  else if(c.tool==='brick'){ const b=qb();
    rows=`<div class="qm-row">${slot(0,'L')}<span class="op">×</span>${slot(1,'H')}</div>
      ${c.bop?`<div class="qm-row">${slot(2,'ow')}<span class="op">×</span>${slot(3,'oh')}</div>`:''}
      <button class="qm-lnk" data-a="qbOpening">${ic(c.bop?'x':'plus','i xs')}${esc(t(c.bop?'qb.openDel':'qb.openAdd'))}</button>
      <span class="qm-optl">${esc(t('qb.thick'))}</span>
      <div class="qm-th">${[1,2,3,4].map(n=>`<button class="${b.halves===n?'on':''}" data-a="qbHalves" data-v="${n}" aria-pressed="${b.halves===n}"><b>${['½','1','1'+DEC()+'5','2'][n-1]}</b><small>${qbThick(b,n)} ${esc(t('qb.mm'))}</small></button>`).join('')}</div>` }
  else rows=`<div class="qm-row">${slots.map((s,i)=>(i?'<span class="op">×</span>':'')+slot(i,s)).join('')}</div>`;
  const r=qcResult();
  const b=c.tool==='brick'?qb():null;
  const extra=b?`${r&&r.sub?`<div class="qm-sub"><span>${esc(r.sub)}</span><span>${esc(r.area)}</span></div>`:''}<div class="qm-sub"><span>${esc(t('qb.spec',{l:b.l,w:b.w,h:b.h,j:b.j,s:b.s}))}</span><button data-a="qbOpen">${esc(t('qb.change'))}</button></div>`:'';
  return `<div class="qm-calc">${rows}<div class="qm-res"><span>${esc(t(r?r.k:{area:'qc.rArea',wall:'qc.rWall',vol:'qc.rVol',sum:'qc.rSum',brick:'qc.rBrick'}[c.tool]))}</span>${r&&r.err?`<em class="qm-err">${ic('alert','i s')}${esc(r.err)}</em>`:r?`<b>${r.txt}</b>`:'<b style="color:#B7C3D9">—</b>'}<button data-a="qcClear">${esc(t('qc.clear'))}</button></div>${extra}</div>`;
}
PAGES.measure=()=>{
  const rs=S.readings.slice().reverse(), b=S.demo.bt, m=U.meas||(U.meas={mode:'single',live:false,val:null}), c=qc();
  if(b!=='connected'){ m.live=false; seen('disconnected') }
  const last=b==='connected'&&m.mode==='cont'&&m.val!=null?m.val:rs[0]?rs[0].mm:null;
  const status=b!=='connected'?`<span>${esc(t(b==='off'?'dev.off':b==='denied'?'dev.denied':'dev.disc'))}</span>`:`<span class="live ${m.live?'on':''}">${esc(t(m.live?'meas.live':'meas.idle'))}</span>`;
  const meter=`<div class="qm-meter"><div class="st">${status}<button data-a="refInfo">${esc(t('meas.ref'))}</button></div><span class="qm-v"><span id="liveVal">${last!=null?fmtLen(last,null,true):'–,–––'}</span><small>${esc(M())}</small></span>
    ${b==='connected'?`<div class="seg wide"><button class="${m.mode==='single'?'on':''}" data-a="measMode" data-v="single">${esc(t('meas.single'))}</button><button class="${m.mode==='cont'?'on':''}" data-a="measMode" data-v="cont">${esc(t('meas.cont'))}</button></div>${m.mode==='cont'?`<button class="qm-live" data-a="measLive">${ic('laser','i s')}${esc(t(m.live?'qc.stop':'qc.start'))} ${simtag()}</button>`:''}`
      :`<div class="banner warn" style="margin:0;width:100%">${ic('btoff','i s')}<span class="tx">${esc(t(b==='off'?'dv.offBody':b==='denied'?'dv.deniedBody':'ms.discBody'))}</span></div>`}</div>`;
  const tools=`<div class="qm-tools">${['area','wall','vol','sum','brick'].map(k=>`<button class="${c.tool===k?'on':''}" data-a="qcTool" data-v="${k}" aria-pressed="${c.tool===k}">${qcIc(k)}<span>${esc(t('qc.'+k))}</span></button>`).join('')}</div>`;
  const used=new Set(c.vals[c.tool].map(x=>x&&x.id));
  const chips=rs.length?`<div class="qm-chips">${rs.slice(0,12).map(x=>`<button class="${used.has(x.id)?'used':''} ${x.src==='sim'?'sim':''}" data-a="qcPick" data-id="${x.id}">${fmtLen(x.mm,null,true)}</button>`).join('')}</div>`:`<p class="qm-hint">${esc(t('qc.none'))}</p>`;
  const list=U.qmList&&rs.length?`<div class="group" style="margin:0">${rs.map(x=>`<div class="listrow"><div class="tx"><b class="cd" style="font-size:20px;font-weight:600">${fmtLen(x.mm,null,true)} ${M()}</b><small>${esc(t('qm.reading',{n:x.n}))}, ${fmtTime(x.ts)}${x.used?', → '+esc(x.used):''}</small></div>${x.src==='sim'?simtag():`<span class="fhint">${esc(t('src.manual'))}</span>`}<button class="ib" data-a="sendReading" data-id="${x.id}" aria-label="${esc(t('qm.send'))}">${ic('send','i s')}</button><button class="ib" data-a="delReading" data-id="${x.id}" aria-label="${esc(t('common.delete'))}">${ic('trash','i s')}</button></div>`).join('')}</div>`:'';
  const main=b!=='connected'?`<button class="btn pri" data-a="device">${ic('bt','i s')}${esc(t('qc.connect'))}</button>`
    :m.mode==='cont'?`<button class="btn pri ${m.val==null?'dis':''}" data-a="qmSaveLive">${ic('save','i s')}${esc(t('qc.saveLive'))}</button>`
    :`<button class="btn pri" data-a="qmMeasure">${ic('laser','i s')}${esc(t('qc.measure'))}</button>`;
  return `<section class="page ${U.anim||''}">${bar({right:devChip()})}<div class="h1">${esc(t('tab.measure'))}</div>${banners()}<div class="scroll" data-scroll="measure"><div class="qm">${meter}${tools}${qcCalc()}${rs.length&&!c.vals[c.tool].some(Boolean)?`<p class="qm-hint">${esc(t('qc.pick'))}</p>`:''}
    <div class="qm-sech"><b>${esc(t('qc.readings'))}</b>${rs.length?`<button data-a="qmList">${esc(t(U.qmList?'qc.hide':'qc.list'))}</button>`:''}</div>${chips}${list}</div></div>
    <div class="footer qm-foot"><div class="btnrow"><button class="btn sec" data-a="qmManual">${ic('kbd','i s')}${esc(t('ed2.manual'))}</button>${main}</div></div></section>`;
};
function qmAddReading(mm,src){ const r={id:uid(),n:S.readings.length+1,mm,ts:Date.now(),src}; S.readings.push(r); qcFill(mm,r.id); commit(); return r }
A.qmMeasure=()=>{ A.measSim(); const m=U.meas; if(m.val==null) return; qmAddReading(m.val,'sim'); seen('quick'); render() };
A.qmSaveLive=()=>{ const m=U.meas; if(m.val==null) return; qmAddReading(m.val,'sim'); seen('quick'); toast(t('qm.saved')); render() };
A.qmManual=()=>{ initForm({'qm.val':''}); openSheet({type:'qmManual'}); setFocus('qm.val','num',''); render() };
SHEETS.qmManual=()=>sheetWrap(t('meas.manualTitle'),field('qm.val',t('qc.dist'),{num:true,suf:M(),err:lenFieldErr('qm.val',DIM_MAX.A),hint:t('ms.hint')}),`<button class="btn pri full" data-a="qmManualSave">${esc(t('common.save'))}</button>`);
A.qmManualSave=()=>{ const v=U.form['qm.val'], res=lenErr(v,DIM_MAX.A); if(!v||res.err){ U.touched['qm.val']=true; seen('invalid'); render(); return } qmAddReading(res.mm,'manual'); seen('manual'); closeSheet(true); toast(t('qm.saved')); render() };
A.qmList=()=>{ U.qmList=!U.qmList; render() };
A.qcTool=d=>{ const c=qc(); c.tool=d.v; c.act=null; render() };
A.qcSlot=d=>{ const c=qc(), i=Number(d.i); if(c.tool==='sum'){ c.vals.sum.splice(i,1); render(); return } c.act=i; render() };
A.qcPick=d=>{ const x=S.readings.find(r=>r.id===d.id); if(!x) return; qcFill(x.mm,x.id); render() };
A.qcClear=()=>{ const c=qc(); c.vals[c.tool]=[]; c.act=null; render() };
/* ---- brick tool: opening on or off, thickness, and the brick/joint/spare sheet ---- */
A.qbOpening=()=>{ const c=qc(); c.bop=!c.bop; if(!c.bop){ c.vals.brick.length=Math.min(c.vals.brick.length,2) } c.act=null; render() };
A.qbHalves=d=>{ qb().halves=Number(d.v); commit(); render() };
A.qbOpen=()=>{ const b=qb(); initForm({'qb.l':String(b.l),'qb.w':String(b.w),'qb.h':String(b.h),'qb.j':String(b.j),'qb.s':String(b.s)}); openSheet({type:'qbSet'}) };
const qbErr=k=>{ const v=String(U.form['qb.'+k]??'').trim(), [a,z]=QB_LIM[k]; return /^\d+$/.test(v)&&Number(v)>=a&&Number(v)<=z?null:t('qb.errRange',{a,b:z}) };
SHEETS.qbSet=()=>{ const f=U.form, cur=[f['qb.l'],f['qb.w'],f['qb.h']].join('×');
  const fld=(k,lab,suf,next)=>field('qb.'+k,t(lab),{num:true,suf,err:qbErr(k),next:next?'qb.'+next:''});
  return sheetWrap(t('qb.title'),`<div class="form" style="gap:12px">
    <div class="fld"><span class="lab">${esc(t('qb.size'))}</span><div class="choice">${QB_PRESETS.map((p,i)=>`<button class="opt ${cur===p.join('×')?'on':''}" data-a="qbPreset" data-v="${i}">${p.join('×')}</button>`).join('')}</div></div>
    <div class="qb-3">${fld('l','qb.len',t('qb.mm'),'w')}${fld('w','qb.wid',t('qb.mm'),'h')}${fld('h','qb.hei',t('qb.mm'),'j')}</div>
    <div class="qb-2">${fld('j','qb.joint',t('qb.mm'),'s')}${fld('s','qb.spare','%','')}</div>
    <p class="note">${ic('info','i s')}<span>${esc(t('qb.note'))}</span></p></div>`,
    `<button class="btn pri full" data-a="qbSave">${esc(t('common.save'))}</button>`) };
A.qbPreset=d=>{ const p=QB_PRESETS[Number(d.v)]; U.form['qb.l']=String(p[0]); U.form['qb.w']=String(p[1]); U.form['qb.h']=String(p[2]); blur(); render() };
A.qbSave=()=>{ if(['l','w','h','j','s'].some(qbErr)){ U.submitTry=true; seen('invalid'); render(); return } const b=qb(); ['l','w','h','j','s'].forEach(k=>b[k]=Number(U.form['qb.'+k])); commit(); closeSheet(true); render() };
