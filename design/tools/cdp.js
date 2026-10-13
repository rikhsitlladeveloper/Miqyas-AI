// Drive the prototype inside the Android WebView over the Chrome DevTools Protocol: run an expression, save a screenshot.
// Needs Node 22+ (built-in WebSocket). See README.md in this folder for the adb port-forward step.
// Usage: node cdp.js <webSocketDebuggerUrl> <out.png | ""> "<js expression>"
const [,,wsUrl,out,expr]=process.argv;
const ws=new WebSocket(wsUrl); let id=0; const pend={};
const send=(method,params={})=>new Promise(r=>{const i=++id; pend[i]=r; ws.send(JSON.stringify({id:i,method,params}))});
ws.onmessage=e=>{const m=JSON.parse(e.data); if(m.id&&pend[m.id]){pend[m.id](m); delete pend[m.id]}};
ws.onopen=async()=>{
  if(expr){ const r=await send('Runtime.evaluate',{expression:expr,awaitPromise:true,returnByValue:true}); console.log(JSON.stringify(r.result&&r.result.result&&r.result.result.value)); }
  if(out){ const s=await send('Page.captureScreenshot',{format:'png'}); require('fs').writeFileSync(out,Buffer.from(s.result.data,'base64')); console.log('shot saved'); }
  ws.close(); process.exit(0);
};
