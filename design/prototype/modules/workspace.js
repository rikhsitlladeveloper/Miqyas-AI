/* ============================== workspaces ==============================
   Project → workspace (a place: floor, room, bathroom, yard…) → room plans, free drawings, photos, notes.
   A workspace is stored in p.floors (it replaces floors), so room plans keep their floorId link and every
   existing room/3D/estimate path keeps working. Drawings, photos and notes live in workspace.items. */
Object.assign(D,{
'ws.tab':['Ish joylari','Рабочие зоны','Workspaces'],
'ws.one':['Ish joyi','Рабочая зона','Workspace'],
'ws.new':['Yangi ish joyi','Новая рабочая зона','New workspace'],
'ws.create':['Ish joyi yaratish','Создать рабочую зону','Create workspace'],
'ws.name':['Nomi','Название','Name'],
'ws.nameReq':['Nomini kiriting','Введите название','Enter a name'],
'ws.type':['Turi','Тип','Type'],
'ws.t.floor':['Qavat','Этаж','Floor'],
'ws.t.room':['Xona','Комната','Room'],
'ws.t.bath':['Hammom','Ванная','Bathroom'],
'ws.t.kitchen':['Oshxona','Кухня','Kitchen'],
'ws.t.balcony':['Balkon','Балкон','Balcony'],
'ws.t.outdoor':['Hovli','Двор','Outdoor'],
'ws.t.other':['Boshqa','Другое','Other'],
'ws.emptyT':['Birinchi ish joyini yarating','Создайте первую рабочую зону','Create your first workspace'],
'ws.emptyB':['Ish joyi — qavat, xona yoki hovli kabi joy. Unda xona chizmalari, suratlar va eslatmalar saqlanadi.','Рабочая зона — это место: этаж, комната или двор. В ней хранятся планы комнат, фото и заметки.','A workspace is a place such as a floor, a room or the yard. It holds room plans, photos and notes.'],
'ws.blankT':['Bu yer hozircha bo‘sh','Здесь пока пусто','Nothing here yet'],
'ws.blankB':['Chizma, surat yoki eslatma qo‘shish uchun + tugmasini bosing.','Нажмите +, чтобы добавить чертёж, фото или заметку.','Tap + to add a sketch, photo or note.'],
'ws.filterEmpty':['Bu turdagi narsa hali yo‘q','Элементов этого типа пока нет','Nothing of this type yet'],
'ws.f.all':['Hammasi','Все','All'],
'ws.f.sketch':['Chizmalar','Чертежи','Sketches'],
'ws.f.photo':['Suratlar','Фото','Photos'],
'ws.f.note':['Eslatmalar','Заметки','Notes'],
'ws.cRoom':['{n} ta xona','{n} {n:комната|комнаты|комнат}','{n} {n:room|rooms}'],
'ws.cDraw':['{n} ta chizma','{n} {n:рисунок|рисунка|рисунков}','{n} {n:drawing|drawings}'],
'ws.cPhoto':['{n} ta surat','{n} фото','{n} {n:photo|photos}'],
'ws.cNote':['{n} ta eslatma','{n} {n:заметка|заметки|заметок}','{n} {n:note|notes}'],
'ws.empty':['Bo‘sh','Пусто','Empty'],
'ws.secRooms':['Xonalar','Комнаты','Rooms'],
'ws.secOther':['Surat, chizma, eslatma','Фото, рисунки, заметки','Photos, drawings, notes'],
'ws.floor':['Pol','Пол','Floor'],
'ws.add':['Qo‘shish','Добавить','Add'],
'ws.netWall':['{v} m² devor','{v} м² стен','{v} m² wall'],
'ws.menuEdit':['Nomi va turini o‘zgartirish','Изменить название и тип','Rename or change type'],
'ws.menuDel':['Ish joyini o‘chirish','Удалить рабочую зону','Delete workspace'],
'ws.delQ':['“{n}” o‘chirilsinmi?','Удалить «{n}»?','Delete “{n}”?'],
'ws.delB':['Ichidagi hamma narsa ham o‘chiriladi: {c}.','Всё содержимое тоже будет удалено: {c}.','Everything inside is deleted too: {c}.'],
'ws.delBEmpty':['Ish joyi bo‘sh.','Рабочая зона пуста.','The workspace is empty.'],
'ws.deleted':['“{n}” o‘chirildi','«{n}» удалена','“{n}” deleted'],
'ws.created':['“{n}” yaratildi','«{n}» создана','“{n}” created'],
'add.title':['Qo‘shish: {n}','Добавить в «{n}»','Add to “{n}”'],
'add.sketch':['Chizma','Чертёж','Sketch'],
'add.sketchD':['Xona rejasi yoki erkin chizma','План комнаты или рисунок','Room plan or free drawing'],
'add.photo':['Surat','Фото','Photo'],
'add.photoD':['O‘lchamlar bilan','С размерами','With dimensions'],
'add.note':['Eslatma','Заметка','Note'],
'add.noteD':['Matn va ro‘yxat','Текст и список','Text and checklist'],
'add.plan':['Xona rejasi','План комнаты','Room plan'],
'add.planD':['Devorlar, o‘lchamlar, eshik va derazalar. 3D va smetaga o‘tadi.','Стены, размеры, двери и окна. Идёт в 3D и смету.','Walls, dimensions, doors and windows. Feeds 3D and the estimate.'],
'add.free':['Erkin chizma','Свободный рисунок','Free drawing'],
'add.freeD':['Qalam, chiziqlar va yozuvlar. Smetaga ta’sir qilmaydi.','Карандаш, линии и подписи. На смету не влияет.','Pen, lines and labels. Doesn’t affect the estimate.'],
'add.camera':['Suratga olish','Сфотографировать','Take a photo'],
'add.cameraD':['Kamera simulyatsiyasi: namunaviy surat olinadi','Симуляция камеры: берётся пример фото','Camera simulation: uses a sample photo'],
'add.gallery':['Galereyadan tanlash','Выбрать из галереи','Choose from gallery'],
'add.galleryD':['Telefondagi haqiqiy surat','Настоящее фото с телефона','A real photo from this phone'],
'it.drawing':['Chizma {n}','Рисунок {n}','Drawing {n}'],
'it.photo':['Surat {n}','Фото {n}','Photo {n}'],
'it.untitled':['Nomsiz eslatma','Заметка без названия','Untitled note'],
'it.rename':['Nomini o‘zgartirish','Переименовать','Rename'],
'it.move':['Boshqa ish joyiga ko‘chirish','Переместить в другую зону','Move to another workspace'],
'it.dup':['Nusxa olish','Дублировать','Duplicate'],
'it.del':['O‘chirish','Удалить','Delete'],
'it.report':['Hisobotga qo‘shish','Включить в отчёт','Include in report'],
'it.moveT':['Qayerga ko‘chirish?','Куда переместить?','Move to'],
'it.moveNone':['Boshqa ish joyi yo‘q. Avval yangisini yarating.','Других рабочих зон нет. Сначала создайте новую.','There’s no other workspace. Create one first.'],
'it.moved':['“{n}” → {w}','«{n}» → {w}','“{n}” → {w}'],
'it.copy':['{n} (nusxa)','{n} (копия)','{n} (copy)'],
'it.deleted':['“{n}” o‘chirildi','«{n}» удалено','“{n}” deleted'],
'it.dims':['{n} ta o‘lcham','{n} {n:размер|размера|размеров}','{n} {n:dimension|dimensions}'],
'it.dimsOpen':['{n} ta o‘lcham kiritilmagan','Без значения: {n}','{n} without a value'],
'it.items':['{d}/{n} bajarildi','{d}/{n} выполнено','{d}/{n} done'],
'it.k.room':['Xona rejasi','План комнаты','Room plan'],
'it.k.drawing':['Erkin chizma','Рисунок','Drawing'],
'it.k.photo':['Surat','Фото','Photo'],
'it.k.note':['Eslatma','Заметка','Note'],
'it.blankDraw':['Bo‘sh varaq','Пустой лист','Blank page'],
'nt.title':['Sarlavha','Заголовок','Title'],
'nt.titlePh':['Masalan: Mijoz istaklari','Например: Пожелания клиента','e.g. Customer wishes'],
'nt.text':['Matn','Текст','Text'],
'nt.textPh':['Eslatmani yozing…','Напишите заметку…','Write your note…'],
'nt.list':['Ro‘yxat','Список','Checklist'],
'nt.add':['Band qo‘shish','Добавить пункт','Add item'],
'nt.itemPh':['Masalan: Gruntovka sotib olish','Например: Купить грунтовку','e.g. Buy primer'],
'nt.del':['Bandni o‘chirish','Удалить пункт','Remove item'],
'nt.tick':['Bajarildi deb belgilash','Отметить выполненным','Mark as done'],
'mk.pen':['Qalam','Карандаш','Pen'],
'mk.line':['Chiziq','Линия','Line'],
'mk.dim':['O‘lcham','Размер','Dimension'],
'mk.arrow':['Strelka','Стрелка','Arrow'],
'mk.text':['Yozuv','Надпись','Text'],
'mk.eraser':['O‘chirg‘ich','Ластик','Eraser'],
'mk.thin':['Ingichka','Тонкая','Thin'],
'mk.thick':['Qalin','Толстая','Thick'],
'mk.c.ink':['Qora','Чёрный','Black'],
'mk.c.cobalt':['Ko‘k','Синий','Blue'],
'mk.c.red':['Qizil','Красный','Red'],
'mk.h.pen':['Barmoq bilan chizing','Рисуйте пальцем','Draw with your finger'],
'mk.h.line':['Torting: 0°, 45°, 90° ga yopishadi','Тяните: прилипает к 0°, 45°, 90°','Drag: snaps to 0°, 45°, 90°'],
'mk.h.dim':['O‘lchanadigan joy bo‘ylab torting','Протяните вдоль измеряемого','Drag along what you measure'],
'mk.h.arrow':['Strelka uchun torting','Тяните, чтобы нарисовать стрелку','Drag to draw an arrow'],
'mk.h.text':['Yozuv qo‘yish uchun bosing','Нажмите, чтобы добавить надпись','Tap to place a label'],
'mk.h.eraser':['O‘chirish uchun ustidan yurgizing','Проведите по линии, чтобы стереть','Rub over a line to erase it'],
'mk.dimT':['O‘lcham','Размер','Dimension'],
'mk.value':['Uzunligi','Длина','Length'],
'mk.laser':['Lazer bilan o‘lchash','Измерить лазером','Measure with laser'],
'mk.recv':['Qabul qilindi: {v}','Получено: {v}','Received: {v}'],
'mk.use':['Shuni olish','Использовать','Use it'],
'mk.later':['Keyinroq','Позже','Later'],
'mk.delLine':['Chiziqni o‘chirish','Удалить линию','Delete line'],
'mk.noLaser':['Lazer ulanmagan. Qiymatni qo‘lda kiriting.','Лазер не подключён. Введите значение вручную.','The laser isn’t connected. Type the value.'],
'mk.textT':['Yozuv','Надпись','Text label'],
'mk.textPh':['Masalan: rozetka','Например: розетка','e.g. socket'],
'mk.delText':['Yozuvni o‘chirish','Удалить надпись','Delete label'],
'mk.caption':['Izoh','Подпись','Caption'],
'mk.captionPh':['Surat ostidagi izoh','Подпись под фото','Caption under the photo'],
'mk.addCaption':['Izoh qo‘shish','Добавить подпись','Add a caption'],
'mk.photoNote':['Suratdagi o‘lchamlar faqat ma’lumot uchun, xona rejasini o‘zgartirmaydi.','Размеры на фото — для справки, план комнаты они не меняют.','Dimensions on photos are for reference; they never change a room plan.'],
'mk.photoErr':['Suratni ochib bo‘lmadi. Boshqasini tanlang.','Не удалось открыть фото. Выберите другое.','Couldn’t open that photo. Choose another.'],
'ph.s1':['Deraza devori','Стена с окном','Window wall'],
'ph.s2':['Hammom quvurlari','Трубы в ванной','Bathroom pipes'],
'ph.s3':['Eshik o‘rni','Дверной проём','Doorway'],
'r.extras':['Chizmalar va suratlar','Рисунки и фото','Drawings and photos'],
'r.notesH':['Eslatmalar','Заметки','Notes'],
'r.photoNote':['Suratlardagi o‘lchamlar ma’lumot uchun berilgan.','Размеры на фото указаны для справки.','Dimensions on photos are for reference.'],
'rpt.extras':['Chizma, surat va eslatmalar','Рисунки, фото и заметки','Drawings, photos and notes'],
'rpt.noExtras':['Ish joylarida chizma, surat yoki eslatma yo‘q','В рабочих зонах нет рисунков, фото и заметок','No drawings, photos or notes in the workspaces'],
'smp.noteT':['Mijoz istaklari','Пожелания клиента','Customer wishes'],
'smp.noteX':['Pol — laminat, devorlar — och kulrang. Ishni dushanbadan boshlash.','Пол — ламинат, стены — светло-серые. Начать в понедельник.','Laminate floor, light grey walls. Start on Monday.'],
'smp.ck1':['Gruntovka sotib olish','Купить грунтовку','Buy primer'],
'smp.ck2':['Rozetkalar joyini kelishish','Согласовать места розеток','Agree socket positions'],
'smp.ck3':['Eski oboyni olib tashlash','Снять старые обои','Strip the old wallpaper'],
'smp.phLab':['Deraza almashtiriladi','Окно под замену','Window to replace']
});

/* extra icons for this module */
document.body.insertAdjacentHTML('afterbegin',`<svg width="0" height="0" style="position:absolute" aria-hidden="true">
<symbol id="i-pen" viewBox="0 0 24 24"><path d="M4 20l4-1L19 8l-3-3L5 16z"/><path d="M14 7l3 3"/></symbol>
<symbol id="i-note" viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6z"/><path d="M15 3v4h4M9 12h7M9 16h5"/></symbol>
<symbol id="i-bath" viewBox="0 0 24 24"><path d="M3 12h18v3a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"/><path d="M6 12V6a2 2 0 0 1 4 0M7 19l-1 2M17 19l1 2"/></symbol>
<symbol id="i-kitchen" viewBox="0 0 24 24"><rect x="4" y="3" width="16" height="18" rx="1.5"/><path d="M4 9h16M8 6h.01M12 6h.01M9 13h6v4H9z"/></symbol>
<symbol id="i-balcony" viewBox="0 0 24 24"><path d="M3 11h18M3 21h18M6 11v10M10 11v10M14 11v10M18 11v10M7 11V4h10v7"/></symbol>
<symbol id="i-tree" viewBox="0 0 24 24"><path d="M12 3l6 8h-4l5 7H5l5-7H6z"/><path d="M12 18v3"/></symbol>
<symbol id="i-eraser" viewBox="0 0 24 24"><path d="M4 15l9-9 6 6-7 7H8z"/><path d="M10 9l6 6M9 19h11"/></symbol>
<symbol id="i-arrow" viewBox="0 0 24 24"><path d="M5 19L19 5M10 5h9v9"/></symbol>
<symbol id="i-text" viewBox="0 0 24 24"><path d="M5 7V4h14v3M12 4v16M9 20h6"/></symbol>
<symbol id="i-line" viewBox="0 0 24 24"><path d="M5 19L19 5"/><path d="M3 17l4 4M17 3l4 4"/></symbol>
</svg>`);

const WS_TYPES=[['floor','layers'],['room','room'],['bath','bath'],['kitchen','kitchen'],['balcony','balcony'],['outdoor','tree'],['other','folder']];
const wsType=w=>w&&w.type||'floor';
const wsIcon=w=>(WS_TYPES.find(x=>x[0]===wsType(w))||WS_TYPES[0])[1];
const WSP=(p,id)=>p&&p.floors.find(f=>f.id===id);
const wsItems=w=>w.items||(w.items=[]);
const wsRooms=(p,w)=>p.rooms.filter(r=>r.floorId===w.id);
const repOf=it=>it.rep!=null?it.rep:it.kind!=='note';
const KIND_IC={room:'room',drawing:'pen',photo:'camera',note:'note'};
function wsSuggest(p,type){
  if(type==='floor') return t('pr.floorName',{n:p.floors.filter(f=>wsType(f)==='floor').length+1});
  const base=t('ws.t.'+type), n=p.floors.filter(f=>{ const nm=floorName(f); return nm===base||nm.startsWith(base+' ') }).length;
  return n?base+' '+(n+1):base;
}
function wsStoreName(p,nm,type){
  for(let k=1;k<=p.floors.length+1;k++) if(type==='floor'&&nm===t('pr.floorName',{n:k})) return '@floor:'+k;
  return nm===t('ws.t.'+type)?'@ws.t.'+type:nm;
}
function wsCounts(p,w){
  const rs=wsRooms(p,w).length, its=wsItems(w), c=k=>its.filter(x=>x.kind===k).length;
  return [[rs,'ws.cRoom'],[c('drawing'),'ws.cDraw'],[c('photo'),'ws.cPhoto'],[c('note'),'ws.cNote']].filter(x=>x[0]).map(([n,k])=>t(k,{n})).join(', ');
}
function itemOf(rt){ const p=P(rt.pid), w=WSP(p,rt.wid), it=w&&wsItems(w).find(x=>x.id===rt.iid); return {p,w,it} }
const keepKey=(old,val)=>dn(old)===val?old:val;
function wsEntries(p,w){
  return [...wsRooms(p,w).map(r=>({k:'room',id:r.id,r,ts:r.created||0})),...wsItems(w).map(it=>({k:it.kind,id:it.id,it,ts:it.created||0}))].sort((a,b)=>b.ts-a.ts);
}
function entryName(e){ return e.k==='room'?dn(e.r.name):e.k==='note'?(dn(e.it.name)||t('it.untitled')):dn(e.it.name) }

/* ---------- project page: workspace list instead of the floor/room table ---------- */
{ const base=roomsTab; roomsTab=function(p,rt){ const v=(rt&&rt.view)||'list'; if(v!=='list'&&p.rooms.length) return base(p,rt); return wsList(p) } }
function wsList(p){
  if(!p.floors.length) return `<div class="ws-empty"><svg width="120" height="84" viewBox="0 0 120 84" aria-hidden="true"><rect x="8" y="10" width="64" height="48" rx="6" fill="#EAF0FE" stroke="#1C4BD1" stroke-width="2"/><rect x="48" y="26" width="64" height="48" rx="6" fill="#fff" stroke="#0E1C36" stroke-width="2"/><path d="M60 44h40M60 54h26" stroke="#5F6B82" stroke-width="2" stroke-linecap="round"/><circle cx="98" cy="68" r="13" fill="#1C4BD1"/><path d="M98 62v12M92 68h12" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/></svg><h3>${esc(t('ws.emptyT'))}</h3><p>${esc(t('ws.emptyB'))}</p><button class="btn ${isLocked()?'locked':'pri'} full" data-a="newSpace">${ic(isLocked()?'lock':'plus','i s')}${esc(t('ws.create'))}</button></div>`;
  const seg=p.rooms.length?`<div class="seg wide" style="margin-bottom:10px">${['list','2d','3d'].map(k=>`<button class="${k==='list'?'on':''}" data-a="pview" data-v="${k}">${esc(k==='list'?t('view.list'):k.toUpperCase())}</button>`).join('')}</div>`:'';
  const rows=p.floors.map(w=>{ const rs=wsRooms(p,w), area=rs.reduce((a,r)=>{ const ar=areas(r); return a+(ar?ar.floor:0) },0);
    return `<button class="wsrow" data-a="openSpace" data-id="${w.id}"><span class="ws-ic">${ic(wsIcon(w))}</span><span class="tx"><b>${esc(floorName(w))}</b><small>${esc(wsCounts(p,w)||t('ws.empty'))}</small></span>${area?`<span class="ar">${fmtArea(area)} ${esc(M2())}</span>`:''}${ic('chev','i s')}</button>` }).join('');
  return `<div class="pad" style="padding-top:12px">${seg}<div class="lgroup ws-list">${rows}</div></div>`;
}

/* ---------- workspace page ---------- */
PAGES.space=(rt)=>{
  const p=P(rt.pid), w=WSP(p,rt.wid); if(!w) return PAGES.project({id:rt.pid,tab:'rooms'});
  const all=wsEntries(p,w), rooms=all.filter(e=>e.k==='room'), other=all.filter(e=>e.k!=='room');
  const sec=(title,list)=>`<div class="ws-sec"><div class="ws-sech"><b>${esc(title)}</b><span class="n">${list.length}</span></div><div class="wgrid">${list.map(e=>wsCard(p,w,e)).join('')}</div></div>`;
  const body=!all.length?`<div class="ws-blank"><svg width="88" height="104" viewBox="0 0 88 104" aria-hidden="true"><path d="M8 6h52l20 20v72H8z" fill="#fff" stroke="#C3CEDF" stroke-width="2" stroke-dasharray="5 4"/><path d="M60 6v20h20" fill="none" stroke="#C3CEDF" stroke-width="2" stroke-dasharray="5 4"/></svg><h3>${esc(t('ws.blankT'))}</h3><p>${esc(t('ws.blankB'))}</p></div><svg class="ws-arrow" viewBox="0 0 96 80" aria-hidden="true"><path d="M6 6C20 50 46 66 82 70" fill="none" stroke="currentColor" stroke-width="2.5" stroke-dasharray="6 6" stroke-linecap="round"/><path d="M72 60l12 10-14 6" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`
    :`<div class="ws-body">${rooms.length?sec(t('ws.secRooms'),rooms):''}${other.length?sec(t('ws.secOther'),other):''}</div>`;
  return `<section class="page space ${U.anim||''}">${bar({back:dn(p.name),right:savedChip()+`<button class="ib" data-a="wsMenu" aria-label="menu">${ic('more')}</button>`})}<div class="ws-head"><span class="ws-ic">${ic(wsIcon(w))}</span><div><h1>${esc(floorName(w))}</h1><small>${esc(floorName(w)===t('ws.t.'+wsType(w))?t('ws.one'):t('ws.t.'+wsType(w)))}</small></div></div>${rooms.length?wsNums(p,w):''}${banners()}<div class="scroll" data-scroll="ws-${w.id}">${body}</div>${U.sheet?'':`<button class="ws-fab" data-a="wsAdd" aria-label="${esc(t('add.title',{n:floorName(w)}))}">${ic(isLocked()?'lock':'plus')}${esc(t('ws.add'))}</button>`}</section>`;
};
/* the workspace's own totals: net wall, floor, measurements confirmed ("+?" while some rooms lack values) */
function wsNums(p,w){
  const rs=wsRooms(p,w); let net=0,nn=0,fl=0,fn=0,need=0,conf=0;
  rs.forEach(r=>{ const a=areas(r); if(a){ fl+=a.floor; fn++; if(a.net!=null){ net+=a.net; nn++ } } const ks=hmDimKeys(r); need+=ks.length; conf+=ks.filter(k=>dimStatus(r.dims[k])==='conf').length });
  const v=(sum,n)=>n?`${fmtArea(sum)} <small>${esc(M2())}${n<rs.length?' +?':''}</small>`:'?';
  return `<div class="pj-nums"><div><span>${esc(t('pl.wall'))}</span><b>${v(net,nn)}</b></div><div><span>${esc(t('ws.floor'))}</span><b>${v(fl,fn)}</b></div><div><span>${esc(t('pl.meas'))}</span><b>${need?conf+'/'+need:'—'}</b></div></div>`;
}
function wsCard(p,w,e){
  let th='',meta='',cls='';
  if(e.k==='room'){ const r=e.r, ar=areas(r), sc=110/Math.max(r.dims.A.v||4000,r.dims.B.v||3000), nx=hmNext(r);
    th=`<div class="wc-th plan">${r.shape==='poly'?thumbSVG(r,120,90):miniPlan(r,sc)}</div>`;
    meta=nx.cls==='ok'?`<small class="okc">${ic('check','i xs')}${esc(ar&&ar.net!=null?t('ws.netWall',{v:fmtArea(ar.net)}):ar?fmtArea(ar.floor)+' '+M2():t('hm.next.ok'))}</small>`
      :`<small class="${nx.cls==='bad'?'errc':nx.cls==='unset'?'':'pend'}">${ic(nx.ic,'i xs')}${esc(nx.txt)}</small>` }
  else if(e.k==='note'){ const it=e.it, ck=it.checks||[], d=ck.filter(c=>c.done).length;
    th=`<div class="wc-th note"><p>${esc(dn(it.text)||'')}</p>${ck.length?`<span class="ckp">${ic('boxok','i xs')}${esc(t('it.items',{d,n:ck.length}))}</span>`:''}</div>`;
    meta=`<small>${esc(fmtDate(it.edited||it.created))}</small>` }
  else { const it=e.it, ds=mkEls(it).filter(x=>x.t==='line'||x.t==='dim'), open=ds.filter(x=>x.v==null).length;
    th=`<div class="wc-th ${e.k==='photo'?'photo':'paper'}">${mkSVG(it,{thumb:true})}</div>`;
    meta=open?`<small class="pend">${ic('clock','i xs')}${esc(t('it.dimsOpen',{n:open}))}</small>`:ds.length?`<small>${ic('dim','i xs')}${esc(t('it.dims',{n:ds.length}))}</small>`:`<small>${esc(mkEls(it).length?fmtDate(it.edited||it.created):t('it.blankDraw'))}</small>` }
  const rep=e.k==='room'?p.report.rooms[e.id]!==false:repOf(e.it);
  return `<div class="wcard" data-card="${e.k}" data-id="${e.id}"><button class="wc-open" data-a="wsOpen" data-k="${e.k}" data-id="${e.id}">${th}<span class="wc-b"><span class="wc-k">${ic(KIND_IC[e.k],'i xs')}${esc(t('it.k.'+e.k))}</span><b>${esc(entryName(e))}</b>${meta}</span></button><button class="ib wc-more" data-a="itemMenu" data-k="${e.k}" data-id="${e.id}" aria-label="menu">${ic('more','i s')}</button>${rep?'<span class="wc-pdf">PDF</span>':''}</div>`;
}

/* ---------- workspace sheets ---------- */
SHEETS.newSpace=(sh)=>{
  const p=P(sh.pid), ty=U.form.wstype||'floor', err=!String(U.form.wsname||'').trim()?t('ws.nameReq'):null;
  const body=`${field('wsname',t('ws.name'),{err,ph:wsSuggest(p,ty)})}<div class="fld"><span class="lab">${esc(t('ws.type'))}</span><div class="ws-types">${WS_TYPES.map(([k,icn])=>`<button class="opt ${ty===k?'on':''}" data-a="wsTypePick" data-v="${k}" aria-pressed="${ty===k}">${ic(icn,'i s')}${esc(t('ws.t.'+k))}</button>`).join('')}</div></div>`;
  return sheetWrap(t(sh.edit?'ws.menuEdit':'ws.new'),body,`<button class="btn pri full ${err?'dis':''}" data-a="${sh.edit?'saveSpace':'createSpace'}">${esc(t(sh.edit?'common.save':'ws.create'))}</button>`);
};
SHEETS.spaceMenu=(sh)=>{ const w=WSP(P(sh.pid),sh.wid);
  return sheetWrap(floorName(w),`<div><button class="listrow" style="padding-left:4px" data-a="wsEdit">${ic(isLocked()?'lock':'edit')}<span class="tx"><b>${esc(t('ws.menuEdit'))}</b></span></button><button class="listrow" style="padding-left:4px;color:#B42318" data-a="wsDelAsk">${ic(isLocked()?'lock':'trash')}<span class="tx"><b>${esc(t('ws.menuDel'))}</b></span></button></div>`,'') };
SHEETS.spaceDel=(sh)=>{ const p=P(sh.pid), w=WSP(p,sh.wid), c=wsCounts(p,w);
  return sheetWrap(t('ws.delQ',{n:floorName(w)}),`<p>${esc(c?t('ws.delB',{c}):t('ws.delBEmpty'))}</p>`,`<div class="btnrow"><button class="btn sec" data-a="closeSheet">${esc(t('common.cancel'))}</button><button class="btn danger" data-a="wsDelete">${ic('trash','i s')}${esc(t('it.del'))}</button></div>`) };
SHEETS.addItem=(sh)=>{
  const p=P(sh.pid), w=WSP(p,sh.wid), step=sh.step||'root';
  const big=(a,icn,l,d,sim)=>`<button class="bigrow" data-a="${a}"><span class="ai">${ic(icn)}</span><span class="tx"><b>${esc(t(l))}</b><small>${esc(t(d))}</small>${sim?simtag():''}</span>${ic('chev','i s')}</button>`;
  if(step==='sketch') return sheetWrap(t('add.sketch'),`<div class="bigrows">${big('addPlan','room','add.plan','add.planD')}${big('addFree','pen','add.free','add.freeD')}</div>`,'',{extra:`<button class="ib" data-a="addStep" data-v="root" aria-label="back" style="order:-1">${ic('back')}</button>`});
  if(step==='photo') return sheetWrap(t('add.photo'),`<div class="bigrows">${big('addCamera','camera','add.camera','add.cameraD',true)}${big('addGallery','folder','add.gallery','add.galleryD')}</div>`,'',{extra:`<button class="ib" data-a="addStep" data-v="root" aria-label="back" style="order:-1">${ic('back')}</button>`});
  return sheetWrap(t('add.title',{n:floorName(w)}),`<div class="addtiles">${[['sketch','pen'],['photo','camera'],['note','note']].map(([k,icn])=>`<button class="addtile" data-a="addStep" data-v="${k}"><span class="ai">${ic(icn,'i l')}</span><b>${esc(t('add.'+k))}</b><small>${esc(t('add.'+k+'D'))}</small></button>`).join('')}</div>`,'');
};
SHEETS.itemMenu=(sh)=>{
  const {p,w}=wsCtx(), e=findEntry(p,sh.k,sh.id); if(!e) return '';
  const rep=e.k==='room'?p.report.rooms[e.id]!==false:repOf(e.it), lk=isLocked();
  const row=(a,icn,k,red)=>`<button class="listrow" style="padding-left:4px;${red?'color:#B42318':''}" data-a="itemAct" data-v="${a}">${ic(lk?'lock':icn)}<span class="tx"><b>${esc(t(k))}</b></span></button>`;
  return sheetWrap(entryName(e),`<div>${row('rename','edit','it.rename')}${row('move','layers','it.move')}${row('dup','copy','it.dup')}<button class="listrow" style="padding-left:4px" data-a="itemAct" data-v="rep" aria-pressed="${rep}">${ic('doc')}<span class="tx"><b>${esc(t('it.report'))}</b></span><span class="switch ${rep?'on':''}"></span></button>${row('del','trash','it.del',true)}</div>`,'');
};
SHEETS.itemRename=(sh)=>sheetWrap(t('it.rename'),field('iname',t('ws.name'),{err:!String(U.form.iname||'').trim()&&sh.k!=='note'?t('ws.nameReq'):null}),`<button class="btn pri full" data-a="itemRenameSave">${esc(t('common.save'))}</button>`);
SHEETS.itemMove=(sh)=>{ const {p,w}=wsCtx(), e=findEntry(p,sh.k,sh.id), others=p.floors.filter(f=>f.id!==(e.k==='room'?e.r.floorId:w.id));
  return sheetWrap(t('it.moveT'),others.length?`<div class="optlist">${others.map(f=>`<button class="opt" data-a="itemMoveTo" data-v="${f.id}"><span style="display:flex;gap:10px;align-items:center">${ic(wsIcon(f),'i s')}${esc(floorName(f))}</span>${ic('chev','i s')}</button>`).join('')}</div>`:`<p class="fhint">${esc(t('it.moveNone'))}</p>`,'') };

function wsCtx(){ const r=top(); const p=P(r.pid||r.id); return {p,w:WSP(p,r.wid)} }
function findEntry(p,k,id){
  if(k==='room'){ const r=R(p,id); return r&&{k,id,r} }
  for(const w of p.floors){ const it=wsItems(w).find(x=>x.id===id); if(it) return {k:it.kind,id,it,w} }
  return null;
}

/* ---------- workspace actions ---------- */
A.newSpace=()=>{ if(!guard()) return; const p=P(top().id); initForm({wsname:wsSuggest(p,'floor'),wstype:'floor'}); openSheet({type:'newSpace',pid:p.id}) };
A.wsTypePick=d=>{ const p=P(U.sheet.pid), old=U.form.wstype||'floor', cur=String(U.form.wsname||'').trim(); if(!cur||cur===wsSuggest(p,old)||(U.sheet.edit&&cur===floorName(WSP(p,U.sheet.edit)))) U.form.wsname=U.sheet.edit&&d.v===old?cur:wsSuggest(p,d.v); U.form.wstype=d.v; render() };
A.createSpace=()=>{ const p=P(U.sheet.pid), nm=String(U.form.wsname||'').trim(), ty=U.form.wstype||'floor'; if(!nm){ U.submitTry=true; render(); return }
  const w={id:uid(),name:wsStoreName(p,nm,ty),type:ty,items:[],created:Date.now()}; p.floors.push(w); p.edited=Date.now(); commit(); closeSheet(true); push({s:'space',pid:p.id,wid:w.id}); toast(t('ws.created',{n:nm})); render() };
A.openSpace=d=>push({s:'space',pid:top().id,wid:d.id});
A.wsFilter=d=>{ top().f=d.v; render() };
A.wsMenu=()=>openSheet({type:'spaceMenu',pid:top().pid,wid:top().wid});
A.wsEdit=()=>{ if(!guard()) return; const p=P(U.sheet.pid), w=WSP(p,U.sheet.wid); initForm({wsname:floorName(w),wstype:wsType(w)}); U.sheet={type:'newSpace',pid:p.id,edit:w.id}; render() };
A.saveSpace=()=>{ const p=P(U.sheet.pid), w=WSP(p,U.sheet.edit), nm=String(U.form.wsname||'').trim(); if(!nm){ U.submitTry=true; render(); return } const ty=U.form.wstype||'floor'; if(nm!==floorName(w)) w.name=wsStoreName(p,nm,ty); w.type=ty; p.edited=Date.now(); commit(); closeSheet() };
A.wsDelAsk=()=>{ if(!guard()) return; U.sheet={type:'spaceDel',pid:U.sheet.pid,wid:U.sheet.wid}; render() };
A.wsDelete=()=>{ const p=P(U.sheet.pid), w=WSP(p,U.sheet.wid), idx=p.floors.indexOf(w), rooms=wsRooms(p,w);
  p.floors.splice(idx,1); p.rooms=p.rooms.filter(r=>r.floorId!==w.id); U.lastDeleted={kind:'space',pid:p.id,w,idx,rooms}; commit(); closeSheet(true);
  if(top().s==='space'){ stack().pop(); U.anim='pop' } toast(t('ws.deleted',{n:floorName(w)}),{label:t('common.undo'),a:'undoDelete'}); render() };
{ const ud=A.undoDelete; A.undoDelete=()=>{ const x=U.lastDeleted;
  if(x&&x.kind==='item'){ const w=WSP(P(x.pid),x.wid); if(w) wsItems(w).splice(x.idx,0,x.it); U.lastDeleted=null; U.toast=null; commit(); render(); return }
  if(x&&x.kind==='space'){ const p=P(x.pid); p.floors.splice(x.idx,0,x.w); p.rooms.push(...x.rooms); U.lastDeleted=null; U.toast=null; commit(); render(); return }
  ud() } }
A.wsAdd=()=>{ if(!guard()) return; openSheet({type:'addItem',pid:top().pid,wid:top().wid,step:'root'}) };
A.addStep=d=>{ if(d.v==='note'){ const {pid,wid}=U.sheet; closeSheet(true); wsNewNote(pid,wid); return } U.sheet.step=d.v; render() };
A.addPlan=()=>{ const {pid,wid}=U.sheet, p=P(pid), w=WSP(p,wid), own=['room','bath','kitchen','balcony'].includes(wsType(w))&&!wsRooms(p,w).length; initForm({rname:own?floorName(w):p.rooms.length?'':t('smp.living'),rfloor:wid,rthick:'0,20'.replace(',',DEC())}); U.sheet={type:'newRoom',pid,fixed:wid}; U.sheetAnim=true; render() };
function wsNewItem(pid,wid,o){ const p=P(pid), w=WSP(p,wid), n=wsItems(w).filter(x=>x.kind===o.kind).length+1;
  const it=Object.assign({id:uid(),created:Date.now(),edited:Date.now(),els:[]},o); if(it.name==null) it.name=t(o.kind==='photo'?'it.photo':'it.drawing',{n}); wsItems(w).push(it); p.edited=Date.now(); commit(); return it }
A.addFree=()=>{ const {pid,wid}=U.sheet; closeSheet(true); const it=wsNewItem(pid,wid,{kind:'drawing',W:1000,H:1300}); push({s:'draw',pid,wid,iid:it.id}) };
A.addCamera=()=>{ const {pid,wid}=U.sheet; closeSheet(true); U.camN=((U.camN||0)%3)+1; const it=wsNewItem(pid,wid,{kind:'photo',src:'@sample:'+U.camN,W:1000,H:750,name:'@ph.s'+U.camN,caption:''}); push({s:'photo',pid,wid,iid:it.id}) };
A.addGallery=()=>{ const {pid,wid}=U.sheet; U.pickTo={pid,wid}; closeSheet(true); render(); wsFileInput().click() };
function wsFileInput(){ let el=document.getElementById('wsFile'); if(el) return el;
  el=document.createElement('input'); el.type='file'; el.accept='image/*'; el.id='wsFile'; el.className='wsfile'; document.body.appendChild(el);
  el.addEventListener('change',()=>{ const f=el.files&&el.files[0]; el.value=''; const to=U.pickTo; if(!f||!to) return;
    const rd=new FileReader(); rd.onerror=()=>{ toast(t('mk.photoErr')); render() };
    rd.onload=()=>{ const img=new Image(); img.onerror=()=>{ toast(t('mk.photoErr')); render() };
      img.onload=()=>{ const max=1280, k=Math.min(1,max/Math.max(img.width,img.height)), cw=Math.round(img.width*k), ch=Math.round(img.height*k); const cv=document.createElement('canvas'); cv.width=cw; cv.height=ch; cv.getContext('2d').drawImage(img,0,0,cw,ch);
        let src; try{ src=cv.toDataURL('image/jpeg',.72) }catch(e){ toast(t('mk.photoErr')); render(); return }
        const it=wsNewItem(to.pid,to.wid,{kind:'photo',src,W:1000,H:Math.round(1000*ch/cw),caption:''}); U.pickTo=null; push({s:'photo',pid:to.pid,wid:to.wid,iid:it.id}) };
      img.src=rd.result };
    rd.readAsDataURL(f) });
  return el;
}
A.wsOpen=d=>{ const r=top(), pid=r.pid, wid=r.wid;
  if(d.k==='room'){ S.lastOpen={pid,rid:d.id}; commit(); push({s:'editor',pid,rid:d.id,mode:'plan'}); return }
  if(d.k==='note'){ wsOpenNote(pid,wid,d.id); return }
  push({s:d.k==='photo'?'photo':'draw',pid,wid,iid:d.id}) };
A.itemMenu=d=>openSheet({type:'itemMenu',k:d.k,id:d.id});
A.itemAct=d=>{ const sh=U.sheet, {p}=wsCtx(), e=findEntry(p,sh.k,sh.id); if(!e) return;
  if(d.v==='rep'){ if(e.k==='room') p.report.rooms[e.id]=p.report.rooms[e.id]===false; else e.it.rep=!repOf(e.it); commit(); render(); return }
  if(!guard()) return;
  if(d.v==='rename'){ noteSync(); initForm({iname:entryName(e)}); U.sheet={type:'itemRename',k:sh.k,id:sh.id}; render(); return }
  if(d.v==='move'){ U.sheet={type:'itemMove',k:sh.k,id:sh.id}; render(); return }
  if(d.v==='dup'){ noteSync();
    if(e.k==='room'){ const c=clone(e.r); c.id=uid(); c.name=t('room.copy',{n:dn(e.r.name)}); c.views=[]; c.created=Date.now(); c.openings.forEach(o=>o.id=uid()); p.rooms.push(c); toast(t('op.added',{o:dn(c.name)})) }
    else { const c=clone(e.it); c.id=uid(); c.name=t('it.copy',{n:entryName(e)}); c.created=c.edited=Date.now(); (c.els||[]).forEach(x=>x.id=uid()); (c.checks||[]).forEach(x=>x.id=uid()); wsItems(e.w).push(c); toast(t('op.added',{o:c.name})) }
    p.edited=Date.now(); commit(); closeSheet(true); render(); return }
  if(d.v==='del'){ const nm=entryName(e);
    if(e.k==='room'){ const idx=p.rooms.indexOf(e.r); p.rooms.splice(idx,1); delete p.report.rooms[e.id]; U.lastDeleted={kind:'room',pid:p.id,r:e.r,idx} }
    else { const its=wsItems(e.w), idx=its.indexOf(e.it); its.splice(idx,1); U.lastDeleted={kind:'item',pid:p.id,wid:e.w.id,it:e.it,idx} }
    p.edited=Date.now(); commit(); closeSheet(true); const tr=top(); if(tr.iid===e.id||tr.rid===e.id){ stack().pop(); U.anim='pop' }
    toast(t('it.deleted',{n:nm}),{label:t('common.undo'),a:'undoDelete'}); render() } };
A.itemRenameSave=()=>{ const sh=U.sheet, {p}=wsCtx(), e=findEntry(p,sh.k,sh.id), nm=String(U.form.iname||'').trim(); if(!nm&&e.k!=='note'){ U.submitTry=true; render(); return }
  if(e.k==='room') e.r.name=keyIfSame(nm,'@smp.living'); else { e.it.name=keepKey(e.it.name,nm); e.it.edited=Date.now(); U.formFor=null }
  commit(); closeSheet() };
A.itemMoveTo=d=>{ const sh=U.sheet, {p}=wsCtx(), e=findEntry(p,sh.k,sh.id), to=WSP(p,d.v);
  if(e.k==='room') e.r.floorId=to.id; else { const its=wsItems(e.w); its.splice(its.indexOf(e.it),1); wsItems(to).push(e.it) }
  const tr=top(); if(tr.iid===e.id) tr.wid=to.id;
  p.edited=Date.now(); commit(); closeSheet(true); toast(t('it.moved',{n:entryName(e),w:floorName(to)})); render() };

/* long-press a card → its menu */
{ let lp=null;
  appEl.addEventListener('pointerdown',e=>{ const c=e.target.closest&&e.target.closest('.wcard'); if(!c||e.target.closest('.wc-more')) return; lp={x:e.clientX,y:e.clientY,tm:setTimeout(()=>{ lp=null; U.lpFired=true; A.itemMenu({k:c.dataset.card,id:c.dataset.id}) },520)} });
  appEl.addEventListener('pointermove',e=>{ if(lp&&Math.hypot(e.clientX-lp.x,e.clientY-lp.y)>10){ clearTimeout(lp.tm); lp=null } });
  ['pointerup','pointercancel'].forEach(ev=>appEl.addEventListener(ev,()=>{ if(lp){ clearTimeout(lp.tm); lp=null } }));
  appEl.addEventListener('click',e=>{ if(U.lpFired){ U.lpFired=false; e.stopPropagation(); e.preventDefault() } },true);
  appEl.addEventListener('contextmenu',e=>{ if(e.target.closest&&e.target.closest('.wcard')) e.preventDefault() }); }

/* ---------- notes ---------- */
function wsNewNote(pid,wid){ const p=P(pid), w=WSP(p,wid); const it={id:uid(),kind:'note',name:'',text:'',checks:[],created:Date.now(),edited:Date.now(),rep:false}; wsItems(w).push(it); p.edited=Date.now(); commit(); wsOpenNote(pid,wid,it.id,true) }
function noteForm(it){ const f={ntitle:dn(it.name),ntext:dn(it.text)}; (it.checks||[]).forEach(c=>f['ck_'+c.id]=dn(c.text)); initForm(f); U.formFor=it.id }
function wsOpenNote(pid,wid,iid,fresh){ const {it}=itemOf({pid,wid,iid}); noteForm(it); push({s:'note',pid,wid,iid}); if(fresh){ setFocus('ntitle','text','ntext'); render() } }
function noteSync(){ const r=top(); if(!r||r.s!=='note') return; const {p,it}=itemOf(r); if(!it||U.formFor!==it.id) return; let ch=false;
  const set=(o,k,v)=>{ if(v===undefined) return; const nv=keepKey(o[k],v); if(nv!==o[k]){ o[k]=nv; ch=true } };
  set(it,'name',U.form.ntitle); set(it,'text',U.form.ntext); (it.checks||[]).forEach(c=>set(c,'text',U.form['ck_'+c.id]));
  if(ch){ it.edited=Date.now(); p.edited=Date.now(); clearTimeout(U.ntT); U.ntT=setTimeout(()=>{ commit() },700) } }
PAGES.note=(rt)=>{
  const {p,w,it}=itemOf(rt); if(!it) return PAGES.space(rt);
  if(U.formFor!==it.id&&!U.sheet) noteForm(it);
  const ck=it.checks||[], done=ck.filter(c=>c.done).length, rep=repOf(it);
  const rows=ck.map((c,i)=>`<div class="ck-row ${c.done?'done':''}"><button class="ck-box" data-a="ntToggle" data-id="${c.id}" aria-pressed="${c.done}" aria-label="${esc(t('nt.tick'))}">${ic(c.done?'boxok':'box')}</button>${field('ck_'+c.id,'',{ph:t('nt.itemPh'),next:ck[i+1]?'ck_'+ck[i+1].id:''})}<button class="ib" data-a="ntDel" data-id="${c.id}" aria-label="${esc(t('nt.del'))}">${ic('x','i s')}</button></div>`).join('');
  return `<section class="page ${U.anim||''}">${bar({backIcon:true,title:t('it.k.note'),sub:floorName(w),right:savedChip()+`<button class="ib" data-a="itemMenu" data-k="note" data-id="${it.id}" aria-label="menu">${ic('more')}</button>`})}<div class="scroll" data-scroll="note-${it.id}"><div class="pad form nt">
    ${field('ntitle',t('nt.title'),{ph:t('nt.titlePh'),next:'ntext'})}
    ${field('ntext',t('nt.text'),{area:true,ph:t('nt.textPh')})}
    <div class="fld"><span class="lab">${esc(t('nt.list'))}${ck.length?` <small>${esc(t('it.items',{d:done,n:ck.length}))}</small>`:''}</span><div class="ck-list">${rows}</div><button class="btn sec sm" data-a="ntAdd">${ic('plus','i s')}${esc(t('nt.add'))}</button></div>
    <button class="listrow sw-row" data-a="ntRep" aria-pressed="${rep}">${ic('doc')}<span class="tx"><b>${esc(t('it.report'))}</b></span><span class="switch ${rep?'on':''}"></span></button>
  </div></div></section>`;
};
const noteIt=()=>itemOf(top()).it;
/* leaving a note that was never filled in (no title, text or list items) removes it, so stray empty notes don't pile up */
{ const basePop=pop; pop=function(){ const r=top(); if(r&&r.s==='note'){ noteSync(); const {w,it}=itemOf(r), blank=v=>!String(dn(v)||'').trim();
    if(it&&blank(it.name)&&blank(it.text)&&!(it.checks||[]).some(c=>!blank(c.text))){ const a=wsItems(w), i=a.indexOf(it); if(i>=0){ a.splice(i,1); commit() } } }
  return basePop.apply(this,arguments) } }
A.ntAdd=()=>{ if(!guard()) return; noteSync(); const it=noteIt(); const c={id:uid(),text:'',done:false}; (it.checks||(it.checks=[])).push(c); U.form['ck_'+c.id]=''; it.edited=Date.now(); commit(); setFocus('ck_'+c.id,'text',''); render() };
A.ntToggle=d=>{ if(!guard()) return; noteSync(); const c=noteIt().checks.find(x=>x.id===d.id); c.done=!c.done; noteIt().edited=Date.now(); commit(); render() };
A.ntDel=d=>{ if(!guard()) return; noteSync(); const it=noteIt(); it.checks=it.checks.filter(x=>x.id!==d.id); delete U.form['ck_'+d.id]; if(U.focus&&U.focus.id==='ck_'+d.id) blur(); it.edited=Date.now(); commit(); render() };
A.ntRep=()=>{ const it=noteIt(); it.rep=!repOf(it); commit(); render() };
{ const tk=typeKey; typeKey=function(k){ if(k==='enter'&&U.focus&&/^ck_/.test(U.focus.id)&&!U.focus.next&&String(U.form[U.focus.id]||'').trim()){ A.ntAdd(); return } tk(k) } }

/* ============================== markup: free drawing + photo dimensions ============================== */
const MK_COL={ink:'#0E1C36',cobalt:'#1C4BD1',red:'#D92D20'};
const MK_TOOLS={drawing:['pen','line','text','eraser'],photo:['dim','arrow','text','pen','eraser']};
const MK_IC={pen:'pen',line:'line',dim:'dim',arrow:'arrow',text:'text',eraser:'eraser'};
const mkEls=it=>it.els||(it.els=[]);
const mkTool=it=>{ const ts=MK_TOOLS[it.kind]; const c=(U.mkTool||{})[it.kind]; return ts.includes(c)?c:ts[0] };
const mkColor=it=>(U.mkCol||{})[it.kind]||(it.kind==='photo'?'red':'ink');
const F_NUM='IBM Plex Sans Condensed,IBM Plex Sans,sans-serif';
const SAMPLE_PH={};
function samplePhoto(n){
  if(SAMPLE_PH[n]) return SAMPLE_PH[n];
  const scenes={
  1:`<defs><linearGradient id="w" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#EFE8DC"/><stop offset="1" stop-color="#D8CDBB"/></linearGradient><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#BFD9F2"/><stop offset="1" stop-color="#E8F2FB"/></linearGradient><linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#A57A50"/><stop offset="1" stop-color="#7E5A39"/></linearGradient></defs><rect width="1000" height="750" fill="url(#w)"/><rect y="610" width="1000" height="140" fill="url(#f)"/>${[0,1,2,3,4,5,6].map(i=>`<path d="M${i*160-40} 610l-60 140" stroke="#6E4E31" stroke-width="3" opacity=".5"/>`).join('')}<rect y="596" width="1000" height="16" fill="#F7F3EC"/><rect x="352" y="140" width="316" height="346" fill="#F9F9F7"/><rect x="368" y="156" width="284" height="314" fill="url(#g)"/><path d="M510 156v314M368 300h284" stroke="#F9F9F7" stroke-width="12"/><rect x="336" y="486" width="348" height="18" fill="#F2EEE7"/><rect x="380" y="512" width="260" height="70" rx="6" fill="#E9E6E0"/>${[0,1,2,3,4,5,6,7,8,9,10,11].map(i=>`<path d="M${394+i*21} 520v54" stroke="#CFCBC3" stroke-width="5"/>`).join('')}<rect x="150" y="520" width="44" height="44" rx="6" fill="#FBFAF7" stroke="#D2CABC"/><circle cx="164" cy="542" r="4" fill="#9C9384"/><circle cx="180" cy="542" r="4" fill="#9C9384"/><rect width="1000" height="750" fill="#000" opacity=".04"/>`,
  2:`<defs><pattern id="t" width="100" height="100" patternUnits="userSpaceOnUse"><rect width="100" height="100" fill="#EEF2F4"/><path d="M0 0H100V100" fill="none" stroke="#C9D2D8" stroke-width="4"/></pattern><linearGradient id="c" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9C5B2E"/><stop offset=".5" stop-color="#E0A06A"/><stop offset="1" stop-color="#8A4F27"/></linearGradient><linearGradient id="s" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8E959C"/><stop offset=".5" stop-color="#E4E8EB"/><stop offset="1" stop-color="#7D848B"/></linearGradient></defs><rect width="1000" height="750" fill="url(#t)"/><rect y="620" width="1000" height="130" fill="#59636B"/><path d="M0 620h1000" stroke="#3F474E" stroke-width="6"/><rect x="420" y="120" width="34" height="500" fill="url(#c)"/><rect x="540" y="200" width="34" height="420" fill="url(#s)"/><rect x="404" y="330" width="66" height="34" rx="5" fill="#C7343A"/><rect x="524" y="330" width="66" height="34" rx="5" fill="#2E6FC2"/><path d="M454 250h86" stroke="url(#c)" stroke-width="22"/><rect x="700" y="420" width="120" height="80" rx="8" fill="#FAFAFA" stroke="#C9D2D8" stroke-width="3"/><rect width="1000" height="750" fill="#000" opacity=".05"/>`,
  3:`<defs><linearGradient id="w" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#DADDE0"/><stop offset="1" stop-color="#C9CDD1"/></linearGradient><linearGradient id="d" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2F353C"/><stop offset="1" stop-color="#4A525B"/></linearGradient></defs><rect width="1000" height="750" fill="url(#w)"/><rect y="630" width="1000" height="120" fill="#8E8A82"/><rect x="330" y="110" width="320" height="520" fill="url(#d)"/><path d="M314 630V94h352v536" fill="none" stroke="#F4F2EE" stroke-width="32"/><rect x="700" y="330" width="40" height="64" rx="6" fill="#F6F5F2" stroke="#B9B6AE"/><rect x="712" y="344" width="16" height="28" rx="3" fill="#E1DED7"/><path d="M330 630l-60 120M650 630l60 120" stroke="#7A766F" stroke-width="3"/><rect width="1000" height="750" fill="#000" opacity=".04"/>`};
  return SAMPLE_PH[n]='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 750">${scenes[n]||scenes[1]}</svg>`);
}
const photoSrc=it=>String(it.src||'').startsWith('@sample:')?samplePhoto(Number(it.src.slice(8))):it.src;
const mkPath=pts=>pts.map((q,i)=>(i?'L':'M')+q[0].toFixed(1)+' '+q[1].toFixed(1)).join('');
function mkElSVG(e,l){
  const c=MK_COL[e.c||'ink'];
  if(e.t==='pen') return `<g data-el="${e.id}"><path d="${mkPath(e.pts.length>1?e.pts:[e.pts[0],[e.pts[0][0]+.1,e.pts[0][1]]])}" fill="none" stroke="${c}" stroke-width="${e.w===2?18:8}" stroke-linecap="round" stroke-linejoin="round"/></g>`;
  if(e.t==='text') return `<g data-el="${e.id}"><text data-lab="${e.id}" x="${e.pts[0][0]}" y="${e.pts[0][1]}" text-anchor="middle" dominant-baseline="middle" font-size="50" font-weight="600" fill="${c}" stroke="#fff" stroke-width="11" paint-order="stroke" stroke-linejoin="round">${esc(dn(e.txt,l))}</text></g>`;
  const [a,b]=e.pts, dx=b[0]-a[0], dy=b[1]-a[1], L=Math.hypot(dx,dy)||1, ux=dx/L, uy=dy/L, nx=-uy, ny=ux;
  if(e.t==='arrow'){ const s=34, hx=b[0]-ux*s, hy=b[1]-uy*s; return `<g data-el="${e.id}"><path d="M${a[0]} ${a[1]}L${hx.toFixed(1)} ${hy.toFixed(1)}" stroke="${c}" stroke-width="8" stroke-linecap="round"/><path d="M${b[0]} ${b[1]}L${(hx+nx*16).toFixed(1)} ${(hy+ny*16).toFixed(1)}L${(hx-nx*16).toFixed(1)} ${(hy-ny*16).toFixed(1)}Z" fill="${c}" stroke="${c}" stroke-width="4" stroke-linejoin="round"/></g>` }
  /* line (drawing) and dim (photo): a dimension line with end marks and a value pill */
  const tick=e.t==='dim'?[nx*20,ny*20]:[(ux+nx)*13,(uy+ny)*13];
  const ends=[a,b].map(q=>`M${(q[0]-tick[0]).toFixed(1)} ${(q[1]-tick[1]).toFixed(1)}L${(q[0]+tick[0]).toFixed(1)} ${(q[1]+tick[1]).toFixed(1)}`).join('');
  const has=e.v!=null, txt=has?fmtLen(e.v,l)+' '+M(l):'?', tw=has?txt.length*21+38:64, th=56;
  const off=e.t==='line'?42:0, mx=(a[0]+b[0])/2+nx*off*(ny>0?-1:1), my=(a[1]+b[1])/2+ny*off*(ny>0?-1:1);
  const halo=e.t==='dim'?`<path d="M${a[0]} ${a[1]}L${b[0]} ${b[1]}${ends}" stroke="#fff" stroke-width="13" stroke-linecap="round" opacity=".85"/>`:'';
  return `<g data-el="${e.id}">${halo}<path d="M${a[0]} ${a[1]}L${b[0]} ${b[1]}${ends}" stroke="${c}" stroke-width="${e.t==='dim'?7:9}" stroke-linecap="round"/><g data-lab="${e.id}" style="cursor:pointer"><rect x="${(mx-tw/2).toFixed(1)}" y="${(my-th/2).toFixed(1)}" width="${tw}" height="${th}" rx="28" fill="${has?'#fff':'#FFF1DF'}" stroke="${has?c:'#9A4D00'}" stroke-width="3" ${has?'':'stroke-dasharray="7 5"'}/><text x="${mx.toFixed(1)}" y="${(my+1).toFixed(1)}" text-anchor="middle" dominant-baseline="middle" font-family="${F_NUM}" font-size="36" font-weight="600" fill="${has?'#0E1C36':'#9A4D00'}">${esc(txt)}</text></g></g>`;
}
function mkBBox(it){
  let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9; mkEls(it).forEach(e=>e.pts.forEach(q=>{ x0=Math.min(x0,q[0]); y0=Math.min(y0,q[1]); x1=Math.max(x1,q[0]); y1=Math.max(y1,q[1]) }));
  if(x0>x1) return null; const pad=70; x0-=pad; y0-=pad; x1+=pad; y1+=pad; const w=Math.max(x1-x0,420), h=Math.max(y1-y0,315), cx=(x0+x1)/2, cy=(y0+y1)/2; return [cx-w/2,cy-h/2,w,h];
}
function mkSVG(it,o={}){
  const W=it.W||1000, H=it.H||(it.kind==='photo'?750:1300), l=o.l;
  let vb=[0,0,W,H];
  if(it.kind==='drawing'&&(o.thumb||o.report)){ const bb=mkBBox(it); if(bb) vb=bb }
  const bg=it.kind==='photo'?`<image href="${photoSrc(it)}" x="0" y="0" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice"/>`
    :`<rect x="${vb[0]}" y="${vb[1]}" width="${vb[2]}" height="${vb[3]}" fill="#fff"/>${o.thumb||o.report?'':`<defs><pattern id="mkdots" width="50" height="50" patternUnits="userSpaceOnUse"><circle cx="25" cy="25" r="2.2" fill="#C9D1DE"/></pattern></defs><rect width="${W}" height="${H}" fill="url(#mkdots)"/>`}`;
  return `<svg class="mk-svg" viewBox="${vb.map(v=>v.toFixed(1)).join(' ')}" preserveAspectRatio="xMidYMid meet" ${o.thumb?'aria-hidden="true"':`role="img" aria-label="${esc(dn(it.name,l))}"`}>${bg}<g class="mk-els">${mkEls(it).map(e=>mkElSVG(e,l)).join('')}</g></svg>`;
}

PAGES.draw=PAGES.photo=(rt)=>{
  const {p,w,it}=itemOf(rt); if(!it) return PAGES.space(rt);
  const ph=it.kind==='photo', tools=MK_TOOLS[it.kind], tool=mkTool(it), col=mkColor(it), h=(U.mkH||{})[it.id]||{u:[],r:[]};
  const opts=tool==='eraser'?`<span class="mk-hint">${esc(t('mk.h.eraser'))}</span>`:`${['ink','cobalt','red'].map(c=>`<button class="mk-sw ${col===c?'on':''}" style="--c:${MK_COL[c]}" data-a="mkColor" data-v="${c}" aria-pressed="${col===c}" aria-label="${esc(t('mk.c.'+c))}">${col===c?ic('check','i xs'):''}</button>`).join('')}${tool==='pen'?`<div class="seg">${[1,2].map(k=>`<button class="${(U.mkW||1)===k?'on':''}" data-a="mkWidth" data-v="${k}">${esc(t(k===1?'mk.thin':'mk.thick'))}</button>`).join('')}</div>`:''}<span class="mk-hint">${esc(t('mk.h.'+tool))}</span>`;
  const right=`<button class="ib" data-a="mkUndo" aria-label="undo" ${h.u.length?'':'disabled'}>${ic('undo')}</button><button class="ib" data-a="mkRedo" aria-label="redo" ${h.r.length?'':'disabled'}>${ic('redo')}</button><button class="ib" data-a="itemMenu" data-k="${it.kind}" data-id="${it.id}" aria-label="menu">${ic('more')}</button>`;
  return `<section class="page mk ${U.anim||''}">${bar({backIcon:true,title:dn(it.name),sub:floorName(w),right})}<div class="mk-stage ${ph?'ph':''}">${mkSVG(it)}</div>${ph?`<button class="mk-cap" data-a="mkCaption">${ic('edit','i s')}<span class="tx">${it.caption?esc(dn(it.caption)):`<span class="ph">${esc(t('mk.addCaption'))}</span>`}</span></button>`:''}<div class="mk-opts">${opts}</div><nav class="tools mk-tools">${tools.map(k=>`<button class="${tool===k?'on':''}" data-a="mkToolPick" data-v="${k}" aria-pressed="${tool===k}">${ic(MK_IC[k])}<span>${esc(t('mk.'+k))}</span></button>`).join('')}</nav></section>`;
};
const mkCur=()=>itemOf(top());
function mkHist(id){ U.mkH=U.mkH||{}; return U.mkH[id]||(U.mkH[id]={u:[],r:[]}) }
function mkSnap(it){ const h=mkHist(it.id); h.u.push(JSON.stringify(mkEls(it))); if(h.u.length>60) h.u.shift(); h.r=[] }
function mkSave(it){ const {p}=mkCur(); it.edited=Date.now(); if(p) p.edited=Date.now(); commit() }
A.mkToolPick=d=>{ const {it}=mkCur(); U.mkTool=U.mkTool||{}; U.mkTool[it.kind]=d.v; render() };
A.mkColor=d=>{ const {it}=mkCur(); U.mkCol=U.mkCol||{}; U.mkCol[it.kind]=d.v; render() };
A.mkWidth=d=>{ U.mkW=Number(d.v); render() };
A.mkUndo=()=>{ const {it}=mkCur(), h=mkHist(it.id); if(!h.u.length) return; h.r.push(JSON.stringify(mkEls(it))); it.els=JSON.parse(h.u.pop()); mkSave(it); render() };
A.mkRedo=()=>{ const {it}=mkCur(), h=mkHist(it.id); if(!h.r.length) return; h.u.push(JSON.stringify(mkEls(it))); it.els=JSON.parse(h.r.pop()); mkSave(it); render() };
function mkOpenDim(e){ initForm({mkv:e.v!=null?fmtLen(e.v,null,true):''}); U.mkRecv=null; U.mkLaser=e.src==='laser'?fmtLen(e.v,null,true):null; openSheet({type:'mkDim',eid:e.id}); if(S.demo.bt!=='connected'){ setFocus('mkv','num',''); render() } }
function mkOpenText(e,pt){ initForm({mkt:e?dn(e.txt):''}); openSheet({type:'mkText',eid:e?e.id:null,pt}); setFocus('mkt','text',''); render() }
SHEETS.mkDim=(sh)=>{
  const {it}=mkCur(), e=it&&mkEls(it).find(x=>x.id===sh.eid); if(!e) return '';
  const v=String(U.form.mkv||'').trim(), err=v?lenFieldErr('mkv',DIM_MAX.A):null;
  const laser=S.demo.bt!=='connected'?`<p class="note">${ic('btoff','i s')}<span>${esc(t('mk.noLaser'))}</span></p>`
    :U.mkRecv!=null?`<div class="mk-recv" role="status">${ic('laser','i s')}<span>${esc(t('mk.recv',{v:''}))}<b>${fmtLen(U.mkRecv,null,true)} ${esc(M())}</b></span><button class="btn pri sm" data-a="mkUseRecv">${esc(t('mk.use'))}</button></div>`
    :`<button class="btn sec full" data-a="mkLaser">${ic('laser','i s')}${esc(t('mk.laser'))} ${simtag()}</button>`;
  return sheetWrap(t('mk.dimT'),`${laser}${field('mkv',t('mk.value'),{num:true,suf:M(),err})}${it.kind==='photo'?`<p class="note">${ic('info','i s')}<span>${esc(t('mk.photoNote'))}</span></p>`:''}<button class="btn ghost" style="color:var(--err);justify-self:start" data-a="mkDelEl">${ic('trash','i s')}${esc(t('mk.delLine'))}</button>`,
    `<div class="btnrow"><button class="btn sec" data-a="closeSheet">${esc(t('mk.later'))}</button><button class="btn pri ${!v||err?'dis':''}" data-a="mkDimSave">${esc(t('common.save'))}</button></div>`);
};
SHEETS.mkText=(sh)=>sheetWrap(t('mk.textT'),`${field('mkt',t('mk.textT'),{ph:t('mk.textPh')})}${sh.eid?`<button class="btn ghost" style="color:var(--err);justify-self:start" data-a="mkDelEl">${ic('trash','i s')}${esc(t('mk.delText'))}</button>`:''}`,`<button class="btn pri full" data-a="mkTextSave">${esc(t('common.save'))}</button>`);
SHEETS.mkCaption=()=>sheetWrap(t('mk.caption'),field('mkc',t('mk.caption'),{ph:t('mk.captionPh')}),`<button class="btn pri full" data-a="mkCapSave">${esc(t('common.save'))}</button>`);
A.mkLaser=()=>{ const {it}=mkCur(), e=mkEls(it).find(x=>x.id===U.sheet.eid); const base=e&&e.v!=null?e.v:800+Math.round(Math.random()*3400); U.mkRecv=Math.max(50,base+Math.round((Math.random()-.5)*(e&&e.v!=null?6:40))); render() };
A.mkUseRecv=()=>{ U.form.mkv=fmtLen(U.mkRecv,null,true); U.mkLaser=U.form.mkv; U.mkRecv=null; render() };
A.mkDimSave=()=>{ const {it}=mkCur(), e=mkEls(it).find(x=>x.id===U.sheet.eid), r=lenErr(U.form.mkv,DIM_MAX.A); if(!e||r.err||r.mm==null){ U.submitTry=true; render(); return }
  mkSnap(it); e.v=r.mm; e.src=U.mkLaser&&U.mkLaser===String(U.form.mkv).trim()?'laser':'manual'; mkSave(it); closeSheet() };
A.mkDelEl=()=>{ const {it}=mkCur(); mkSnap(it); it.els=mkEls(it).filter(x=>x.id!==U.sheet.eid); mkSave(it); closeSheet() };
A.mkTextSave=()=>{ const {it}=mkCur(), sh=U.sheet, v=String(U.form.mkt||'').trim(), e=sh.eid&&mkEls(it).find(x=>x.id===sh.eid);
  if(e){ mkSnap(it); if(v) e.txt=keepKey(e.txt,v); else it.els=mkEls(it).filter(x=>x!==e) }
  else if(v){ mkSnap(it); mkEls(it).push({id:uid(),t:'text',pts:[sh.pt],txt:v,c:mkColor(it)}) }
  mkSave(it); closeSheet() };
A.mkCaption=()=>{ if(!guard()) return; const {it}=mkCur(); initForm({mkc:dn(it.caption)}); openSheet({type:'mkCaption'}); setFocus('mkc','text',''); render() };
A.mkCapSave=()=>{ const {it}=mkCur(); it.caption=keepKey(it.caption,String(U.form.mkc||'').trim()); mkSave(it); closeSheet() };

/* pointer drawing on the canvas: live DOM updates while the finger moves, one model update on release */
{ const NS='http://www.w3.org/2000/svg'; let g=null;
  const pt=(svg,e)=>{ const m=svg.getScreenCTM(); if(!m) return [0,0]; const q=new DOMPoint(e.clientX,e.clientY).matrixTransform(m.inverse()), vb=svg.viewBox.baseVal, cl=(v,lo,hi)=>Math.min(hi,Math.max(lo,v)); return [Math.round(cl(q.x,vb.x+4,vb.x+vb.width-4)*10)/10,Math.round(cl(q.y,vb.y+4,vb.y+vb.height-4)*10)/10] };
  const snap=(a,b)=>{ if(!S.settings.angleSnap) return b; const dx=b[0]-a[0], dy=b[1]-a[1], L=Math.hypot(dx,dy), ang=Math.atan2(dy,dx), st=Math.PI/4, k=Math.round(ang/st)*st; return Math.abs(ang-k)<0.14?[Math.round((a[0]+Math.cos(k)*L)*10)/10,Math.round((a[1]+Math.sin(k)*L)*10)/10]:b };
  const segD=(q,a,b)=>{ const dx=b[0]-a[0], dy=b[1]-a[1], L2=dx*dx+dy*dy; let s=L2?((q[0]-a[0])*dx+(q[1]-a[1])*dy)/L2:0; s=Math.max(0,Math.min(1,s)); return Math.hypot(q[0]-a[0]-s*dx,q[1]-a[1]-s*dy) };
  const near=(e,q)=>{ if(e.t==='text') return Math.hypot(q[0]-e.pts[0][0],q[1]-e.pts[0][1])<70; const ps=e.pts.length>1?e.pts:[e.pts[0],e.pts[0]]; for(let i=1;i<ps.length;i++) if(segD(q,ps[i-1],ps[i])<26) return true; return false };
  appEl.addEventListener('pointerdown',e=>{
    const svg=e.target.closest&&e.target.closest('.mk-stage .mk-svg'); if(!svg||U.sheet) return;
    const rt=top(); if(rt.s!=='draw'&&rt.s!=='photo') return; const {it}=itemOf(rt); if(!it) return;
    e.preventDefault(); if(isLocked()){ openSheet({type:'locked'}); return }
    const tool=mkTool(it), p0=pt(svg,e), lab=e.target.closest('[data-lab]'), layer=svg.querySelector('.mk-els'), c=MK_COL[mkColor(it)];
    if(lab&&tool!=='eraser'&&tool!=='pen'){ g={mode:'lab',id:lab.dataset.lab,x:e.clientX,y:e.clientY}; return }
    try{ svg.setPointerCapture(e.pointerId) }catch(_){}
    if(tool==='pen'){ const n=document.createElementNS(NS,'path'); n.setAttribute('fill','none'); n.setAttribute('stroke',c); n.setAttribute('stroke-width',(U.mkW||1)===2?18:8); n.setAttribute('stroke-linecap','round'); n.setAttribute('stroke-linejoin','round'); n.setAttribute('d',mkPath([p0,[p0[0]+.1,p0[1]]])); layer.appendChild(n); g={mode:'pen',svg,it,n,pts:[p0]} }
    else if(tool==='line'||tool==='dim'||tool==='arrow'){ const n=document.createElementNS(NS,'path'); n.setAttribute('stroke',c); n.setAttribute('stroke-width',7); n.setAttribute('stroke-linecap','round'); n.setAttribute('stroke-dasharray','14 10'); layer.appendChild(n); g={mode:'line',svg,it,n,tool,a:p0,b:p0} }
    else if(tool==='text') g={mode:'text',it,p:p0,x:e.clientX,y:e.clientY};
    else if(tool==='eraser'){ g={mode:'erase',svg,it,hit:new Set(),last:p0}; erase(p0) }
  });
  function erase(q){ mkEls(g.it).forEach(x=>{ if(!g.hit.has(x.id)&&near(x,q)){ g.hit.add(x.id); const n=g.svg.querySelector(`[data-el="${x.id}"]`); if(n) n.style.opacity=.15 } }) }
  appEl.addEventListener('pointermove',e=>{ if(!g||!g.svg) return; const q=pt(g.svg,e);
    if(g.mode==='pen'){ const l=g.pts[g.pts.length-1]; if(Math.hypot(q[0]-l[0],q[1]-l[1])>4){ g.pts.push(q); g.n.setAttribute('d',mkPath(g.pts)) } }
    else if(g.mode==='line'){ g.b=snap(g.a,q); g.n.setAttribute('d',`M${g.a[0]} ${g.a[1]}L${g.b[0]} ${g.b[1]}`) }
    else if(g.mode==='erase'){ const l=g.last, n=Math.max(1,Math.ceil(Math.hypot(q[0]-l[0],q[1]-l[1])/12)); for(let i=1;i<=n;i++) erase([l[0]+(q[0]-l[0])*i/n,l[1]+(q[1]-l[1])*i/n]); g.last=q } });
  const end=e=>{ if(!g) return; const s=g; g=null; const it=s.it;
    if(e.type==='pointercancel'){ render(); return }
    if(s.mode==='lab'){ if(Math.hypot(e.clientX-s.x,e.clientY-s.y)<12){ const {it:cur}=mkCur(), el=mkEls(cur).find(x=>x.id===s.id); if(el) el.t==='text'?mkOpenText(el):mkOpenDim(el) } return }
    if(s.mode==='pen'){ mkSnap(it); mkEls(it).push({id:uid(),t:'pen',pts:s.pts,c:mkColor(it),w:U.mkW||1}); mkSave(it); render(); return }
    if(s.mode==='line'){ if(Math.hypot(s.b[0]-s.a[0],s.b[1]-s.a[1])<30){ render(); return } mkSnap(it); const el={id:uid(),t:s.tool,pts:[s.a,s.b],c:mkColor(it)}; if(s.tool!=='arrow') el.v=null; mkEls(it).push(el); mkSave(it); render(); if(s.tool!=='arrow') mkOpenDim(el); return }
    if(s.mode==='text'){ if(Math.hypot(e.clientX-s.x,e.clientY-s.y)<12) mkOpenText(null,s.p); return }
    if(s.mode==='erase'){ if(s.hit.size){ mkSnap(it); it.els=mkEls(it).filter(x=>!s.hit.has(x.id)); mkSave(it) } render() } };
  appEl.addEventListener('pointerup',end); appEl.addEventListener('pointercancel',end); }

/* ---------- report: drawings/photos/notes chosen per item ---------- */
{ const so=snapshotOf; snapshotOf=function(p){ const sn=so(p); sn.extras=[];
  p.floors.forEach(w=>wsItems(w).filter(repOf).slice().sort((a,b)=>a.created-b.created).forEach(it=>{ if(it.kind!=='note'&&!mkEls(it).length&&it.kind==='drawing') return; const c=clone(it); c.ws=floorName(w,p.report.lang); if(c.kind==='photo') c.src=photoSrc(it); sn.extras.push(c) }));
  return sn } }
function extraPages(sn,head,l){
  const ex=sn.extras||[], pages=[], figs=ex.filter(x=>x.kind!=='note'), notes=ex.filter(x=>x.kind==='note');
  for(let i=0;i<figs.length;i+=2){ const two=figs.slice(i,i+2);
    pages.push(head()+`<h2>${esc(t('r.extras',null,l))}</h2>`+two.map(x=>`<figure class="rx"><div class="rx-img">${mkSVG(x,{report:true,l})}</div><figcaption><b>${esc(dn(x.name,l))}</b>, ${esc(x.ws)}${x.caption?`. ${esc(dn(x.caption,l))}`:''}</figcaption></figure>`).join('')+(two.some(x=>x.kind==='photo')?`<p class="fn">${esc(t('r.photoNote',null,l))}</p>`:'')) }
  if(notes.length) pages.push(head()+`<h2>${esc(t('r.notesH',null,l))}</h2>`+notes.map(n=>`<div class="rnote"><b>${esc(dn(n.name,l)||t('it.untitled',null,l))}</b> <span>${esc(n.ws)}</span>${n.text?`<p>${esc(dn(n.text,l))}</p>`:''}${(n.checks||[]).length?`<ul>${n.checks.map(c=>`<li>${c.done?'☑':'☐'} ${esc(dn(c.text,l))}</li>`).join('')}</ul>`:''}</div>`).join(''));
  return pages;
}
{ const pr=PAGES.report; PAGES.report=rt=>{ const html=pr(rt), p=P(rt.pid); if(!p) return html;
  const its=p.floors.flatMap(w=>wsItems(w).map(it=>({it,w})));
  const fld=`<div class="fld"><span class="lab">${esc(t('rpt.extras'))}</span>${its.length?`<div class="choice">${its.map(({it,w})=>{ const on=repOf(it); return `<button class="opt ${on?'on':''}" data-a="repItem" data-w="${w.id}" data-id="${it.id}">${ic(on?'check':'plus','i xs')}${ic(KIND_IC[it.kind],'i xs')}${esc(it.kind==='note'?(dn(it.name)||t('it.untitled')):dn(it.name))}</button>` }).join('')}</div>`:`<div class="fhint">${esc(t('rpt.noExtras'))}</div>`}</div>`;
  const mark=`<div class="fld"><span class="lab">${esc(t('rpt.views'))}</span>`; return html.includes(mark)?html.replace(mark,fld+mark):html } }
A.repItem=d=>{ const p=P(top().pid), w=WSP(p,d.w), it=w&&wsItems(w).find(x=>x.id===d.id); if(!it) return; it.rep=!repOf(it); commit(); render() };

/* ---------- sample content for the demo jumps ---------- */
{ const sp=sampleProject; sampleProject=function(level){ const p=sp(level); const w=p.floors[0]; if(w){ w.type='floor'; w.items=[]; if(level>=1){ const now=Date.now();
  w.items.push({id:uid(),kind:'note',name:'@smp.noteT',text:'@smp.noteX',checks:[{id:uid(),text:'@smp.ck1',done:true},{id:uid(),text:'@smp.ck2',done:false},{id:uid(),text:'@smp.ck3',done:false}],created:now-86400e3*2,edited:now-86400e3*2,rep:false});
  w.items.push({id:uid(),kind:'photo',name:'@ph.s1',src:'@sample:1',W:1000,H:750,caption:'',created:now-86400e3,edited:now-86400e3,els:[{id:uid(),t:'dim',pts:[[352,112],[668,112]],v:1200,src:'laser',c:'red'},{id:uid(),t:'dim',pts:[[700,140],[700,486]],v:1500,src:'laser',c:'red'},{id:uid(),t:'arrow',pts:[[250,640],[358,486]],c:'red'},{id:uid(),t:'text',pts:[[250,690]],txt:'@smp.phLab',c:'red'}]}) } }
  p.rooms.forEach(r=>r.created=r.created||Date.now()-3600e3); return p } }

/* ---------- render hook: note text follows the keyboard; the Android status bar stays light (the sign-in screens are white now) ---------- */
{ const base=render; render=function(){ noteSync(); base(); if(window.MetrxNative&&U.darkTop!==false){ U.darkTop=false; try{ MetrxNative.setDarkTop(false) }catch(e){} } } }
{ const ini=initForm; initForm=function(v){ U.formFor=null; ini(v) } }
