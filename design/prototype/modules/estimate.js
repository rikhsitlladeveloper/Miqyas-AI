/* ============================== Estimate (option A): BOM table ==============================
   Name | Qty | Price | Sum, like a paper bill of materials. A missing quantity, price or labour amount shows
   in amber ("?") and is counted in a warning above the table. A zero price is legitimate and is not flagged.
   Rows open the existing row sheet; every quantity stays typed by the builder. */
Object.assign(D,{
'et.miss':['{n} ta qatorda miqdor yoki narx yo‘q','Не заполнено строк: {n} (количество или цена)','{n} {n:row is|rows are} missing a quantity or price'],
'et.qty':['Miqdor','Кол-во','Qty'],
'et.price':['Narx','Цена','Price'],
'et.sum':['Summa','Сумма','Sum'],
'et.addRow':['Qator qo‘shish','Добавить строку','Add row'],
'et.later':['Miqdor yoki narxni keyin kiritish mumkin. Taklif chiqarishdan oldin to‘ldiring.','Количество или цену можно ввести позже. Заполните до выпуска предложения.','You can add the quantity or price later. Fill them in before issuing a quote.'],
'et.block':['Taklif chiqarishdan oldin smetadagi {n} ta qatorni to‘ldiring','Перед выпуском предложения заполните строки сметы: {n}','Fill in {n} estimate {n:row|rows} before issuing a quote']
});
estimateTab=function(p,tt){
  const blank=v=>String(v??'').trim()==='';
  const last=p.quotes[p.quotes.length-1]; let ban='';
  if(last){ const same=fingerprint(snapshotOf(p))===last.fp; ban=`<div class="banner ${same?'':'warn'}">${ic(same?'check':'info','i s')}<span class="tx">${esc(t(same?'es.same':'es.changed',{n:last.no}))}</span></div>` }
  const mats=p.estimate.materials, labs=p.estimate.labor;
  const missing=mats.filter(m=>blank(m.qty)||blank(m.price)).length+labs.filter(l=>blank(l.amount)).length;
  const lk=isLocked();
  const num=(v,txt)=>blank(v)?'<span class="miss">?</span>':`<span>${txt}</span>`;
  const mRows=mats.map(m=>{ const bad=blank(m.qty)||blank(m.price);
    return `<button class="et-r" data-a="editRow" data-k="mat" data-id="${m.id}"><span class="nm">${esc(dn(m.name)||'—')}<small>${esc(dn(m.unit)||'')}</small></span>${num(m.qty,fmtNumStr(m.qty))}${num(m.price,money(parseDec(m.price,p.precision).val||0n,p))}${bad?'<span class="miss">—</span>':`<span class="sum">${money(lineTotal(m.qty,m.price,p.precision),p)}</span>`}</button>` }).join('')||`<div class="et-empty">${esc(t('es.emptyMat'))}</div>`;
  const lRows=labs.map(l=>`<button class="et-r lab" data-a="editRow" data-k="lab" data-id="${l.id}"><span class="nm">${esc(dn(l.name)||'—')}<small>${esc(t('es.lump'))}</small></span>${blank(l.amount)?'<span class="miss">?</span>':`<span class="sum">${money(parseDec(l.amount,p.precision).val||0n,p)}</span>`}</button>`).join('')||`<div class="et-empty">${esc(t('es.emptyLab'))}</div>`;
  const add=k=>`<button class="et-add" data-a="addRow" data-k="${k}">${ic(lk?'lock':'plus','i s')}${esc(t('et.addRow'))}</button>`;
  const pstr=p.precision?t('es.pN',{n:p.precision}):t('es.p0');
  return `<div class="et">
    <div class="et-meta"><span>${esc(t('es.cur',{c:p.currency,p:pstr}))}</span><button data-a="areas">${esc(t('es.areas'))}</button></div>
    ${ban}${missing?`<div class="et-miss" role="status">${ic('alert','i s')}<span>${esc(t('et.miss',{n:missing}))}</span></div>`:''}
    <div class="et-tbl"><div class="et-h"><b>${esc(t('es.mat'))}</b><span>${esc(t('et.qty'))}</span><span>${esc(t('et.price'))}</span><span>${esc(t('et.sum'))}</span></div>${mRows}${add('mat')}<div class="et-sub"><span>${esc(t('es.matTot'))}</span><span>${money(tt.m,p)}</span></div></div>
    <div class="et-tbl"><div class="et-h lab"><b>${esc(t('es.lab'))}</b><span>${esc(t('et.sum'))}</span></div>${lRows}${add('lab')}<div class="et-sub"><span>${esc(t('es.labTot'))}</span><span>${money(tt.l,p)}</span></div></div>
    <p class="note">${ic('info','i s')}<span>${esc(t('es.note'))}</span></p></div>`;
};
/* a quote can't be issued while estimate rows are missing a quantity, price or amount */
function etMissing(p){ const blank=v=>String(v??'').trim()===''; return p.estimate.materials.filter(m=>blank(m.qty)||blank(m.price)).length+p.estimate.labor.filter(l=>blank(l.amount)).length }
{ const base=A.issue; A.issue=d=>{ const rt=top(), p=P(rt.pid||rt.id); const n=p?etMissing(p):0; if(n){ toast(t('et.block',{n})); render(); return } base(d) } }
