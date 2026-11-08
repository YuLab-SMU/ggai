// usage: node cdp_hover.mjs <targetId> <x> <y> <out.png>
// Moves the mouse to (x,y) on a loopback CDP target (port 9334) and saves a screenshot.
import { writeFileSync } from 'node:fs';
const [targetId, x, y, out] = process.argv.slice(2);
const list = await (await fetch('http://127.0.0.1:9334/json/list')).json();
const t = list.find(t => t.id === targetId);
const ws = new WebSocket(t.webSocketDebuggerUrl);
let id = 0; const pending = new Map();
ws.onmessage = ev => { const m = JSON.parse(ev.data); if (pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await new Promise(r => ws.onopen = r);
await send('Page.bringToFront');
for (const [dx, dy] of [[-20, -20], [-5, -5], [0, 0]]) {
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: +x + dx, y: +y + dy });
  await new Promise(r => setTimeout(r, 250));
}
await new Promise(r => setTimeout(r, 1200));
const shot = await send('Page.captureScreenshot', { format: 'png' });
writeFileSync(out, Buffer.from(shot.result.data, 'base64'));
console.log('saved', out);
ws.close();
