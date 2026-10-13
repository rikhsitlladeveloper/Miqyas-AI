/* ============================== Measure (option C): one press + quick area ==============================
   One "Measure" press takes the (simulated) laser reading and saves it. A small calculator turns readings into
   area, net wall (length × height minus one door/window), volume or a sum of lengths; tap a reading to fill the
   selected box, and new readings fill it automatically. Geometry only: estimate quantities stay typed. */
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
'qc.add':['+','+','+']
});
const QC_SLOTS={area:['L','W'],wall:['L','H','ow','oh'],vol:['L','W','H'],sum:[]};
const QC_IC={area:'room',wall:'walls',vol:'cube',sum:'dim'};
function qc(){ if(!U.qc) U.qc={tool:'area',vals:{area:[],wall:[],vol:[],sum:[]},act:null}; return U.qc }
function qcActive(){ const c=qc(), n=QC_SLOTS[c.tool].length, v=c.vals[c.tool];
  if(c.tool==='sum') return v.length; if(c.act!=null&&c.act<n) return c.act; for(let i=0;i<n;i++) if(!v[i]) return i; return null }
function qcFill(mm,id){ const c=qc(), v=c.vals[c.tool], i=qcActive(); if(i==null) return; v[i]={mm,id}; c.act=null }
function qcResult(){ const c=qc(), v=c.vals[c.tool], g=i=>v[i]&&v[i].mm;
  if(c.tool==='area') return g(0)&&g(1)?{k:'qc.rArea',txt:fmtArea(g(0)*g(1))+' '+M2()}:null;
  if(c.tool==='wall'){ if(!g(0)||!g(1)) return null; const op=g(2)&&g(3)?g(2)*g(3):0; const net=g(0)*g(1)-op; return net>0?{k:'qc.rWall',txt:fmtArea(net)+' '+M2()}:{k:'qc.rWall',err:t('qc.opBig')} }
  if(c.tool==='vol') return g(0)&&g(1)&&g(2)?{k:'qc.rVol',txt:(g(0)*g(1)*g(2)/1e9).toFixed(2).replace('.',DEC())+' '+M()+'³'}:null;
  if(c.tool==='sum') return v.length?{k:'qc.rSum',txt:fmtLen(v.reduce((a,x)=>a+x.mm,0))+' '+M()}:null;
}
function qcCalc(){
  const c=qc(), slots=QC_SLOTS[c.tool], v=c.vals[c.tool], act=qcActive();
  const slot=(i,lab)=>{ const x=v[i]; return `<button class="qm-slot ${x?'':'empty'} ${act===i?'act':''}" data-a="qcSlot" data-i="${i}"><b>${x?fmtLen(x.mm,null,true):'?'}</b><small>${esc(t('qc.'+lab))}</small></button>` };
  let rows='';
  if(c.tool==='sum') rows=`<div class="qm-row" style="flex-wrap:wrap">${v.map((x,i)=>`${i?'<span class="op">+</span>':''}<button class="qm-slot" style="flex:0 0 auto;padding:7px 10px" data-a="qcSlot" data-i="${i}"><b>${fmtLen(x.mm,null,true)}</b></button>`).join('')}${v.length?'<span class="op">+</span>':''}<button class="qm-slot empty act" style="flex:0 0 auto;padding:7px 14px" data-a="noop"><b>?</b></button></div>`;
  else if(c.tool==='wall') rows=`<div class="qm-row">${slot(0,'L')}<span class="op">×</span>${slot(1,'H')}</div><span class="qm-optl">${esc(t('qc.open'))}</span><div class="qm-row">${slot(2,'ow')}<span class="op">×</span>${slot(3,'oh')}</div>`;
  else rows=`<div class="qm-row">${slots.map((s,i)=>(i?'<span class="op">×</span>':'')+slot(i,s)).join('')}</div>`;
  const r=qcResult();
  return `<div class="qm-calc">${rows}<div class="qm-res"><span>${esc(t(r?r.k:{area:'qc.rArea',wall:'qc.rWall',vol:'qc.rVol',sum:'qc.rSum'}[c.tool]))}</span>${r&&r.err?`<em class="qm-err">${ic('warn','i s')}${esc(r.err)}</em>`:r?`<b>${r.txt}</b>`:'<b style="color:#B7C3D9">—</b>'}<button data-a="qcClear">${esc(t('qc.clear'))}</button></div></div>`;
}
PAGES.measure=()=>{
  const rs=S.readings.slice().reverse(), b=S.demo.bt, m=U.meas||(U.meas={mode:'single',live:false,val:null}), c=qc();
  if(b!=='connected'){ m.live=false; seen('disconnected') }
  const last=b==='connected'&&m.mode==='cont'&&m.val!=null?m.val:rs[0]?rs[0].mm:null;
  const status=b!=='connected'?`<span>${esc(t(b==='off'?'dev.off':b==='denied'?'dev.denied':'dev.disc'))}</span>`:`<span class="live ${m.live?'on':''}">${esc(t(m.live?'meas.live':'meas.idle'))}</span>`;
  const meter=`<div class="qm-meter"><div class="st">${status}<button data-a="refInfo">${esc(t('meas.ref'))}</button></div><span class="qm-v"><span id="liveVal">${last!=null?fmtLen(last,null,true):'–,–––'}</span><small>${esc(M())}</small></span>
    ${b==='connected'?`<div class="seg wide"><button class="${m.mode==='single'?'on':''}" data-a="measMode" data-v="single">${esc(t('meas.single'))}</button><button class="${m.mode==='cont'?'on':''}" data-a="measMode" data-v="cont">${esc(t('meas.cont'))}</button></div>${m.mode==='cont'?`<button class="qm-live" data-a="measLive">${ic('laser','i s')}${esc(t(m.live?'qc.stop':'qc.start'))} ${simtag()}</button>`:''}`
      :`<div class="banner warn" style="margin:0;width:100%">${ic('btoff','i s')}<span class="tx">${esc(t(b==='off'?'dv.offBody':b==='denied'?'dv.deniedBody':'ms.discBody'))}</span></div>`}</div>`;
  const tools=`<div class="qm-tools">${['area','wall','vol','sum'].map(k=>`<button class="${c.tool===k?'on':''}" data-a="qcTool" data-v="${k}" aria-pressed="${c.tool===k}">${ic(QC_IC[k],'i s')}<span>${esc(t('qc.'+k))}</span></button>`).join('')}</div>`;
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
