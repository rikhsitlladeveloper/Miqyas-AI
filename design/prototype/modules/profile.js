/* ============================== Profile (option A): status first, short groups ==============================
   Name and phone (they appear on every quote), then three status tiles: Laser, Backup, Subscription. A problem
   turns amber and opens its fix. Two short groups hold the settings builders change; the rest is in "More settings". */
Object.assign(D,{
'pf.onQuote':['Har bir taklifda shu ism va telefon chiqadi','Это имя и телефон будут в каждом КП','This name and phone appear on every quote'],
'pf.laser':['Lazer','Лазер','Laser'],
'pf.backup':['Zaxira','Резерв','Backup'],
'pf.sub':['Obuna','Подписка','Subscription'],
'pf.btOn':['Ulangan','Подключён','Connected'],
'pf.btDisc':['Ulanmagan','Не подключён','Not connected'],
'pf.btOff':['Bluetooth o‘chiq','Bluetooth выкл.','Bluetooth off'],
'pf.btDenied':['Ruxsat yo‘q','Нет доступа','No access'],
'pf.bkNever':['Hali yo‘q','Ещё нет','Not yet'],
'pf.bkDays':['{n} kun oldin','{n} {n:день|дня|дней} назад','{n} {n:day|days} ago'],
'pf.bkToday':['Bugun','Сегодня','Today'],
'pf.bkNone':['Loyiha yo‘q','Нет проектов','No projects'],
'pf.subOn':['Faol','Активна','Active'],
'pf.subOff':['Tugagan','Истекла','Expired'],
'pf.gReport':['Til va hisobot','Язык и отчёт','Language and report'],
'pf.gMeasure':['O‘lchash va chizma','Замер и чертёж','Measuring and drawing'],
'pf.more':['Boshqa sozlamalar','Другие настройки','More settings'],
'pf.snapOn':['Yoqilgan','Вкл.','On'],
'pf.snapOff':['O‘chiq','Выкл.','Off']
});
function pfRow(a,icn,label,val,cls){ return `<button class="listrow" data-a="${a}">${ic(icn)}<span class="tx"><b>${esc(label)}</b></span><span class="val ${cls||''}">${esc(val||'')}</span>${ic('chev','i s')}</button>` }
function pfTiles(){
  const bt=S.demo.bt, lb=S.settings.lastBackup, np=S.projects.length;
  const days=lb?Math.floor((Date.now()-lb)/864e5):null, bkWarn=np>0&&(lb==null||days>=7);
  const bkVal=!np&&!lb?t('pf.bkNone'):lb==null?t('pf.bkNever'):days<1?t('pf.bkToday'):t('pf.bkDays',{n:days});
  const tile=(a,icn,lab,val,st)=>`<button class="pf-st ${st}" data-a="${a}">${ic(st==='warn'?'alert':icn,'i s')}<span>${esc(lab)}</span><b>${esc(val)}</b></button>`;
  return `<div class="pf-tiles">${tile('device','bt',t('pf.laser'),t(bt==='connected'?'pf.btOn':bt==='off'?'pf.btOff':bt==='denied'?'pf.btDenied':'pf.btDisc'),bt==='connected'?'ok':'warn')}${tile('goBackup','save',t('pf.backup'),bkVal,bkWarn?'warn':lb?'ok':'')}${tile('goSub','card',t('pf.sub'),t(isLocked()?'pf.subOff':'pf.subOn'),isLocked()?'warn':'')}</div>`;
}
PAGES.profile=()=>{
  const b=S.settings.builder; const ini=(b.name||'?').split(/\s+/).map(x=>x[0]||'').join('').slice(0,2).toUpperCase();
  const pdfN=Object.values(S.settings.pdf).filter(Boolean).length;
  return `<section class="page ${U.anim||''}">${bar({right:savedChip()})}<div class="h1">${esc(t('tab.profile'))}</div>${banners()}<div class="scroll" data-scroll="profile"><div class="pf">
    <div class="pf-me"><button class="pf-who" data-a="goBuilder"><span class="avatar">${esc(ini)}</span><span class="tx"><b>${esc(b.name||t('prof.noName'))}</b><small>${esc(b.phone?fmtPhone(b.phone):t('se.notSet'))}</small></span><span class="ib" aria-hidden="true">${ic('edit','i s')}</span></button><p class="pf-cap">${ic('doc','i s')}<span>${esc(t('pf.onQuote'))}</span></p></div>
    ${pfTiles()}
    <div class="grouph">${esc(t('pf.gReport'))}</div><div class="lgroup">
    ${pfRow('langSheet','globe',t('se.lang'),LNAME[S.lang])}
    ${pfRow('repLangSheet','doc',t('se.reportLang'),LNAME[S.settings.reportLang])}
    ${pfRow('pdfSheet','layers',t('se.pdf'),pdfN+'/5')}
    ${pfRow('currencySheet','coin',t('np.currency'),S.settings.currency)}
    </div><div class="grouph">${esc(t('pf.gMeasure'))}</div><div class="lgroup">
    ${pfRow('defaultsSheet','door',t('se.defaults'),fmtLen(S.settings.defaults.door.w)+' × '+fmtLen(S.settings.defaults.door.h))}
    <button class="listrow" data-a="toggleSnap" aria-pressed="${!!S.settings.angleSnap}">${ic('ruler')}<span class="tx"><b>${esc(t('se.snap'))}</b></span><span class="switch ${S.settings.angleSnap?'on':''}"></span></button>
    </div>${accountGroup()}
    <button class="pf-more" data-a="pfMore">${ic('sliders','i s')}<span>${esc(t('pf.more'))}</span>${ic('chev','i s')}</button>
    <p class="note pf-local">${ic('device','i s')}<span>${esc(t('prof.local'))}</span></p>
  </div></div></section>`;
};
PAGES.settingsMore=()=>`<section class="page ${U.anim||''}">${bar({backIcon:true,title:t('pf.more')})}<div class="scroll" data-scroll="pfm"><div class="pf" style="padding-top:8px"><div class="lgroup">
  ${pfRow('unitsSheet','ruler',t('se.units'),t('un.'+UNIT()))}
  ${pfRow('roomLabelSheet','room',t('se.label'),t('se.label.'+(S.settings.roomLabel||'both')))}
  ${pfRow('hintsReset','info',t('se.hintsReset'),'')}
  </div><div class="lgroup">
  ${pfRow('device','bt',t('se.device'),t(S.demo.bt==='connected'?'dev.conn':S.demo.bt==='off'?'dev.off':S.demo.bt==='denied'?'dev.denied':'dev.disc'))}
  ${pfRow('goBackup','save',t('se.backup'),S.settings.lastBackup?fmtDate(S.settings.lastBackup):'')}
  ${pfRow('goSub','card',t('se.sub'),t(isLocked()?'se.expired':'se.active'))}
  </div><div class="lgroup">${pfRow('aboutSheet','info',t('se.about'),'')}</div></div></div></section>`;
A.pfMore=()=>push({s:'settingsMore'});
