---
name: reverse-engineer
description: Method for reverse engineering a binary with a disassembler MCP (IDA idalib, Ghidra, Binary Ninja) so that every claim is addressed, verified in the disassembly, recorded in docs/, and checked against an oracle where one exists. Use for any task labeled `re` or any reading of the target's code.
---

# Reverse engineering method

This skill packages the method used in OpenRB-338. Merge it with your own "reverse engineer
anything" skill: keep your tool-specific steps and add the rules below.

## 1. Open safely

1. Get the database path from the supervisor's prompt. Do not search the disk for it.
2. Copy it into `<scratchpad>/<branch>/`. The human's file is only read.
3. Open the copy headless (IDA: `idb_open(input_path=<copy>, mode="force_headless")`).
4. Never rename, retype, comment or patch. Facts go into docs/ and the task notes.
5. Close without saving (`idb_close(save=false)`).

## 2. Trust order

1. **The disassembly** is the reference.
2. **The bytes.** Decode constants from the raw bytes, not from the tool's float display.
3. **The decompiler** is a second opinion only. Check against the disassembly:
   - operand order of floating-point ops (x87 `fsubr` and `fdivr` reverse the operands);
   - every store width, which is a rounding point (`fstp dword` rounds to f32);
   - every integer conversion and its rounding mode;
   - signedness of compares and shifts.
4. Know which data ranges are zero on disk and filled at run time. A table there must be dumped
   from a live process or regenerated.

## 3. Record as you go

In the task's notes (`backlog task edit N --append-notes`):
- **Evidence:** function, address, the instruction that proves it, e.g.
  `0x436CF3 imul edx,0C0h; shr edx,3 -> tick = rbs*24`.
- **Checks against data:** what you ran over real inputs and what matched.
- **Failed hypotheses:** each idea you refuted and the address or data that refuted it.
- **Reproduce:** the command or the script logic, so a reviewer can redo it without your scratch
  files.

## 4. Write the conclusions into docs/

- Every fact carries its address (state the image base and address prefix per module).
- Mark each item **[C]** (confirmed in the disassembly) or **[G]** (guessed or inferred).
- Resolve the survey's [G] items you touched: confirm, refute or narrow them, in place.
- A defect of the original also goes into `docs/original_bugs.md` with What, Where, Trigger,
  Effect, Corpus, Model in the rewrite, and [C]/[G]. The rewrite copies the bug on purpose and
  says where.
- Errata of an official spec go into a section of the topic document.

## 5. Prove it with an oracle

Static reading proposes and the oracle decides. In order of preference:
1. **A headless host** that loads the original library and calls it directly (fast and
   deterministic).
2. **The original app** on a test machine, driven by a runner script. Take the shared-hardware
   permits first.
3. **A reference corpus** of the original's outputs plus a comparator that prints the first
   difference (position, context, both values).

State the oracle result in the notes and the commit message: exact, within tolerance, or the
first differing value.

## 6. Stop conditions

- A design choice the evidence does not settle: write a `Decide:` task with options and a
  recommendation, add the dependency, and stop.
- Work outside the task's scope: create a follow-up task with refs and ACs.
