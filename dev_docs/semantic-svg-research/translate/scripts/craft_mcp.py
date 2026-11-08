#!/usr/bin/env python3
"""Drive craft-anything-cli in MCP mode so several browser tools share one session.
usage: craft_mcp.py calls.json out.json"""
import json, subprocess, sys, os
CRAFT = "/tmp/ggai_research/tools/craft/craft-anything-cli-0.5.0-macos-universal/craft-anything-cli"
calls = json.load(open(sys.argv[1]))
out_path = sys.argv[2]
p = subprocess.Popen([CRAFT, "--deep", "--allow-run", "mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=open(out_path + ".stderr", "w"), text=True, bufsize=1, cwd="/tmp/ggai_research/translate")
def send(msg):
    p.stdin.write(json.dumps(msg) + "\n"); p.stdin.flush()
def recv(want_id):
    while True:
        line = p.stdout.readline()
        if not line:
            raise SystemExit("mcp server closed")
        try:
            m = json.loads(line)
        except Exception:
            continue
        if m.get("id") == want_id:
            return m
send({"jsonrpc": "2.0", "id": 0, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "ggai-research", "version": "0"}}})
init = recv(0)
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
results = []
for i, c in enumerate(calls, start=1):
    send({"jsonrpc": "2.0", "id": i, "method": "tools/call", "params": {"name": c["name"], "arguments": c.get("arguments", {})}})
    r = recv(i)
    results.append({"call": c, "response": r})
    res = r.get("result") or {}
    txt = ""
    for part in res.get("content", []) or []:
        if part.get("type") == "text":
            txt += part["text"]
    if c.get("save_png"):
        import base64
        def find_b64(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k in ("base64", "data") and isinstance(v, str) and len(v) > 1000:
                        return v
                    r_ = find_b64(v)
                    if r_: return r_
            elif isinstance(o, list):
                for v in o:
                    r_ = find_b64(v)
                    if r_: return r_
            return None
        b64 = None
        for part in res.get("content", []) or []:
            if part.get("type") == "image":
                b64 = part.get("data")
        if not b64:
            try: b64 = find_b64(json.loads(txt))
            except Exception: b64 = find_b64(res)
        if b64:
            open(c["save_png"], "wb").write(base64.b64decode(b64)); print("   saved", c["save_png"])
        else:
            print("   NO PNG FOUND")
    print(f"[{i}] {c['name']}: isError={res.get('isError')} err={r.get('error')} :: {txt[:300]!r}", flush=True)
json.dump({"init": init, "results": results}, open(out_path, "w"), indent=1)
p.stdin.close(); p.wait(timeout=60)
