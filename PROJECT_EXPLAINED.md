# SPI Firmware Update Controller — Full Project Explainer

Read this like your mentor is sitting next to you asking "why," not just "what." Every
section ends with the answer you'd actually say out loud in the viva. If you remember
nothing else, remember this one sentence:

> **We built a system that takes bytes from a host, holds them safely in a buffer, and
> pushes them out one bit at a time over SPI to a peripheral device — and it works in
> both directions, across two independent clocks, with proof (not just a demo) that the
> data survives the trip.**

---

## 1. The problem, restated in plain words

The brief asked for: firmware bytes come in from a host → get buffered in memory → get
sent out serially, one bit at a time, over a synchronous link → to a "programmable
device" (a flash chip, in our case simulated by `flash_model_tb.v`). It named the
required building blocks: **FSM, Clock Divider, PISO/SIPO, Counters, FIFO, CDC,
Memory.** Every one of those exists in this project. Here's where:

| Required block | Our file | One-line job |
|---|---|---|
| FSM | `spi_fsm.v` | The brain — decides when to read the buffer, assert CS, shift, stop |
| Clock Divider | `clk_div.v` | Turns a fast system clock into a slow SPI clock (SCLK) |
| PISO | `piso_reg.v` | Turns one parallel byte into a serial bit-stream on MOSI |
| SIPO | `sipo_reg.v` | Turns an incoming serial bit-stream on MISO back into a byte |
| Counters | `bit_counter.v` | Tracks "which bit of the byte are we on" (0–7) |
| FIFO | `sync_fifo.v` | The buffer — holds bytes until the SPI side is ready for them |
| CDC | `cdc_logic.v` + `async_fifo.v` | Lets the host's clock and the SPI clock be two genuinely different, unrelated clocks, safely |
| Memory | The FIFO's internal RAM array | Where the buffered bytes physically live |

Everything else in the repo (`spi_master.v`, `spi_slave.v`, `single_clock_top.v`,
`dual_clock_top.v`) is **structural glue** — modules that don't invent new logic, they
just wire the pieces above together in a specific shape.

---

## 2. SPI, from zero, in the way you'll be asked about it

SPI is a 4-wire synchronous serial bus:

- **SCLK** — the clock, always driven by the master.
- **MOSI** (Master Out, Slave In) — data from master to slave.
- **MISO** (Master In, Slave Out) — data from slave to master.
- **CS** (Chip Select, active-low) — master pulls this low to say "I'm talking to you now."

Both sides shift on **every** clock edge — one edge to change the data line, the
opposite edge to sample it. Which edge does which is defined by two settings:

- **CPOL** (clock polarity) — does the clock idle **low** (0) or **high** (1) when nothing is happening?
- **CPHA** (clock phase) — is data sampled on the **first** edge of a cycle (0) or the **second** (1)?

That gives four combinations, called Modes 0–3:

| Mode | CPOL | CPHA | Idle level | Data changes on | Data sampled on |
|---|---|---|---|---|---|
| 0 | 0 | 0 | Low | falling edge | **rising edge** |
| 1 | 0 | 1 | Low | rising edge | falling edge |
| 2 | 1 | 0 | High | rising edge | falling edge |
| 3 | 1 | 1 | High | falling edge | rising edge |

**We built Mode 0**, and it wasn't an accident — check the code:
- `clk_div.v` holds `sclk` at `0` whenever it's disabled → clock idles low → **CPOL = 0**.
- `piso_reg.v` shifts a new MOSI bit out on `sclk`'s **falling** edge.
- `sipo_reg.v` samples MISO on `sclk`'s **rising** edge.

That "shift on falling, sample on rising" pairing is exactly Mode 0. If your mentor
asks "why Mode 0 and not 1, 2, or 3": **Mode 0 (and its mirror, Mode 3) is what almost
every commodity SPI flash chip actually supports** — Winbond W25Q-series, Microchip
SST25-series, and most others. It's the industry-default choice, not a random pick.
What we did *not* do is make CPOL/CPHA configurable — the design only speaks Mode 0.
Say that plainly if asked; don't pretend it's adjustable.

---

## 3. Every module, what it does, and why it's built that way

### `bit_counter.v` — "which bit are we on?"
A 3-bit counter, 0 to 7. Counts up once per enabled clock cycle; on the 8th count it
pulses `done` for exactly one cycle and wraps back to 0. Nothing shifts data itself —
it just tells the rest of the system "a full byte has gone by."

### `clk_div.v` — "make SCLK slower than the system clock"
Takes the fast system clock and toggles `sclk` once every `divide` input-clock cycles.
It also **gates** the clock: when `enable` is low, `sclk` is forced to a constant 0
rather than free-running. Real SPI devices need the clock to stay quiet between
transactions — a free-running clock toggling while CS is high can confuse a real chip
or waste power. This gating is why we can't just wire the system clock straight to
SCLK.

### `piso_reg.v` — Parallel-In, Serial-Out
Loads one 8-bit byte in parallel (`load` pulse), then shifts it out one bit at a time,
MSB first, on every SCLK falling edge. Because `piso_reg` needs to react to `sclk`
(a slow, *derived* clock) but is itself clocked by the fast system `clk`, it can't just
say `always @(negedge sclk)` — instead it samples `sclk` into a register (`sclk_d`)
every `clk` cycle and computes `sclk_fall = ~sclk & sclk_d` (current sclk is low, but
it *was* high last cycle → a falling edge just happened). This is the standard trick
for detecting edges on a slower, gated clock signal from within a faster clock domain.

### `sipo_reg.v` — Serial-In, Parallel-Out
The mirror image of `piso_reg`: samples MISO on every SCLK **rising** edge (same
`sclk_d`-based edge-detect trick, just looking for the opposite transition), and once 8
bits have been collected, latches them into `rx_data` and pulses `rx_valid` for one
cycle. **This module had a real bug that we found and fixed tonight — see Section 8.**

### `spi_master.v` — the structural wrapper
Per the spec: "no internal sequential logic of its own." It just instantiates
`clk_div`, `piso_reg`, `sipo_reg`, and `bit_counter`, and wires them together, exposing
the physical pins (SCLK, MOSI, CS) plus the received byte (`rx_data`, `rx_valid`) to
the outside world. One detail worth knowing cold: `bit_counter`'s reset is wired as
`reset | !enable`, not just `reset`. That's deliberate — the instant the FSM drops
`enable` (a transaction just ended), the counter is force-cleared immediately rather
than waiting for a spare SCLK edge that might never come (since SCLK is also gated off
by the same `enable`). Without that, the counter could sit at a stale bit position and
corrupt the very next byte's counting.

### `spi_slave.v` — the slave side (added tonight)
Your mentor's most pointed question was "did you design the slave part, or only the
master?" Until tonight, the honest answer was "only the master." `spi_slave.v` closes
that gap. It's deliberately **not** new shift-register logic — it reuses the exact same
verified `piso_reg` and `sipo_reg` blocks the master uses, just wired the other way:
its `piso_reg` drives MISO (loaded with the byte the slave wants to send, the instant
CS falls), and its `sipo_reg` captures MOSI. Reusing already-verified blocks instead of
writing new ones is a deliberate engineering choice — less new code means less new risk.

### `spi_fsm.v` — the brain (see Section 4 for the full walkthrough)
The Moore state machine that sequences everything: notices the FIFO isn't empty, pulls
a byte out, asserts CS, runs the shift, checks if there's more, and either loops back
for the next byte or ends the transaction.

### `sync_fifo.v` — the buffer, single clock domain
A circular buffer with a write pointer and a read pointer, each **one bit wider** than
needed to address the memory. That extra bit is the whole trick (see Section 5).

### `cdc_logic.v` and `async_fifo.v` — crossing between two clocks safely
Used only in the dual-clock system. See Section 6 — this is one of the harder concepts
and worth having a clean, confident answer for.

### `single_clock_top.v` and `dual_clock_top.v` — the two top-level systems
`single_clock_top` wires FIFO + FSM + master together on one shared clock — this is the
"does the logic work at all, ignoring timing danger" baseline. `dual_clock_top` swaps
in the CDC-safe `async_fifo` and adds a *second* FIFO for the return path (SPI → host),
so data can flow both ways across two genuinely independent clocks: a fast host clock
and a slower SPI clock. This is a step beyond the original 10-day spec, which only
asked for one-directional CDC — we extended it to full duplex.

---

## 4. The FSM, state by state

`spi_fsm.v` is a **Moore machine**: outputs depend only on the current state, never
directly on inputs. It's built with the standard two-always-block pattern — one
`always @(posedge clk)` block that just remembers the current state, and one
`always @(*)` combinational block that decides outputs and the next state. Six states:

1. **IDLE** — do nothing, just watch `fifo_empty`. The moment it goes low (there's data
   waiting), move to `LOAD_BYTE`.
2. **LOAD_BYTE** — pulse `fifo_rd_en` for one cycle to pull the next byte out of the
   FIFO. Also pulls `fsm_cs` low here already (not just in the next state) — this is a
   deliberate fix: without it, CS would blip high for one cycle between consecutive
   bytes of the same burst, which is a real protocol violation for multi-byte transfers.
3. **ASSERT_CS** — CS is low, and we pulse `load` so the PISO grabs the byte the FIFO
   just handed us. One cycle only.
4. **SHIFT** — turn on `enable`, which starts the clock divider (SCLK begins toggling)
   and the bit counter. Sit here until `byte_done` fires (8 bits have gone out), then
   pulse `rx_fifo_wr_en` to save whatever came back on MISO.
5. **CHECK** — is there more data in the FIFO? If yes, go back to `LOAD_BYTE` (CS never
   rises — this is what makes a multi-byte burst one continuous transaction instead of
   N separate ones). If no, go to `DEASSERT_CS`.
6. **DEASSERT_CS** — pull CS back high, the transaction is over, return to `IDLE`.

If asked to draw this from memory: six boxes in a loop, arrows exactly as above, and
remember that **CS only ever goes high in two places**: never asserted at all (IDLE),
or explicitly in DEASSERT_CS. It's low through LOAD_BYTE → ASSERT_CS → SHIFT → CHECK
every single time, which is what keeps a multi-byte burst glitch-free.

---

## 5. The FIFO full/empty trick

Both `sync_fifo.v` and `async_fifo.v` use read and write pointers that are **one bit
wider than needed to address the memory** (e.g. a 16-deep FIFO needs 4 bits to address
it, but the pointers are 5 bits). Why:

- **Empty**: the two pointers are *exactly* equal, extra bit included.
- **Full**: the *address* bits are equal (same slot) **but the extra bit differs**.

That extra bit is effectively "how many times has this pointer wrapped around the
buffer." If both pointers point at the same slot but one of them has wrapped one more
time than the other, the buffer is full, not empty — without the extra bit, "same
address" is ambiguous between those two cases and you can't tell full from empty at all.

---

## 6. Clock Domain Crossing — Gray code and the 2-flop synchronizer

This only matters in `dual_clock_top.v`, where the host and SPI sides run on two
**independent, unrelated clocks**. A pointer value can't just be wired straight across
clock domains — if multiple bits change at once and the destination clock samples it
mid-transition, it can catch a partially-updated, completely wrong value (not just a
metastable single bit — an actually meaningless number).

Two techniques fix this, and we use both:

1. **Gray code** (`bin2gray` / `gray2bin` in `cdc_logic.v`): re-encode the pointer so
   that incrementing it only ever changes **one bit at a time**. Now, even if the
   destination clock samples mid-transition, it either catches the old value or the new
   value — never a meaningless in-between one, because there's no "in-between" when only
   one bit moves.
2. **2-flop synchronizer** (`sync_2ff`): even a single bit that changes state right at a
   clock edge can go metastable (settle to an unpredictable 0 or 1 for a little while)
   in the receiving domain. Passing the signal through two back-to-back flip-flops
   gives it a full extra clock cycle to resolve before anything downstream reads it.

Put together: convert the pointer to Gray code (so at most one bit ever moves) → pass
it through two flip-flops in the destination clock's domain (so that one bit has time
to settle) → convert back to binary → now it's safe to compare against the local
pointer for the full/empty check.

---

## 7. The clock divider — the honest answer

Your mentor pushed hard on "why divide by that number, did you verify it, is there a
reference." Here's the honest, defensible answer, not a made-up one:

`flash_model_tb.v` — the thing our SPI master actually talks to in simulation — is a
**purely behavioral model**. It has no real timing constraints, no setup/hold
requirements, no maximum clock rating. There is no real chip in this simulation whose
datasheet we could be violating. So the divider value wasn't derived from a spec,
because there was no spec to derive it from — **say this directly if asked, don't
invent a fake justification.**

What *is* the right answer: `clk_div` takes `divide` as a **parameter** specifically so
it isn't hard-coded. The correct process for real hardware is:

```
divide ≥ system_clock_frequency / (2 × target_device_max_SCLK_frequency)
```

taken from the actual target chip's datasheet, with margin left over for board trace
delay and setup/hold timing closure once you're doing real timing analysis (not just
behavioral simulation).

One more thing worth raising yourself, proactively, before anyone else catches it:
**`clk_div.v`'s own header comment says the default is `divide=4` (→12.5 MHz from a 100
MHz clock), but `spi_master.v` actually instantiates it with `divide=2` (→25 MHz).**
That's a real inconsistency between the documentation and the actual wiring. Pointing
it out yourself, unprompted, is a far stronger answer than getting caught not knowing
it — it shows you actually read your own code rather than just trusting the comments.

---

## 8. The bug we found tonight — and why it's a good story to tell

This is worth walking through in the defense, because it directly answers "did you
verify anything, or did you just assume it works":

**What we built to check it:** `tb_master_slave.v` — one testbench, a real
`spi_master` and a real `spi_slave` wired together, checking automatically (with
`if`/`$display` PASS/FAIL) whether the byte each side sent is the byte the other side
actually received. Not a manual "look at the waveform and eyeball it" test — an
automatic pass/fail check, exactly what your mentor asked for.

**What happened the first time we ran it:** it failed. Both directions read back
`0x00` — nothing was ever received, on either side.

**What we found:** `sipo_reg.v` detects an SCLK edge by comparing the current SCLK
value against a copy of itself delayed by one system-clock cycle (`sclk_d`) — this is
the same, completely normal edge-detection technique `piso_reg` uses. The problem: the
FSM turns `enable` off the **instant** `bit_counter` (a separate module, clocked
*directly* by SCLK with zero delay) reports the 8th bit is done — and that's the exact
same instant as the real, final SCLK edge. `sipo_reg`, because of its one-cycle
detection delay, doesn't actually notice that final edge until one cycle later — by
which point `enable` has already dropped, so its condition `enable && sclk_rise` fails,
and the last bit (plus the whole byte, plus the `rx_valid` pulse) is silently dropped.
**Forever. Every single byte, every single time**, in every part of the design that
receives data (`spi_master`'s own RX path, and therefore `dual_clock_top`'s entire RX
FIFO).

**The fix:** register `enable` the same way `sclk` already is, and accept a detected
edge if `enable` was high *either right now or one cycle ago*:
`(enable || enable_d) && sclk_rise`. That closes exactly this race without touching the
FSM or any other timing.

**How we know it's actually fixed, not just "should be fixed":** re-ran the same
testbench — both directions went from FAIL to PASS. Then re-ran the pre-existing,
already-working tests (`tb_spi_master.v`, `tb_piso_reg.v`) to make sure the fix didn't
break the transmit side — both still pass, unchanged. That's the actual verification
story: found by a real automatic test, root-caused with signal tracing, fixed with a
one-line change, and confirmed with a before/after comparison plus a regression check.

If your mentor asks "how do you know your design actually works" — this is your
answer. Not "we ran it and it looked fine," but "we wrote a test that could fail, it
did fail, we found out exactly why, and now it doesn't."

---

## 9. Why we kept both the per-module tests *and* one integrated test

This was the mentor's gate-circuit analogy: you verify an AND gate and an XOR gate
separately, but you still need to build the *actual* circuit out of them and test *that*
before you know the whole thing works. Same idea here:

- **Per-module testbenches** (`tb_bit_counter`, `tb_clk_div`, `tb_piso_reg`,
  `tb_spi_master`, `tb_fsm_fifo`, `tb_phase1_all_4stags`) isolate one block at a time —
  useful for finding a bug and knowing exactly which module it's in, without the rest
  of the system's complexity in the way.
- **One integrated testbench** (`tb_master_slave.v`, and the pre-existing
  `tb_single_clock_top.v` / `tb_dual_clock_top.v`) proves the *composition* works —
  that the pieces, wired together the way the real system wires them, actually pass
  data correctly end to end. **The bug in Section 8 only ever showed up in the
  integrated test.** Every per-module test that touched `sipo_reg` in isolation could
  have passed without ever exercising this exact race condition, because the race
  depends on the *interaction* between `bit_counter`'s zero-lag timing and
  `sipo_reg`'s one-cycle-lagged detection — two different modules, both individually
  "correct," failing only when combined. That's the whole reason integration testing
  exists, and now you have a concrete, real example of it happening in your own project.

---

## 10. How to read the waveform (Vivado)

Open the waveform for `tb_master_slave` (Flow Navigator → Simulation → Run Behavioral
Simulation, after setting it as the simulation top). Add these signals if they aren't
already shown, roughly top to bottom:

```
clk, reset            (top-level timing)
cs, sclk, mosi, miso   (the actual SPI bus)
enable, byte_done      (master's control signals)
u_slave/rx_valid, u_slave/rx_data     (what the slave captured)
u_master/rx_valid, u_master/rx_data   (what the master captured back)
```

What you should actually see, tick by tick (real numbers from our run — use these to
sanity-check your own waveform, they should match exactly):

1. **0–30 ns**: `reset` high, everything at 0.
2. **~35 ns**: `reset` releases; the testbench loads `0xB6` into the master's own PISO
   (this is the byte the master will send).
3. **~40 ns**: `cs` falls to 0 — the slave is now selected. The slave's own PISO loads
   `0x3C` (the byte the slave will send back) right at this moment.
4. **~55 ns to ~335 ns**: `sclk` toggles 8 full cycles, one rising edge every 40 ns
   (that's `divide=2`: 100 MHz system clock ÷ 4 = 25 MHz SCLK). On every rising edge,
   read off one bit of MOSI and one bit of MISO:

   | Rising edge # | Time | MOSI bit | MISO bit |
   |---|---|---|---|
   | 1 | 55 ns  | 1 | 0 |
   | 2 | 95 ns  | 0 | 0 |
   | 3 | 135 ns | 1 | 1 |
   | 4 | 175 ns | 1 | 1 |
   | 5 | 215 ns | 0 | 1 |
   | 6 | 255 ns | 1 | 1 |
   | 7 | 295 ns | 1 | 0 |
   | 8 | 335 ns | 0 | 0 |

   Read the MOSI column top to bottom: `1 0 1 1 0 1 1 0` = **0xB6** — exactly what the
   master loaded. Read the MISO column the same way: `0 0 1 1 1 1 0 0` = **0x3C** —
   exactly what the slave loaded. This is MSB-first shifting, which is why the *first*
   bit you see is the top bit of the byte, not the bottom one.
5. **335 ns**: `byte_done` pulses high for one cycle — `bit_counter` (inside the
   master) has seen all 8 edges.
6. **340 ns**: `cs` goes back to 1 (deasserted) — the FSM/testbench ends the transaction.
7. **345 ns**: `rx_valid` pulses on *both* sides, and `rx_data` updates to the final
   value — `0xB6` on the slave's side, `0x3C` on the master's side. Notice this is
   **5 ns after `cs` already went high** — that's the one-cycle detection lag from
   Section 8, and it's exactly why the fix was needed: without it, this final update
   would never have happened at all, because `enable` (and in the old, broken version,
   the missing grace period) would already be gone by 345 ns.

If you're instead looking at `tb_dual_clock_top`'s waveform, the same reading technique
applies, just with three bytes back-to-back instead of one, and two independent clocks
(`host_clk` at 200 MHz, `spi_clk` at 100 MHz) instead of one shared `clk` — watch for
the extra latency between a byte being ready on the SPI side and it becoming visible on
the host side, which is the 2-flop synchronizer in Section 6 doing its job.

---

## 11. Known limitations — say these yourself, before you're asked

Being the one to raise a gap, with a clear reason it's out of scope for now, reads as
competence. Getting caught not knowing about it reads as the opposite.

- **`spi_slave.v` doesn't support other SPI modes** — Mode 0 only, matching the master.
  Making CPOL/CPHA configurable is real, additional work, not done tonight.
- **`spi_slave.v`'s MISO data loads once per CS assertion** — in a multi-byte burst
  (CS held low across several bytes, which our FSM does), only the *first* byte sent
  back from the slave is guaranteed correct; the slave would need to reload its
  transmit register once per byte, not once per transaction, for multi-byte slave-TX
  to be fully correct. Fine for the one-byte verification test; a real limitation for
  anything longer.
- **`dual_clock_top`'s RX-direction FIFO has its `full` flag left unconnected.** If the
  host doesn't read incoming bytes fast enough, new data silently overwrites unread
  data with no overflow warning.
- **`tb_dual_clock_top.v` still only `$display`s its RX bytes** — it doesn't assert
  them against an expected value the way `tb_master_slave.v` does. It runs and produces
  output, but that output isn't automatically checked.
- **`src/sync_fifo.v` and `sim/sync_fifo.v` are identical duplicate files** — harmless,
  but if you ever change FIFO logic, remember there are two copies.

---

## 12. Quick answer key — mapped directly to the questions you were actually asked

**"How many testbenches, and are they integrated?"**
Nine per-module/per-integration testbenches for isolating individual blocks, plus one
new fully integrated, self-checking master+slave testbench (`tb_master_slave.v`) and
two existing full-system testbenches (`tb_single_clock_top.v`, `tb_dual_clock_top.v`).
Per-module tests find bugs fast and pinpoint which module; the integrated tests are
what actually proves the system works, and in fact caught a real bug the per-module
tests couldn't have (Section 8).

**"What are SPI modes — do you know them?"** See Section 2. Answer with the CPOL/CPHA
table from memory, then state we implemented Mode 0 and why that's the standard choice.

**"How did you pick the clock divider value, did you verify it?"** See Section 7. No
real target chip exists in this simulation to verify against; the value is a
`parameter` precisely so it can be tuned once a real device is chosen, and the correct
formula is `divide ≥ sys_clk / (2 × device_max_SCLK)`.

**"Did you design the slave, or only the master?"** Both now — `spi_slave.v`, reusing
the same verified PISO/SIPO blocks as the master (Section 3).

**"Should you integrate everything into one top module and one testbench?"** Yes, and
we did — `tb_master_slave.v` (plus the pre-existing top-level ones). Section 9 explains
why this matters beyond just "the mentor asked for it."

**"Can you show data transmitting through MOSI/MISO and explain it?"** Yes — Section 10
walks through the exact waveform, edge by edge, with real numbers.
