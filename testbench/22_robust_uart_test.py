"""
GQH Hardware Track - robust UART test (participant version)

Sends 100 packets to your Tang Nano 20K over UART, checks every response
against a software reference model, and writes a CSV + summary.

Change ONLY the PORT setting below. Do not change the packet protocol or the
scoring logic. The official judging run uses a different, unpublished seed.

Requires: Python 3 and pyserial  (pip install pyserial)
"""

import csv
import random
import struct
import time
from collections import deque

import serial

# ============================================================
# SETTINGS  (change PORT only)
# ============================================================

PORT = "COM11"          # your board's COM port (see Windows Device Manager)
BAUD = 115200

PACKET_COUNT = 100     # official run length: indices 0-99
WINDOW_SIZE = 16       # indices 0-15 are warm-up

PRICE_MIN = 0
PRICE_MAX = 100

ITEM_A = 0x11
ITEM_B = 0x22

# PRACTICE seed. The official judging seed is different and not published.
RANDOM_SEED = 0x57214720

CSV_FILE = "trade_results_100.csv"
SUMMARY_FILE = "trade_summary_100.txt"

ACTION_NONE = 0x00
ACTION_SELL = 0x01
ACTION_BUY = 0x02

TIMEOUT_S = 1.0        # per-packet timeout used by the judge

SCORED_PACKETS_TOTAL = PACKET_COUNT - WINDOW_SIZE   # 84
SCORED_ACTIONS_TOTAL = SCORED_PACKETS_TOTAL * 2     # 168


# ============================================================
# PACKET FORMAT
# ============================================================

# PC -> FPGA: [index16, item1_8, price1_16, item2_8, price2_16]
INPUT_STRUCT = struct.Struct(">HBHBH")

# FPGA -> PC: [index16, item1_8, action1_8, item2_8, action2_8, reserved16]
OUTPUT_STRUCT = struct.Struct(">HBBBBH")


def action_name(v):
    return {
        ACTION_NONE: "NONE",
        ACTION_SELL: "SELL",
        ACTION_BUY: "BUY",
    }.get(v, f"0x{v:02X}")


# ============================================================
# SOFTWARE REFERENCE MODEL
# ============================================================

class MovingAverageReference:
    def __init__(self):
        self.window = deque(maxlen=WINDOW_SIZE)
        self.running_sum = 0
        self.last_price = None
        self.action = ACTION_NONE

    def process(self, price):
        # Warm-up: fill the window AND keep the previous price current.
        if len(self.window) < WINDOW_SIZE:
            self.window.append(price)
            self.running_sum += price
            self.last_price = price
            return None

        old_avg = self.running_sum >> 4

        oldest = self.window[0]
        new_sum = self.running_sum - oldest + price
        new_avg = new_sum >> 4

        if self.last_price <= old_avg and price > new_avg:
            self.action = ACTION_BUY
        elif self.last_price >= old_avg and price < new_avg:
            self.action = ACTION_SELL
        # No crossing -> repeat the previous action.

        self.window.append(price)
        self.running_sum = new_sum
        self.last_price = price
        return self.action


# ============================================================
# GENERATE ALL TEST VECTORS BEFORE TRANSMISSION
# ============================================================

rng = random.Random(RANDOM_SEED)
prices_a = [rng.randint(PRICE_MIN, PRICE_MAX) for _ in range(PACKET_COUNT)]
prices_b = [rng.randint(PRICE_MIN, PRICE_MAX) for _ in range(PACKET_COUNT)]

# Slot placement: after warm-up, either item may appear in either slot on any
# packet. Your design must route by item ID only.
slot_rng = random.Random(RANDOM_SEED ^ 0xA5A5A5A5)
swap_slots = [
    (i >= WINDOW_SIZE and slot_rng.random() < 0.5) for i in range(PACKET_COUNT)
]

ref_a = MovingAverageReference()
ref_b = MovingAverageReference()
expected_a = [ref_a.process(p) for p in prices_a]
expected_b = [ref_b.process(p) for p in prices_b]


# ============================================================
# TEST  (stop-and-wait: never send N+1 until N is fully answered)
# ============================================================

rows = []
successful_latencies = []
correct_packets = 0
correct_actions = 0
timeout_count = 0

print()
print(f"Generated {PACKET_COUNT} packets "
      f"({SCORED_PACKETS_TOTAL} scored, {SCORED_ACTIONS_TOTAL} scored actions).")
print(f"Opening {PORT} at {BAUD} baud...")
print()

with serial.Serial(PORT, BAUD, timeout=TIMEOUT_S) as ser:

    time.sleep(0.2)
    ser.reset_input_buffer()

    for index in range(PACKET_COUNT):

        pa, pb = prices_a[index], prices_b[index]
        exp_a, exp_b = expected_a[index], expected_b[index]

        if swap_slots[index]:
            item1, price1, expected1 = ITEM_B, pb, exp_b
            item2, price2, expected2 = ITEM_A, pa, exp_a
        else:
            item1, price1, expected1 = ITEM_A, pa, exp_a
            item2, price2, expected2 = ITEM_B, pb, exp_b

        tx = INPUT_STRUCT.pack(index, item1, price1, item2, price2)

        t0 = time.perf_counter_ns()
        ser.write(tx)
        rx = ser.read(8)
        t1 = time.perf_counter_ns()
        latency_us = (t1 - t0) / 1000.0

        base = {
            "index": index,
            "tx_item1": f"0x{item1:02X}",
            "tx_price1": price1,
            "tx_item2": f"0x{item2:02X}",
            "tx_price2": price2,
            "expected_action1": "IGNORED" if expected1 is None else action_name(expected1),
            "expected_action2": "IGNORED" if expected2 is None else action_name(expected2),
        }

        # ---------------- TIMEOUT / PARTIAL RESPONSE ----------------
        if len(rx) != 8:
            timeout_count += 1
            partial_hex = rx.hex(" ").upper() if rx else "NONE"
            print(f"[{index:02d}] TIMEOUT: received {len(rx)}/8 bytes: {partial_hex}")
            rows.append({
                **base,
                "rx_index": "", "rx_item1": "", "rx_action1": "",
                "rx_item2": "", "rx_action2": "", "rx_reserved": partial_hex,
                "action1_correct": "", "action2_correct": "", "packet_correct": "",
                "status": "TIMEOUT",
                "latency_us": f"{latency_us:.2f}",
            })
            # A timeout ends the run. Packets not received score zero.
            break

        rx_index, rx_item1, rx_action1, rx_item2, rx_action2, reserved = \
            OUTPUT_STRUCT.unpack(rx)
        successful_latencies.append(latency_us)

        # ---------------- SCORE ----------------
        if index < WINDOW_SIZE:
            status = "IGNORED_WARMUP"
            action1_correct = action2_correct = packet_correct = ""
            expected1_text = expected2_text = "---"
        else:
            index_ok = rx_index == index
            item1_ok = rx_item1 == item1
            item2_ok = rx_item2 == item2
            action1_ok = rx_action1 == expected1
            action2_ok = rx_action2 == expected2
            reserved_ok = reserved == 0x0000

            correct_actions += int(action1_ok) + int(action2_ok)

            packet_ok = (index_ok and item1_ok and item2_ok
                         and action1_ok and action2_ok and reserved_ok)

            if packet_ok:
                correct_packets += 1
                status = "CORRECT"
            else:
                failed = []
                if not index_ok:
                    failed.append("INDEX")
                if not item1_ok:
                    failed.append("ITEM1")
                if not action1_ok:
                    failed.append("ACTION1")
                if not item2_ok:
                    failed.append("ITEM2")
                if not action2_ok:
                    failed.append("ACTION2")
                if not reserved_ok:
                    failed.append("RESERVED")
                status = "WRONG_" + "_".join(failed)

            action1_correct = "YES" if action1_ok else "NO"
            action2_correct = "YES" if action2_ok else "NO"
            packet_correct = "YES" if packet_ok else "NO"
            expected1_text = action_name(expected1)
            expected2_text = action_name(expected2)

        rows.append({
            **base,
            "rx_index": rx_index,
            "rx_item1": f"0x{rx_item1:02X}",
            "rx_action1": action_name(rx_action1),
            "rx_item2": f"0x{rx_item2:02X}",
            "rx_action2": action_name(rx_action2),
            "rx_reserved": f"0x{reserved:04X}",
            "action1_correct": action1_correct,
            "action2_correct": action2_correct,
            "packet_correct": packet_correct,
            "status": status,
            "latency_us": f"{latency_us:.2f}",
        })

        print(
            f"[{index:02d}] TX: 0x{item1:02X}:{price1:3d}, 0x{item2:02X}:{price2:3d} | "
            f"EXPECTED: {expected1_text:4s}, {expected2_text:4s} | "
            f"RX: 0x{rx_item1:02X}:{action_name(rx_action1):4s}, "
            f"0x{rx_item2:02X}:{action_name(rx_action2):4s} | "
            f"{status:16s} | {latency_us:9.2f} us"
        )


# ============================================================
# WRITE CSV
# ============================================================

csv_fields = [
    "index", "tx_item1", "tx_price1", "tx_item2", "tx_price2",
    "expected_action1", "expected_action2",
    "rx_index", "rx_item1", "rx_action1", "rx_item2", "rx_action2", "rx_reserved",
    "action1_correct", "action2_correct", "packet_correct",
    "status", "latency_us",
]

with open(CSV_FILE, "w", newline="", encoding="utf-8") as file:
    writer = csv.DictWriter(file, fieldnames=csv_fields)
    writer.writeheader()
    writer.writerows(rows)


# ============================================================
# FINAL STATISTICS  (fixed denominators: 84 packets / 168 actions)
# ============================================================

packet_correctness = correct_packets / SCORED_PACKETS_TOTAL * 100.0
action_correctness = correct_actions / SCORED_ACTIONS_TOTAL * 100.0
packet_points = 50.0 * correct_packets / SCORED_PACKETS_TOTAL
action_points = 20.0 * correct_actions / SCORED_ACTIONS_TOTAL

average_latency_us = (
    sum(successful_latencies) / len(successful_latencies)
    if successful_latencies else 0.0
)

lines = [
    "FPGA Dual-Item Trade Signal Test",
    "================================",
    "",
    f"Requested packets: {PACKET_COUNT}",
    f"Packets successfully received: {len(successful_latencies)}",
    f"Warm-up packets ignored: {WINDOW_SIZE}",
    f"Scored packets (fixed): {SCORED_PACKETS_TOTAL}",
    f"Correct packets: {correct_packets}",
    f"Packet correctness: {packet_correctness:.2f}%",
    f"Correct individual actions: {correct_actions}/{SCORED_ACTIONS_TOTAL}",
    f"Action correctness: {action_correctness:.2f}%",
    f"Timeouts: {timeout_count}",
    "",
    f"Estimated correctness points: {packet_points + action_points:.1f} / 70",
    "",
    f"Average successful round-trip latency: {average_latency_us:.2f} us",
    f"Average successful round-trip latency: {average_latency_us / 1000.0:.3f} ms",
    "",
    f"UART port: {PORT}",
    f"UART baud rate: {BAUD}",
    f"Practice seed: 0x{RANDOM_SEED:08X}",
    "",
]

with open(SUMMARY_FILE, "w", encoding="utf-8") as file:
    file.write("\n".join(lines))

print()
print("=" * 40)
print("FINAL TEST RESULTS")
print("=" * 40)
for ln in lines[3:-1]:
    if ln:
        print(ln)
print(f"CSV output: {CSV_FILE}")
print(f"Summary output: {SUMMARY_FILE}")
print("=" * 40)
print()
