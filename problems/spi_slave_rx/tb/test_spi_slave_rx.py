"""cocotb testbench for spi_slave_rx -- identical for every (format, dialect, model) cell.

Checks:
  T1  reset values (and reset mid-operation, T1b)
  T2  a sequence of bytes, one byte per cs_n assertion
  T3  back-to-back bytes with cs_n held low
  T4  a partial byte aborted by cs_n (must NOT produce valid; next byte must re-align)
  T5  valid is exactly one clk cycle wide and data holds between bytes
  T6  mosi is sampled on sclk RISING edges (mosi changes on falling edges)
Latency budget: valid must arrive within MAX_LAT clk cycles of the 8th sclk rising edge.
"""
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer

CLK_NS = 10          # 100 MHz system clock
SCLK_HALF_NS = 60    # 12 clk cycles per sclk period (>= 8x requirement)
MAX_LAT = 6          # clk cycles from 8th rising edge to valid


def val(sig, tag):
    """int() of a signal, turning X/Z into a test failure with a readable message."""
    try:
        return int(sig.value)
    except ValueError:
        raise AssertionError(f"{tag}: {sig._name} is X/Z ({sig.value})") from None


async def reset(dut):
    dut.rst_n.value = 0
    dut.sclk.value = 0
    dut.mosi.value = 0
    dut.cs_n.value = 1
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def spi_send_bits(dut, bits):
    """Drive bits (MSB first) in mode 0: mosi set while sclk low, sclk rises, sclk falls."""
    for b in bits:
        dut.mosi.value = b
        await Timer(SCLK_HALF_NS, "ns")
        dut.sclk.value = 1
        await Timer(SCLK_HALF_NS, "ns")
        dut.sclk.value = 0
    dut.mosi.value = random.randint(0, 1)   # junk after the byte so a late sampler reads garbage


async def wait_valid(dut, max_cycles, tag):
    for i in range(max_cycles):
        await RisingEdge(dut.clk)
        await Timer(1, "ns")
        if val(dut.valid, tag) == 1:
            return i
    return None


async def expect_byte(dut, byte, tag):
    bits = [(byte >> (7 - i)) & 1 for i in range(8)]
    await spi_send_bits(dut, bits[:7])
    dut.mosi.value = bits[7]
    await Timer(SCLK_HALF_NS, "ns")
    dut.sclk.value = 1                     # 8th rising edge
    lat = await wait_valid(dut, MAX_LAT + 2, tag)
    assert lat is not None, f"{tag}: valid never asserted for byte 0x{byte:02X}"
    assert lat <= MAX_LAT, f"{tag}: valid latency {lat} > {MAX_LAT}"
    got = val(dut.data, tag)
    assert got == byte, f"{tag}: data=0x{got:02X} expected 0x{byte:02X}"
    await RisingEdge(dut.clk)              # T5: exactly one cycle wide
    await Timer(1, "ns")
    assert val(dut.valid, tag) == 0, f"{tag}: valid wider than one clk cycle"
    await Timer(SCLK_HALF_NS, "ns")        # finish the 8th sclk period
    dut.sclk.value = 0
    await Timer(SCLK_HALF_NS, "ns")
    assert val(dut.data, tag) == byte, f"{tag}: data did not hold after valid"


@cocotb.test(timeout_time=2, timeout_unit="ms")   # whole test is ~45 us of sim time
async def test_spi_slave_rx(dut):
    random.seed(1)
    cocotb.start_soon(Clock(dut.clk, CLK_NS, "ns").start())
    await reset(dut)

    assert val(dut.data, "T1") == 0, "T1: data != 0 after reset"
    assert val(dut.valid, "T1") == 0, "T1: valid != 0 after reset"

    for byte in [0xA5, 0x00, 0xFF, 0x55, 0xAA, 0x80, 0x01] + [random.randint(0, 255) for _ in range(5)]:
        dut.cs_n.value = 0
        await Timer(SCLK_HALF_NS, "ns")
        await expect_byte(dut, byte, "T2")
        dut.cs_n.value = 1
        await ClockCycles(dut.clk, 5)
        assert val(dut.valid, "T2") == 0, "T2: spurious valid while idle"

    dut.cs_n.value = 0                      # T3 back-to-back with cs_n low
    await Timer(SCLK_HALF_NS, "ns")
    for byte in [0x3C, 0xC3, 0x5A, random.randint(0, 255)]:
        await expect_byte(dut, byte, "T3")
    dut.cs_n.value = 1
    await ClockCycles(dut.clk, 5)

    last = val(dut.data, "T4")              # T4 partial byte aborted by cs_n
    dut.cs_n.value = 0
    await Timer(SCLK_HALF_NS, "ns")
    await spi_send_bits(dut, [1, 1, 1])
    dut.cs_n.value = 1
    await ClockCycles(dut.clk, 8)
    assert val(dut.valid, "T4") == 0, "T4: valid asserted for a partial byte"
    assert val(dut.data, "T4") == last, "T4: data changed on a partial byte"
    dut.cs_n.value = 0
    await Timer(SCLK_HALF_NS, "ns")
    await expect_byte(dut, 0x0F, "T4")
    dut.cs_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 0                     # T1b reset mid-operation clears data
    await ClockCycles(dut.clk, 2)
    assert val(dut.data, "T1b") == 0, "T1b: data not cleared by reset"
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
