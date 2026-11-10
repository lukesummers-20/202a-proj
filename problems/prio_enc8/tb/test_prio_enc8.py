"""Exhaustive cocotb test for prio_enc8 (all 256 inputs) -- identical for every (format, dialect, model) cell."""
import cocotb
from cocotb.triggers import Timer


def model(req):
    if req == 0:
        return 0, 0
    return max(i for i in range(8) if (req >> i) & 1), 1


def val(sig, tag):
    """int() of a signal, turning X/Z into a test failure with a readable message."""
    try:
        return int(sig.value)
    except ValueError:
        raise AssertionError(f"{tag}: {sig._name} is X/Z ({sig.value})") from None


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_prio_enc8(dut):
    for req in range(256):
        dut.req.value = req
        await Timer(1, "ns")
        tag = f"req=0x{req:02X}"
        e_idx, e_valid = model(req)
        got_idx, got_valid = val(dut.idx, tag), val(dut.valid, tag)
        assert got_valid == e_valid, f"{tag}: valid={got_valid} expected {e_valid}"
        assert got_idx == e_idx, f"{tag}: idx={got_idx} expected {e_idx}"
