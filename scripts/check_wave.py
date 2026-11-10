#!/usr/bin/env python3
"""Format-sufficiency helper: replay the clocked WaveDrom diagrams of spec_wave.md against ref.sv.

For every ```wavedrom block that has a `clk` row drawn with "p", each column is one clk cycle:
inputs are held for the column and sampled at the rising edge that ends it; every output drawn
in the diagram is compared, column by column, with what the reference produces.
Symbolic data labels ("A", "P") are mapped to arbitrary distinct byte values. Column 0 is applied
for one extra cycle first, so a diagram that starts in reset shows post-reset outputs in column 0.
Diagrams without a "p" clock row (e.g. spi_slave_rx's half-sclk columns, combinational examples)
or that do not start with rst_n low are skipped and must still be checked by hand.

  python scripts/check_wave.py sync_fifo
Exit code 0 iff every replayed diagram matches the reference."""
import argparse, json, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from lint import load_problem  # noqa: E402


def expand(sig):
    """wave string -> per-column value: '0' | '1' | 'x' | data label."""
    data, out, cur = iter(sig.get("data", [])), [], "x"
    for ch in sig["wave"]:
        if ch in "01x":
            cur = ch
        elif ch in "=23456789":
            cur = next(data)
        elif ch != ".":
            raise ValueError(f"unsupported wave character {ch!r} in {sig['name']}")
        out.append(cur)
    return out


class Symbols:
    def __init__(self):
        self.codes = {}

    def value(self, tok):
        if tok in ("0", "1"):
            return int(tok)
        if re.fullmatch(r"(0x)?[0-9A-Fa-f]{2}", tok):
            return int(tok, 16)
        return self.codes.setdefault(tok, 0xA1 + 0x11 * len(self.codes) & 0xFF)


def replay(problem, idx, diagram, workdir):
    prob = load_problem(problem)
    ports = {p["name"]: p for p in prob["ports"]}
    rows = {s["name"]: s for s in diagram["signal"] if s.get("name")}
    ncol = len(rows["clk"]["wave"])
    sym = Symbols()
    ins = {n: expand(s) for n, s in rows.items() if n != "clk" and ports.get(n, {}).get("dir") == "input"}
    outs = {n: expand(s) for n, s in rows.items() if ports.get(n, {}).get("dir") == "output"}
    unknown = [n for n in rows if n not in ports]
    if unknown:
        return [f"rows that are not ports: {unknown}"]

    def lit(name, tok):
        w = ports[name]["width"]
        return f"{w}'bx" if tok == "x" else f"{w}'d{sym.value(tok)}"

    lines = ["`timescale 1ns/1ps", "module tb;", "  reg clk = 0; always #5 clk = ~clk;"]
    for p in prob["ports"]:
        if p["name"] != "clk":
            kind = "reg" if p["dir"] == "input" else "wire"
            lines.append(f"  {kind} [{p['width'] - 1}:0] {p['name']};")
    lines.append(f"  {prob['module']} dut ({', '.join('.%s(%s)' % (p['name'], p['name']) for p in prob['ports'])});")
    lines.append("  initial begin")
    for col in [0] + list(range(ncol)):                 # column 0 twice (pre-roll)
        lines.append("    " + " ".join(f"{n} = {lit(n, v[col])};" for n, v in ins.items()))
        lines.append("    #9;")
        for n, v in outs.items():
            if v[col] != "x":
                lines.append(f"    if ({n} !== {lit(n, v[col])}) $display(\"MISMATCH col {col}: {n}=%h, "
                             f"diagram says {v[col]} (%h)\", {n}, {lit(n, v[col])});")
        lines.append("    @(posedge clk); #1;")
    lines += ["    $finish;", "  end", "endmodule"]
    tb = workdir / f"wave_tb_{idx}.sv"
    tb.write_text("\n".join(lines) + "\n")
    vvp = workdir / f"wave_tb_{idx}.vvp"
    c = subprocess.run(["iverilog", "-g2012", "-s", "tb", "-o", str(vvp), str(tb),
                        str(ROOT / "problems" / problem / "ref.sv")], capture_output=True, text=True)
    if c.returncode:
        return [f"iverilog: {c.stderr.strip()[:300]}"]
    r = subprocess.run(["vvp", str(vvp)], capture_output=True, text=True, timeout=60)
    return [l for l in r.stdout.splitlines() if l.startswith("MISMATCH")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("problem")
    a = ap.parse_args()
    text = (ROOT / "problems" / a.problem / "spec_wave.md").read_text()
    blocks = re.findall(r"```wavedrom\n(.*?)```", text, re.S)
    ok, replayed = True, 0
    with tempfile.TemporaryDirectory() as tmp:
        for i, b in enumerate(blocks, 1):
            d = json.loads(b)
            clk = next((s for s in d["signal"] if s.get("name") == "clk"), None)
            if not clk or not clk["wave"].startswith("p"):
                print(f"  [SKIP] diagram {i}: no per-cycle clk row; check by hand")
                continue
            rst = next((s for s in d["signal"] if s.get("name") == "rst_n"), None)
            if not rst or not rst["wave"].startswith("0"):
                print(f"  [SKIP] diagram {i}: does not start in reset (initial state unknown); check by hand")
                continue
            replayed += 1
            bad = replay(a.problem, i, d, Path(tmp))
            ok &= not bad
            print(f"  [{'OK' if not bad else 'FAIL'}] diagram {i}: {len(clk['wave'])} columns"
                  + "".join(f"\n         {m}" for m in bad))
    print(f"{a.problem}: {replayed}/{len(blocks)} diagrams replayed against ref.sv, "
          f"{'all match' if ok else 'MISMATCHES'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
