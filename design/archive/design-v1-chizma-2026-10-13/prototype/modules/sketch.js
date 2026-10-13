/* ============================== sketch module: polygon rooms (shape:'poly') ============================== */
/* Room model: a normal room plus shape:'poly' and poly:{verts:[{x,y}] (mm, sketch proportions, clockwise, y down), diags:[{id,a,b}], template}.
   Wall lengths live in r.dims[wallId] (A,B,C,D,E,F,G,J,… skipping H/I/O/T/X), check measurements in r.dims['X1'…].
   Directions come from the sketch (snapped to 45° when S.settings.angleSnap). Computed lengths are never written to r.dims. */
Object.assign(D,{
'sk.title':['Xona chizmasi','Эскиз помещения','Room sketch'],
'sk.draw':['Chizish','Рисовать','Draw'],
'sk.tap':['Burchaklar','По углам','Tap corners'],
'sk.snap':['90°/45°','90°/45°','90°/45°'],
'sk.snapOn':['Burchaklar 90° va 45° ga tekislanadi','Углы выравниваются по 90° и 45°','Angles snap to 90° and 45°'],
'sk.snapOff':['Burchaklar chizmadagidek qoladi','Углы остаются как на эскизе','Angles stay as sketched'],
'sk.drawHint':['Xona chegarasini bitta chiziq bilan chizing','Обведите помещение одной линией','Draw the room outline in one stroke'],
'sk.tapHint':['Burchaklarni ketma-ket bosing, so‘ng birinchisini bosib yoping','Нажимайте углы по порядку, затем первый, чтобы замкнуть','Tap each corner in order, then the first one to close'],
'sk.demo':['Namuna chiziq','Пример линии','Sample stroke'],
'sk.redraw':['Qayta chizish','Перерисовать','Redraw'],
'sk.close':['Xonani yopish','Замкнуть','Close room'],
'sk.undoTap':['Oxirgi burchakni olib tashlash','Убрать последний угол','Remove last corner'],
'sk.open':['Chizma yopilmagan. Uchlarini ulang yoki «Xonani yopish» ni bosing.','Контур не замкнут. Соедините концы или нажмите «Замкнуть».','The outline isn’t closed. Join the ends or tap Close room.'],
'sk.cross':['Devorlar bir-birini kesib o‘tmoqda. Chiziq o‘zini kesmasin, qayta chizing.','Стены пересекаются. Перерисуйте так, чтобы линия не пересекала себя.','Walls cross each other. Redraw so the line doesn’t cross itself.'],
'sk.short':['Chiziq juda qisqa. Butun xonani aylantirib chizing.','Линия слишком короткая. Обведите всё помещение.','Too short. Draw around the whole room.'],
'sk.many':['Burchaklar juda ko‘p (ko‘pi bilan 20). Devorlarni tekisroq chizing.','Слишком много углов (не больше 20). Рисуйте стены ровнее.','Too many corners (20 at most). Draw straighter walls.'],
'sk.few':['Kamida 3 ta devor kerak.','Нужно минимум 3 стены.','At least 3 walls are needed.'],
'sk.ready':['{n} ta devor. Keyin har birini o‘lchaysiz.','Стен: {n}. Дальше измерьте каждую.','{n} walls. Next you measure each one.'],
'sk.walls':['{n} ta devor','{n} {n:стена|стены|стен}','{n} walls'],
'sk.created':['“{n}” yaratildi. Devorlarni o‘lchang.','«{n}» создано. Измерьте стены.','“{n}” created. Measure the walls.'],
'sk.edit':['Shaklni tahrirlash','Изменить форму','Edit shape'],
'sk.check':['Tekshiruv o‘lchami','Контрольный замер','Check size'],
'sk.editHint':['Burchakni suring. O‘lchangan qiymatlar o‘zgarmaydi.','Перетащите угол. Измеренные размеры не меняются.','Drag a corner. Measured sizes stay as they are.'],
'sk.pick1':['Birinchi burchakni bosing','Нажмите первый угол','Tap the first corner'],
'sk.pick2':['Ikkinchi burchakni bosing. Mavjud tekshiruvni olib tashlash uchun uni bosing.','Нажмите второй угол. Нажатие на контрольный замер удалит его.','Tap the second corner. Tap an existing check to remove it.'],
'sk.corner':['{n}-burchak','Угол {n}','Corner {n}'],
'sk.diagAdj':['Bu ikki burchak bitta devorda. Qarama-qarshi burchakni tanlang.','Эти углы на одной стене. Выберите противоположный угол.','These corners share a wall. Pick a corner across the room.'],
'sk.diagDup':['Bu tekshiruv allaqachon bor.','Такой контрольный замер уже есть.','That check already exists.'],
'sk.diagAdded':['{d}: {a}- va {b}-burchak orasini o‘lchang','{d}: измерьте от угла {a} до угла {b}','{d}: measure from corner {a} to corner {b}'],
'sk.diagDel':['{d} olib tashlandi','{d} удалён','{d} removed'],
'sk.diagName':['{d} diagonal','Диагональ {d}','Diagonal {d}'],
'sk.diagWarn':['{d} rejadan {e} m farq qiladi. Burchak 90° bo‘lmasligi mumkin. Tekshiring yoki qayta o‘lchang.','{d} отличается от плана на {e} м. Угол может быть не 90°. Проверьте или перемерьте.','{d} is {e} m off the plan. A corner may not be 90°. Check it or measure again.'],
'sk.conflict':['{w} devorlar mos kelmayapti, farq {e} m. Birini tekshiring yoki qayta o‘lchang.','Стены {w} не сходятся, разница {e} м. Проверьте или перемерьте одну из них.','Walls {w} don’t add up, off by {e} m. Check or re-measure one of them.'],
'sk.negative':['Bu o‘lchamlarda {w} devor 0 dan kichik chiqadi. O‘lchamlarni yoki chizmani tekshiring.','С такими размерами стена {w} получается меньше 0. Проверьте размеры или эскиз.','With these sizes wall {w} comes out below 0. Check the sizes or the sketch.'],
'sk.crossSol':['Bu o‘lchamlarda devorlar kesishadi. O‘lchamlarni yoki chizmani tekshiring.','С такими размерами стены пересекаются. Проверьте размеры или эскиз.','With these sizes the walls cross. Check the sizes or the sketch.'],
'sk.needEither':['Shaklni aniqlash uchun {a} yoki {b} ni o‘lchang','Чтобы задать форму, измерьте {a} или {b}','Measure {a} or {b} to fix the shape'],
'sk.needN':['Shakl uchun yana {n} ta devorni o‘lchang: {w}','Для формы измерьте ещё {n} {n:стену|стены|стен}: {w}','Measure {n} more {n:wall|walls} to fix the shape: {w}'],
'sk.needSome':['Shakl uchun {w} dan {n} tasini o‘lchang','Для формы измерьте {n} из: {w}','Measure {n} of {w} to fix the shape'],
'sk.computed':['{w}: boshqa devorlardan hisoblandi','{w}: рассчитано по другим стенам','{w}: computed from the other walls'],
'sk.computedTap':['{w} hisoblangan: {v} m. O‘lchasangiz, tekshiruv bo‘ladi.','{w} рассчитана: {v} м. Замер станет проверкой.','{w} is computed: {v} m. Measuring it adds a check.'],
'sk.calc':['hisoblangan','рассчитано','computed'],
'sk.st.bad':['mos kelmaydi','не сходится','doesn’t add up'],
'sk.st.unres':['aniqlanmagan','не определено','unresolved'],
'sk.legC':['hisoblangan','рассчитано','computed'],
'sk.legX':['mos kelmaydi','не сходится','doesn’t add up'],
'sk.legU':['aniqlanmagan','не определено','unresolved'],
'sk.crossDrag':['Devorlar kesishib qoldi. Burchak joyiga qaytarildi.','Стены пересеклись. Угол возвращён на место.','Walls would cross. The corner went back.'],
'sk.need3d':['3D uchun shakl aniqlangan va balandlik tasdiqlangan bo‘lsin.','Для 3D нужна определённая форма и подтверждённая высота.','3D needs a resolved shape and a confirmed height.'],
'sk.soon':['Tez orada','Скоро','Coming soon'],
});

/*SK-PURE-START*/
const SK_TOL=20;                       // mm: closure / diagonal tolerance
const SK_LETTERS='ABCDEFGJKLMNPQRSUVWYZ'; // skips H, I, O, T, X (height, thickness, diagonals, look-alikes)
function skWallIds(n){ return SK_LETTERS.slice(0,n).split('') }
function skSnapAng(a){ const q=Math.PI/4; return Math.round(a/q)*q }
function skNormAng(a){ while(a<=-Math.PI) a+=2*Math.PI; while(a>Math.PI) a-=2*Math.PI; return a }
function skUnit(a){ const c=Math.cos(a),s=Math.sin(a); return [Math.abs(c)<1e-12?0:c,Math.abs(s)<1e-12?0:s] }
function skDirs(V,snap){ const n=V.length; return V.map((p,i)=>{ const q=V[(i+1)%n]; const a=Math.atan2(q[1]-p[1],q[0]-p[0]); return snap?skSnapAng(a):a }) }
function skBuildVerts(dirs,len,start){ const out=[[start[0],start[1]]]; for(let i=0;i<dirs.length-1;i++){ const u=skUnit(dirs[i]),p=out[i]; out.push([p[0]+u[0]*len[i],p[1]+u[1]*len[i]]) } return out }
function skArea(V){ let a=0; for(let i=0;i<V.length;i++){ const p=V[i],q=V[(i+1)%V.length]; a+=p[0]*q[1]-q[0]*p[1] } return a/2 }
function skCentroid(V){ let a=0,cx=0,cy=0; V.forEach((p,i)=>{ const q=V[(i+1)%V.length]; const c=p[0]*q[1]-q[0]*p[1]; a+=c; cx+=(p[0]+q[0])*c; cy+=(p[1]+q[1])*c });
  if(Math.abs(a)<1e-9){ const n=V.length; return [V.reduce((s,p)=>s+p[0],0)/n,V.reduce((s,p)=>s+p[1],0)/n] } return [cx/(3*a),cy/(3*a)] }
function skInside(V,p){ let c=false; for(let i=0,j=V.length-1;i<V.length;j=i++){ const a=V[i],b=V[j]; if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]) c=!c } return c }
function skLabelPt(V){ const c=skCentroid(V); if(skInside(V,c)) return c; const y=c[1], xs=[];
  V.forEach((a,i)=>{ const b=V[(i+1)%V.length]; if((a[1]>y)!==(b[1]>y)) xs.push(a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1])) }); xs.sort((p,q)=>p-q);
  let best=null,bw=-1; for(let i=0;i+1<xs.length;i+=2){ if(xs[i+1]-xs[i]>bw){ bw=xs[i+1]-xs[i]; best=[(xs[i]+xs[i+1])/2,y] } } return best||V[0].slice() }
/* intersection point of segments ab and cd (touching counts), or null */
function skSegX(a,b,c,d){
  const r=[b[0]-a[0],b[1]-a[1]], s=[d[0]-c[0],d[1]-c[1]], den=r[0]*s[1]-r[1]*s[0], rr=r[0]*r[0]+r[1]*r[1];
  if(Math.abs(den)<1e-9*Math.max(1,rr)){
    const cr=(c[0]-a[0])*r[1]-(c[1]-a[1])*r[0]; if(rr<1e-12||Math.abs(cr)>1e-6*Math.sqrt(rr)*Math.max(1,Math.sqrt(rr))) return null;
    const t0=((c[0]-a[0])*r[0]+(c[1]-a[1])*r[1])/rr, t1=((d[0]-a[0])*r[0]+(d[1]-a[1])*r[1])/rr, lo=Math.max(0,Math.min(t0,t1)), hi=Math.min(1,Math.max(t0,t1));
    if(hi-lo>1e-9){ const t=(lo+hi)/2; return [a[0]+r[0]*t,a[1]+r[1]*t] } return null }
  const t=((c[0]-a[0])*s[1]-(c[1]-a[1])*s[0])/den, u=((c[0]-a[0])*r[1]-(c[1]-a[1])*r[0])/den, e=1e-9;
  return t>=-e&&t<=1+e&&u>=-e&&u<=1+e?[a[0]+r[0]*t,a[1]+r[1]*t]:null }
/* first self-intersection of a polygon/polyline (including zero-length edges and walls folding back), or null */
function skSelfX(V,closed){
  const n=V.length, m=closed?n:n-1;
  for(let i=0;i<m;i++){ const a=V[i],b=V[(i+1)%n]; if(Math.hypot(b[0]-a[0],b[1]-a[1])<1e-9) return a.slice() }
  for(let i=0;i<m;i++) for(let j=i+2;j<m;j++){ if(closed&&i===0&&j===m-1) continue; const x=skSegX(V[i],V[(i+1)%n],V[j],V[(j+1)%n]); if(x) return x }
  for(let i=closed?0:1;i<(closed?n:n-1);i++){ const a=V[(i-1+n)%n],b=V[i],c=V[(i+1)%n]; const ux=a[0]-b[0],uy=a[1]-b[1],vx=c[0]-b[0],vy=c[1]-b[1],la=Math.hypot(ux,uy),lc=Math.hypot(vx,vy);
    if(Math.abs((ux*vy-uy*vx)/(la*lc))<1e-6&&(ux*vx+uy*vy)>0) return b.slice() }
  return null }
/* Closure solver. dirs: wall angles (rad, y down); lens: confirmed lengths (mm) or null.
   status 'solved' (len filled; computed = indices derived from closure), 'conflict' (conflict = indices of confirmed walls involved,
   reason closure|negative|cross, err mm) or 'unresolved' (measure = walls to measure; either = [a,b] when one of two parallel walls is enough). */
function skSolve(dirs,lens,o){
  const tol=(o&&o.tol)||SK_TOL, UV=dirs.map(skUnit), len=lens.map(x=>x==null?null:x), unk=[]; let kx=0,ky=0;
  lens.forEach((l,i)=>{ if(l==null) unk.push(i); else { kx+=l*UV[i][0]; ky+=l*UV[i][1] } });
  const res={status:'',len,computed:[],conflict:[],unknown:unk,measure:[],either:null,some:0,keep:null,err:0,reason:null,neg:null};
  const along=(ex,ey)=>{ const m=Math.hypot(ex,ey)||1; return lens.map((l,i)=>l!=null&&Math.abs((UV[i][0]*ex+UV[i][1]*ey)/m)>0.05?i:-1).filter(i=>i>=0) };
  const fail=(reason,ex,ey,err,neg)=>{ res.status='conflict'; res.reason=reason; res.err=err; res.neg=neg??null; res.conflict=along(ex,ey); return res };
  const finish=()=>{ const V=skBuildVerts(dirs,len,[0,0]); if(skSelfX(V,true)){ res.status='conflict'; res.reason='cross'; res.conflict=res.computed.length?res.computed.slice():lens.map((l,i)=>l!=null?i:-1).filter(i=>i>=0); return res } res.status='solved'; return res };
  if(!unk.length){ const e=Math.hypot(kx,ky); res.err=e; return e>tol?fail('closure',kx,ky,e):finish() }
  if(unk.length===1){ const k=unk[0], l=-(kx*UV[k][0]+ky*UV[k][1]), ex=kx+l*UV[k][0], ey=ky+l*UV[k][1], e=Math.hypot(ex,ey);
    if(e>tol) return fail('closure',ex,ey,e);
    if(l<=tol) return fail('negative',UV[k][0],UV[k][1],0,k);
    len[k]=Math.round(l); res.computed=[k]; return finish() }
  if(unk.length===2){ const [a,b]=unk, det=UV[a][0]*UV[b][1]-UV[a][1]*UV[b][0];
    if(Math.abs(det)>1e-6){ const la=(-kx*UV[b][1]+ky*UV[b][0])/det, lb=(kx*UV[a][1]-ky*UV[a][0])/det;
      if(la<=tol||lb<=tol){ const k=la<=tol?a:b; return fail('negative',UV[k][0],UV[k][1],0,k) }
      len[a]=Math.round(la); len[b]=Math.round(lb); res.computed=[a,b]; return finish() }
    const pp=[-UV[a][1],UV[a][0]], rr=kx*pp[0]+ky*pp[1];
    if(Math.abs(rr)>tol) return fail('closure',pp[0]*rr,pp[1]*rr,Math.abs(rr));
    res.status='unresolved'; res.either=[a,b]; res.measure=[a,b]; return res }
  res.status='unresolved';
  for(let x=unk.length-1;x>0;x--) for(let y=x-1;y>=0;y--){ const a=unk[y],b=unk[x]; if(Math.abs(UV[a][0]*UV[b][1]-UV[a][1]*UV[b][0])>1e-6){ res.keep=[a,b]; res.measure=unk.filter(i=>i!==a&&i!==b); return res } }
  res.measure=unk.slice(); res.some=unk.length-1; return res }
/* diagonal check: measured v vs plan distance between corners a and b */
function skCheckDiag(V,a,b,v,tol){ const calc=Math.round(Math.hypot(V[b][0]-V[a][0],V[b][1]-V[a][1])); const diff=v-calc; return {calc,diff,ok:Math.abs(diff)<=(tol||SK_TOL)} }
function skRDP(P,eps){
  if(P.length<3) return P.map(p=>p.slice()); const keep=new Uint8Array(P.length); keep[0]=keep[P.length-1]=1; const st=[[0,P.length-1]];
  while(st.length){ const [a,b]=st.pop(); const A_=P[a],B_=P[b],dx=B_[0]-A_[0],dy=B_[1]-A_[1],L=Math.hypot(dx,dy); let md=0,mi=-1;
    for(let i=a+1;i<b;i++){ const d=L<1e-9?Math.hypot(P[i][0]-A_[0],P[i][1]-A_[1]):Math.abs((P[i][0]-A_[0])*dy-(P[i][1]-A_[1])*dx)/L; if(d>md){md=d;mi=i} }
    if(md>eps&&mi>0){ keep[mi]=1; st.push([a,mi],[mi,b]) } }
  return P.filter((p,i)=>keep[i]).map(p=>p.slice()) }
/* remove short edges and near-collinear corners */
function skClean(V,closed,minLen){
  V=V.map(p=>p.slice()); let changed=true;
  while(changed&&V.length>(closed?3:2)){ changed=false; const n=V.length, m=closed?n:n-1; let si=-1,sl=Infinity;
    for(let i=0;i<m;i++){ const l=Math.hypot(V[(i+1)%n][0]-V[i][0],V[(i+1)%n][1]-V[i][1]); if(l<sl){sl=l;si=i} }
    if(sl<minLen){ const j=(si+1)%n;
      if(!closed&&si===0) V.splice(1,1); else if(!closed&&j===n-1) V.splice(si,1); else { V[si]=[(V[si][0]+V[j][0])/2,(V[si][1]+V[j][1])/2]; V.splice(j,1) }
      changed=true; continue }
    for(let i=closed?0:1;i<(closed?n:n-1);i++){ const a=V[(i-1+n)%n],b=V[i],c=V[(i+1)%n];
      if(Math.abs(skNormAng(Math.atan2(c[1]-b[1],c[0]-b[0])-Math.atan2(b[1]-a[1],b[0]-a[0])))<0.21){ V.splice(i,1); changed=true; break } } }
  return V }
/* snap edge directions to 45° steps; for closed shapes adjust lengths (least squares) so the outline closes. null if it can't. */
function skSnapPoly(V,closed){
  const n=V.length, m=closed?n:n-1; if(m<1) return null; let E=[];
  for(let i=0;i<m;i++){ const p=V[i],q=V[(i+1)%n],l=Math.hypot(q[0]-p[0],q[1]-p[1]); if(l>1e-9) E.push({a:skSnapAng(Math.atan2(q[1]-p[1],q[0]-p[0])),l}) }
  let again=true;
  while(again&&E.length>1){ again=false; const k=E.length, lim=closed?k:k-1;
    for(let i=0;i<lim;i++){ const j=(i+1)%k; if(j===i) break; const d=Math.abs(skNormAng(E[j].a-E[i].a));
      if(d<1e-6){ E[i].l+=E[j].l; E.splice(j,1); again=true; break }
      if(Math.abs(d-Math.PI)<1e-6){ const diff=E[i].l-E[j].l; if(diff<0) E[i].a=E[j].a; E[i].l=Math.abs(diff); E.splice(j,1); again=true; break } }
    E=E.filter(e=>e.l>1e-6) }
  if(closed){ if(E.length<3) return null; const UV=E.map(e=>skUnit(e.a)); let a=0,b=0,c=0,ex=0,ey=0;
    E.forEach((e,i)=>{ a+=UV[i][0]*UV[i][0]; b+=UV[i][0]*UV[i][1]; c+=UV[i][1]*UV[i][1]; ex+=e.l*UV[i][0]; ey+=e.l*UV[i][1] });
    const det=a*c-b*b; if(Math.abs(det)<1e-9) return null; const lx=(c*ex-b*ey)/det, ly=(-b*ex+a*ey)/det;
    for(let i=0;i<E.length;i++){ const nl=E[i].l-(UV[i][0]*lx+UV[i][1]*ly); if(nl<Math.max(E[i].l*0.3,1)) return null; E[i].l=nl } }
  else if(!E.length) return null;
  const pts=[[0,0]]; E.forEach((e,i)=>{ if(closed&&i===E.length-1) return; const u=skUnit(e.a),p=pts[pts.length-1]; pts.push([p[0]+u[0]*e.l,p[1]+u[1]*e.l]) });
  const avg=W=>[W.reduce((s,p)=>s+p[0],0)/W.length,W.reduce((s,p)=>s+p[1],0)/W.length];
  const sh=closed?(()=>{const c0=avg(V),c1=avg(pts);return [c0[0]-c1[0],c0[1]-c1[1]]})():[V[0][0],V[0][1]];
  return pts.map(p=>[p[0]+sh[0],p[1]+sh[1]]) }
/* stroke (or tapped corners) -> {verts, closed, err:null|'short'|'few'|'many'|'cross', x:[crossing point]} */
function skProcess(pts,o){
  o=o||{}; const P0=(pts||[]).filter((p,i,a)=>i===0||Math.hypot(p[0]-a[i-1][0],p[1]-a[i-1][1])>0.5);
  if(P0.length<(o.tap?2:5)) return {err:'short',verts:P0,closed:false};
  const xs=P0.map(p=>p[0]),ys=P0.map(p=>p[1]), Dg=Math.hypot(Math.max(...xs)-Math.min(...xs),Math.max(...ys)-Math.min(...ys));
  if(!o.tap&&Dg<40) return {err:'short',verts:P0,closed:false};
  let closed=!!o.closed, V;
  if(o.tap) V=P0.map(p=>p.slice());
  else { const ct=Math.max(26,Dg*0.15), last=P0[P0.length-1];
    if(!closed&&Math.hypot(P0[0][0]-last[0],P0[0][1]-last[1])<ct) closed=true;
    V=skRDP(P0,Math.max(6,Dg*0.035));
    if(closed&&V.length>3&&Math.hypot(V[0][0]-V[V.length-1][0],V[0][1]-V[V.length-1][1])<ct) V.pop() }
  V=skClean(V,closed,Math.max(o.tap?4:10,Dg*0.05));
  if(closed&&V.length<3) return {err:'few',verts:V,closed};
  if(o.snap){ const s=skSnapPoly(V,closed); if(s) V=skClean(s,closed,1) }
  if(V.length>20) return {err:'many',verts:V,closed};
  const x=skSelfX(V,closed); if(x) return {err:'cross',x,verts:V,closed};
  return {verts:V,closed,err:null} }
/* clockwise on screen (positive area with y down), first corner = top-left */
function skOrient(V){
  let W=V.map(p=>p.slice()); if(skArea(W)<0) W.reverse();
  const ys=W.map(p=>p[1]), minY=Math.min(...ys), tol=(Math.max(...ys)-minY)*0.01+1e-6; let bi=0,bx=Infinity;
  W.forEach((p,i)=>{ if(p[1]<=minY+tol&&p[0]<bx){ bx=p[0]; bi=i } }); return W.slice(bi).concat(W.slice(0,bi)) }
/*SK-PURE-END*/

const SK_PX=25, SK_VW=360, SK_VH=440;                       // sketch pad: 1 px = 25 mm
const SK_LSHAPE=[[0,0],[3000,0],[3000,1500],[6000,1500],[6000,5000],[0,5000]];
const skF=x=>x.toFixed(1), skP=p=>skF(p[0])+' '+skF(p[1]);
SK_LETTERS.split('').forEach((c,i)=>{ if(!(c in WALL_CORNER)) WALL_CORNER[c]=i+1 });
function skIsPoly(r){ return !!(r&&r.shape==='poly'&&r.poly&&r.poly.verts&&r.poly.verts.length>=3) }
const skDiagId=k=>/^X\d+$/.test(String(k));
const skCache=new Map();
function skGeo(r){
  const snap=S.settings.angleSnap!==false, key=JSON.stringify([snap,r.poly,r.dims]); const c=skCache.get(r.id); if(c&&c.key===key) return c.g;
  const V=r.poly.verts.map(v=>[v.x,v.y]), n=V.length, ids=skWallIds(n), dirs=skDirs(V,snap);
  const lens=ids.map(id=>{ const d=r.dims[id]; return d&&d.v!=null?d.v:null });
  const sol=skSolve(dirs,lens,{tol:SK_TOL}), solved=sol.status==='solved';
  const verts=solved?skBuildVerts(dirs,sol.len,V[0]):V;
  const comp=new Set(sol.computed), bad=new Set(sol.conflict), unres=new Set(sol.either||[]);
  const walls=ids.map((id,i)=>{ const d=r.dims[id]||{v:null}; const st=d.pending?'recv':d.v!=null?(bad.has(i)?'bad':'conf'):comp.has(i)?'calc':unres.has(i)?'unres':'unset';
    return {id,i,st,len:d.v!=null?d.v:comp.has(i)?sol.len[i]:null,computed:comp.has(i)} });
  const diags=(r.poly.diags||[]).filter(dg=>dg.a<n&&dg.b<n).map(dg=>{ const d=r.dims[dg.id]||{v:null}; const ck=solved&&d.v!=null?skCheckDiag(verts,dg.a,dg.b,d.v,SK_TOL):null;
    return Object.assign({},dg,{v:d.v,pending:d.pending||null,calc:ck?ck.calc:null,diff:ck?ck.diff:null,st:d.pending?'recv':d.v==null?'unset':!ck?'conf':ck.ok?'ok':'warn'}) });
  const g={n,ids,dirs,lens,sol,solved,verts,sketch:V,walls,diags}; skCache.set(r.id,{key,g}); return g;
}
const skStWord=(st,l)=>t({conf:'room.ok',ok:'room.ok',recv:'ms.received',unset:'room.unset',calc:'sk.calc',bad:'sk.st.bad',warn:'sk.st.bad',unres:'sk.st.unres'}[st]||'room.unset',null,l);
function skMiter(IP,NO,w){ const n=IP.length; return IP.map((p,i)=>{ const a=NO[(i-1+n)%n],b=NO[i],d=1+a[0]*b[0]+a[1]*b[1]; return d<0.15?[p[0]+b[0]*w,p[1]+b[1]*w]:[p[0]+(a[0]+b[0])*w/d,p[1]+(a[1]+b[1])*w/d] }) }
function skFrame(V){ const n=V.length; const UU=V.map((p,i)=>{ const q=V[(i+1)%n],L=Math.hypot(q[0]-p[0],q[1]-p[1])||1; return [(q[0]-p[0])/L,(q[1]-p[1])/L,L] }); return {UU,NO:UU.map(u=>[u[1],-u[0]])} }

/* ---------- hooks ---------- */
const skRoomWallsOrig=roomWalls;
roomWalls=function(r){ if(!skIsPoly(r)) return skRoomWallsOrig(r); const g=skGeo(r), V=g.verts;
  return g.walls.map((w,i)=>({id:w.id,corner:i+1,len:w.len,dimKey:w.id,derived:w.computed,p0:V[i].slice(),p1:V[(i+1)%g.n].slice()})) };
const skAreasOrig=areas;
areas=function(r){ if(!skIsPoly(r)) return skAreasOrig(r); const g=skGeo(r); if(!g.solved) return null;
  const floor=Math.abs(skArea(g.verts)), perim=g.sol.len.reduce((a,b)=>a+b,0), H=r.dims.H.v;
  if(H==null) return {floor,perim,gross:null,open:null,net:null};
  const gross=perim*H, open=r.openings.reduce((a,o)=>a+o.w*o.h,0); return {floor,perim,gross,open,net:gross-open} };
const skUnconfOrig=unconfCount;
unconfCount=function(r){ if(!skIsPoly(r)) return skUnconfOrig(r); const g=skGeo(r);
  return g.walls.filter(w=>w.st!=='conf'&&w.st!=='calc').length+(dimStatus(r.dims.H)!=='conf'?1:0)+g.diags.filter(d=>d.st==='recv'||d.st==='unset'||d.st==='warn').length };
const skSizeOrig=roomSizeText;
roomSizeText=function(r,l){ return skIsPoly(r)?t('sk.walls',{n:r.poly.verts.length},l):skSizeOrig(r,l) };
const sk3DReadyOrig=room3DReady;
room3DReady=function(r){ return skIsPoly(r)?skGeo(r).solved&&r.dims.H.v!=null:sk3DReadyOrig(r) };
const skMeasuredOrig=measuredOK;
measuredOK=function(r){ return skIsPoly(r)?skGeo(r).solved&&r.dims.H.v!=null:skMeasuredOrig(r) };
const skSimOrig=simTarget;
simTarget=function(r,dim){ if(!skIsPoly(r)) return skSimOrig(r,dim); const V=r.poly.verts, n=V.length, i=skWallIds(n).indexOf(dim);
  const r10=x=>Math.max(10,Math.round(x/10)*10), dist=(a,b)=>Math.hypot(V[b].x-V[a].x,V[b].y-V[a].y);
  if(i>=0) return r10(dist(i,(i+1)%n));
  const dg=skDiagId(dim)&&(r.poly.diags||[]).find(x=>x.id===dim); if(dg) return r10(dist(dg.a,dg.b));
  return skSimOrig(r,dim) };
const skDimNameOrig=DIMNAME;
DIMNAME=function(d,l){ return skDiagId(d)?t('sk.diagName',{d},l):skDimNameOrig(d,l) };
const skReportRowsOrig=reportDimRows;
reportDimRows=function(r,l,prov){ if(!skIsPoly(r)) return skReportRowsOrig(r,l,prov); const g=skGeo(r);
  return g.walls.map(w=>`<tr><td>${esc(t('op.wall',null,l))} ${w.id}</td><td class="r">${fmtLen(w.len,l)} ${t('u.m',null,l)}${w.computed?` <span class="prov">(${esc(t('sk.calc',null,l))})</span>`:prov(w.id)}</td></tr>`).join('')
    +g.diags.map(dg=>`<tr><td>${esc(t('sk.diagName',{d:dg.id},l))}, ${dg.a+1}–${dg.b+1}</td><td class="r">${fmtLen(dg.v,l)} ${t('u.m',null,l)}${prov(dg.id)}</td></tr>`).join('') };
const skPlanOrig=planSVG;
planSVG=function(r,o){ return skIsPoly(r)?skPlanSVG(r,o||{}):skPlanOrig(r,o) };

/* ---------- plan drawing ---------- */
function skPill(cx,cy,st,txt,sel,attrs,label){
  const amb='#9A4D00',red='#B42318',cob='#1C4BD1',ink='#0E1C36';
  const C={conf:['#FFFFFF','#FFFFFF',ink],ok:['#FFFFFF','#FFFFFF',ink],recv:['#FFF1DF',amb,ink],unset:['#FFFFFF','#5F6B82','#3E4A61'],calc:['#E7EEFD',cob,cob],bad:['#FDEDEB',red,red],warn:['#FFF1DF',amb,amb],unres:['#FFF1DF',amb,amb]}[st]||['#FFFFFF','#5F6B82',ink];
  const left=st==='recv'?'clock':(st==='bad'||st==='warn')?'alert':'', right=st==='conf'||st==='ok';
  const wd=16+txt.length*8+(left||right?15:0), x0=cx-wd/2, lx=x0+11;
  let h=`<g ${attrs||''} role="${attrs?'button':'img'}" aria-label="${esc(label)}"><title>${esc(label)}</title>`;
  if(attrs) h+=`<rect x="${skF(x0-6)}" y="${skF(cy-20)}" width="${skF(wd+12)}" height="40" fill="transparent"/>`;
  h+=`<rect x="${skF(x0)}" y="${skF(cy-13)}" width="${skF(wd)}" height="26" rx="3" fill="${C[0]}" stroke="${sel?cob:C[1]}" stroke-width="${sel?2.2:st==='bad'?1.8:1.2}" ${['unset','calc','unres'].includes(st)?'stroke-dasharray="3 2"':''}/>`;
  if(left==='clock') h+=`<circle cx="${skF(lx)}" cy="${skF(cy)}" r="4.8" fill="none" stroke="${amb}" stroke-width="1.4"/><path d="M${skF(lx)} ${skF(cy-2.6)}V${skF(cy)}l1.8 1.2" stroke="${amb}" stroke-width="1.3" fill="none"/>`;
  if(left==='alert') h+=`<path d="M${skF(lx)} ${skF(cy-5.5)}L${skF(lx+5.6)} ${skF(cy+4.6)}H${skF(lx-5.6)}Z" fill="none" stroke="${C[2]}" stroke-width="1.4" stroke-linejoin="round"/><path d="M${skF(lx)} ${skF(cy-1.6)}v2.4" stroke="${C[2]}" stroke-width="1.4"/>`;
  h+=`<text x="${skF(cx+(left?7:right?-7:0))}" y="${skF(cy+5)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-weight="600" font-size="15" fill="${C[2]}" ${st==='calc'?'font-style="italic"':''}>${esc(txt)}</text>`;
  if(right){ const kx=cx+wd/2-14; h+=`<path d="M${skF(kx)} ${skF(cy)}l3 3 5.5-5.5" stroke="${ink}" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` }
  return h+'</g>';
}
function skPlanSVG(r,o){
  const g=skGeo(r), l=o.lang||CUR, rep=!!o.report, edit=!!o.edit&&!rep, pick=!rep&&!edit&&o.diagPick?o.diagPick:null, live=!rep&&!edit&&!pick;
  const drag=edit&&U.skDrag&&U.skDrag.rid===r.id?U.skDrag:null;
  const V=edit?g.sketch:g.verts, n=V.length;
  const vv=x=>x&&x.v!=null?x.v:x&&x.pending?x.pending.mm:null, T=vv(r.dims.T)??200;
  const ink='#0E1C36',ink2='#3E4A61',cob='#1C4BD1',amb='#9A4D00',red='#B42318',paper=rep?'#FFFFFF':'#F3F6FA';
  const {UU,NO}=skFrame(V), LEN=UU.map(u=>u[2]);
  const xs=V.map(p=>p[0]),ys=V.map(p=>p[1]),minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys),bw=Math.max(maxX-minX,1),bh=Math.max(maxY-minY,1);
  const W=g.walls.map(w=>{ const d=r.dims[w.id]||{v:null}; let st=w.st; if(rep&&(st==='recv'||st==='unres')) st=d.v!=null?'conf':'unset';
    const txt=st==='recv'?fmtLen(d.pending.mm,l,true):st==='unset'?'?':st==='unres'?'[?]':st==='calc'?'='+fmtLen(w.len,l):st==='bad'?'['+fmtLen(d.v,l)+']':fmtLen(d.v,l);
    return {id:w.id,st,txt,wd:16+txt.length*8+(['recv','conf','bad'].includes(st)?15:0)} });
  const side=i=>{ const q=NO[i]; return q[1]<-0.92?'T':q[1]>0.92?'B':q[0]>0.92?'R':q[0]<-0.92?'L':null };
  const opsOn=i=>r.openings.some(x=>x.wall===g.ids[i]);
  const sideOps={T:0,B:0,L:0,R:0}; let aligned=false;
  for(let i=0;i<n;i++){ const sd=side(i); if(!sd) aligned=true; else if(opsOn(i)) sideOps[sd]=1 }
  const VW=360, HB=rep?250:240, sEst=Math.min((VW-150)/(bw+2*T),HB/(bh+2*T));
  // dimension rows per bounding-box side (walls in a notch dimension to the outside, as a chain)
  const rows=[],placed={T:[],B:[],L:[],R:[]},maxRow={T:-1,B:-1,L:-1,R:-1};
  [...Array(n).keys()].sort((a,b)=>LEN[b]-LEN[a]).forEach(i=>{ const sd=side(i); if(!sd) return; const hz=sd==='T'||sd==='B';
    const a=hz?V[i][0]:V[i][1], b=hz?V[(i+1)%n][0]:V[(i+1)%n][1], lo=Math.min(a,b), hi=Math.max(a,b), mid=(lo+hi)/2, half=((hz?W[i].wd/2:13)+4)/sEst, iv=[Math.min(lo,mid-half),Math.max(hi,mid+half)];
    let row=0; while(placed[sd].some(x=>x.row===row&&x.iv[1]>iv[0]+1&&iv[1]>x.iv[0]+1)) row++; placed[sd].push({row,iv}); rows[i]=row; maxRow[sd]=Math.max(maxRow[sd],row) });
  const base=sd=>sideOps[sd]?42:30, offOf=(sd,row)=>base(sd)+row*((sd==='L'||sd==='R')?76:30);
  const mg=sd=>Math.max(maxRow[sd]<0?20:offOf(sd,maxRow[sd])+((sd==='L'||sd==='R')?40:17),aligned?60:0);
  let s,ox,oy,VH;
  if(o.view){ ({s,ox,oy,VH}=o.view) }
  else { const mT=mg('T'),mB=mg('B'),mL=mg('L'),mR=mg('R'); s=Math.min((VW-mL-mR)/(bw+2*T),HB/(bh+2*T));
    const left=mL+((VW-mL-mR)-(bw+2*T)*s)/2; ox=left+T*s-minX*s; oy=mT+T*s-minY*s; VH=mT+(bh+2*T)*s+mB }
  if(edit) U.skView={rid:r.id,s,ox,oy,VW,VH};
  const tw=Math.max(3,T*s), IP=V.map(p=>[ox+p[0]*s,oy+p[1]*s]), OP=skMiter(IP,NO,tw);
  const pt=(i,mm,k)=>[IP[i][0]+UU[i][0]*mm*s+NO[i][0]*k,IP[i][1]+UU[i][1]*mm*s+NO[i][1]*k];
  const obx0=Math.min(...OP.map(p=>p[0])),obx1=Math.max(...OP.map(p=>p[0])),oby0=Math.min(...OP.map(p=>p[1])),oby1=Math.max(...OP.map(p=>p[1]));
  const sel=o.sel, selI=rep?-1:g.ids.indexOf(sel);
  let h='';
  const band=(i,pad)=>{ const a=IP[i],b=IP[(i+1)%n],u=UU[i],q=NO[i]; return [[a[0]-u[0]*pad-q[0]*pad,a[1]-u[1]*pad-q[1]*pad],[b[0]+u[0]*pad-q[0]*pad,b[1]+u[1]*pad-q[1]*pad],[b[0]+u[0]*pad+q[0]*(tw+pad),b[1]+u[1]*pad+q[1]*(tw+pad)],[a[0]-u[0]*pad+q[0]*(tw+pad),a[1]-u[1]*pad+q[1]*(tw+pad)]].map(skP).join(' ') };
  if(selI>=0) h+=`<polygon points="${band(selI,5)}" fill="#E7EEFD" stroke="${cob}" stroke-width="1.5"/>`;
  h+=`<path d="M${OP.map(skP).join('L')}Z M${IP.map(skP).join('L')}Z" fill="url(#skh${rep?'R':''})" fill-rule="evenodd" stroke="${ink}" stroke-width="1.2" stroke-linejoin="miter"/>`;
  if(selI>=0) h+=`<polygon points="${[IP[selI],IP[(selI+1)%n],OP[(selI+1)%n],OP[selI]].map(skP).join(' ')}" fill="${cob}"/>`;
  if(live) for(let i=0;i<n;i++) h+=`<polygon points="${band(i,12)}" fill="transparent" data-a="selDim" data-d="${g.ids[i]}"/>`;
  // openings (offsets scaled when the drawn wall differs from its measured length)
  const issues=roomIssues(r).map(x=>x.o.id); const kOf=i=>{ const wl=g.walls[i].len; return wl?LEN[i]/wl:1 };
  r.openings.forEach(op=>{ const i=g.ids.indexOf(op.wall); if(i<0) return; const k=kOf(i), off=op.off*k, ow=op.w*k, nin=[-NO[i][0],-NO[i][1]];
    const p0=pt(i,off,0),p1=pt(i,off+ow,0),q0=pt(i,off,tw),q1=pt(i,off+ow,tw); const bad=issues.includes(op.id), selO=o.selOp===op.id, col=bad?red:selO?cob:ink;
    h+=`<polygon points="${[p0,p1,q1,q0].map(skP).join(' ')}" fill="${paper}"/><path d="M${skP(p0)}L${skP(q0)}M${skP(p1)}L${skP(q1)}" stroke="${col}" stroke-width="1.2"/>`;
    if(op.type==='door'){ const R_=ow*s, tip=[p0[0]+nin[0]*R_,p0[1]+nin[1]*R_]; h+=`<path d="M${skP(p0)}L${skP(tip)}" stroke="${col}" stroke-width="2.2"/><path d="M${skP(p1)}A${skF(R_)} ${skF(R_)} 0 0 1 ${skP(tip)}" fill="none" stroke="${col}" stroke-width="1" stroke-dasharray="3 3"/>` }
    else { const a1=pt(i,off,tw/3),b1=pt(i,off+ow,tw/3),a2=pt(i,off,2*tw/3),b2=pt(i,off+ow,2*tw/3); h+=`<polygon points="${[p0,p1,q1,q0].map(skP).join(' ')}" fill="#FFFFFF" stroke="${col}" stroke-width="1.2"/><path d="M${skP(a1)}L${skP(b1)}M${skP(a2)}L${skP(b2)}" stroke="${col}" stroke-width="1"/>` }
    if(bad) h+=`<polygon points="${[p0,p1,q1,q0].map(skP).join(' ')}" fill="none" stroke="${red}" stroke-width="2.5" stroke-dasharray="4 3"/>`;
    if(live){ const kk=Math.min(ow*s,30); h+=`<polygon points="${[pt(i,off-150,tw+10),pt(i,off+ow+150,tw+10),pt(i,off+ow+150,-kk),pt(i,off-150,-kk)].map(skP).join(' ')}" fill="transparent" data-a="editOpening" data-id="${op.id}"/>` } });
  // room name + floor area
  const lp=skLabelPt(V), lcx=ox+lp[0]*s, lcy=oy+lp[1]*s;
  h+=`<text x="${skF(lcx)}" y="${skF(lcy-3)}" text-anchor="middle" font-size="11.5" font-weight="600" letter-spacing=".06em" fill="${ink2}">${esc(dn(r.name,l)).toUpperCase()}</text><text x="${skF(lcx)}" y="${skF(lcy+12)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-size="12.5" fill="${ink2}">${g.solved?fmtArea(Math.abs(skArea(g.verts)),l):'?'} ${t('u.m2',null,l)}</text>`;
  // wall letters + corner numbers
  for(let i=0;i<n;i++){ const m=pt(i,LEN[i]/2,-17), on=selI===i;
    h+=`<g ${live?`data-a="selDim" data-d="${g.ids[i]}"`:''}><circle cx="${skF(m[0])}" cy="${skF(m[1])}" r="9" fill="${on?cob:'#FFFFFF'}" stroke="${on?cob:ink2}"/><text x="${skF(m[0])}" y="${skF(m[1]+4)}" text-anchor="middle" font-size="11" font-weight="600" fill="${on?'#FFFFFF':ink}">${g.ids[i]}</text></g>` }
  if(!pick) for(let i=0;i<n;i++){ const a=NO[(i-1+n)%n],b=NO[i]; let bx=-(a[0]+b[0]),by=-(a[1]+b[1]); const bl=Math.hypot(bx,by); if(bl<1e-6){bx=-b[0];by=-b[1]} else {bx/=bl;by/=bl}
    h+=`<text x="${skF(IP[i][0]+bx*12)}" y="${skF(IP[i][1]+by*12+3.5)}" text-anchor="middle" font-size="9.5" fill="${ink2}">${i+1}</text>` }
  // dimensions
  const tickAt=(p,u,col)=>{ const v=[(u[0]+u[1])*2.9,(u[1]-u[0])*2.9]; return `<path d="M${skF(p[0]-v[0])} ${skF(p[1]-v[1])}L${skF(p[0]+v[0])} ${skF(p[1]+v[1])}" stroke="${col}" stroke-width="1.6"/>` };
  const colOf=st=>({recv:amb,unset:'#5F6B82',calc:cob,bad:red,unres:amb,warn:amb}[st]||ink);
  const angTxt=u=>{ let a=Math.atan2(u[1],u[0])*180/Math.PI; if(a>=90) a-=180; if(a<-90) a+=180; return a };
  for(let i=0;i<n;i++){ // opening chains along the wall
    const id=g.ids[i], ops=r.openings.filter(x=>x.wall===id).sort((a,b)=>a.off-b.off); if(!ops.length) continue; const k=kOf(i), Lw=LEN[i];
    const stops=[0]; ops.forEach(x=>stops.push(x.off*k,(x.off+x.w)*k)); stops.push(Lw); const uq=[...new Set(stops.map(x=>Math.max(0,Math.min(Lw,x))))].sort((a,b)=>a-b);
    h+=`<path d="M${skP(pt(i,0,tw+18))}L${skP(pt(i,Lw,tw+18))}" stroke="${ink2}" stroke-width="0.9"/>`;
    uq.forEach(x=>{ h+=`<path d="M${skP(pt(i,x,tw+3))}L${skP(pt(i,x,tw+22))}" stroke="${ink2}" stroke-width="0.8"/>`+tickAt(pt(i,x,tw+18),UU[i],ink2) });
    for(let j=0;j<uq.length-1;j++){ const len=(uq[j+1]-uq[j])/k; if(len<=0) continue; const m=pt(i,(uq[j]+uq[j+1])/2,tw+9), a=angTxt(UU[i]);
      h+=`<text x="${skF(m[0])}" y="${skF(m[1]+4)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-size="11.5" fill="${ink2}" ${Math.abs(a)>0.5?`transform="rotate(${skF(a)} ${skF(m[0])} ${skF(m[1])})"`:''}>${fmtLen(Math.round(len),l)}</text>` } }
  for(let i=0;i<n;i++){
    const w=W[i], col=colOf(w.st), dash=w.st!=='conf'?'stroke-dasharray="5 4"':'', sd=side(i), a=IP[i], b=IP[(i+1)%n]; let mid;
    if(sd==='T'||sd==='B'){ const sg=sd==='T'?-1:1, y=sd==='T'?oby0-offOf(sd,rows[i]):oby1+offOf(sd,rows[i]);
      h+=`<path d="M${skF(a[0])} ${skF(a[1]+sg*(tw+3))}L${skF(a[0])} ${skF(y+sg*5)}M${skF(b[0])} ${skF(b[1]+sg*(tw+3))}L${skF(b[0])} ${skF(y+sg*5)}" stroke="${col}" stroke-width="0.9"/><path d="M${skF(a[0])} ${skF(y)}L${skF(b[0])} ${skF(y)}" stroke="${col}" stroke-width="1.1" ${dash}/>`+tickAt([a[0],y],[1,0],col)+tickAt([b[0],y],[1,0],col);
      mid=[(a[0]+b[0])/2,y] }
    else if(sd){ const sg=sd==='L'?-1:1, x=sd==='L'?obx0-offOf(sd,rows[i]):obx1+offOf(sd,rows[i]);
      h+=`<path d="M${skF(a[0]+sg*(tw+3))} ${skF(a[1])}L${skF(x+sg*5)} ${skF(a[1])}M${skF(b[0]+sg*(tw+3))} ${skF(b[1])}L${skF(x+sg*5)} ${skF(b[1])}" stroke="${col}" stroke-width="0.9"/><path d="M${skF(x)} ${skF(a[1])}L${skF(x)} ${skF(b[1])}" stroke="${col}" stroke-width="1.1" ${dash}/>`+tickAt([x,a[1]],[0,1],col)+tickAt([x,b[1]],[0,1],col);
      mid=[x,(a[1]+b[1])/2] }
    else { const k=opsOn(i)?42:30, p=pt(i,0,tw+k), q=pt(i,LEN[i],tw+k);
      h+=`<path d="M${skP(pt(i,0,tw+3))}L${skP(pt(i,0,tw+k+5))}M${skP(pt(i,LEN[i],tw+3))}L${skP(pt(i,LEN[i],tw+k+5))}" stroke="${col}" stroke-width="0.9"/><path d="M${skP(p)}L${skP(q)}" stroke="${col}" stroke-width="1.1" ${dash}/>`+tickAt(p,UU[i],col)+tickAt(q,UU[i],col);
      mid=pt(i,LEN[i]/2,tw+k) }
    h+=skPill(mid[0],mid[1],w.st,w.txt,live&&sel===w.id,live?`data-a="selDim" data-d="${w.id}"`:'',`${t('op.wall',null,l)} ${w.id}: ${w.txt}, ${skStWord(w.st,l)}`);
  }
  // check measurements (diagonals)
  const boxes=[[lcx-40,lcy-16,lcx+40,lcy+16]];
  g.diags.forEach(dg=>{ const a=IP[dg.a],b=IP[dg.b], st=rep?(dg.v!=null?(dg.st==='warn'?'warn':'conf'):'unset'):dg.st, isSel=live&&sel===dg.id;
    const val=st==='recv'?fmtLen(dg.pending.mm,l,true):dg.v!=null?fmtLen(dg.v,l):'?', txt=`${dg.id} ${st==='warn'?'['+val+']':val}`, wd=16+txt.length*8+15;
    h+=`<path d="M${skP(a)}L${skP(b)}" stroke="${isSel?cob:colOf(st)}" stroke-width="${isSel?2:1.2}" stroke-dasharray="2 4" stroke-linecap="round"/><circle cx="${skF(a[0])}" cy="${skF(a[1])}" r="2.6" fill="${ink2}"/><circle cx="${skF(b[0])}" cy="${skF(b[1])}" r="2.6" fill="${ink2}"/>`;
    let c=null; for(const f of [.5,.36,.64,.25,.75]){ const q=[a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f], bx=[q[0]-wd/2,q[1]-13,q[0]+wd/2,q[1]+13]; if(!boxes.some(z=>z[0]<bx[2]&&bx[0]<z[2]&&z[1]<bx[3]&&bx[1]<z[3])){ c=q; boxes.push(bx); break } }
    if(!c) c=[(a[0]+b[0])/2,(a[1]+b[1])/2];
    const attrs=live?`data-a="selDim" data-d="${dg.id}"`:pick?`data-a="skDelDiag" data-id="${dg.id}"`:'';
    h+=skPill(c[0],c[1],st,txt,isSel,attrs,`${t('sk.diagName',{d:dg.id},l)}, ${dg.a+1}–${dg.b+1}: ${val}, ${skStWord(st,l)}`) });
  // overlays: corner pickers, edit handles, guides, angle arc, magnifier
  let ov='';
  if(pick) IP.forEach((q,i)=>{ const on=pick.a===i; ov+=`<g data-a="skPickCorner" data-i="${i}" role="button" aria-label="${esc(t('sk.corner',{n:i+1}))}"><circle cx="${skF(q[0])}" cy="${skF(q[1])}" r="22" fill="transparent"/><circle cx="${skF(q[0])}" cy="${skF(q[1])}" r="11" fill="${on?cob:'#FFFFFF'}" stroke="${cob}" stroke-width="2"/><text x="${skF(q[0])}" y="${skF(q[1]+4)}" text-anchor="middle" font-size="11" font-weight="600" fill="${on?'#FFFFFF':cob}">${i+1}</text></g>` });
  if(edit){
    if(drag) (drag.guides||[]).forEach(gd=>{ ov+=gd.x!=null?`<path d="M${skF(ox+gd.x*s)} 0V${skF(VH)}" stroke="${cob}" stroke-width="1" stroke-dasharray="6 4" opacity=".75"/>`:`<path d="M0 ${skF(oy+gd.y*s)}H${VW}" stroke="${cob}" stroke-width="1" stroke-dasharray="6 4" opacity=".75"/>` });
    IP.forEach((q,i)=>{ const on=drag&&drag.i===i; ov+=`<g data-skv="${i}" role="button" aria-label="${esc(t('sk.corner',{n:i+1}))}"><circle cx="${skF(q[0])}" cy="${skF(q[1])}" r="22" fill="transparent"/><circle cx="${skF(q[0])}" cy="${skF(q[1])}" r="${on?9:7.5}" fill="${on?cob:'#FFFFFF'}" stroke="${cob}" stroke-width="2.5"/></g>` });
    if(drag){ const i=drag.i, q=IP[i], pv=IP[(i-1+n)%n], nx=IP[(i+1)%n], aN=Math.atan2(nx[1]-q[1],nx[0]-q[0]), aP=Math.atan2(pv[1]-q[1],pv[0]-q[0]); let ia=aP-aN; while(ia<=1e-9) ia+=2*Math.PI;
      const R1=24, e0=[q[0]+Math.cos(aN)*R1,q[1]+Math.sin(aN)*R1], e1=[q[0]+Math.cos(aP)*R1,q[1]+Math.sin(aP)*R1], am=aN+ia/2, lt=[q[0]+Math.cos(am)*44,q[1]+Math.sin(am)*44], deg=Math.round(ia*180/Math.PI);
      ov+=`<path d="M${skP(e0)}A${R1} ${R1} 0 ${ia>Math.PI?1:0} 1 ${skP(e1)}" fill="none" stroke="${cob}" stroke-width="1.6"/><rect x="${skF(lt[0]-19)}" y="${skF(lt[1]-10)}" width="38" height="20" rx="10" fill="${cob}"/><text x="${skF(lt[0])}" y="${skF(lt[1]+4.5)}" text-anchor="middle" font-size="12" font-weight="600" fill="#FFFFFF">${deg}°</text>`;
      const Lx=Math.max(44,Math.min(VW-44,q[0])), Ly=q[1]>110?q[1]-82:q[1]+82;
      ov+=`<defs><clipPath id="skPlc"><circle cx="${skF(Lx)}" cy="${skF(Ly)}" r="40"/></clipPath></defs><g pointer-events="none"><circle cx="${skF(Lx)}" cy="${skF(Ly)}" r="40" fill="${paper}"/><g clip-path="url(#skPlc)"><use href="#skpg" transform="translate(${skF(Lx)} ${skF(Ly)}) scale(2) translate(${skF(-q[0])} ${skF(-q[1])})"/></g><circle cx="${skF(Lx)}" cy="${skF(Ly)}" r="40" fill="none" stroke="${ink}" stroke-width="1.5"/><path d="M${skF(Lx-8)} ${skF(Ly)}H${skF(Lx+8)}M${skF(Lx)} ${skF(Ly-8)}V${skF(Ly+8)}" stroke="${cob}" stroke-width="1.2"/></g>` } }
  const hatch=`<pattern id="skh${rep?'R':''}" width="4" height="4" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="4" height="4" fill="#FFFFFF"/><rect width="1.1" height="4" fill="${ink}"/></pattern>`;
  return `<svg class="sk-plan" viewBox="0 0 ${VW} ${skF(VH)}" font-family="IBM Plex Sans, sans-serif" role="img" aria-label="${esc(dn(r.name,l))}"><defs>${hatch}</defs><g ${edit?'id="skpg"':''}>${h}</g>${ov}</svg>`;
}

/* mini plan (2D overview) and project thumbnail */
const skMiniOrig=miniPlan;
miniPlan=function(r,s,l){ if(!skIsPoly(r)) return skMiniOrig(r,s,l);
  const g=skGeo(r), ok=g.solved, V=g.verts, xs=V.map(p=>p[0]), ys=V.map(p=>p[1]), minX=Math.min(...xs), minY=Math.min(...ys), bw=Math.max(...xs)-minX, bh=Math.max(...ys)-minY;
  if(Math.max(bw,bh)*s>170) s=170/Math.max(bw,bh);
  const T=r.dims.T.v||200, tw=Math.max(2.5,T*s), pad=18, ox=pad+tw-minX*s, oy=pad+tw-minY*s, VW=bw*s+2*(pad+tw), VH=bh*s+2*(pad+tw);
  const IP=V.map(p=>[ox+p[0]*s,oy+p[1]*s]), {UU,NO}=skFrame(V), OP=skMiter(IP,NO,tw), ink='#0E1C36'; let h='';
  if(ok){ h+=`<path d="M${OP.map(skP).join('L')}Z M${IP.map(skP).join('L')}Z" fill="${ink}" fill-rule="evenodd"/>`;
    r.openings.forEach(o=>{ const i=g.ids.indexOf(o.wall); if(i<0) return; const u=UU[i], q=NO[i], P0=[IP[i][0]+u[0]*o.off*s,IP[i][1]+u[1]*o.off*s], P1=[IP[i][0]+u[0]*(o.off+o.w)*s,IP[i][1]+u[1]*(o.off+o.w)*s], Q0=[P0[0]+q[0]*tw,P0[1]+q[1]*tw], Q1=[P1[0]+q[0]*tw,P1[1]+q[1]*tw];
      h+=`<polygon points="${[P0,P1,Q1,Q0].map(skP).join(' ')}" fill="#fff" ${o.type==='window'?`stroke="${ink}" stroke-width=".8"`:''}/>`;
      if(o.type==='door'){ const R_=o.w*s, tip=[P0[0]-q[0]*R_,P0[1]-q[1]*R_]; h+=`<path d="M${skP(P0)}L${skP(tip)}" stroke="${ink}" stroke-width="1.4"/>` } }) }
  else h+=`<path d="M${IP.map(skP).join('L')}Z" fill="none" stroke="#5F6B82" stroke-width="1.5" stroke-dasharray="5 4"/>`;
  const lp=skLabelPt(V), cx=ox+lp[0]*s, cy=oy+lp[1]*s;
  h+=`<text x="${skF(cx)}" y="${skF(cy-2)}" text-anchor="middle" font-size="10.5" font-weight="600" letter-spacing=".05em" fill="${ink}">${esc(dn(r.name,l)).toUpperCase()}</text><text x="${skF(cx)}" y="${skF(cy+11)}" text-anchor="middle" font-family="IBM Plex Sans Condensed, sans-serif" font-size="11" fill="#3E4A61">${ok?fmtArea(Math.abs(skArea(V)),l):'?'} ${t('u.m2',null,l)}</text>`;
  return `<svg width="${VW.toFixed(0)}" height="${VH.toFixed(0)}" viewBox="0 0 ${skF(VW)} ${skF(VH)}" font-family="IBM Plex Sans, sans-serif" role="img" aria-label="${esc(dn(r.name,l))}">${h}</svg>` };
const skThumbOrig=thumbSVG;
thumbSVG=function(r,w=56,h=48){ if(!skIsPoly(r)) return skThumbOrig(r,w,h);
  const g=skGeo(r), V=g.verts, xs=V.map(p=>p[0]), ys=V.map(p=>p[1]), minX=Math.min(...xs), minY=Math.min(...ys), bw=Math.max(...xs)-minX||1, bh=Math.max(...ys)-minY||1;
  const s=Math.min((w-14)/bw,(h-14)/bh), x0=(w-bw*s)/2, y0=(h-bh*s)/2, pts=V.map(p=>skF(x0+(p[0]-minX)*s)+','+skF(y0+(p[1]-minY)*s)).join(' ');
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true"><polygon points="${pts}" fill="#fff" stroke="${g.solved?'#0E1C36':'#5F6B82'}" stroke-width="${g.solved?Math.max(2,(r.dims.T.v||200)*s).toFixed(1):1.5}" stroke-linejoin="miter" ${g.solved?'':'stroke-dasharray="4 3"'}/></svg>` };

/* ---------- 3D: extrude each wall along the polygon, floor from THREE.Shape, per-wall cutaway ---------- */
const skMount3DOrig=mount3D;
mount3D=function(host,rooms,single){ const k=JSON.stringify([S.settings.angleSnap,rooms.map(r=>skIsPoly(r)?r.poly:0)]); if(k!==T3.skKey){ T3.key=null; T3.skKey=k } return skMount3DOrig(host,rooms,single) };
const skBuild3DOrig=build3D;
build3D=function(rooms,single){
  if(!rooms.some(skIsPoly)) return skBuild3DOrig(rooms,single);
  const THREE=window.THREE; const sc=new THREE.Scene(); sc.background=new THREE.Color(0xF3F6FA);
  sc.add(new THREE.HemisphereLight(0xffffff,0xC9D3E0,0.5)); sc.add(new THREE.AmbientLight(0xffffff,0.3));
  const glassM=new THREE.MeshLambertMaterial({color:0x9DB8E8,transparent:true,opacity:0.5});
  const groups=[],labels=[]; let ox=0,maxW=0,maxH=0; const GAP=1.2;
  const pieces=(a0,a1,ops,H)=>{ const out=[]; let cur=a0; ops.slice().sort((p,q)=>p[0]-q[0]).forEach(o=>{ if(o[0]>cur) out.push([cur,o[0],0,H]); if(o[2]>0) out.push([o[0],o[1],0,o[2]]); if(o[2]+o[3]<H) out.push([o[0],o[1],o[2]+o[3],H]); cur=Math.max(cur,o[1]) }); if(cur<a1) out.push([cur,a1,0,H]); return out };
  rooms.forEach(room=>{
    const H=room.dims.H.v/1000, T=(room.dims.T.v||200)/1000, WS=roomWalls(room), n=WS.length;
    const IP=WS.map(w=>[w.p0[0]/1000,w.p0[1]/1000]), {UU,NO}=skFrame(IP), OP=skMiter(IP,NO,T);
    const minX=Math.min(...OP.map(p=>p[0])),maxX=Math.max(...OP.map(p=>p[0])),minZ=Math.min(...OP.map(p=>p[1])),maxZ=Math.max(...OP.map(p=>p[1]));
    const X=x=>x-minX+ox, Z=z=>z-minZ;
    const prism=(q,y0,y1,m,e)=>{ if(y1-y0<1e-4||Math.abs(skArea(q))<1e-7) return; const sh=new THREE.Shape(); q.forEach((p,i)=>{ const x=X(p[0]),y=-Z(p[1]); i?sh.lineTo(x,y):sh.moveTo(x,y) });
      const geo=new THREE.ExtrudeGeometry(sh,{depth:y1-y0,bevelEnabled:false}); const mesh=new THREE.Mesh(geo,m); mesh.rotation.x=-Math.PI/2; mesh.position.y=y0; sc.add(mesh);
      if(e){ const ln=new THREE.LineSegments(new THREE.EdgesGeometry(geo),e); ln.rotation.x=-Math.PI/2; ln.position.y=y0; sc.add(ln) } };
    const gw=[];
    WS.forEach((w,i)=>{
      const m=new THREE.MeshLambertMaterial({color:room.colors.wall,transparent:true}), e=new THREE.LineBasicMaterial({color:0x0E1C36,transparent:true});
      const a=IP[i], b=IP[(i+1)%n], u=UU[i], len=u[2], q=NO[i], at=d=>[a[0]+u[0]*d,a[1]+u[1]*d], off=(p,k)=>[p[0]+q[0]*k,p[1]+q[1]*k];
      const ops=room.openings.filter(o=>o.wall===w.id).map(o=>[o.off/1000,(o.off+o.w)/1000,(o.sill||0)/1000,o.h/1000,o.type]);
      pieces(0,len,ops,H).forEach(pc=>{ const s0=Math.max(0,pc[0]), s1=Math.min(len,pc[1]); if(s1-s0<1e-4) return;
        const i0=s0<1e-6?a:at(s0), o0=s0<1e-6?OP[i]:off(at(s0),T), i1=s1>len-1e-6?b:at(s1), o1=s1>len-1e-6?OP[(i+1)%n]:off(at(s1),T);
        prism([i0,i1,o1,o0],pc[2],pc[3],m,e) });
      ops.forEach(o=>{ if(o[4]==='window') prism([off(at(o[0]),T/2-0.01),off(at(o[1]),T/2-0.01),off(at(o[1]),T/2+0.01),off(at(o[0]),T/2+0.01)],o[2],o[2]+o[3],glassM,null) });
      gw.push({m,e,n:q});
      if(single){ const md=at(len/2); labels.push([w.id,X(md[0]+q[0]*T/2),H+0.25,Z(md[1]+q[1]*T/2)]) } });
    const fs=new THREE.Shape(); IP.forEach((p,i)=>{ const x=X(p[0]),y=-Z(p[1]); i?fs.lineTo(x,y):fs.moveTo(x,y) });
    const fl=new THREE.Mesh(new THREE.ShapeGeometry(fs),new THREE.MeshLambertMaterial({color:room.colors.floor,side:THREE.DoubleSide})); fl.rotation.x=-Math.PI/2; fl.position.y=0.001; sc.add(fl);
    const c=skCentroid(IP); groups.push({cx:X(c[0]),cz:Z(c[1]),mats:{},skWalls:gw});
    if(!single) labels.push([dn(room.name),X(c[0]),H+0.45,Z(c[1])]);
    ox+=(maxX-minX)+GAP; maxW=Math.max(maxW,maxZ-minZ); maxH=Math.max(maxH,H);
  });
  const span=Math.max(ox-GAP,1);
  const dl=new THREE.DirectionalLight(0xffffff,0.55); dl.position.set(span*0.7+3,maxH*3+4,maxW*1.6+3); sc.add(dl);
  const gs=Math.max(span,maxW)+4; const grid=new THREE.GridHelper(gs,Math.round(gs*2),0xC3CEDF,0xDCE4F0); grid.position.set(span/2,-0.002,maxW/2); sc.add(grid);
  T3.scene=sc; T3.groups=groups; T3.dims={L:span,W:maxW,H:maxH}; T3.tgt=[span/2,maxH*0.3,maxW/2]; T3.r=Math.max(span,maxW)*(single?2.2:1.7)+2.5;
  if(!single){ T3.theta=Math.PI/2+0.45; T3.phi=0.9 }
  T3.cam=new THREE.PerspectiveCamera(40,1,0.1,300); T3.labels=labels;
};
const skDraw3DOrig=draw3D;
draw3D=function(){
  const gs=T3.groups; if(!gs||!gs.some(g=>g.skWalls)||!T3.renderer||!T3.scene||!T3.host||!T3.cam) return skDraw3DOrig();
  const cx=T3.tgt[0]+T3.r*Math.sin(T3.phi)*Math.cos(T3.theta), cz=T3.tgt[2]+T3.r*Math.sin(T3.phi)*Math.sin(T3.theta), isTop=T3.phi<0.35;
  gs.forEach(gp=>{ if(!gp.skWalls) return; const dx=cx-gp.cx, dz=cz-gp.cz, dd=Math.hypot(dx,dz);
    gp.skWalls.forEach(w=>{ const facing=!isTop&&(dx*w.n[0]+dz*w.n[1])>0.4*dd; w.m.opacity=facing?0.14:1; w.m.depthWrite=!facing; w.e.opacity=facing?0.35:1 }) });
  T3.groups=gs.filter(g=>!g.skWalls); try{ skDraw3DOrig() } finally { T3.groups=gs } };

/* ---------- history, measuring ---------- */
const skState=r=>JSON.stringify({dims:r.dims,openings:r.openings,name:r.name,poly:r.poly});
const skPushHistOrig=pushHist;
pushHist=function(r){ if(!skIsPoly(r)) return skPushHistOrig(r); const h=U.hist[r.id]||(U.hist[r.id]={u:[],r:[]}); h.u.push(skState(r)); if(h.u.length>40) h.u.shift(); h.r=[] };
const skRouteRoom=()=>{ const tp=top(); const p=tp&&tp.pid&&P(tp.pid); return {tp,p,r:p&&R(p,tp.rid)} };
const skUndoOrig=A.undo, skRedoOrig=A.redo;
A.undo=d=>{ const {p,r}=skRouteRoom(); if(!skIsPoly(r)) return skUndoOrig(d); const h=U.hist[r.id]; if(!h||!h.u.length) return;
  h.r.push(skState(r)); Object.assign(r,JSON.parse(h.u.pop())); touchRoom(p); U.toast=null; U.skDrag=null; closeSheet(true); toast(t('ed.undone')); render() };
A.redo=d=>{ const {p,r}=skRouteRoom(); if(!skIsPoly(r)) return skRedoOrig(d); const h=U.hist[r.id]; if(!h||!h.r.length) return;
  h.u.push(skState(r)); Object.assign(r,JSON.parse(h.r.pop())); touchRoom(p); render() };
const skApplyDimOrig=applyDim;
applyDim=function(p,r,dim,mm,src){ if(!skIsPoly(r)||!skDiagId(dim)) return skApplyDimOrig(p,r,dim,mm,src);
  pushHist(r); const d=r.dims[dim]; d.v=mm; d.src=src; delete d.pending; touchRoom(p); seen('confirmed');
  closeSheet(true); toast(t('ms.confirmed',{d:DIMNAME(dim),v:fmtLen(mm,null,true)+' '+M()}),{label:t('common.undo'),a:'undo'}); render() };
const skSelDimOrig=A.selDim;
A.selDim=d=>{ const {tp,p,r}=skRouteRoom(); if(!skIsPoly(r)) return skSelDimOrig(d);
  if(isLocked()){ openSheet({type:'locked'}); return } if(U.skEdit===r.id) return; const k=d.d; if(!r.dims[k]) return;
  const w=skGeo(r).walls.find(x=>x.id===k); if(w&&w.computed&&w.len!=null) toast(t('sk.computedTap',{w:k,v:fmtLen(w.len)}));
  if(tp.s==='editor'&&tp.mode!=='plan') tp.mode='plan'; U.skDiag=null; openMeasure(p.id,r.id,k) };
const skBackOrig=A.back; A.back=d=>{ U.skEdit=null; U.skDiag=null; U.skDrag=null; return skBackOrig(d) };
const skModeOrig=A.mode; A.mode=d=>{ U.skEdit=null; U.skDiag=null; U.skDrag=null; return skModeOrig(d) };
/* shared toolbar actions, only if the main file / wall-view module hasn't defined them */
if(!A.edHeight) A.edHeight=()=>{ if(isLocked()){ openSheet({type:'locked'}); return } const {p,r}=edRoom(); U.skEdit=null; U.skDiag=null; if(top().mode!=='plan') top().mode='plan'; openMeasure(p.id,r.id,'H') };
if(!A.edOpenings) A.edOpenings=()=>{ U.skEdit=null; U.skDiag=null; if(top().mode!=='plan') top().mode='plan'; A.tool({v:'door'}) };
if(!A.roomInfo) A.roomInfo=()=>{ U.skEdit=null; U.skDiag=null; A.tool({v:'room'}) };
if(!A.wallView) A.wallView=()=>{ toast(t('ed.tb.walls')+': '+t('sk.soon')); render() };

/* opening sheet for polygon rooms: any wall, corners numbered around the polygon */
const skOpSheetOrig=SHEETS.opening;
SHEETS.opening=sh=>{
  const p=P(sh.pid), r=R(p,sh.rid); if(!skIsPoly(r)) return skOpSheetOrig(sh);
  const F=U.form, type=F.otype, walls=roomWalls(r); let wi=walls.findIndex(w=>w.id===F.owall); if(wi<0){ wi=0; F.owall=walls[0].id }
  const wall=F.owall, corner=wi+1, nextC=(wi+1)%walls.length+1, errs={}, parsed={};
  [['ow','w',DIM_MAX.A],['oh','h',DIM_MAX.H],['ooff','off',DIM_MAX.A],['osill','sill',DIM_MAX.H]].forEach(([id,k,max])=>{ if(id==='osill'&&type!=='window') return;
    const res=id==='ooff'||id==='osill'?(()=>{ const x=parseDec(F[id],3); if(x.err) return {err:x.err==='precision'?t('err.precision',{n:3}):t('err.'+x.err)}; return {mm:Number(x.val)} })():lenErr(F[id],max);
    if(res.err) errs[id]=res.err; else parsed[k]=res.mm });
  let geoErr=null;
  if(!Object.keys(errs).length){ const o={id:sh.oid||'new',type,wall,w:parsed.w,h:parsed.h,off:parsed.off,sill:type==='window'?parsed.sill:0}; const iss=openingIssue(r,o,r.openings); if(iss){ geoErr=iss; seen('invalid') } }
  const L=wallLen(r,wall)||5000, w_=parsed.w||0, off=parsed.off||0, sx=280/L;
  const dia=`<svg viewBox="0 0 320 54" class="minidia" style="width:100%"><path d="M20 30H300" stroke="#0E1C36" stroke-width="6"/><circle cx="20" cy="30" r="5" fill="#1C4BD1"/><text x="20" y="16" text-anchor="middle" font-size="11" font-weight="600" fill="#1C4BD1">${corner}</text><text x="300" y="16" text-anchor="middle" font-size="11" fill="#3E4A61">${nextC}</text><rect x="${(20+off*sx).toFixed(1)}" y="25" width="${Math.max(2,w_*sx).toFixed(1)}" height="10" fill="#fff" stroke="${geoErr?'#B42318':'#1C4BD1'}" stroke-width="1.5"/><path d="M20 46H${(20+off*sx).toFixed(1)}" stroke="#1C4BD1" stroke-width="1.2"/><path d="M${(20+off*sx-5).toFixed(1)} 43l5 3-5 3" stroke="#1C4BD1" fill="none" stroke-width="1.2"/></svg>`;
  const body=`${sh.oid?'':`<div class="seg wide">${['door','window'].map(x=>`<button class="${type===x?'on':''}" data-a="setForm" data-k="otype" data-v="${x}">${esc(t(x==='door'?'op.door':'op.window'))}</button>`).join('')}</div>`}
    <div class="fld"><span class="lab">${esc(t('op.wall'))}</span><div class="choice sk-walls">${walls.map(w=>`<button class="opt ${wall===w.id?'on':''}" data-a="setForm" data-k="owall" data-v="${w.id}" aria-pressed="${wall===w.id}">${w.id} <small>${w.len!=null?fmtLen(w.len):'?'}</small></button>`).join('')}</div></div>
    ${dia}<span class="fhint">${esc(t('op.offsetHelp',{c:corner}))}</span>
    <div class="btnrow" style="align-items:start">${field('ow',t('op.width'),{num:true,suf:M(),err:errs.ow,next:'oh'})}${field('oh',t('op.height'),{num:true,suf:M(),err:errs.oh,next:'ooff'})}</div>
    <div class="btnrow" style="align-items:start">${field('ooff',t('op.offset',{c:corner}),{num:true,suf:M(),err:errs.ooff,next:type==='window'?'osill':''})}${type==='window'?field('osill',t('op.sill'),{num:true,suf:M(),err:errs.osill}):'<div style="flex:1"></div>'}</div>
    ${geoErr?`<div class="banner err" style="margin:0">${ic('alert','i s')}<span class="tx">${esc(geoErr.msg)}</span></div>`:''}
    ${sh.oid?'':`<p class="note">${ic('info','i s')}<span>${esc(t('re.sample'))}</span></p>`}`;
  const bad=Object.keys(errs).length||geoErr;
  const foot=`<div class="btnrow">${sh.oid?`<button class="btn danger" data-a="delOpening">${ic('trash','i s')}${esc(t('common.delete'))}</button>`:`<button class="btn sec" data-a="closeSheet">${esc(t('common.cancel'))}</button>`}<button class="btn pri ${bad?'dis':''}" data-a="saveOpening">${esc(t('common.save'))}</button></div>`;
  return sheetWrap(sh.oid?t(type==='door'?'op.door':'op.window'):t('op.new.'+type),body,foot);
};

/* ---------- poly editor ---------- */
function skHint(r,g){
  const iss=roomIssues(r);
  if(iss.length) return `<div class="banner err sk-hint">${ic('alert','i s')}<span class="tx">${esc(iss[0].iss.msg)}</span><button class="act" data-a="editOpening" data-id="${iss[0].o.id}">${esc(t('ed.fix'))}</button></div>`;
  const sol=g.sol, list=ix=>ix.map(i=>g.ids[i]).join(', ');
  if(sol.status==='conflict'){
    const msg=sol.reason==='negative'?t('sk.negative',{w:g.ids[sol.neg]}):sol.reason==='cross'?t('sk.crossSol'):t('sk.conflict',{w:list(sol.conflict),e:fmtLen(Math.round(sol.err),null,true)});
    const first=sol.conflict.length?g.ids[sol.conflict[0]]:null;
    return `<div class="banner err sk-hint">${ic('alert','i s')}<span class="tx">${esc(msg)}</span>${first?`<button class="act" data-a="selDim" data-d="${first}">${esc(t('ms.remeasure'))}</button>`:''}</div>` }
  const dw=g.diags.find(d=>d.st==='warn');
  if(dw) return `<div class="banner warn sk-hint">${ic('alert','i s')}<span class="tx">${esc(t('sk.diagWarn',{d:dw.id,e:fmtLen(Math.abs(dw.diff),null,true)}))}</span><button class="act" data-a="selDim" data-d="${dw.id}">${esc(t('ms.remeasure'))}</button></div>`;
  if(sol.status==='unresolved'){
    const msg=sol.either?t('sk.needEither',{a:g.ids[sol.either[0]],b:g.ids[sol.either[1]]}):sol.some?t('sk.needSome',{n:sol.some,w:list(sol.measure)}):t('sk.needN',{n:sol.measure.length,w:list(sol.measure)});
    return `<div class="hintline sk-hint"><button data-a="selDim" data-d="${g.ids[sol.measure[0]]}">${ic('dim','i s')}${esc(msg)}</button></div>` }
  const next=(g.walls.find(w=>w.st==='recv')||{}).id||(dimStatus(r.dims.H)!=='conf'?'H':null)||(g.diags.find(d=>d.st==='recv'||d.st==='unset')||{}).id;
  if(next) return `<div class="hintline sk-hint"><button data-a="selDim" data-d="${next}">${ic('dim','i s')}${esc(t('ed.next',{d:DIMNAME(next)}))}</button></div>`;
  const ar=areas(r), comp=g.walls.filter(w=>w.computed).map(w=>w.id);
  return `<div class="hintline sk-hint">${ic('check','i s')}<span>${esc(t('ed.allOk'))}${ar?`. ${esc(t('rp.floorArea'))} ${fmtArea(ar.floor)} ${M2()}`:''}${comp.length?`. ${esc(t('sk.computed',{w:comp.join(', ')}))}`:''}</span></div>`;
}
function skEditor(rt,p,r){
  const mode=rt.mode||'plan', f=p.floors.find(x=>x.id===r.floorId)||p.floors[0], h=U.hist[r.id]||{u:[],r:[]};
  const right=`<button class="ib" data-a="undo" ${h.u.length?'':'disabled'} aria-label="${esc(t('common.undo'))}">${ic('undo')}</button><button class="ib" data-a="redo" ${h.r.length?'':'disabled'} aria-label="redo">${ic('redo')}</button>`;
  const sub=`<div class="subbar"><div class="seg"><button class="${mode==='plan'?'on':''}" data-a="mode" data-v="plan">${esc(t('ed.plan'))}</button><button class="${mode==='3d'?'on':''}" data-a="mode" data-v="3d">3D</button></div><span class="sp"></span>${devChip()}</div>`;
  const msSel=U.sheet&&U.sheet.type==='measure'?U.sheet.dim:null, opSel=U.sheet&&U.sheet.type==='opening'?U.sheet.oid:null;
  const active=msSel==='H'?'edHeight':U.sheet&&U.sheet.type==='opening'?'edOpenings':U.sheet&&U.sheet.type==='roomProps'?'roomInfo':'';
  let body='';
  if(mode==='plan'){
    const g=skGeo(r), edit=U.skEdit===r.id, dg=U.skDiag&&U.skDiag.rid===r.id?U.skDiag:null, snap=S.settings.angleSnap!==false;
    const chip=k=>{ const d=r.dims[k],st=dimStatus(d),v=st==='recv'?fmtLen(d.pending.mm,null,true):st==='unset'?'?':fmtLen(d.v); return `<button class="chip ${st==='recv'?'recv':st==='unset'?'unset':''} ${msSel===k?'sel':''}" data-a="selDim" data-d="${k}">${esc(t(k==='H'?'ed.Hs':'ed.Ts'))} <b>${v}</b>${st==='unset'?'':' '+M()}${st==='conf'?ic('check','i xs'):st==='recv'?ic('clock','i xs'):''}</button>` };
    const snapBtn=`<button class="chip sk-snap" data-a="skSnap" aria-pressed="${snap}">${ic(snap?'boxok':'box','i xs')}${esc(t('sk.snap'))}</button>`;
    const head=edit?`<div class="chips sk-chips sk-bar">${ic('edit','i s')}<span class="sk-bartx">${esc(t('sk.editHint'))}</span>${snapBtn}<button class="btn pri sm" data-a="skEdit">${esc(t('common.done'))}</button></div>`
      :dg?`<div class="chips sk-chips sk-bar">${ic('dim','i s')}<span class="sk-bartx">${esc(t(dg.a==null?'sk.pick1':'sk.pick2'))}</span><button class="btn sec sm" data-a="skDiagMode">${esc(t('common.cancel'))}</button></div>`
      :`<div class="chips sk-chips">${chip('H')}${chip('T')}<button class="chip" data-a="skEdit">${ic('edit','i xs')}${esc(t('sk.edit'))}</button><button class="chip" data-a="skDiagMode">${ic('plus','i xs')}${esc(t('sk.check'))}</button></div>`;
    const sts=new Set(g.walls.map(w=>w.st).concat(g.diags.map(d=>d.st)));
    const leg=[sts.has('calc')?`<span><b>=</b> ${esc(t('sk.legC'))}</span>`:'',sts.has('bad')||sts.has('warn')?`<span><b>[ ]</b> ${esc(t('sk.legX'))}</span>`:'',sts.has('unres')?`<span><b>[?]</b> ${esc(t('sk.legU'))}</span>`:''].join('');
    body=`${head}<div class="canvas ${U.sheet?'top':''} ${edit?'sk-edit':''}">${planSVG(r,{sel:msSel,selOp:opSel,edit,diagPick:dg})}${leg&&!U.sheet?`<div class="sk-legend">${leg}</div>`:''}</div>${edit||dg?'':skHint(r,g)}${edToolbar(p,r,active)}`;
  } else {
    seen('3d'); const ready=room3DReady(r);
    const wc=['#ECE8E1','#D9D4CB','#D6E0EC','#E6D3B3'], fc=['#C49A6C','#8A6343','#B9BDC2','#A7A39C'];
    body=ready?`<div class="three" id="three"><span class="hint">${esc(t('3d.hint'))}</span></div><div class="ctl3d">
      <div class="btnrow"><button class="btn sec sm" data-a="preset" data-v="top">${esc(t('3d.top'))}</button><button class="btn sec sm" data-a="preset" data-v="corner">${esc(t('3d.corner'))}</button></div>
      <div class="swrow"><span>${esc(t('3d.walls'))}</span>${wc.map(c=>`<button class="sw ${r.colors.wall===c?'on':''}" style="background:${c}" data-a="color" data-k="wall" data-v="${c}" aria-label="${c}"></button>`).join('')}</div>
      <div class="swrow"><span>${esc(t('3d.floor'))}</span>${fc.map(c=>`<button class="sw ${r.colors.floor===c?'on':''}" style="background:${c}" data-a="color" data-k="floor" data-v="${c}" aria-label="${c}"></button>`).join('')}</div>
      <button class="btn pri full" data-a="saveView">${ic('camera','i s')}${esc(t('3d.save'))}</button><span class="fhint" style="text-align:center">${esc(t('3d.count',{n:r.views.length}))}</span></div>`
      :`<div class="empty"><h3>${esc(t('sk.need3d'))}</h3><button class="btn sec" data-a="mode" data-v="plan">${esc(t('ed.plan'))}</button></div>`;
  }
  return `<section class="page ${U.anim||''}">${bar({backIcon:true,title:dn(r.name),sub:t('ed.sub',{f:floorName(f),t:fmtLen(r.dims.T.v)}),right})}${sub}${body}</section>`;
}
const skEditorOrig=PAGES.editor;
PAGES.editor=rt=>{ const p=P(rt.pid), r=R(p,rt.rid); return skIsPoly(r)?skEditor(rt,p,r):skEditorOrig(rt) };

A.skEdit=()=>{ const {r}=edRoom(); if(U.skEdit===r.id){ U.skEdit=null; U.skDrag=null; render(); return } if(!guard()) return; closeSheet(true); U.skDiag=null; U.skEdit=r.id; render() };
A.skDiagMode=()=>{ const {r}=edRoom(); if(U.skDiag&&U.skDiag.rid===r.id){ U.skDiag=null; render(); return } if(!guard()) return; closeSheet(true); U.skEdit=null; U.skDiag={rid:r.id,a:null}; render() };
A.skPickCorner=d=>{ const {p,r}=edRoom(), dg=U.skDiag; if(!dg||!skIsPoly(r)) return; const i=Number(d.i), n=r.poly.verts.length;
  if(dg.a==null||dg.a===i){ dg.a=dg.a===i?null:i; render(); return }
  const a=Math.min(dg.a,i), b=Math.max(dg.a,i);
  if(b-a===1||(a===0&&b===n-1)){ toast(t('sk.diagAdj')); render(); return }
  if((r.poly.diags||[]).some(x=>x.a===a&&x.b===b)){ U.skDiag=null; toast(t('sk.diagDup')); render(); return }
  pushHist(r); let k=1; while(r.dims['X'+k]) k++; const id='X'+k; (r.poly.diags=r.poly.diags||[]).push({id,a,b}); r.dims[id]={v:null,src:null}; touchRoom(p); U.skDiag=null;
  toast(t('sk.diagAdded',{d:id,a:a+1,b:b+1})); openMeasure(p.id,r.id,id) };
A.skDelDiag=d=>{ const {p,r}=edRoom(); pushHist(r); r.poly.diags=r.poly.diags.filter(x=>x.id!==d.id); delete r.dims[d.id]; touchRoom(p); U.skDiag=null; toast(t('sk.diagDel',{d:d.id}),{label:t('common.undo'),a:'undo'}); render() };
A.skSnap=()=>{ S.settings.angleSnap=!(S.settings.angleSnap!==false); commit(); const tp=top(); if(tp&&tp.s==='sketch') skRecompute(tp); toast(t(S.settings.angleSnap?'sk.snapOn':'sk.snapOff')); render() };

/* corner drag with alignment guides and 45° snapping; the sketch changes, confirmed numbers don't */
function skDragTo(r,i,x,y,view){
  const V=r.poly.verts.map(v=>[v.x,v.y]), n=V.length, prev=V[(i-1+n)%n], next=V[(i+1)%n]; let p=[x,y], snapped=false; const guides=[];
  if(S.settings.angleSnap!==false){
    const ray=o=>{ const a=Math.atan2(p[1]-o[1],p[0]-o[0]), as=skSnapAng(a); return Math.abs(skNormAng(a-as))<0.14?as:null };
    const a1=ray(prev), a2=ray(next);
    if(a1!=null&&a2!=null){ const u1=skUnit(a1),u2=skUnit(a2), det=-u1[0]*u2[1]+u1[1]*u2[0];
      if(Math.abs(det)>1e-6){ const sd=(-(next[0]-prev[0])*u2[1]+(next[1]-prev[1])*u2[0])/det; if(sd>0){ p=[prev[0]+u1[0]*sd,prev[1]+u1[1]*sd]; snapped=true } } }
    if(!snapped){ const o=a1!=null?prev:a2!=null?next:null, a=a1!=null?a1:a2; if(o){ const u=skUnit(a), L=(p[0]-o[0])*u[0]+(p[1]-o[1])*u[1]; p=[o[0]+u[0]*L,o[1]+u[1]*L]; snapped=true } } }
  if(!snapped){ const tol=10/view.s; let bx=null,by=null;
    V.forEach((q,j)=>{ if(j===i) return; if(Math.abs(q[0]-p[0])<tol&&(bx==null||Math.abs(q[0]-p[0])<Math.abs(bx-p[0]))) bx=q[0]; if(Math.abs(q[1]-p[1])<tol&&(by==null||Math.abs(q[1]-p[1])<Math.abs(by-p[1]))) by=q[1] });
    if(bx!=null) p[0]=bx; if(by!=null) p[1]=by }
  p=[Math.round(p[0]/10)*10,Math.round(p[1]/10)*10];
  V.forEach((q,j)=>{ if(j===i) return; if(Math.abs(q[0]-p[0])<1&&!guides.some(g=>g.x===q[0])) guides.push({x:q[0]}); if(Math.abs(q[1]-p[1])<1&&!guides.some(g=>g.y===q[1])) guides.push({y:q[1]}) });
  return {p,guides};
}

/* ---------- sketch route ---------- */
function skMakeRoom(p,b,verts,template){
  const r=newRoom(b.fid,b.name,b.T); r.shape='poly'; r.template='poly'; r.poly={verts,diags:[],template};
  skWallIds(verts.length).forEach(id=>{ if(!r.dims[id]) r.dims[id]={v:null,src:null} });
  p.rooms.push(r); p.edited=Date.now(); S.lastOpen={pid:p.id,rid:r.id}; commit(); return r;
}
A.newSketchRoom=d=>{
  if(!guard()) return; const sh=U.sheet, p=sh&&P(sh.pid); if(!p) return; const F=U.form;
  if(!String(F.rname||'').trim()||lenFieldErr('rthick',DIM_MAX.T)){ U.submitTry=true; render(); return }
  const b={pid:p.id,fid:F.rfloor||p.floors[0].id,name:keyIfSame(F.rname.trim(),'@smp.living'),T:lenErr(F.rthick,DIM_MAX.T).mm}; blur();
  if(d.v==='lshape'){ const r=skMakeRoom(p,b,SK_LSHAPE.map(([x,y])=>({x,y})),'lshape'); closeSheet(true); toast(t('sk.created',{n:dn(r.name)})); push({s:'editor',pid:p.id,rid:r.id,mode:'plan'}); return }
  closeSheet(true); push(Object.assign({s:'sketch',mode:'draw',raw:null,taps:[],res:null,closed:false},b));
};
function skRecompute(rt){
  const snap=S.settings.angleSnap!==false, taps=rt.taps||[];
  if(rt.mode==='tap') rt.res=taps.length>=2||rt.closed?skProcess(taps,{tap:true,closed:rt.closed,snap}):null;
  else rt.res=rt.raw?skProcess(rt.raw,{closed:rt.closed,snap}):null;
  if(rt.res&&rt.res.closed&&!rt.res.err) rt.res.verts=skOrient(rt.res.verts);
}
function skDemoStroke(){ // wobbly hand-drawn L-shape, in pad units (1 = 25 mm)
  const C=[[60,60],[180,60],[180,120],[300,120],[300,260],[60,260],[63,67]], pts=[]; let k=0;
  for(let i=0;i<C.length-1;i++){ const a=C[i],b=C[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]),m=Math.max(2,Math.round(L/5)),ux=(b[0]-a[0])/L,uy=(b[1]-a[1])/L;
    for(let j=0;j<m;j++){ const f=j/m, w=2.4*Math.sin(k*0.45)+1.3*Math.sin(k*1.7+i), c=j<2&&i>0?2.5:0; k++; pts.push([Math.round((a[0]+ux*L*f-uy*w+ux*c)*10)/10,Math.round((a[1]+uy*L*f+ux*w+uy*c)*10)/10]) } }
  pts.push(C[C.length-1].slice()); return pts }
const skPathD=pts=>'M'+pts.map(skP).join('L');
function skPadSVG(rt){
  const res=rt.res, taps=rt.taps||[], ink='#0E1C36', cob='#1C4BD1', red='#B42318', amb='#9A4D00'; let g='';
  if(rt.raw&&rt.raw.length>1) g+=`<path d="${skPathD(rt.raw)}" fill="none" stroke="#9AA8BF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`;
  if(rt.mode==='tap') taps.forEach((p,i)=>{ g+=i===0&&taps.length>=3&&!rt.closed?`<circle cx="${skF(p[0])}" cy="${skF(p[1])}" r="14" fill="rgba(28,75,209,.1)" stroke="${cob}" stroke-dasharray="3 3"/>`:''; g+=`<circle cx="${skF(p[0])}" cy="${skF(p[1])}" r="3" fill="#9AA8BF"/>` });
  if(res&&res.verts&&res.verts.length>1){ const V=res.verts, bad=res.err==='cross', col=bad?red:ink;
    g+=`<path d="${skPathD(V)}${res.closed?'Z':''}" fill="${res.closed&&!res.err?'rgba(28,75,209,.07)':'none'}" stroke="${col}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round" ${bad?'stroke-dasharray="7 5"':''}/>`;
    V.forEach(p=>{ g+=`<circle cx="${skF(p[0])}" cy="${skF(p[1])}" r="4.5" fill="#FFFFFF" stroke="${col}" stroke-width="2"/>` });
    if(res.closed&&!res.err){ const ids=skWallIds(V.length); V.forEach((p,i)=>{ const q=V[(i+1)%V.length], L=Math.hypot(q[0]-p[0],q[1]-p[1])||1, m=[(p[0]+q[0])/2-(q[1]-p[1])/L*14,(p[1]+q[1])/2+(q[0]-p[0])/L*14];
      g+=`<circle cx="${skF(m[0])}" cy="${skF(m[1])}" r="9" fill="#FFFFFF" stroke="#3E4A61"/><text x="${skF(m[0])}" y="${skF(m[1]+4)}" text-anchor="middle" font-size="11" font-weight="600" fill="${ink}">${ids[i]}</text>` }) }
    if(!res.closed){ const a=V[0], b=V[V.length-1];
      g+=`<path d="M${skP(b)}L${skP(a)}" stroke="${amb}" stroke-width="1.5" stroke-dasharray="3 4"/><g role="img" aria-label="start"><circle cx="${skF(a[0])}" cy="${skF(a[1])}" r="8" fill="${cob}"/><circle cx="${skF(a[0])}" cy="${skF(a[1])}" r="3" fill="#FFFFFF"/></g><g role="img" aria-label="end"><circle cx="${skF(b[0])}" cy="${skF(b[1])}" r="8" fill="#FFFFFF" stroke="${cob}" stroke-width="2.5"/></g>` }
    if(bad&&res.x) g+=`<circle cx="${skF(res.x[0])}" cy="${skF(res.x[1])}" r="11" fill="#FDEDEB" stroke="${red}" stroke-width="2"/><path d="M${skF(res.x[0]-4)} ${skF(res.x[1]-4)}L${skF(res.x[0]+4)} ${skF(res.x[1]+4)}M${skF(res.x[0]+4)} ${skF(res.x[1]-4)}L${skF(res.x[0]-4)} ${skF(res.x[1]+4)}" stroke="${red}" stroke-width="2"/>` }
  return `<svg class="sk-draw" viewBox="0 0 ${SK_VW} ${SK_VH}" role="img" aria-label="${esc(t('sk.title'))}" style="overflow:visible"><defs><clipPath id="skLc"><circle id="skLcC" cx="-99" cy="-99" r="42"/></clipPath></defs><g id="skInk"><g id="skRes">${g}</g><path id="skStroke" d="" fill="none" stroke="${cob}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></g><g id="skLoupe" display="none" pointer-events="none"><circle class="skLb" r="42" fill="#FFFFFF"/><g clip-path="url(#skLc)"><use id="skLuse" href="#skInk"/></g><circle class="skLb" r="42" fill="none" stroke="${ink}" stroke-width="1.5"/><path id="skLx" d="" stroke="${cob}" stroke-width="1.2"/></g></svg>`;
}
PAGES.sketch=rt=>{
  const p=P(rt.pid); if(!p) return PAGES.projects();
  const mode=rt.mode||'draw', res=rt.res, taps=rt.taps||[], snap=S.settings.angleSnap!==false, has=!!(rt.raw||taps.length), ok=!!(res&&!res.err&&res.closed&&res.verts.length>=3);
  const sub=`<div class="subbar"><div class="seg">${[['draw','sk.draw'],['tap','sk.tap']].map(([k,lab])=>`<button class="${mode===k?'on':''}" data-a="skMode" data-v="${k}" aria-pressed="${mode===k}">${esc(t(lab))}</button>`).join('')}</div><span class="sp"></span>${mode==='tap'&&taps.length&&!rt.closed?`<button class="ib" data-a="skUndoTap" aria-label="${esc(t('sk.undoTap'))}">${ic('undo')}</button>`:''}<button class="chip sk-snap" data-a="skSnap" aria-pressed="${snap}">${ic(snap?'boxok':'box','i xs')}${esc(t('sk.snap'))}</button></div>`;
  const tip=!has?`<div class="sk-tip">${ic(mode==='tap'?'plus':'edit','i s')}<span>${esc(t(mode==='tap'?'sk.tapHint':'sk.drawHint'))}</span></div>`:'';
  let msg;
  if(res&&res.err) msg=`<div class="banner ${res.err==='cross'?'err':'warn'} sk-msg">${ic('alert','i s')}<span class="tx">${esc(t('sk.'+res.err))}</span><button class="act" data-a="skRedraw">${esc(t('sk.redraw'))}</button></div>`;
  else if(res&&!res.closed) msg=`<div class="banner warn sk-msg">${ic('info','i s')}<span class="tx">${esc(t('sk.open'))}</span>${res.verts.length>=3?`<button class="act" data-a="skClose">${esc(t('sk.close'))}</button>`:''}</div>`;
  else if(ok) msg=`<div class="hintline">${ic('check','i s')}<span>${esc(t('sk.ready',{n:res.verts.length}))}</span></div>`;
  else msg=`<div class="hintline"><span>${esc(t(mode==='tap'?'sk.tapHint':'sk.drawHint'))}</span></div>`;
  const foot=`<div class="footer"><button class="simbtn" data-a="skDemo">${ic('edit')}${esc(t('sk.demo'))} ${simtag()}</button><div class="btnrow"><button class="btn sec ${has?'':'dis'}" data-a="skRedraw">${ic('undo','i s')}${esc(t('sk.redraw'))}</button><button class="btn pri ${ok?'':'dis'}" data-a="skCreate">${esc(t('nr.create'))}</button></div></div>`;
  return `<section class="page ${U.anim||''}">${bar({close:true,title:t('sk.title'),sub:dn(rt.name)})}${sub}<div class="canvas sk-pad">${skPadSVG(rt)}${tip}</div>${msg}${foot}</section>`;
};
const skReset=rt=>{ rt.raw=null; rt.taps=[]; rt.res=null; rt.closed=false };
A.skMode=d=>{ const rt=top(); if(rt.s!=='sketch') return; rt.mode=d.v; skReset(rt); render() };
A.skRedraw=()=>{ const rt=top(); if(rt.s!=='sketch') return; skReset(rt); render() };
A.skDemo=()=>{ const rt=top(); if(rt.s!=='sketch') return; skReset(rt); rt.mode='draw'; rt.raw=skDemoStroke(); skRecompute(rt); render() };
A.skClose=()=>{ const rt=top(); if(rt.s!=='sketch') return; if(rt.mode!=='tap'&&rt.res&&rt.res.verts) rt.raw=rt.raw||rt.res.verts; rt.closed=true; skRecompute(rt); render() };
A.skUndoTap=()=>{ const rt=top(); if(rt.s!=='sketch') return; (rt.taps||[]).pop(); rt.closed=false; skRecompute(rt); render() };
A.skCreate=()=>{
  if(!guard()) return; const rt=top(); const res=rt.res; if(rt.s!=='sketch'||!res||res.err||!res.closed) return; const p=P(rt.pid);
  let V=res.verts.map(([x,y])=>[Math.round(x*SK_PX/10)*10,Math.round(y*SK_PX/10)*10]).filter((q,i,a)=>{ const o=a[(i+1)%a.length]; return q[0]!==o[0]||q[1]!==o[1] });
  V=skOrient(V); if(V.length<3||skSelfX(V,true)){ toast(t('sk.cross')); render(); return }
  const r=skMakeRoom(p,{fid:rt.fid,name:rt.name,T:rt.T},V.map(([x,y])=>({x,y})),'sketch');
  stack().pop(); toast(t('sk.created',{n:dn(r.name)})); push({s:'editor',pid:p.id,rid:r.id,mode:'plan'});
};

/* ---------- pointer input: drawing, tapping corners, dragging corners ---------- */
let skPtr=null, skRaf=0;
const skSchedule=()=>{ if(!skRaf) skRaf=requestAnimationFrame(()=>{ skRaf=0; render() }) };
function skPadPoint(svg,e){ const rc=svg.getBoundingClientRect(), sc=Math.min(rc.width/SK_VW,rc.height/SK_VH)||1, ox=rc.left+(rc.width-SK_VW*sc)/2, oy=rc.top+(rc.height-SK_VH*sc)/2; return [Math.round((e.clientX-ox)/sc*10)/10,Math.round((e.clientY-oy)/sc*10)/10] }
function skLoupeAt(svg,p){
  const lp=svg.querySelector('#skLoupe'); if(!lp) return; if(!p){ lp.setAttribute('display','none'); return }
  const Lx=Math.max(44,Math.min(SK_VW-44,p[0])), Ly=p[1]>120?p[1]-92:p[1]+92; lp.removeAttribute('display');
  lp.querySelectorAll('.skLb').forEach(c=>{ c.setAttribute('cx',Lx); c.setAttribute('cy',Ly) }); const cc=svg.querySelector('#skLcC'); if(cc){ cc.setAttribute('cx',Lx); cc.setAttribute('cy',Ly) }
  const u=svg.querySelector('#skLuse'); if(u) u.setAttribute('transform',`translate(${Lx} ${Ly}) scale(2) translate(${-p[0]} ${-p[1]})`);
  const x=svg.querySelector('#skLx'); if(x) x.setAttribute('d',`M${Lx-8} ${Ly}H${Lx+8}M${Lx} ${Ly-8}V${Ly+8}`);
}
appEl.addEventListener('pointerdown',e=>{
  if(e.button>0||skPtr) return;
  const pad=e.target.closest&&e.target.closest('.sk-draw');
  if(pad){ const rt=top(); if(!rt||rt.s!=='sketch') return; e.preventDefault(); const p=skPadPoint(pad,e);
    skPtr={kind:rt.mode==='tap'?'tap':'draw',id:e.pointerId,svg:pad,pts:[p],c0:[e.clientX,e.clientY]}; try{ pad.setPointerCapture(e.pointerId) }catch(_){}
    if(skPtr.kind==='draw'){ const rs=pad.querySelector('#skRes'); if(rs) rs.setAttribute('display','none'); const tp=appEl.querySelector('.sk-tip'); if(tp) tp.style.display='none'; skLoupeAt(pad,p) }
    return }
  const hnd=e.target.closest&&e.target.closest('[data-skv]');
  if(hnd){ const {p,r}=skRouteRoom(); if(!skIsPoly(r)||U.skEdit!==r.id) return; if(isLocked()){ openSheet({type:'locked'}); return }
    const v=U.skView; if(!v||v.rid!==r.id) return; e.preventDefault();
    U.skDrag={rid:r.id,pid:p.id,i:Number(hnd.dataset.skv),view:Object.assign({},v),orig:clone(r.poly.verts),moved:false,guides:[]}; skPtr={kind:'drag',id:e.pointerId}; render() }
});
window.addEventListener('pointermove',e=>{
  if(!skPtr||e.pointerId!==skPtr.id) return;
  if(skPtr.kind==='draw'){ const p=skPadPoint(skPtr.svg,e), l=skPtr.pts[skPtr.pts.length-1]; if(Math.hypot(p[0]-l[0],p[1]-l[1])<1.5) return; skPtr.pts.push(p);
    const path=skPtr.svg.querySelector('#skStroke'); if(path) path.setAttribute('d',skPathD(skPtr.pts)); skLoupeAt(skPtr.svg,p); return }
  if(skPtr.kind==='drag'){ const d=U.skDrag; if(!d) return; const p=P(d.pid), r=R(p,d.rid), svg=appEl.querySelector('.sk-plan'); if(!r||!svg) return;
    const v=d.view, rc=svg.getBoundingClientRect(), sc=Math.min(rc.width/v.VW,rc.height/v.VH)||1, ox=rc.left+(rc.width-v.VW*sc)/2, oy=rc.top+(rc.height-v.VH*sc)/2;
    const res=skDragTo(r,d.i,((e.clientX-ox)/sc-v.ox)/v.s,((e.clientY-oy)/sc-v.oy)/v.s,v), o=d.orig[d.i];
    if(!d.moved){ if(Math.hypot(res.p[0]-o.x,res.p[1]-o.y)<10) return; pushHist(r); d.moved=true }
    r.poly.verts[d.i]={x:res.p[0],y:res.p[1]}; d.guides=res.guides; skSchedule() }
});
function skUp(e){
  if(!skPtr||e.pointerId!==skPtr.id) return; const k=skPtr; skPtr=null; const rt=top();
  if(k.kind==='draw'&&rt&&rt.s==='sketch'){ rt.raw=k.pts.map(p=>[Math.round(p[0]),Math.round(p[1])]); rt.taps=[]; rt.closed=false; skRecompute(rt); render(); return }
  if(k.kind==='tap'&&rt&&rt.s==='sketch'){ if(e.type==='pointercancel'||Math.hypot(e.clientX-k.c0[0],e.clientY-k.c0[1])>10||rt.closed) return; const p=k.pts[0]; rt.taps=rt.taps||[];
    if(rt.taps.length>=3&&Math.hypot(p[0]-rt.taps[0][0],p[1]-rt.taps[0][1])<22) rt.closed=true; else rt.taps.push([Math.round(p[0]),Math.round(p[1])]);
    skRecompute(rt); render(); return }
  if(k.kind==='drag'){ const d=U.skDrag; U.skDrag=null; if(!d) return; const p=P(d.pid), r=R(p,d.rid);
    if(r&&d.moved){ const V=r.poly.verts.map(v=>[v.x,v.y]);
      if(skSelfX(V,true)||skArea(V)<=0){ r.poly.verts=d.orig; const h=U.hist[r.id]; if(h&&h.u.length) h.u.pop(); toast(t('sk.crossDrag')) } else touchRoom(p) }
    render() }
}
window.addEventListener('pointerup',skUp); window.addEventListener('pointercancel',skUp);
