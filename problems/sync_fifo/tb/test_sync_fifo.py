"""cocotb testbench for sync_fifo -- identical for every (format, dialect, model) cell.

Scoreboard against a Python deque. Checks after every clock edge: full, empty, rd_data
(new item on an accepted read, otherwise unchanged).
  T1  reset values
  T2  fill to full; one extra write is ignored
  T3  drain in order; one extra read is ignored and rd_data holds
  T4  simultaneous read+write keeps the count
  T5  read+write while full: read accepted, write ignored
  T5b read+write while empty: write accepted, read ignored
  T6  300 random cycles
  T7  reset mid-operation, then the FIFO works again from empty
"""
import random
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer

DEPTH = 4


def val(sig, tag):
    """int() of a signal, turning X/Z into a test failure with a readable message."""
    try:
        return int(sig.value)
    except ValueError:
        raise AssertionError(f"{tag}: {sig._name} is X/Z ({sig.value})") from None


class Model:
    def __init__(self):
        self.q = deque()
        self.last = 0          # expected rd_data

    def __len__(self):
        return len(self.q)


async def check(dut, m, tag):
    await ReadOnly()
    n = len(m)
    full, empty, rd = val(dut.full, tag), val(dut.empty, tag), val(dut.rd_data, tag)
    assert full == (n == DEPTH), f"{tag}: full={full} with {n} items stored"
    assert empty == (n == 0), f"{tag}: empty={empty} with {n} items stored"
    assert rd == m.last, f"{tag}: rd_data=0x{rd:02X} expected 0x{m.last:02X}"
    await Timer(1, "ns")   # leave the ReadOnly phase before driving again


async def reset(dut, m, tag):
    dut.rst_n.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    m.q.clear()
    m.last = 0
    await check(dut, m, tag)
    dut.rst_n.value = 1


async def step(dut, m, wr, wdata, rd, tag):
    """Apply one cycle of inputs, advance the model identically, check outputs after the edge."""
    dut.wr_en.value = wr
    dut.wr_data.value = wdata
    dut.rd_en.value = rd
    await RisingEdge(dut.clk)
    full_b, empty_b = len(m) == DEPTH, len(m) == 0     # decisions use the state BEFORE the edge
    if rd and not empty_b:
        m.last = m.q.popleft()
    if wr and not full_b:
        m.q.append(wdata)
    await check(dut, m, tag)


@cocotb.test(timeout_time=1, timeout_unit="ms")   # whole test is ~4 us of sim time
async def test_sync_fifo(dut):
    random.seed(2)
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    m = Model()
    await reset(dut, m, "T1 reset")
    await step(dut, m, 0, 0, 0, "T1 idle")

    for d in [0xA1, 0xA2, 0xA3, 0xA4, 0xA5]:           # T2: 5th write is ignored
        await step(dut, m, 1, d, 0, "T2 fill")
    for _ in range(5):                                  # T3: 5th read is ignored
        await step(dut, m, 0, 0, 1, "T3 drain")

    await step(dut, m, 1, 0x11, 0, "T4 pre")
    for d in [0x22, 0x33, 0x44]:
        await step(dut, m, 1, d, 1, "T4 read+write")
    assert len(m) == 1

    for d in [0x55, 0x66, 0x77]:
        await step(dut, m, 1, d, 0, "T5 fill")
    await step(dut, m, 1, 0x88, 1, "T5 read+write while full")
    assert len(m) == 3
    for _ in range(4):                                  # 0x88 must never come out
        await step(dut, m, 0, 0, 1, "T5 drain")

    await step(dut, m, 1, 0x99, 1, "T5b read+write while empty")
    assert len(m) == 1
    await step(dut, m, 0, 0, 1, "T5b drain")

    for i in range(300):
        await step(dut, m, random.randint(0, 1), random.randint(0, 255), random.randint(0, 1), f"T6[{i}]")

    for d in [0xB1, 0xB2, 0xB3]:
        await step(dut, m, 1, d, 0, "T7 pre")
    await step(dut, m, 0, 0, 1, "T7 pre")
    await reset(dut, m, "T7 reset mid-operation")
    for d in [0xC1, 0xC2, 0xC3, 0xC4]:
        await step(dut, m, 1, d, 0, "T7 fill after reset")
    for _ in range(4):
        await step(dut, m, 0, 0, 1, "T7 drain after reset")
