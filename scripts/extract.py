#!/usr/bin/env python3
"""Pull the module source out of an LLM response: first fenced block containing module…endmodule,
else the first module…endmodule span in the raw text. Returns (code or None, reason)."""
import re, sys

FENCE = re.compile(r"```[ \t]*([A-Za-z0-9_+-]*)[ \t]*\n(.*?)```", re.S)
MODULE = re.compile(r"(\bmodule\s+\w+.*?\bendmodule\b)", re.S)


def extract(text):
    if not text:
        return None, "empty_response"
    blocks = [b for _, b in FENCE.findall(text)]
    for b in blocks:
        m = MODULE.search(b)
        if m:
            return m.group(1).strip() + "\n", "fenced"
    m = MODULE.search(text)
    if m:
        return m.group(1).strip() + "\n", "unfenced"
    if blocks:
        return blocks[0].strip() + "\n", "fenced_no_module_kw"
    return None, "no_code_found"


if __name__ == "__main__":
    code, why = extract(sys.stdin.read())
    sys.stderr.write(why + "\n")
    if code:
        sys.stdout.write(code)
