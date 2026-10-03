# Project Name

## Team Members

- Tyler Lee - tylerleee0105@gmail,com
- Dustin N - dustinn1204@gmail.com 
- Cole Hawkins - thecolehawkins@gmail.com

## Project Overview

Briefly explain what your project does and the main idea behind the implementation.

## FPGA Implementation

Describe what is implemented directly on the FPGA.

During the official run, no team-supplied host software is executed. All UART parsing, state, algorithmic computation, and response generation must happen on the FPGA.

## Host-Side Tooling (Local Testing Only)

List any host-side scripts or tools used for local testing or demos. These are **not** run during judging. If none, write `None.`

## Hardware

- FPGA board: Tang Nano 20K
- FPGA number / asset tag assigned to team: `#___`
- Additional hardware/peripherals used:

## HDL / Languages

- HDL used: VHDL
- Host-side language(s) for local testing, if applicable:

## Toolchain

- Gowin EDA version: (organizer reference: V1.9.11.03 Education)
- Device part number: (organizer reference: GW2AR-LV18QN88C8/I7)
- Other required software/tools:
- Operating system, if relevant:

## Top-Level Entity / Module

The top-level entity/module name is your choice. Make sure it is set as the Gowin **Top Module/Entity**.

```text
top_level_name_here
```

## Top-Level Ports

Confirm that the top-level port names match the organizer-supplied `19_tang_nano_20k.cst` exactly (port names may not be renamed):

```text
sys_clk    pin 4   in   27 MHz clock
reset_btn  pin 87  in   pull-down (optional)
uart_rx_i  pin 70  in   BL616 -> FPGA
uart_tx_o  pin 69  out  FPGA -> BL616
led0_n     pin 15  out  active low (optional)
led1_n     pin 16  out  active low (optional)
```

## Organizer-Supplied Constraint File

State that the organizer-provided `19_tang_nano_20k.cst` file is used and identify its location in this repository.

Do not create your own constraint file or recreate the board pin constraints in FloorPlanner.

## Repository Structure

Briefly describe the important folders/files, including where the final `.fs` file is.

## Build Instructions

1. Open/import the Gowin project.
2. Add/verify required source files.
3. Add the organizer-supplied `.cst` as the physical constraint file.
4. Verify the top-level entity/module.
5. Run synthesis.
6. Run Place & Route.
7. Locate the generated programming file (`impl/pnr/<project>.fs`) and copy it to the repository.
8. Note any project-specific steps.

## Programming the Tang Nano 20K

Explain how to load the final `.fs` onto the board. Judges program in **SRAM mode**.

- `.fs` file location in this repository:

## Fixed UART Interface

Confirm that the design follows the official interface:

```text
PC -> FPGA:
[index16][item1_8][price1_16][item2_8][price2_16]

FPGA -> PC:
[index16][item1_8][action1_8][item2_8][action2_8][reserved16]

reserved = 0x0000

ITEM_A = 0x11
ITEM_B = 0x22

NONE = 0x00
SELL = 0x01
BUY  = 0x02

UART = 115200 baud, 8N1, LSB first
Packet size = 8 bytes each direction
Multi-byte fields = big-endian
Routing = by item ID; response mirrors request slot order
```

## How to Reproduce the Demo

1.
2.
3.

Expected result:

```text
Describe what the judge should observe.
```

## Verification / Testing

Describe how the design was tested, including results from `21_quick_uart_test.py` and `22_robust_uart_test.py`.

## Judging Metrics / Results

> Official judging uses one 100-packet run (indices 0–99): 84 scored packets and 168 scored actions.

### Correctness

- Local test used:
- Packet correctness (out of 84):
- Action correctness (out of 168):
- Estimated correctness points from `trade_summary_100.txt` (out of 70):

### Latency

- Average measured round-trip latency:
- Idle time or buffering between response bytes (BL616 workaround):
- Test/setup used:

### LUT Usage

After synthesis, open:

**Synthesis Report → Resource → Resource Usage Summary**

Record:

- **Total LUT (used for judging):**
- LUT2:
- LUT3:
- LUT4:
- Other relevant resource usage:

## External Libraries / IP / Starter Code

List any external libraries, IP cores, starter code, datasets, or other pre-existing resources used and their purpose. If none were used, write `None.`

## Known Limitations

Document any limitations, incomplete features, assumptions, or known issues.

## Final Submission

- GitHub repository URL:
- Devpost project URL:

This repository must stay public through judging and must not be deleted or renamed. Private repositories are not accepted.

Do not put the SHA in your README: a commit cannot contain its own SHA. Record the full SHA from `git rev-parse HEAD` and enter it on Devpost (in your Devpost project description if there is no dedicated field).