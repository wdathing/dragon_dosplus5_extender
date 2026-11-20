#!/usr/bin/env python3
"""Build DOSplus 5.0 with the DW42 extender for One ROM's drivewire plugin.

    ./build.py [onerom|becker]

writes build/DP50PSR-ONE.rom, or build/DP50PSR-BCK.rom for becker:
DP50NEW.ROM, DOSplus at $C000-$DFFF, then DW42-2516.ASM assembled with
--define onerom=1 or becker=1 at $E000, padded to 16K for a 27128 in the
cartridge.

- onerom, the default, talks to the plugin over the ROM address bus, through
  dwone.asm, and needs no Becker port or bit-banger.
- becker talks through a Becker port at $FF49-$FF4A, clear of DOSplus's
  WD2797 at $FF40-$FF43.  One ROM's plugin answers one there for a coco-grub
  entry, as 2romBck.bat's build does for a Dragon's own Becker hardware.

The .bat files build the Becker and DW4 variants on Windows.  This builds the
onerom and becker ones, and checks what the batch files take on trust:

- DP50NEW.ROM is DOSplus already patched to jump into the extender, by
  reptch in DW42-2516.ASM.  Each JMP it carries must still land on the label
  reptch would point it at, or a change to the extender ahead of those labels
  sends DOSplus into the middle of something else.
- The image ends below $FF00.  The cartridge select covers $C000-$FEFF.
- For onerom, DOSplus's byte at $C100 isn't the plugin's ready status, which
  DWRead would take as a reply before the plugin has written one.  The plugin
  checks the same at startup, and records an error.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
DOS = ROOT / "DP50NEW.ROM"
SOURCE = ROOT / "DW42-2516.ASM"
# Per variant: the define that selects its DWRead and DWWrite, and its output.
VARIANTS = {
    "onerom": ("onerom", BUILD / "DP50PSR-ONE.rom"),
    "becker": ("becker", BUILD / "DP50PSR-BCK.rom"),
}

DOS_BASE = 0xC000
DOS_SIZE = 0x2000
IMAGE_SIZE = 0x4000
CART_END = 0xFF00  # first address the cartridge select doesn't cover

# DOSplus addresses reptch patches with a JMP, and the label each lands on.
# The eighth patch, at $C149 to rsbtchk, isn't applied in DP50NEW.ROM.
PATCHED_JMPS = {
    0xC106: "entry",
    0xC325: "inidsk",
    0xC9F3: "fildir",
    0xD1A4: "modtrk",
    0xC836: "patbck",
    0xC170: "noHdw",
    0xC6C9: "dosReset",
}

STATUS_ADDR = 0xC100
STATUS_READY = 0x02  # dwone.asm's DWRREADY


def fail(msg):
    print(f"build.py: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    args = sys.argv[1:]
    if len(args) > 1 or (args and args[0] not in VARIANTS):
        fail(f"usage: build.py [{'|'.join(VARIANTS)}]")
    variant = args[0] if args else "onerom"
    define, out = VARIANTS[variant]

    BUILD.mkdir(exist_ok=True)
    ext = BUILD / "extender.rom"
    sym = BUILD / "extender.sym"
    try:
        subprocess.run(["asm6809", "-9", "-B", "-q",
                        "--define", f"{define}=1", "--define", "drgrom=1",
                        f"--symbols={sym}", f"--listing={BUILD / 'extender.lst'}",
                        f"--output={ext}", str(SOURCE)],
                       check=True, cwd=ROOT)
    except (OSError, subprocess.CalledProcessError) as e:
        fail(f"assembling {SOURCE.name}: {e}")

    symbols = {}
    for line in sym.read_text().splitlines():
        m = re.match(r"^(\w+)\s+equ\s+(\d+)$", line)
        if m:
            symbols[m.group(1)] = int(m.group(2))

    dos = DOS.read_bytes()
    if len(dos) != DOS_SIZE:
        fail(f"{DOS.name} is {len(dos)} bytes, not {DOS_SIZE}")
    for addr, label in PATCHED_JMPS.items():
        at = dos[addr - DOS_BASE:addr - DOS_BASE + 3]
        target = int.from_bytes(at[1:], "big")
        if at[0] != 0x7E or target != symbols.get(label):
            fail(f"{DOS.name}'s ${addr:04X} holds {at.hex()}, not JMP {label} "
                 f"(${symbols.get(label, 0):04X})")
    if variant == "onerom" and dos[STATUS_ADDR - DOS_BASE] == STATUS_READY:
        fail(f"{DOS.name}'s ${STATUS_ADDR:04X} reads as the plugin's ready status")

    image = dos + ext.read_bytes()
    if DOS_BASE + len(image) > CART_END:
        fail(f"the image runs to ${DOS_BASE + len(image) - 1:04X}, past the "
             f"cartridge select's ${CART_END - 1:04X}")
    out.write_bytes(image + bytes(IMAGE_SIZE - len(image)))
    print(f"{out}  ends ${DOS_BASE + len(image) - 1:04X}")


if __name__ == "__main__":
    main()
