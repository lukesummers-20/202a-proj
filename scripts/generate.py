#!/usr/bin/env python3
"""Build the prompt for one (problem, format, dialect) cell and query an LLM n times.
Every request/response is appended to runs/<run_id>/generations.jsonl before any processing.

Providers: mock (reference or mutant, no key) | openai (OPENAI_API_KEY; OPENAI_BASE_URL for
vLLM/Ollama-compatible endpoints) | anthropic (ANTHROPIC_API_KEY)

  python scripts/generate.py --problem spi_slave_rx --format table --dialect sv --print-prompt
"""
import argparse, hashlib, json, os, random, time, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORMATS = ["prose", "table", "wave", "combined"]
# dialect -> (instruction file, header file, code-fence language, design file suffix)
DIALECTS = {"v2001": ("dialect_v2001.txt", "header.v", "verilog", ".v"),
            "sv": ("dialect_sv.txt", "header.sv", "systemverilog", ".sv")}


def build_prompt(problem, fmt, dialect):
    pdir = ROOT / "problems" / problem
    system = (ROOT / "prompts" / "system.txt").read_text()
    dialect_file, header_file, lang, _ = DIALECTS[dialect]
    dialect_txt = (ROOT / "prompts" / dialect_file).read_text()
    header = (pdir / header_file).read_text()
    if fmt == "combined":
        spec = "\n\n".join(
            f"## {name.capitalize()} description\n\n" + (pdir / f"spec_{name}.md").read_text()
            for name in ["prose", "table", "wave"])
    else:
        spec = (pdir / f"spec_{fmt}.md").read_text()
    user = (f"# Specification\n\n{spec}\n\n# Language requirements\n\n{dialect_txt}\n"
            f"# Module header (use verbatim)\n\n```{lang}\n{header}```\n\n"
            f"Write the complete module now.")
    return system, user


def call_mock(system, user, model, temperature, seed, problem):
    """'mock-ref' -> reference; 'mock-mutant' -> random mutant; 'mock-mixed' -> reference 60% of the time."""
    pdir = ROOT / "problems" / problem
    rng = random.Random(seed)
    muts = sorted((pdir / "mutants").glob("*.sv"))
    if model == "mock-ref" or (model == "mock-mixed" and rng.random() < 0.6) or not muts:
        code = (pdir / "ref.sv").read_text()
    else:
        code = rng.choice(muts).read_text()
    return {"text": f"Here is the design:\n\n```systemverilog\n{code}```\n",
            "usage": {"input_tokens": len(system + user) // 4, "output_tokens": len(code) // 4},
            "model_version": model}


def call_openai(system, user, model, temperature, seed, max_tokens):
    from openai import OpenAI
    client = OpenAI(base_url=os.environ.get("OPENAI_BASE_URL") or None)
    kw = dict(model=model, temperature=temperature, max_tokens=max_tokens,
              messages=[{"role": "system", "content": system}, {"role": "user", "content": user}])
    if seed is not None:
        kw["seed"] = seed
    r = client.chat.completions.create(**kw)
    return {"text": r.choices[0].message.content,
            "usage": {"input_tokens": r.usage.prompt_tokens, "output_tokens": r.usage.completion_tokens},
            "model_version": r.model, "system_fingerprint": getattr(r, "system_fingerprint", None),
            "stop_reason": r.choices[0].finish_reason}


def call_anthropic(system, user, model, temperature, seed, max_tokens):
    import anthropic
    client = anthropic.Anthropic()
    r = client.messages.create(model=model, max_tokens=max_tokens, temperature=temperature,
                               system=system, messages=[{"role": "user", "content": user}])
    return {"text": "".join(b.text for b in r.content if b.type == "text"),
            "usage": {"input_tokens": r.usage.input_tokens, "output_tokens": r.usage.output_tokens},
            "model_version": r.model, "stop_reason": r.stop_reason}


def generate(problem, fmt, dialect, provider, model, n, temperature, max_tokens, run_id, seed0=0,
             greedy_extra=False):
    """n samples at `temperature`; if greedy_extra, one more sample at T=0 (flagged greedy=True,
    excluded from pass@k by score.py, used for determinism checks)."""
    system, user = build_prompt(problem, fmt, dialect)
    out_dir = ROOT / "runs" / run_id
    out_dir.mkdir(parents=True, exist_ok=True)
    jsonl = out_dir / "generations.jsonl"
    prompt_hash = hashlib.sha256((system + user).encode()).hexdigest()[:12]
    (out_dir / "prompts").mkdir(exist_ok=True)
    (out_dir / "prompts" / f"{problem}__{fmt}__{dialect}__{prompt_hash}.md").write_text(
        f"<!-- SYSTEM -->\n{system}\n<!-- USER -->\n{user}")
    plan = [(i, temperature, False) for i in range(n)]
    if greedy_extra:
        plan.append((n, 0.0, True))
    records = []
    for i, temp, greedy in plan:
        seed = seed0 + i
        t0 = time.time()
        if provider == "mock":
            resp = call_mock(system, user, model, temp, seed, problem)
        elif provider == "openai":
            resp = call_openai(system, user, model, temp, seed, max_tokens)
        elif provider == "anthropic":
            resp = call_anthropic(system, user, model, temp, seed, max_tokens)
        else:
            raise ValueError(provider)
        rec = {"gen_id": str(uuid.uuid4())[:8], "run_id": run_id, "problem": problem, "format": fmt,
               "dialect": dialect, "provider": provider, "model": model,
               "model_version": resp.get("model_version"), "sample": i, "seed": seed, "greedy": greedy,
               "temperature": temp, "max_tokens": max_tokens, "prompt_hash": prompt_hash,
               "usage": resp["usage"], "stop_reason": resp.get("stop_reason"),
               "latency_s": round(time.time() - t0, 2),
               "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "response": resp["text"]}
        with open(jsonl, "a") as f:
            f.write(json.dumps(rec) + "\n")
        records.append(rec)
    return records


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--problem", required=True)
    ap.add_argument("--format", required=True, choices=FORMATS)
    ap.add_argument("--dialect", default="sv", choices=list(DIALECTS))
    ap.add_argument("--provider", default="mock", choices=["mock", "openai", "anthropic"])
    ap.add_argument("--model", default="mock-mixed")
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--temperature", type=float, default=0.8)
    ap.add_argument("--max-tokens", type=int, default=4096)
    ap.add_argument("--run-id", default="dev")
    ap.add_argument("--seed0", type=int, default=0)
    ap.add_argument("--greedy-extra", action="store_true")
    ap.add_argument("--print-prompt", action="store_true")
    a = ap.parse_args()
    if a.print_prompt:
        s, u = build_prompt(a.problem, a.format, a.dialect)
        print("=== SYSTEM ===\n" + s + "\n=== USER ===\n" + u)
    else:
        recs = generate(a.problem, a.format, a.dialect, a.provider, a.model, a.n,
                        a.temperature, a.max_tokens, a.run_id, a.seed0, a.greedy_extra)
        print(f"{len(recs)} generations appended to runs/{a.run_id}/generations.jsonl")
