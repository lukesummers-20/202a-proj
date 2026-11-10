#!/usr/bin/env python3
"""Gate 2+3: compile a candidate and run the problem's cocotb testbench.
Usage: python scripts/simulate.py --problem spi_slave_rx --design cand.sv [--sim icarus|verilator] [--workdir d]
Prints JSON: {"status": pass|fail|compile_error|timeout|tool_error, "first_assert": ..., "log": ..., "wall_s": ...}

run() does the work in-process; run_isolated() re-invokes this script in a subprocess with a hard
wall-clock kill, which is what run_matrix.py uses so a hanging design can't stall the matrix.
Works with cocotb >= 2.0 (cocotb_tools.runner) and 1.9 (cocotb.runner)."""
import argparse, json, os, re, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_problem(pid):
    import yaml
    return yaml.safe_load((ROOT / "problems" / pid / "problem.yaml").read_text())


def run(problem_id, design, sim="icarus", workdir=None, waves=False):
    try:
        from cocotb_tools.runner import get_runner          # cocotb >= 2.0
    except ImportError:
        from cocotb.runner import get_runner                # cocotb 1.9.x
    prob = load_problem(problem_id)
    top = prob["top_for_sim"]
    tbdir = ROOT / "problems" / problem_id / "tb"
    test_module = f"test_{problem_id}"
    workdir = Path(workdir) if workdir else Path(tempfile.mkdtemp(prefix=f"{problem_id}_"))
    workdir.mkdir(parents=True, exist_ok=True)
    workdir = workdir.resolve()
    build_dir = workdir / "sim_build"
    result = {"status": "tool_error", "sim": sim, "log": str(workdir / "test.log"),
              "first_assert": None, "wall_s": None}
    design = Path(design).resolve()
    t0 = time.time()
    runner = get_runner(sim)
    build_args = ["-g2012"] if sim == "icarus" else ["-Wno-fatal", "--timing", "-Wno-WIDTH", "-Wno-UNUSED"]

    # Verilator's generated Makefile runs helper scripts with $PYTHON3 (default: `python3` on PATH).
    # Without an activated venv that can be a different interpreter, which then crashes on the
    # venv's PYTHONPATH ("SRE module mismatch"). Pin both to the interpreter running this script.
    os.environ["PYTHON3"] = sys.executable
    venv_bin = str(Path(sys.executable).parent)
    if not os.environ.get("PATH", "").startswith(venv_bin + os.pathsep):
        os.environ["PATH"] = venv_bin + os.pathsep + os.environ.get("PATH", "")

    # cocotb 2.x builds the simulator's PYTHONPATH from sys.path; 1.9 inherits the env var
    os.environ["PYTHONPATH"] = str(tbdir) + os.pathsep + os.environ.get("PYTHONPATH", "")
    if str(tbdir) not in sys.path:
        sys.path.insert(0, str(tbdir))

    try:
        runner.build(sources=[str(design)], hdl_toplevel=top, build_dir=str(build_dir),
                     build_args=build_args, always=True, waves=waves,
                     log_file=str(workdir / "build.log"), timescale=("1ns", "1ps"))
    except Exception as e:
        result["status"] = "compile_error"
        result["first_assert"] = _rel(_first_error(workdir / "build.log") or str(e)[:300])
        result["wall_s"] = round(time.time() - t0, 2)
        return result
    try:
        results_xml = runner.test(hdl_toplevel=top, test_module=test_module, build_dir=str(build_dir),
                                  test_dir=str(workdir), log_file=str(workdir / "test.log"),
                                  extra_env={"COCOTB_LOG_LEVEL": "INFO"}, waves=waves,
                                  timescale=("1ns", "1ps"))
    except Exception as e:
        result["first_assert"] = _rel(str(e)[:300])
        result["wall_s"] = round(time.time() - t0, 2)
        return result

    xml = Path(results_xml) if results_xml else workdir / "results.xml"
    result["status"], result["first_assert"] = _parse_results(xml, workdir / "test.log")
    result["first_assert"] = _rel(result["first_assert"])
    result["wall_s"] = round(time.time() - t0, 2)
    return result


def run_isolated(problem_id, design, sim="icarus", workdir=None, timeout=120, waves=False):
    """Same as run(), in a child process killed after `timeout` wall-clock seconds."""
    cmd = [sys.executable, str(Path(__file__).resolve()), "--problem", problem_id, "--design", str(design),
           "--sim", sim, "--inprocess"]
    if workdir:
        cmd += ["--workdir", str(workdir)]
    if waves:
        cmd.append("--waves")
    t0 = time.time()
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"status": "timeout", "sim": sim, "log": None,
                "first_assert": f"wall-clock timeout after {timeout}s", "wall_s": round(time.time() - t0, 2)}
    lines = [l for l in r.stdout.splitlines() if l.startswith("{")]
    if not lines:
        return {"status": "tool_error", "sim": sim, "log": None,
                "first_assert": (r.stderr.strip().splitlines() or ["no output"])[-1][:300],
                "wall_s": round(time.time() - t0, 2)}
    return json.loads(lines[-1])


def _rel(msg):
    """Strip the absolute repo path from tool messages so results files are portable."""
    return msg.replace(str(ROOT) + os.sep, "") if isinstance(msg, str) else msg


def _first_error(path):
    try:
        txt = Path(path).read_text(errors="ignore")
    except FileNotFoundError:
        return None
    for line in txt.splitlines():
        if re.search(r"error|Error|%Error", line):
            return line.strip()[:300]
    return None


def _parse_results(xml_path, test_log):
    try:
        import xml.etree.ElementTree as ET
        root = ET.parse(xml_path).getroot()
    except Exception:
        return "tool_error", f"no results.xml at {xml_path}"
    failures, msg, ran = 0, None, 0
    for tc in root.iter("testcase"):
        ran += 1
        f = tc.find("failure")
        if f is not None:
            failures += 1
            if msg is None:
                msg = (f.get("message") or "").strip()[:300]
    if ran == 0:
        return "tool_error", "no testcases ran"
    if failures == 0:
        return "pass", None
    try:
        log = Path(test_log).read_text(errors="ignore")
        if "SimTimeoutError" in log or "Timeout" in (msg or ""):
            return "timeout", msg or "SimTimeoutError"
        m = re.search(r"AssertionError: (.*)", log)
        if m:
            msg = m.group(1).strip()[:300]
    except FileNotFoundError:
        pass
    return "fail", msg


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--problem", required=True)
    ap.add_argument("--design", required=True)
    ap.add_argument("--sim", default="icarus", choices=["icarus", "verilator"])
    ap.add_argument("--workdir", default=None)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--waves", action="store_true")
    ap.add_argument("--inprocess", action="store_true", help="no subprocess/timeout wrapper (internal)")
    a = ap.parse_args()
    if a.inprocess:
        res = run(a.problem, a.design, a.sim, a.workdir, a.waves)
    else:
        res = run_isolated(a.problem, a.design, a.sim, a.workdir, a.timeout, a.waves)
    print(json.dumps(res))
