# Advent of code 2023

AoC2023 written in bare x86 assembly.

Each problem has its own assembly file: `one-1.S`, `one-2.S`, etc. There's also a `common.S` file for common functionality between problems.

All problem input files are stored in `data/`. As a personal rule, I can't hardcode the problem inputs, they _must_ be read from a file at runtime.

As best I can, functions defined in `common.S` follow the x86_64 System V calling convention.

## Building

To build, run `make`, passing the problem name (eg. `make one-1.elf`). Or `make all` to build everything. `make clean` is defined.
