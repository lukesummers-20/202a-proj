#!/usr/bin/env python3
"""pass@k per cell, bootstrap CIs over problems, failure classes, lint/compliance summary.
  python scripts/score.py --run-id cp1 [--k 1] [--by format dialect model] [--csv runs/cp1/summary.csv]

Unit of analysis: a cell = (problem, *by). pass@k is computed per (problem, *by) from the n sampled
(T>0) generations; the aggregate is the mean over problems with a percentile bootstrap CI that
resamples problems. Greedy (T=0) samples are excluded from pass@k and reported separately."""
import argparse, json, math, random
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def pass_at_k(n, c, k):
    """Unbiased estimator (Chen et al. 2021)."""
    if n < k:
        return float("nan")
    if n - c < k:
        return 1.0
    return 1.0 - math.prod((n - c - i) / (n - i) for i in range(k))


def bootstrap_ci(values, iters=2000, alpha=0.05, seed=0):
    if not values:
        return (float("nan"), float("nan"))
    rng = random.Random(seed)
    means = sorted(sum(s := [rng.choice(values) for _ in values]) / len(s) for _ in range(iters))
    return means[int(alpha / 2 * iters)], means[int((1 - alpha / 2) * iters) - 1]


def label(key):
    return " / ".join(map(str, key))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--k", type=int, default=1)
    ap.add_argument("--by", nargs="+", default=["format", "dialect", "model"])
    ap.add_argument("--csv", default=None)
    a = ap.parse_args()
    all_rows = [json.loads(l) for l in (ROOT / "runs" / a.run_id / "results.jsonl").open()]
    rows = [r for r in all_rows if not r.get("greedy")]
    greedy = [r for r in all_rows if r.get("greedy")]

    cells = defaultdict(lambda: {"n": 0, "c": 0, "classes": defaultdict(int), "latch": 0, "lint_clean": 0,
                                 "slang_ok": 0, "compliant": 0, "tokens_out": 0})
    for r in rows:
        key = (r["problem"],) + tuple(r.get(b) for b in a.by)
        c = cells[key]
        c["n"] += 1
        c["c"] += r["sim_status"] == "pass"
        c["classes"][r["failure_class"]] += 1
        lint = r.get("lint") or {}
        if lint.get("verilator_warnings", {}).get("LATCH"):
            c["latch"] += 1
        c["lint_clean"] += bool(lint.get("verilator_ok")) and not lint.get("verilator_warnings")
        c["slang_ok"] += bool(lint.get("slang_ok"))
        c["compliant"] += bool(r.get("dialect_compliant"))
        c["tokens_out"] += (r.get("usage") or {}).get("output_tokens", 0)

    agg = defaultdict(list)
    for key, c in cells.items():
        agg[key[1:]].append(pass_at_k(c["n"], c["c"], a.k))

    print(f"\n== pass@{a.k} by {a.by}  (run {a.run_id}, {len(rows)} sampled generations"
          f"{f' + {len(greedy)} greedy' if greedy else ''}, {len({r['problem'] for r in rows})} problems) ==")
    print(f"{label(a.by):40s} {'pass@k':>7s} {'95% CI':>16s} {'#prob':>6s}")
    out = []
    for key in sorted(agg):
        vals = [v for v in agg[key] if not math.isnan(v)]
        if not vals:
            print(f"{label(key):40s}   (n < k in every problem)")
            continue
        m = sum(vals) / len(vals)
        lo, hi = bootstrap_ci(vals)
        print(f"{label(key):40s} {m:7.3f} [{lo:6.3f},{hi:6.3f}] {len(vals):6d}")
        out.append((key, m, lo, hi, len(vals)))

    print("\n== failure classes ==")
    cls = defaultdict(lambda: defaultdict(int))
    for key, c in cells.items():
        for k2, v in c["classes"].items():
            cls[key[1:]][k2] += v
    for key in sorted(cls):
        tot = sum(cls[key].values())
        parts = ", ".join(f"{k2}={v}" for k2, v in sorted(cls[key].items(), key=lambda x: -x[1]))
        print(f"{label(key):40s} n={tot:3d}  {parts}")

    print("\n== lint / compliance ==")
    for key in sorted(agg):
        sel = [c for k, c in cells.items() if k[1:] == key]
        n = sum(c["n"] for c in sel)
        s = lambda f: sum(c[f] for c in sel)  # noqa: E731
        print(f"{label(key):40s} slang_ok={s('slang_ok')}/{n}  lint_clean={s('lint_clean')}/{n}  "
              f"latch_warn={s('latch')}/{n}  dialect_compliant={s('compliant')}/{n}  "
              f"out_tokens/gen={s('tokens_out') / max(n, 1):.0f}")

    if greedy:
        print("\n== greedy (T=0) samples: pass / total ==")
        gb = defaultdict(lambda: [0, 0])
        for r in greedy:
            key = tuple(r.get(b) for b in a.by)
            gb[key][0] += r["sim_status"] == "pass"
            gb[key][1] += 1
        for key in sorted(gb):
            print(f"{label(key):40s} {gb[key][0]}/{gb[key][1]}")

    if a.csv:
        import csv
        with open(a.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(a.by + [f"pass_at_{a.k}", "ci_lo", "ci_hi", "n_problems"])
            for key, m, lo, hi, n in out:
                w.writerow(list(key) + [round(m, 4), round(lo, 4), round(hi, 4), n])
        print(f"\nwrote {a.csv}")


if __name__ == "__main__":
    main()
