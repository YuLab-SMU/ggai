#!/usr/bin/env python3
"""Pixel-diff each rendering against the ggsave PNG with Craft web-pixels-compare and REA compare-web-screenshots."""
import json, subprocess, os, base64, hashlib, csv
T = "/tmp/ggai_research/translate"
CRAFT = "/tmp/ggai_research/tools/craft/craft-anything-cli-0.5.0-macos-universal/craft-anything-cli"
REA = "/tmp/ggai_research/tools/rea/node_modules/.bin/rea"
env = dict(os.environ, PATH="/tmp/ggai_research/tools/node/node-v24.22.2-darwin-arm64/bin:" + os.environ["PATH"])
figs = ["a_facet", "b_patchwork", "c_repel", "e_pointrange", "d_heatmap", "a1_no_annotate", "a2_no_facet", "a3_points_facet_annot"]
renders = {"svglite": "{f}_svglite_craft.png", "plotly": "{f}_plotly_rea.png", "cx": "{f}_cx_rea.png",
           "plotly_grob": "{f}_grob_plotly_rea.png", "blank": "blank_craft.png"}
def artifact(path):
    b = open(path, "rb").read()
    a = {"sha256": hashlib.sha256(b).hexdigest(), "bytes": len(b), "media_type": "image/png", "data_base64": base64.b64encode(b).decode()}
    p = f"{T}/rea/artifacts/{os.path.basename(path)}.json"
    json.dump(a, open(p, "w")); return p
rows = []
for f in figs:
    gg = f"{T}/exp/{f}_gg.png"
    for r, pat in renders.items():
        shot = f"{T}/shots/" + pat.format(f=f)
        if not os.path.exists(shot):
            continue
        c = subprocess.run([CRAFT, "web-pixels-compare", "--before", json.dumps({"path": gg}), "--after", json.dumps({"path": shot}),
                            "--tolerance", "16", "--common-area", "true"], capture_output=True, text=True)
        cr = json.loads(c.stdout)["result"]
        q = subprocess.run([REA, "compare-web-screenshots", artifact(gg), artifact(shot), "--channel-threshold", "16", "--format", "json"],
                           capture_output=True, text=True, env=env)
        rr = json.loads(q.stdout)["normalized_result"]
        rows.append({"figure": f, "render": r, "craft_diff_frac": round(cr["difference_fraction"], 4),
                     "craft_layout_sim": round(cr.get("layout_similarity", float("nan")), 3),
                     "craft_ssim": round(cr.get("perceptual_similarity", float("nan")), 3),
                     "rea_changed_ratio": round(rr["changed_ratio"], 4), "rea_mean_abs_delta": round(rr["mean_absolute_channel_delta"], 2),
                     "agree": cr["differing_pixels"] == rr["changed_pixels"]})
        print(rows[-1], flush=True)
with open(f"{T}/pixel_diffs.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
json.dump(rows, open(f"{T}/pixel_diffs.json", "w"), indent=1)
