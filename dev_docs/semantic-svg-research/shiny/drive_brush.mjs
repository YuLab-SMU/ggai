// Fallback driver: neither REA capture-browser-scenario nor Craft web-walkthrough-record
// supports mouse drag, so brush gestures are driven here with REA's bundled playwright-core.
// Connects to the headless Chrome on 127.0.0.1:9444, reloads the app, records raw
// websocket frames, and performs two brushes: one inside panel 1, one crossing panels 1->2.
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
const require = createRequire("/tmp/ggai_research/tools/rea/node_modules/");
const { chromium } = require("playwright-core");

const out = process.argv[2];
const browser = await chromium.connectOverCDP("http://127.0.0.1:9444");
const ctx = browser.contexts()[0];
const page = ctx.pages().find(p => p.url().startsWith("http://127.0.0.1:8765"));
const frames = [];
let step = "reload";
page.on("websocket", ws => {
  ws.on("framesent", f => frames.push({ step, dir: "sent", t: Date.now(), payload: String(f.payload) }));
  ws.on("framereceived", f => {
    const s = String(f.payload);
    frames.push({ step, dir: "received", t: Date.now(), bytes: s.length, payload: s.length > 20000 ? s.slice(0, 20000) + "...[truncated]" : s });
  });
});
await page.reload({ waitUntil: "load" });
await page.waitForSelector("#facet img[src^='data:']", { timeout: 20000 });
await page.waitForTimeout(2500);
const box = await page.locator("#facet img").boundingBox();
const dpr = await page.evaluate(() => window.devicePixelRatio);

async function drag(label, x0, y0, x1, y1) {
  step = label;
  await page.mouse.move(box.x + x0, box.y + y0);
  await page.mouse.down();
  for (let i = 1; i <= 10; i++) {
    await page.mouse.move(box.x + x0 + (x1 - x0) * i / 10, box.y + y0 + (y1 - y0) * i / 10);
    await page.waitForTimeout(20);
  }
  await page.mouse.up();
  await page.waitForTimeout(1500);
  const brushDiv = await page.evaluate(() => {
    const b = document.querySelector("#facet [id$='_brush']");
    return b ? { id: b.id, style: b.getAttribute("style") } : null;
  });
  const text = await page.locator("#brush_info").innerText();
  return { label, from: [x0, y0], to: [x1, y1], brushDiv, brush_info: text };
}

const results = { img_box: box, devicePixelRatio: dpr };
results.within_panel1 = await drag("brush-panel1", 80, 100, 200, 250);
// a drag starting in panel 1 and ending deep in panel 2 (css x ~ 234..417)
results.cross_panel = await drag("brush-cross-panel", 120, 80, 330, 260);
step = "done";
writeFileSync(out, JSON.stringify({ results, frames }, null, 1));
// do not close: the external Chrome is reused by Craft; just exit
console.log(JSON.stringify(results, null, 1).slice(0, 4000));
process.exit(0);
