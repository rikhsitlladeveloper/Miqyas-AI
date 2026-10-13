/* ============================== auth (opening animation, welcome, sign up, log in, forgot password) ==============================
   Adapted from the "Log in, Registration, Onboarding / Sign in & Sign up / Forgot password" community kit:
   welcome → create account (3 steps) → success; log in with error states; forgot password (3 steps) → success.
   METRX changes: phone number + SMS code instead of email (phone-first market), Google as the one social option,
   and "Continue without an account" because the offline core never needs one. The server, SMS and Google are simulated. */
Object.assign(D,{
'au.welcome':['Ish joyida o‘lchash va smeta','Замеры и сметы прямо на объекте','Measurements and estimates, on site'],
'au.tagline':['Xonani lazer bilan o‘lchang, chizmasini ko‘ring va smetani ⟦PDF⟧ qilib yuboring.','Измеряйте комнаты лазером, смотрите чертёж и отправляйте смету в PDF.','Measure rooms with a laser, check the drawing and send the estimate as a PDF.'],
'au.google':['⟦Google⟧ orqali davom etish','Продолжить с Google','Continue with Google'],
'au.signup':['Hisob yaratish','Создать аккаунт','Create an account'],
'au.login':['Kirish','Войти','Log in'],
'au.or':['yoki','или','or'],
'au.skip':['Hisobsiz davom etish','Продолжить без аккаунта','Continue without an account'],
'au.skipNote':['Ilova to‘liq ishlaydi. Loyihalar shu telefonda saqlanadi.','Всё работает. Проекты хранятся на этом телефоне.','Everything works. Projects are saved on this phone.'],
'au.terms':['Davom etib, Foydalanish shartlari va Maxfiylik siyosatiga rozilik bildirasiz.','Продолжая, вы принимаете Условия использования и Политику конфиденциальности.','By continuing, you agree to the Terms of Use and Privacy Policy.'],
'au.skipAnim':['Animatsiyani o‘tkazib yuborish','Пропустить анимацию','Skip animation'],
'su.phoneTitle':['Ism va telefon raqamingiz','Имя и номер телефона','Your name and phone'],
'su.phoneBody':['Raqamingizga ⟦SMS⟧ orqali kod yuboramiz. Ism va raqam hisobotlarda chiqadi.','Мы отправим код в SMS. Имя и номер появятся в отчётах.','We’ll text you a code. Your name and number appear on reports.'],
'su.sendCode':['Kod yuborish','Отправить код','Send code'],
'su.have':['Hisobingiz bormi?','Уже есть аккаунт?','Already have an account?'],
'vc.title':['Kodni kiriting','Введите код','Enter the code'],
'vc.body':['{p} raqamiga 6 xonali kod yubordik.','Мы отправили 6-значный код на {p}.','We sent a 6-digit code to {p}.'],
'vc.resendIn':['Kodni qayta yuborish: {t}','Отправить снова через {t}','Resend code in {t}'],
'vc.resend':['Kodni qayta yuborish','Отправить код снова','Resend code'],
'vc.sent':['Yangi kod yuborildi','Новый код отправлен','New code sent'],
'vc.change':['Raqamni o‘zgartirish','Изменить номер','Change number'],
'vc.wrong':['Kod noto‘g‘ri. ⟦SMS⟧ dagi kodni tekshiring.','Неверный код. Проверьте код в SMS.','That code is wrong. Check the code in the text message.'],
'vc.verify':['Tasdiqlash','Подтвердить','Confirm'],
'vc.fromSms':['⟦SMS⟧ dan: {c}','Из SMS: {c}','From Messages: {c}'],
'vc.sim':['⟦SMS⟧ yuborilmaydi. Sinov kodi: {c}','SMS не отправляется. Тестовый код: {c}','No text is sent. Test code: {c}'],
'pw.title':['Parol o‘ylab toping','Придумайте пароль','Create a password'],
'pw.body':['Boshqa telefonda hisobingizga kirish uchun kerak bo‘ladi.','Он нужен, чтобы войти в аккаунт на другом телефоне.','You’ll need it to log in on another phone.'],
'pw.label':['Parol','Пароль','Password'],
'pw.req':['Parolni kiriting','Введите пароль','Enter your password'],
'pw.show':['Ko‘rsatish','Показать','Show'],
'pw.hide':['Yashirish','Скрыть','Hide'],
'pw.r1':['Kamida 8 ta belgi','Не менее 8 символов','At least 8 characters'],
'pw.r2':['Kamida bitta raqam','Хотя бы одна цифра','At least one number'],
'pw.r3':['Kamida bitta harf','Хотя бы одна буква','At least one letter'],
'pw.strength':['Parol: {s}','Пароль: {s}','Password: {s}'],
'pw.weak':['zaif','слабый','weak'],
'pw.ok':['yaxshi','хороший','good'],
'pw.strong':['kuchli','надёжный','strong'],
'su.doneT':['Hisob yaratildi','Аккаунт создан','Account created'],
'su.doneB':['Obuna shu hisobga bog‘lanadi. Loyihalar avvalgidek shu telefonda saqlanadi, yangi telefonga zaxira nusxa orqali o‘tkaziladi.','Подписка привязана к этому аккаунту. Проекты по-прежнему хранятся на этом телефоне; на новый телефон их переносят через резервную копию.','Your subscription is linked to this account. Projects stay on this phone; move them to a new phone with a backup.'],
'li.title':['Hisobingizga kiring','Войдите в аккаунт','Log in to your account'],
'li.forgot':['Parolni unutdingizmi?','Забыли пароль?','Forgot password?'],
'li.noAcc':['Hisobingiz yo‘qmi?','Нет аккаунта?','No account yet?'],
'li.checking':['Tekshirilmoqda…','Проверяем…','Checking…'],
'li.demo':['Sinov hisobi: {p}, parol {w}','Тестовый аккаунт: {p}, пароль {w}','Test account: {p}, password {w}'],
'li.welcomeBack':['Xush kelibsiz, {n}','С возвращением, {n}','Welcome back, {n}'],
'auerr.wrong':['Telefon raqami yoki parol noto‘g‘ri.','Неверный номер телефона или пароль.','The phone number or password is wrong.'],
'auerr.offline':['Internet yo‘q. Kirish uchun internet kerak, lekin hisobsiz ishlashda davom etishingiz mumkin.','Нет интернета. Для входа нужен интернет, но можно работать без аккаунта.','No internet. Logging in needs a connection, but you can keep working without an account.'],
'auerr.exists':['Bu raqamga hisob allaqachon ochilgan.','С этим номером уже есть аккаунт.','There’s already an account with this number.'],
'auerr.unknown':['Bu raqamga hisob ochilmagan.','Аккаунт с этим номером не найден.','There’s no account with this number.'],
'fp.title':['Parolni tiklash','Восстановление пароля','Reset your password'],
'fp.body':['Hisobingiz raqamini kiriting. Unga ⟦SMS⟧ orqali kod yuboramiz.','Введите номер аккаунта. Мы отправим на него код в SMS.','Enter your account’s phone number and we’ll text you a code.'],
'fp.newTitle':['Yangi parol','Новый пароль','New password'],
'fp.newBody':['Eski parol endi ishlamaydi.','Старый пароль перестанет работать.','Your old password will stop working.'],
'fp.repeat':['Parolni takrorlang','Повторите пароль','Repeat password'],
'fp.mismatch':['Parollar bir xil emas','Пароли не совпадают','The passwords don’t match'],
'fp.save':['Parolni saqlash','Сохранить пароль','Save password'],
'fp.doneT':['Parol yangilandi','Пароль изменён','Password updated'],
'fp.doneB':['Endi yangi parol bilan kiring.','Теперь войдите с новым паролем.','Log in with your new password.'],
'gg.title':['Hisobni tanlang','Выберите аккаунт','Choose an account'],
'gg.sub':['⟦METRX⟧ ilovasiga kirish uchun','чтобы продолжить в METRX','to continue to METRX'],
'gg.other':['Boshqa hisobdan foydalanish','Использовать другой аккаунт','Use another account'],
'gg.note':['⟦Google⟧ ismingiz va elektron pochtangizni ⟦METRX⟧ bilan ulashadi.','Google передаст METRX ваше имя и адрес электронной почты.','Google will share your name and email address with METRX.'],
'gp.title':['Telefon raqamingiz','Ваш номер телефона','Your phone number'],
'gp.body':['⟦Google⟧ raqamni bermaydi. U hisobot va takliflarda mijozlar uchun chiqadi.','Google не передаёт номер. Он появится в отчётах и предложениях для клиентов.','Google doesn’t share your number. It appears on reports and quotes for customers.'],
'ac.group':['Hisob','Аккаунт','Account'],
'ac.signIn':['Kirish yoki hisob yaratish','Войти или создать аккаунт','Log in or create an account'],
'ac.noneB':['Ilova hisobsiz ham to‘liq ishlaydi','Приложение работает и без аккаунта','The app works fully without one'],
'ac.viaG':['⟦Google⟧ orqali kirilgan','Вход через Google','Signed in with Google'],
'ac.viaP':['Telefon raqami orqali kirilgan','Вход по номеру телефона','Signed in with phone number'],
'ac.out':['Hisobdan chiqish','Выйти из аккаунта','Log out'],
'ac.outQ':['Hisobdan chiqilsinmi?','Выйти из аккаунта?','Log out?'],
'ac.outB':['Loyihalar shu telefonda qoladi. Istalgan payt qayta kirishingiz mumkin.','Проекты останутся на этом телефоне. Войти снова можно в любой момент.','Your projects stay on this phone. You can log in again any time.'],
'ac.outDone':['Hisobdan chiqildi. Loyihalar shu telefonda qoldi.','Вы вышли. Проекты остались на этом телефоне.','Logged out. Your projects are still on this phone.'],
'ac.signedG':['⟦Google⟧ hisobi ulandi','Аккаунт Google подключён','Google account connected']
});
const SMS_CODE='482913', AUTH_KEY='metrx-auth-db';
const LSHORT={uz:'O‘zbekcha',uzc:'Ўзбекча',ru:'Русский',en:'English'};
const GLOGO=`<svg viewBox="0 0 18 18" aria-hidden="true"><path fill="#EA4335" d="M9 3.48c1.69 0 2.83.73 3.48 1.34l2.54-2.48C13.46.89 11.43 0 9 0 5.48 0 2.44 2.02.96 4.96l2.91 2.26C4.6 5.05 6.62 3.48 9 3.48z"/><path fill="#4285F4" d="M17.64 9.2c0-.74-.06-1.28-.19-1.84H9v3.34h4.96c-.1.83-.64 2.08-1.84 2.92l2.84 2.2c1.7-1.57 2.68-3.88 2.68-6.62z"/><path fill="#FBBC05" d="M3.88 10.78A5.54 5.54 0 0 1 3.58 9c0-.62.11-1.22.29-1.78L.96 4.96A9 9 0 0 0 0 9c0 1.45.35 2.82.96 4.04l2.92-2.26z"/><path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.84-2.2c-.76.53-1.78.9-3.12.9-2.38 0-4.4-1.57-5.12-3.74L.97 13.04C2.45 15.98 5.48 18 9 18z"/></svg>`;
const reduceMotion=()=>{ try{ return matchMedia('(prefers-reduced-motion: reduce)').matches }catch(e){ return false } };

/* simulated account server: phone → {name, pw}; one test account is always present */
function authDb(){ let db=null; try{ db=JSON.parse(localStorage.getItem(AUTH_KEY)||'null') }catch(e){} if(!db||typeof db!=='object') db={}; if(!db['935551234']) db['935551234']={name:'@smp.builder',pw:'metrx2026'}; return db }
function authSave(db){ try{ localStorage.setItem(AUTH_KEY,JSON.stringify(db)) }catch(e){} }
const pwRules=v=>{ v=String(v||''); return {len:v.length>=8,num:/\d/.test(v),let:/\p{L}/u.test(v)} };
const pwOk=v=>{ const r=pwRules(v); return r.len&&r.num&&r.let };
function pwScore(v){ v=String(v||''); if(!v) return 0; const r=pwRules(v); let s=(r.len?1:0)+(r.num&&r.let?1:0)+(r.len&&(v.length>=12||/[^\p{L}\d]/u.test(v))?1:0); return Math.max(1,s) }
const initials=n=>String(n||'?').trim().split(/\s+/).map(x=>x[0]||'').join('').slice(0,2).toUpperCase();

function auStep(){ const s=S.firstRunStep; return s===2?'local':(s==null||s===1)?'splash':s }
function auGo(step,dir,focus){ S.firstRunStep=step; U.auErr=null; U.codeErr=null; U.resent=false; U.showPw=false; U.gpick=false; U.langMenu=false; blur(); if(focus) setFocus(focus[0],focus[1],focus[2]||''); U.anim=dir==='back'?'pop':'push'; commit(); render() }
function auExit(){ const fromProf=S.authFromProfile; S.firstRun=false; delete S.firstRunStep; delete S.authFromProfile; U.gpick=false; U.langMenu=false; U.su=null; U.fp=null; blur(); if(fromProf){ S.nav.tab='profile'; S.nav.stacks.profile=[{s:'profile'}] } U.anim=null; commit(); render() }
function auSignIn(acc,msg){ S.account=acc; const b=S.settings.builder; if(!b.name&&acc.name) b.name=dn(acc.name); if(!b.phone&&acc.phone) b.phone=acc.phone; auExit(); if(msg){ toast(msg); render() } }
function auNet(){ if(S.demo.offline){ U.auErr='offline'; blur(); render(); return false } return true }
const AU_BACK={su1:'welcome',su2:'su1',su3:'su1',li:'welcome',fp1:'li',fp2:'fp1',fp3:'fp1',local:'welcome',gphone:'welcome',fpDone:'li'};
function auBack(){
  if(U.gpick){ U.gpick=false; render(); return true }
  if(U.langMenu){ U.langMenu=false; render(); return true }
  const s=auStep();
  if(s==='splash'){ A.auSplashDone(); return true }
  if(s==='welcome'){ if(S.authFromProfile){ auExit(); return true } return false }
  if(s==='suDone'){ auExit(); return true }
  if(s==='fpDone'){ A.auToLogin(); return true }
  const b=AU_BACK[s];
  /* going back to a phone step keeps what was already typed there */
  if(b==='su1'&&U.su) initForm({bname:U.su.name,bphone:U.su.phone});
  if(b==='fp1'&&U.fp) initForm({fpphone:U.fp.phone});
  if(b){ auGo(b,'back'); return true }
  return false;
}

/* ---------- pieces ---------- */
function auPlan(splash){
  const F='IBM Plex Sans Condensed,IBM Plex Sans,sans-serif';
  return `<svg class="au-plan" viewBox="0 0 300 220" aria-hidden="true">
  <g class="w-dimx" stroke="#8FB0FF" stroke-width="1.4" fill="none"><path d="M60 44V20M240 44V20M60 28H240M55 33l10-10M235 33l10-10"/></g>
  <g class="w-dimy" stroke="#8FB0FF" stroke-width="1.4" fill="none"><path d="M246 50H270M246 194H270M262 50V194M257 55l10-10M257 199l10-10"/></g>
  <path class="w-walls" pathLength="1" d="M222 194H240V50H60V194H190" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="square"/>
  <g class="w-open" fill="none" stroke="#8FB0FF" stroke-width="1.5"><rect x="56.5" y="100" width="7" height="43" fill="#0E1C36"/><path d="M60 100V143"/><path d="M190 194V162A32 32 0 0 1 222 194" stroke-dasharray="3 3"/></g>
  <g class="w-lab" font-family="${F}" font-weight="600" font-size="13" fill="#fff" text-anchor="middle"><rect x="127" y="19" width="46" height="18" rx="3" fill="#0E1C36"/><text x="150" y="32.5">${fmtLen(5000)}</text><g transform="translate(262 122) rotate(-90)"><rect x="-23" y="-9" width="46" height="18" rx="3" fill="#0E1C36"/><text y="4.5">${fmtLen(4000)}</text></g></g>
  ${splash?`<g class="w-laser"><rect x="64" y="74" width="9" height="12" rx="2" fill="#FFB547"/><path class="w-beam" pathLength="1" d="M73 80H236" stroke="#FFB547" stroke-width="1.6"/><circle class="w-dot" cx="236" cy="80" r="3.5" fill="#FFB547"/><g class="w-read"><rect x="102" y="90" width="96" height="22" rx="11" fill="#FFB547"/><text id="spVal" x="150" y="105.5" text-anchor="middle" font-family="${F}" font-weight="600" font-size="13" fill="#0E1C36">${fmtLen(5000,null,true)} ${esc(M())}</text></g></g>`:''}
  </svg>`;
}
function auErrH(){
  const s=auStep(); const k=U.auErr||(S.demo.offline&&s==='welcome'?'offline':null); if(!k) return '';
  const act=k==='exists'?`<button class="act" data-a="auTo" data-v="li">${esc(t('au.login'))}</button>`:k==='unknown'?`<button class="act" data-a="auTo" data-v="su1">${esc(t('au.signup'))}</button>`:'';
  return `<div class="banner ${k==='offline'?'':'err'}" role="alert">${ic(k==='offline'?'plane':'alert','i s')}<span class="tx">${esc(t('auerr.'+k))}</span>${act}</div>`;
}
const pwTgl=()=>`<button type="button" class="pwtgl" data-a="auPwTgl" aria-pressed="${!!U.showPw}">${esc(t(U.showPw?'pw.hide':'pw.show'))}</button>`;
function pwBlock(v){
  const r=pwRules(v), sc=pwScore(v);
  const meter=v?`<div class="pwmeter ${sc<2?'weak':''}"><span class="bars">${[1,2,3].map(i=>`<i class="${i<=sc?'on':''}"></i>`).join('')}</span><span>${esc(t('pw.strength',{s:t(['','pw.weak','pw.ok','pw.strong'][sc])}))}</span></div>`:'';
  return meter+`<ul class="pwrules">${[['len','pw.r1'],['num','pw.r2'],['let','pw.r3']].map(([k,l])=>`<li class="${r[k]?'ok':''}">${r[k]?ic('check','i s'):'<span class="dot"></span>'}<span>${esc(t(l))}</span></li>`).join('')}</ul>`;
}
function codeBoxes(id,bad){
  const v=String(U.form[id]||''), f=U.focus&&U.focus.id===id;
  return `<button type="button" class="otp ${bad?'bad':''}" data-a="focus" data-f="${id}" data-k="code" data-n="" aria-label="${esc(t('vc.title'))}">${[0,1,2,3,4,5].map(i=>{ const cur=f&&i===Math.min(v.length,5)&&v.length<6; return `<span class="${cur?'cur':''} ${v[i]?'fill':''}">${esc(v[i]||'')}${cur?'<i class="caret"></i>':''}</span>` }).join('')}</button>`;
}
function gSheet(){
  if(!U.gpick) return '';
  const nm=t('smp.builder');
  return `<div class="gscrim" data-a="auGClose"></div><div class="gsheet" role="dialog" aria-label="${esc(t('gg.title'))}"><div class="gh">${GLOGO}<b>${esc(t('gg.title'))}</b><small>${esc(t('gg.sub'))}</small>${simtag()}</div><button class="gacc" data-a="auGPick" data-v="me"><span class="av">${esc(initials(nm))}</span><span class="tx"><b>${esc(nm)}</b><small>bobur.rahimov@gmail.com</small></span></button><button class="gacc" data-a="auGPick" data-v="other"><span class="av add">${ic('plus','i s')}</span><span class="tx"><b>${esc(t('gg.other'))}</b></span></button><p class="gn">${ic('info','i s')}<span>${esc(t('gg.note'))}</span></p></div>`;
}
function auPage(o){
  const anim=U.anim==='push'||U.anim==='pop'?U.anim:'';
  const back=o.noBack?`<span class="ib" aria-hidden="true"></span>`:`<button class="ib" data-a="auBack" aria-label="back">${ic('back')}</button>`;
  const steps=o.step?`<div class="au-steps" aria-hidden="true">${[1,2,3].map(i=>`<i class="${i<=o.step?'on':''}"></i>`).join('')}</div>`:'';
  return `<section class="page ${anim}"><div class="bar">${back}<div class="ttl au-ttl"><b>${esc(o.title||'')}</b>${o.step?`<small>${o.step}/3</small>`:''}</div><span class="ib" aria-hidden="true"></span></div>${steps}<div class="scroll" data-scroll="au"><div class="onb au">${o.body}</div></div>${o.cta?`<div class="footer">${o.cta}</div>`:''}${o.foot?`<div class="au-foot">${o.foot}</div>`:''}${gSheet()}</section>`;
}
const bodyWithPhone=(key,ph)=>esc(t(key,{p:'\u0001'})).replace('\u0001','<b>'+esc(fmtPhone(ph))+'</b>');

/* ---------- screens ---------- */
const AUP={};
AUP.splash=()=>`<section class="page"><button class="au-hero splash" data-a="auSplashDone" aria-label="${esc(t('au.skipAnim'))}">${auPlan(true)}<span class="au-wm">${'METRX'.split('').map((c,i)=>`<span style="animation-delay:${(1.95+i*.06).toFixed(2)}s">${c}</span>`).join('')}</span></button></section>`;
AUP.welcome=()=>{
  const fromS=U.anim==='fromSplash', prof=!!S.authFromProfile;
  const menu=U.langMenu?`<div class="au-menu" role="menu">${LANGS.map(x=>`<button class="${S.lang===x?'on':''}" data-a="frLang" data-v="${x}" role="menuitemradio" aria-checked="${S.lang===x}"><span>${esc(LNAME[x])}</span>${S.lang===x?ic('check','i s'):''}</button>`).join('')}</div>`:'';
  return `<section class="page"><div class="au-hero ${fromS?'grow':''}">${prof?`<button class="ib au-x" data-a="auBack" aria-label="${esc(t('common.close'))}">${ic('x')}</button>`:''}<span class="au-wm ${prof?'shift':''}">METRX</span><button class="au-lang" data-a="auLangMenu" aria-expanded="${!!U.langMenu}" aria-label="${esc(t('se.lang'))}">${ic('globe','i s')}<span>${esc(LSHORT[S.lang])}</span></button>${auPlan(false)}</div>${menu}
  <div class="au-sheet ${fromS?'up':''}" data-scroll="auw"><h2>${esc(t('au.welcome'))}</h2><p class="lead">${esc(t('au.tagline'))}</p>${auErrH()}
  <div class="au-btns"><button class="btn gbtn full" data-a="auGoogle">${GLOGO}<span>${esc(t('au.google'))}</span></button><button class="btn pri full" data-a="auTo" data-v="su1">${esc(t('au.signup'))}</button><button class="btn sec full" data-a="auTo" data-v="li">${esc(t('au.login'))}</button></div>
  <div class="au-or">${esc(t('au.or'))}</div>
  <button class="au-skip" data-a="auTo" data-v="local">${ic('device')}<span class="tx"><b>${esc(t('au.skip'))}</b><small>${esc(t('au.skipNote'))}</small></span>${ic('chev','i s')}</button>
  <p class="au-terms">${esc(t('au.terms'))}</p></div>${gSheet()}</section>`;
};
AUP.su1=()=>{
  const nErr=!String(U.form.bname||'').trim()?t('bd.req'):null, pErr=phoneErr(U.form.bphone,true);
  return auPage({title:t('au.signup'),step:1,foot:esc(t('au.terms')),body:`<h2>${esc(t('su.phoneTitle'))}</h2><p class="lead">${esc(t('su.phoneBody'))}</p>${auErrH()}${field('bname',t('bd.name'),{err:nErr,next:'bphone',ph:t('fr.namePh')})}${field('bphone',t('bd.phone'),{tel:true,err:pErr,ph:'90 123 45 67'})}<button class="btn pri full ${nErr||pErr?'dis':''}" data-a="auSendSu">${esc(t('su.sendCode'))}</button><div class="au-row"><span>${esc(t('su.have'))}</span><button class="au-link" data-a="auTo" data-v="li">${esc(t('au.login'))}</button></div>`});
};
function codeScreen(title,ctx){
  const v=String(U.form.code||''), left=Math.max(0,Math.ceil(((U.resendAt||0)-Date.now())/1000));
  return auPage({title,step:2,body:`<h2>${esc(t('vc.title'))}</h2><p class="lead">${bodyWithPhone('vc.body',ctx.phone)}</p>${auErrH()}${codeBoxes('code',!!U.codeErr)}${U.codeErr?`<div class="ferr" role="alert">${ic('alert','i s')}<span>${esc(U.codeErr)}</span></div>`:''}<button class="btn pri full ${v.length<6?'dis':''}" data-a="auVerify">${esc(t('vc.verify'))}</button>
  <div class="au-row">${left>0?`<span id="resendT">${esc(t('vc.resendIn',{t:'0:'+pad2(left)}))}</span>`:`<button class="au-link" data-a="auResend">${esc(t('vc.resend'))}</button>`}<span aria-hidden="true">|</span><button class="au-link" data-a="auBack">${esc(t('vc.change'))}</button></div>${U.resent?`<p class="note" style="justify-content:center">${ic('check','i s')}<span>${esc(t('vc.sent'))}</span></p>`:''}
  <p class="note">${simtag()}<span>${esc(t('vc.sim',{c:SMS_CODE}))}</span></p>`});
}
AUP.su2=()=>codeScreen(t('au.signup'),U.su);
AUP.su3=()=>{ const v=String(U.form.pw||'');
  return auPage({title:t('au.signup'),step:3,body:`<h2>${esc(t('pw.title'))}</h2><p class="lead">${esc(t('pw.body'))}</p>${auErrH()}${field('pw',t('pw.label'),{pw:true,right:pwTgl()})}${pwBlock(v)}<button class="btn pri full ${pwOk(v)?'':'dis'}" data-a="auCreate">${esc(t('au.signup'))}</button>`}) };
AUP.suDone=()=>{ const a=S.account||{}, nm=dn(a.name||S.settings.builder.name);
  return auPage({noBack:true,body:`<div class="au-done"><span class="ok">${ic('check')}</span><h2>${esc(t('su.doneT'))}</h2><p class="lead">${esc(t('su.doneB'))}</p><div class="au-card"><span class="avatar">${esc(initials(nm))}</span><span class="tx"><b>${esc(nm)}</b><small>${esc(fmtPhone(a.phone))}</small></span></div></div>`,cta:`<button class="btn pri full" data-a="auFinish">${esc(t('fr.start'))}</button>`}) };
AUP.li=()=>{
  const pe=phoneErr(U.form.liphone,true), pwE=!String(U.form.lipw||'')?t('pw.req'):null;
  return auPage({title:t('au.login'),body:`<h2>${esc(t('li.title'))}</h2>${auErrH()}<button class="btn gbtn full" data-a="auGoogle">${GLOGO}<span>${esc(t('au.google'))}</span></button><div class="au-or">${esc(t('au.or'))}</div>${field('liphone',t('bd.phone'),{tel:true,err:pe,ph:'90 123 45 67',next:'lipw'})}${field('lipw',t('pw.label'),{pw:true,err:pwE,right:pwTgl()})}<div class="au-row r"><button class="au-link" data-a="auTo" data-v="fp1">${esc(t('li.forgot'))}</button></div>
  <button class="btn pri full ${pe||pwE?'dis':''}" data-a="auLogin" ${U.busy?'style="pointer-events:none" aria-busy="true"':''}>${U.busy?`<span class="spin"></span>${esc(t('li.checking'))}`:esc(t('au.login'))}</button>
  <div class="au-row"><span>${esc(t('li.noAcc'))}</span><button class="au-link" data-a="auTo" data-v="su1">${esc(t('au.signup'))}</button></div><p class="note">${simtag()}<span>${esc(t('li.demo',{p:'+998 93 555 12 34',w:'metrx2026'}))}</span></p>`});
};
AUP.fp1=()=>{ const pe=phoneErr(U.form.fpphone,true);
  return auPage({title:t('fp.title'),step:1,body:`<h2>${esc(t('fp.title'))}</h2><p class="lead">${esc(t('fp.body'))}</p>${auErrH()}${field('fpphone',t('bd.phone'),{tel:true,err:pe,ph:'90 123 45 67'})}<button class="btn pri full ${pe?'dis':''}" data-a="auSendFp">${esc(t('su.sendCode'))}</button>`}) };
AUP.fp2=()=>codeScreen(t('fp.title'),U.fp);
AUP.fp3=()=>{ const v=String(U.form.pw||''), v2=String(U.form.pw2||''), mm=v2&&v!==v2?t('fp.mismatch'):null;
  return auPage({title:t('fp.title'),step:3,body:`<h2>${esc(t('fp.newTitle'))}</h2><p class="lead">${esc(t('fp.newBody'))}</p>${field('pw',t('pw.label'),{pw:true,right:pwTgl(),next:'pw2'})}${pwBlock(v)}${field('pw2',t('fp.repeat'),{pw:true,err:mm})}<button class="btn pri full ${pwOk(v)&&v===v2?'':'dis'}" data-a="auSavePw">${esc(t('fp.save'))}</button>`}) };
AUP.fpDone=()=>auPage({noBack:true,body:`<div class="au-done"><span class="ok">${ic('lock')}</span><h2>${esc(t('fp.doneT'))}</h2><p class="lead">${esc(t('fp.doneB'))}</p></div>`,cta:`<button class="btn pri full" data-a="auToLogin">${esc(t('au.login'))}</button>`});
AUP.local=()=>{
  const nErr=!String(U.form.bname||'').trim()?t('bd.req'):null, pErr=phoneErr(U.form.bphone,true);
  return auPage({title:t('au.skip'),body:`<h2>${esc(t('fr.aboutTitle'))}</h2><p class="lead">${esc(t('fr.aboutBody'))}</p>${field('bname',t('bd.name'),{err:nErr,next:'bphone',ph:t('fr.namePh')})}${field('bphone',t('bd.phone'),{tel:true,err:pErr,ph:'90 123 45 67'})}<p class="note">${ic('device','i s')}<span>${esc(t('fr.noAccount'))}</span></p>`,cta:`<button class="btn pri full ${nErr||pErr?'dis':''}" data-a="frDone">${esc(t('fr.start'))}</button>`});
};
AUP.gphone=()=>{
  const g=U.g||{}, nErr=!String(U.form.bname||'').trim()?t('bd.req'):null, pErr=phoneErr(U.form.bphone,true);
  return auPage({title:'Google',body:`<span class="gchip">${GLOGO}<span>${esc(g.email||'Google')}</span></span><h2>${esc(t('gp.title'))}</h2><p class="lead">${esc(t('gp.body'))}</p>${field('bname',t('bd.name'),{err:nErr,next:'bphone',ph:t('fr.namePh')})}${field('bphone',t('bd.phone'),{tel:true,err:pErr,ph:'90 123 45 67'})}`,cta:`<button class="btn pri full ${nErr||pErr?'dis':''}" data-a="auGDone">${esc(t('fr.start'))}</button>`});
};
renderFirstRun=function(){
  const s=auStep();
  if((s==='su2'||s==='su3')&&!U.su){ S.firstRunStep='su1'; initForm({bname:'',bphone:''}); return renderFirstRun() }
  if((s==='fp2'||s==='fp3')&&!U.fp){ S.firstRunStep='fp1'; initForm({fpphone:''}); return renderFirstRun() }
  if(s==='gphone'&&!U.g){ S.firstRunStep='welcome'; return renderFirstRun() }
  return (AUP[s]||AUP.welcome)();
};

/* ---------- actions ---------- */
A.auSplashDone=()=>{ if(!S.firstRun||auStep()!=='splash') return; clearTimeout(U.splashT); U.splashT=null; S.firstRunStep='welcome'; U.anim='fromSplash'; commit(); render() };
A.auLangMenu=()=>{ U.langMenu=!U.langMenu; render() };
{ const fl=A.frLang; A.frLang=d=>{ U.langMenu=false; fl(d) } }
A.auBack=()=>{ auBack() };
A.auTo=d=>{
  const s=d.v, b=S.settings.builder, keepPh=(U.form&&(U.form.liphone||U.form.bphone||U.form.fpphone))||'';
  if(s==='su1'){ initForm({bname:'',bphone:keepPh}); auGo(s,null,['bname','text','bphone']) }
  else if(s==='li'){ initForm({liphone:keepPh,lipw:''}); auGo(s,null,keepPh?['lipw','pw','']:['liphone','tel','lipw']) }
  else if(s==='fp1'){ initForm({fpphone:keepPh}); auGo(s,null,keepPh?null:['fpphone','tel','']) }
  else if(s==='local'){ if(S.authFromProfile&&b.name){ auExit(); return } initForm({bname:b.name||'',bphone:b.phone||''}); auGo(s,null,b.name?null:['bname','text','bphone']) }
};
A.auPwTgl=()=>{ U.showPw=!U.showPw; render() };
A.auSendSu=()=>{ const n=String(U.form.bname||'').trim(); if(!n||phoneErr(U.form.bphone,true)){ U.submitTry=true; render(); return } if(!auNet()) return; const ph=digits(U.form.bphone); if(authDb()[ph]){ U.auErr='exists'; blur(); render(); return } U.su={name:n,phone:ph}; U.resendAt=Date.now()+59e3; initForm({code:''}); auGo('su2',null,['code','code','']) };
A.auVerify=()=>{ const s=auStep(), v=String(U.form.code||''); if(v.length<6) return; if(v!==SMS_CODE){ U.codeErr=t('vc.wrong'); setFocus('code','code',''); render(); return } if(s==='su2'){ initForm({pw:''}); auGo('su3',null,['pw','pw','']) } else { initForm({pw:'',pw2:''}); auGo('fp3',null,['pw','pw','pw2']) } };
A.auPaste=()=>{ U.form.code=SMS_CODE; U.codeErr=null; blur(); A.auVerify() };
A.auResend=()=>{ if(Date.now()<(U.resendAt||0)) return; U.resendAt=Date.now()+59e3; U.resent=true; U.form.code=''; U.codeErr=null; setFocus('code','code',''); render() };
A.auCreate=()=>{ const pw=String(U.form.pw||''); if(!pwOk(pw)){ U.submitTry=true; render(); return } if(!auNet()) return; const db=authDb(); db[U.su.phone]={name:U.su.name,pw}; authSave(db); const b=S.settings.builder; if(!b.name){ b.name=U.su.name; b.phone=U.su.phone } S.account={method:'phone',name:U.su.name,phone:U.su.phone}; auGo('suDone') };
A.auFinish=()=>auExit();
A.auLogin=()=>{ const pe=phoneErr(U.form.liphone,true), pw=String(U.form.lipw||''); if(pe||!pw){ U.submitTry=true; render(); return } if(!auNet()) return; blur(); U.busy=true; U.auErr=null; render();
  setTimeout(()=>{ U.busy=false; if(!S.firstRun||auStep()!=='li') return; const ph=digits(U.form.liphone), acc=authDb()[ph]; if(!acc||acc.pw!==pw){ U.auErr='wrong'; render(); return } auSignIn({method:'phone',name:acc.name,phone:ph},t('li.welcomeBack',{n:dn(acc.name)})) },900) };
A.auSendFp=()=>{ if(phoneErr(U.form.fpphone,true)){ U.submitTry=true; render(); return } if(!auNet()) return; const ph=digits(U.form.fpphone); if(!authDb()[ph]){ U.auErr='unknown'; blur(); render(); return } U.fp={phone:ph}; U.resendAt=Date.now()+59e3; initForm({code:''}); auGo('fp2',null,['code','code','']) };
A.auSavePw=()=>{ const v=String(U.form.pw||''); if(!pwOk(v)||v!==U.form.pw2){ U.submitTry=true; render(); return } const db=authDb(); if(db[U.fp.phone]) db[U.fp.phone].pw=v; authSave(db); auGo('fpDone') };
A.auToLogin=()=>{ const ph=U.fp?U.fp.phone:''; U.fp=null; initForm({liphone:ph,lipw:''}); auGo('li','back',ph?['lipw','pw','']:['liphone','tel','lipw']) };
A.auGoogle=()=>{ if(!auNet()) return; blur(); U.gpick=true; render() };
A.auGClose=()=>{ U.gpick=false; render() };
A.auGPick=d=>{ U.gpick=false; const me=d.v==='me'; U.g={method:'google',name:me?t('smp.builder'):'',email:me?'bobur.rahimov@gmail.com':''}; const b=S.settings.builder;
  if(b.name&&b.phone){ auSignIn(Object.assign({},U.g,{name:b.name,phone:b.phone}),t('ac.signedG')); return }
  initForm({bname:b.name||U.g.name,bphone:b.phone||''}); auGo('gphone',null,U.g.name?['bphone','tel','']:['bname','text','bphone']) };
A.auGDone=()=>{ const n=String(U.form.bname||'').trim(); if(!n||phoneErr(U.form.bphone,true)){ U.submitTry=true; render(); return } const ph=digits(U.form.bphone); S.settings.builder={name:n,phone:ph}; auSignIn(Object.assign({},U.g,{name:n,phone:ph}),t('ac.signedG')) };
A.frDone=()=>{ const n=String(U.form.bname||'').trim(); if(!n||phoneErr(U.form.bphone,true)){ U.submitTry=true; render(); return } S.settings.builder={name:n,phone:digits(U.form.bphone)}; auExit() };
A.frBack=()=>auGo('welcome','back');
/* Profile → Account */
A.acSignIn=()=>{ closeSheet(true); blur(); S.authFromProfile=true; S.firstRun=true; S.firstRunStep='welcome'; U.anim=null; commit(); render() };
A.acOut=()=>openSheet({type:'logout'});
A.acOutYes=()=>{ S.account=null; commit(); closeSheet(true); toast(t('ac.outDone')); render() };
SHEETS.logout=()=>sheetWrap(t('ac.outQ'),`<p>${esc(t('ac.outB'))}</p>`,`<div class="btnrow"><button class="btn sec" data-a="closeSheet">${esc(t('common.cancel'))}</button><button class="btn danger" data-a="acOutYes">${esc(t('ac.out'))}</button></div>`);
function accountGroup(){
  const a=S.account, h=`<div class="grouph">${esc(t('ac.group'))}</div>`;
  if(!a) return h+`<div class="lgroup"><button class="listrow" data-a="acSignIn">${ic('user')}<span class="tx"><b>${esc(t('ac.signIn'))}</b><small>${esc(t('ac.noneB'))}</small></span>${ic('chev','i s')}</button></div>`;
  const g=a.method==='google';
  return h+`<div class="lgroup"><div class="listrow">${g?`<span class="gico">${GLOGO}</span>`:ic('phone')}<span class="tx"><b>${esc(t(g?'ac.viaG':'ac.viaP'))}</b><small>${esc(g?(a.email||fmtPhone(a.phone)):fmtPhone(a.phone))}</small></span></div><button class="listrow" data-a="acOut">${ic('back')}<span class="tx"><b style="color:var(--err)">${esc(t('ac.out'))}</b></span>${ic('chev','i s')}</button></div>`;
}

/* timers that live outside the full re-render: splash auto-advance + reading counter, SMS resend countdown */
{ const base=render; render=function(){ base(); auAfter() } }
function auAfter(){
  const s=S.firstRun?auStep():null;
  if(s==='splash'&&!U.splashT){
    const t0=performance.now(), rm=reduceMotion();
    U.splashT=setTimeout(()=>{ U.splashT=null; A.auSplashDone() },rm?1200:3100);
    if(!rm){ const tick=now=>{ const el=document.getElementById('spVal'); if(!el||auStep()!=='splash') return; const p=Math.min(1,Math.max(0,(now-t0-1050)/520)); el.textContent=fmtLen(Math.round(5000*(1-Math.pow(1-p,3))),null,true)+' '+M(); if(p<1) requestAnimationFrame(tick) }; requestAnimationFrame(tick) }
  }
  if((s==='su2'||s==='fp2')&&(U.resendAt||0)>Date.now()&&!U.rsT){
    U.rsT=setInterval(()=>{ const el=document.getElementById('resendT'), left=Math.ceil((U.resendAt-Date.now())/1000);
      if(!el||left<=0){ clearInterval(U.rsT); U.rsT=null; if(el&&left<=0) render(); return }
      el.textContent=t('vc.resendIn',{t:'0:'+pad2(left)}) },1000);
  }
}
