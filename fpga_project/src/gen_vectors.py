import random
import struct
from collections import deque

ITEM_A, ITEM_B = 0x11, 0x22
NONE, SELL, BUY = 0, 1, 2


class Ref:
    def __init__(self):
        self.window = deque(maxlen=16)
        self.total = 0
        self.prev = None
        self.action = NONE

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
            self.action = BUY
        elif self.prev >= old_avg and price < new_avg:
            self.action = SELL
        self.window.append(price)
        self.total = new_total
        self.prev = price
        return self.action


lines = []


def session(prices_a, prices_b, swaps):
    ra, rb = Ref(), Ref()
    for idx, (pa, pb) in enumerate(zip(prices_a, prices_b)):
        ea, eb = ra.process(pa), rb.process(pb)
        ea = NONE if ea is None else ea
        eb = NONE if eb is None else eb
        if swaps[idx]:
            req = struct.pack(">HBHBH", idx, ITEM_B, pb, ITEM_A, pa)
            exp = struct.pack(">HBBBBH", idx, ITEM_B, eb, ITEM_A, ea, 0)
        else:
            req = struct.pack(">HBHBH", idx, ITEM_A, pa, ITEM_B, pb)
            exp = struct.pack(">HBBBBH", idx, ITEM_A, ea, ITEM_B, eb, 0)
        lines.append(f"R {req.hex().upper()} {exp.hex().upper()}")


seed = 0x57214720
rng = random.Random(seed)
pa = [rng.randint(0, 100) for _ in range(100)]
pb = [rng.randint(0, 100) for _ in range(100)]
srng = random.Random(seed ^ 0xA5A5A5A5)
sw = [(i >= 16 and srng.random() < 0.5) for i in range(100)]

lines.append("S A5")
lines.append("S 5A")
lines.append("S 00")
lines.append("W 45")

session(pa, pb, sw)

qa = [50] * 16 + [80, 85, 85, 20, 15]
qb = [100] * 16 + [60, 55, 55, 130, 140]
qs = [False] * 21
for k in (16, 19, 20):
    qs[k] = True
session(qa, qb, qs)

r = random.Random(1)
session([r.randint(0, 65535) for _ in range(100)],
        [r.randint(0, 65535) for _ in range(100)],
        [r.random() < 0.5 for _ in range(100)])

r = random.Random(2)
session([r.choice([0, 65535, 65535, 32768, 1]) for _ in range(80)],
        [r.randint(98, 102) for _ in range(80)],
        [r.random() < 0.5 for _ in range(80)])

r = random.Random(3)
session([r.randint(0, 100) for _ in range(40)],
        [r.randint(0, 100) for _ in range(40)],
        [r.random() < 0.5 for _ in range(40)])

open("testbench/vectors.txt", "w").write("\n".join(lines) + "\n")
print(len(lines), "lines")
