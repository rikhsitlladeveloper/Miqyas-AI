/* ============================== minimal: small markup changes for the minimal look ==============================
   New project: a two-line header as in the founder's design, the step ("New project") above the title ("Project details"). */
{ const np=PAGES.newProject; PAGES.newProject=r=>{ const h=np(r); if(stack().some(x=>x.edit)||(r&&r.edit)) return h;
  return h.replace(`<div class="ttl"><b>${esc(t('np.title'))}</b></div>`,`<div class="ttl"><b>${esc(t('np.editTitle'))}</b><small class="ey">${esc(t('np.title'))}</small></div>`) } }
