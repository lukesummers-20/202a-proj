#!/usr/bin/env python3
"""pass@1 heat-map: rows = problems, cols = formats, one panel per (model, dialect)
(models down, dialects across).
Each cell shows pass@1 and passes/samples; cells that were not run are left blank.
Greedy (T=0) samples are excluded, as in score.py.

  python scripts/heatmap.py --run-id pilot [--out runs/pilot/heatmap.png]"""
import argparse, json
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FORMATS = ["prose", "table", "wave", "combined"]
INK, MUTED = "#1f2328", "#6b7280"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    rows = [json.loads(l) for l in (ROOT / "runs" / a.run_id / "results.jsonl").open()]
    cnt = defaultdict(lambda: [0, 0])      # (model, dialect, problem, format) -> [n, passes]
    for r in rows:
        if r.get("greedy"):
            continue
        k = (r["model"], r["dialect"], r["problem"], r["format"])
        cnt[k][0] += 1
        cnt[k][1] += r["sim_status"] == "pass"
    models = sorted({k[0] for k in cnt})
    dialects = sorted({k[1] for k in cnt})
    problems = sorted({k[2] for k in cnt})
    cmap = plt.get_cmap("Blues").copy()    # sequential, one hue: light = low pass rate
    cmap.set_bad("#f3f4f6")
    # one row of panels per model, one column per dialect
    fig, axes = plt.subplots(len(models), len(dialects), squeeze=False, sharex=True, sharey=True,
                             figsize=(4.2 * len(dialects) + 1.6, (0.62 * len(problems) + 0.75) * len(models) + 0.9))
    for (r, m), (c0, d) in ((x, y) for x in enumerate(models) for y in enumerate(dialects)):
        ax = axes[r][c0]
        grid = [[cnt[(m, d, p, f)][1] / cnt[(m, d, p, f)][0] if (m, d, p, f) in cnt else float("nan")
                 for f in FORMATS] for p in problems]
        im = ax.imshow(grid, vmin=0, vmax=1, cmap=cmap, aspect="auto")
        ax.set_xticks(range(len(FORMATS)), FORMATS)
        ax.set_yticks(range(len(problems)), problems)
        ax.tick_params(length=0, colors=INK, labelsize=9)
        ax.set_title(f"{m} · {d}", fontsize=10, color=INK)
        for s in ax.spines.values():
            s.set_visible(False)
        ax.set_xticks([x - 0.5 for x in range(1, len(FORMATS))], minor=True)   # white gaps between cells
        ax.set_yticks([y - 0.5 for y in range(1, len(problems))], minor=True)
        ax.grid(which="minor", color="white", linewidth=2)
        ax.tick_params(which="minor", length=0)
        for i, p in enumerate(problems):
            for j, f in enumerate(FORMATS):
                if (m, d, p, f) not in cnt:
                    ax.text(j, i, "not run", ha="center", va="center", fontsize=7, color=MUTED)
                    continue
                n, c = cnt[(m, d, p, f)]
                ax.text(j, i, f"{c / n:.2f}  ({c}/{n})", ha="center", va="center", fontsize=8,
                        color="white" if c / n > 0.55 else INK)
    fig.colorbar(im, ax=axes.ravel().tolist(), shrink=0.6, pad=0.02).set_label("pass@1", color=INK)
    fig.suptitle(f"pass@1 by problem and spec format (run {a.run_id})", fontsize=11, color=INK, x=0.02, y=0.95, ha="left")
    out = a.out or str(ROOT / "runs" / a.run_id / "heatmap.png")
    fig.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    print("wrote", out)


if __name__ == "__main__":
    main()
