#!/usr/bin/env python3
"""Gates 0/1: Slang legality, Verilator --lint-only, port check, construct counts, dialect compliance.
Usage: python scripts/lint.py --problem spi_slave_rx --design cand.sv [--dialect sv]
Informational for scoring (the functional testbench decides pass/fail), except ports_ok."""
import argparse, json, re, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CONSTRUCTS = {
    "always_ff": r"\balways_ff\b", "always_comb": r"\balways_comb\b", "always_latch": r"\balways_latch\b",
    "always_at": r"\balways\s*@", "logic": r"\blogic\b", "reg": r"\breg\b", "wire": r"\bwire\b",
    "enum": r"\benum\b", "typedef": r"\btypedef\b", "struct": r"\bstruct\b", "interface": r"\binterface\b",
    "initial": r"\binitial\b", "delay": r"#\s*\d", "display": r"\$display|\$monitor",
}


def strip_comments(code):
    return re.sub(r"//.*?$|/\*.*?\*/", "", code, flags=re.S | re.M)


def count_constructs(code):
    code_nc = strip_comments(code)
    return {k: len(re.findall(p, code_nc)) for k, p in CONSTRUCTS.items()}


def dialect_compliant(c, dialect):
    if dialect == "sv":
        return c["always_ff"] + c["always_comb"] > 0 and c["always_at"] == 0 and c["reg"] == 0
    if dialect == "v2001":
        return (c["always_ff"] + c["always_comb"] + c["logic"] + c["enum"] + c["typedef"] + c["struct"]) == 0
    return None


def load_problem(problem):
    import yaml
    return yaml.safe_load((ROOT / "problems" / problem / "problem.yaml").read_text())


def check_ports(code, problem):
    prob = load_problem(problem)
    code = strip_comments(code)
    m = re.search(r"\bmodule\s+(\w+)", code)
    if not m:
        return False, "no module keyword"
    if m.group(1) != prob["module"]:
        return False, f"module name {m.group(1)} != {prob['module']}"
    missing = [p["name"] for p in prob["ports"] if not re.search(r"\b" + p["name"] + r"\b", code)]
    return (not missing), (f"missing ports {missing}" if missing else None)


def run_slang(design):
    exe = shutil.which("slang")
    if exe:
        r = subprocess.run([exe, "--quiet", str(design)], capture_output=True, text=True, timeout=60)
        return r.returncode == 0, (r.stderr or r.stdout).strip()[:300] or None
    try:
        import pyslang
        SyntaxTree = getattr(getattr(pyslang, "syntax", pyslang), "SyntaxTree")   # pyslang >= 12 layout
        Compilation = getattr(getattr(pyslang, "ast", pyslang), "Compilation")
        DiagnosticEngine = getattr(getattr(pyslang, "diagnostics", pyslang), "DiagnosticEngine", None) \
            or getattr(pyslang, "DiagnosticEngine")
        tree = SyntaxTree.fromFile(str(design))
        comp = Compilation()
        comp.addSyntaxTree(tree)
        diags = [d for d in comp.getAllDiagnostics() if d.isError()]
        msg = None
        if diags:
            msg = DiagnosticEngine(comp.sourceManager).formatMessage(diags[0])[:300]
        return len(diags) == 0, msg
    except ImportError:
        return None, "slang not installed"


def run_verilator(design, top):
    exe = shutil.which("verilator")
    if not exe:
        return None, {}, ["verilator not installed"]
    r = subprocess.run([exe, "--lint-only", "-Wall", "--timing", "-Wno-DECLFILENAME", "-Wno-UNUSEDSIGNAL",
                        "--top-module", top, str(design)], capture_output=True, text=True, timeout=120)
    warns, errs = {}, []
    for line in (r.stderr + r.stdout).splitlines():
        m = re.match(r"%Warning-(\w+):", line)
        if m:
            warns[m.group(1)] = warns.get(m.group(1), 0) + 1
        elif line.startswith("%Error") and "Exiting due to" not in line:
            errs.append(line[:200])
    return (len(errs) == 0), warns, errs


def lint_all(design, problem, dialect=None):
    code = Path(design).read_text()
    c = count_constructs(code)
    s_ok, s_msg = run_slang(design)
    v_ok, v_w, v_e = run_verilator(design, load_problem(problem)["module"])
    p_ok, p_msg = check_ports(code, problem)
    return {"slang_ok": s_ok, "slang_msg": s_msg, "verilator_ok": v_ok, "verilator_warnings": v_w,
            "verilator_errors": v_e, "ports_ok": p_ok, "ports_msg": p_msg, "constructs": c,
            "dialect_compliant": dialect_compliant(c, dialect) if dialect else None}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--problem", required=True)
    ap.add_argument("--design", required=True)
    ap.add_argument("--dialect", default=None, choices=["sv", "v2001"])
    a = ap.parse_args()
    print(json.dumps(lint_all(a.design, a.problem, a.dialect)))
