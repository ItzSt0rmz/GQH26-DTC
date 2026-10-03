"""
GQH Hardware Track - quick UART test (participant version)

A short sanity check of basic communication and packet format. Run this first,
then run 22_robust_uart_test.py.

Change ONLY the PORT setting below.

Requires: Python 3 and pyserial  (pip install pyserial)
"""

import struct
import time
from collections import deque

import serial

PORT = "COM11"      # your board's COM port (see Windows Device Manager)
BAUD = 115200

ACTION_NONE = 0x00
ACTION_SELL = 0x01
ACTION_BUY = 0x02

ITEM_A = 0x11
ITEM_B = 0x22

WARMUP = 16


def action_name(v):
    return {
        ACTION_NONE: "NONE",
        ACTION_SELL: "SELL",
        ACTION_BUY: "BUY",
    }.get(v, f"0x{v:02X}")


def build_input_packet(index, item1, price1, item2, price2):
    # > H B H B H = 16 + 8 + 16 + 8 + 16 = 64 bits
    return struct.pack(">HBHBH", index, item1, price1, item2, price2)


def decode_output_packet(raw):
    # Output = index, item1, action1, item2, action2, reserved16
    return struct.unpack(">HBBBBH", raw)


class Reference:
    """Same 16-sample moving-average model the robust test uses."""

    def __init__(self):
        self.window = deque(maxlen=16)
        self.total = 0
        self.prev = None
        self.action = ACTION_NONE

    def process(self, price):
        if len(self.window) < 16:
            self.window.append(price)
            self.total += price
            self.prev = price
            return None
        old_avg = self.total >> 4
        new_total = self.total - self.window[0] + price
        new_avg = new_total >> 4
        if self.prev <= old_avg and price > new_avg:
            self.action = ACTION_BUY
        elif self.prev >= old_avg and price < new_avg:
            self.action = ACTION_SELL
        self.window.append(price)
        self.total = new_total
        self.prev = price
        return self.action


prices_a = [50] * 16 + [80, 85, 85, 20, 15]
prices_b = [100] * 16 + [60, 55, 55, 130, 140]

# After warm-up the items appear in either slot, in no fixed pattern.
# Your design must route by item ID only, never by packet index or slot.
swap_slots = {16: True, 17: False, 18: False, 19: True, 20: True}

ref_a, ref_b = Reference(), Reference()
expected_a = [ref_a.process(p) for p in prices_a]
expected_b = [ref_b.process(p) for p in prices_b]

problems = 0

with serial.Serial(PORT, BAUD, timeout=1.0) as ser:
    time.sleep(0.2)
    ser.reset_input_buffer()

    for index, (pa, pb) in enumerate(zip(prices_a, prices_b)):

        if swap_slots.get(index, False):
            item1, price1, exp1 = ITEM_B, pb, expected_b[index]
            item2, price2, exp2 = ITEM_A, pa, expected_a[index]
        else:
            item1, price1, exp1 = ITEM_A, pa, expected_a[index]
            item2, price2, exp2 = ITEM_B, pb, expected_b[index]

        tx = build_input_packet(index, item1, price1, item2, price2)

        t0 = time.perf_counter_ns()
        ser.write(tx)
        rx = ser.read(8)
        t1 = time.perf_counter_ns()

        if len(rx) != 8:
            raise TimeoutError(
                f"Timeout at index {index}: received {len(rx)} of 8 bytes"
            )

        rx_index, rx_item1, action1, rx_item2, action2, reserved = \
            decode_output_packet(rx)

        latency_us = (t1 - t0) / 1000.0

        if index < WARMUP:
            verdict = "WARMUP"
        else:
            ok = (rx_index == index and rx_item1 == item1 and rx_item2 == item2
                  and action1 == exp1 and action2 == exp2 and reserved == 0)
            verdict = "OK" if ok else "MISMATCH"
            if not ok:
                problems += 1

        print(
            f"idx={rx_index:3d} | "
            f"item 0x{rx_item1:02X}: {action_name(action1):4s} | "
            f"item 0x{rx_item2:02X}: {action_name(action2):4s} | "
            f"reserved=0x{reserved:04X} | "
            f"{verdict:8s} | {latency_us:9.1f} us"
        )

print()
print("PASS" if problems == 0 else f"{problems} MISMATCH(ES): see the lines above")
