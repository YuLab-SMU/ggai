// usage: node cdp_eval.mjs <targetId> <js-expression>   (loopback CDP 9334, our own local pages only)
const [targetId, expr] = process.argv.slice(2);
const t = (await (await fetch('http://127.0.0.1:9334/json/list')).json()).find(t => t.id === targetId);
const ws = new WebSocket(t.webSocketDebuggerUrl); let id = 0; const pending = new Map();
ws.onmessage = ev => { const m = JSON.parse(ev.data); if (pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await new Promise(r => ws.onopen = r);
const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true });
console.log(JSON.stringify(r.result.result.value ?? r.result, null, 1));
ws.close();
