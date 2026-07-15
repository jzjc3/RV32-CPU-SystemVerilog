"""
cli.py -- front-end for the teaching RISC-V toolchain.

THE COMMON CASE: just give it your C file. It compiles, assembles, and
simulates in one step, and writes prog.asm / prog.mem / prog.lst next to it:

    python3 python_scripts/toolchain/cli.py prog.c --dump a0

(prog.mem is the machine-code file you'll load onto the CPU you build.)

If you'd rather run a single stage by hand, name it as a subcommand:

    compile   C source  ->  .asm                  (human-readable assembly)
    asm       .asm      ->  .mem + .lst            (.mem = machine code)
    run       .mem      ->  simulate a built .mem
    build     C source  ->  compile + assemble + simulate
                            (exactly what the bare "prog.c" form runs for you)

HANDY OPTIONS (for the bare "prog.c" form, and for build / run):
    --dump a0,a1,sp   print these registers when the program stops -- a0 holds
                      the value your C code returned. --dump-all shows all 32.
    --trace           print every instruction as it executes
    --strict          stop at the first warning
    --max-cycles N    cutoff for this Python simulator of your CPU (default
                      10,000,000; full name --max-simulator-cycles) -- separate
                      from any Vivado simulation later

EXIT CODES: 0 success | 1 compile/assemble or usage error | 2 runtime error |
3 a warning that --strict promoted to an error.
"""

import argparse
import os
import sys

import assembler
import compiler
import simulator


def cmd_compile(args):
    try:
        with open(args.input) as f:
            source = f.read()
    except OSError as e:
        print("error: %s" % e, file=sys.stderr)
        sys.exit(1)
    try:
        asm = compiler.compile_source(source, filename=args.input, mem_top=args.mem_size)
    except compiler.CompileError as e:
        print(e.render(), file=sys.stderr)
        sys.exit(1)
    out = args.output or os.path.splitext(args.input)[0] + ".asm"
    with open(out, "w") as f:
        f.write(asm)
    print("wrote %s" % out)


def cmd_asm(args):
    try:
        mem, lst = assembler.assemble_file(args.input, args.output)
    except assembler.AsmError as e:
        print(e.render(), file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print("error: %s" % e, file=sys.stderr)
        sys.exit(1)
    print("wrote %s" % mem)
    print("wrote %s" % lst)


def cmd_run(args):
    cpu = simulator.CPU(
        mem_size=args.mem_size,
        strict=args.strict,
        no_warnings=args.no_warnings,
        warn_stream=args.warn_stream,
        progress_check=not args.no_progress_check,
        stack_depth_warn=args.stack_depth_warn,
    )
    regs = [r.strip() for r in args.dump.split(",")] if args.dump else None
    try:
        simulator.load_mem_file(cpu, args.mem)
        simulator.run(cpu, max_cycles=args.max_cycles, trace=args.trace)
    except FileNotFoundError as e:
        print("error: %s" % e, file=sys.stderr)
        sys.exit(1)
    except simulator.StrictWarning as e:
        print("error (--strict): %s" % e, file=sys.stderr)
        print(simulator.format_state(cpu, regs, show_all=args.dump_all), file=sys.stderr)
        sys.exit(3)
    except simulator.SimError as e:
        print("runtime error: %s" % e, file=sys.stderr)
        print(simulator.format_state(cpu, regs, show_all=args.dump_all), file=sys.stderr)
        sys.exit(2)
    print(simulator.format_summary(cpu))
    print(simulator.format_state(cpu, regs, show_all=args.dump_all))


def cmd_build(args):
    base = os.path.splitext(args.input)[0]
    asm_path = base + ".asm"
    cmd_compile(argparse.Namespace(input=args.input, output=asm_path,
                                   mem_size=args.mem_size))
    cmd_asm(argparse.Namespace(input=asm_path, output=base))
    if not args.no_run:
        cmd_run(argparse.Namespace(
            mem=base + ".mem", mem_size=args.mem_size, max_cycles=args.max_cycles,
            trace=args.trace, dump=args.dump, dump_all=args.dump_all,
            strict=args.strict, no_warnings=args.no_warnings,
            warn_stream=args.warn_stream, no_progress_check=args.no_progress_check,
            stack_depth_warn=args.stack_depth_warn))


def _add_run_flags(p):
    p.add_argument("--mem-size", type=int, default=1 << 16)
    p.add_argument("--max-simulator-cycles", "--max-cycles", dest="max_cycles",
                   type=int, default=10_000_000,
                   help="stop this Python simulator after N instructions "
                        "(infinite-loop cutoff; default 10,000,000). This is the "
                        "Python simulator of the ISA -- NOT the Vivado simulation "
                        "you may run on your SystemVerilog CPU later.")
    p.add_argument("--trace", action="store_true")
    p.add_argument("--dump", default=None,
                   help="comma-separated registers to print (ABI or xN names)")
    p.add_argument("--dump-all", action="store_true", help="dump all 32 registers")
    p.add_argument("--strict", action="store_true", help="first warning -> error")
    p.add_argument("--no-warnings", action="store_true")
    p.add_argument("--warn-stream", action="store_true",
                   help="stream warnings as they fire instead of batching")
    p.add_argument("--no-progress-check", action="store_true")
    p.add_argument("--stack-depth-warn", type=int, default=8192)


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    # With no arguments, show the (useful) help rather than a terse error.
    if not argv:
        argv = ["--help"]
    # Convenience: a bare "cli.py prog.c ..." (first token is a filename, not a
    # subcommand or a flag) means "build prog.c ..." -- the whole pipeline.
    elif not argv[0].startswith("-") and argv[0] not in ("compile", "asm", "run", "build"):
        argv = ["build"] + argv

    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    # NB: add_subparsers(required=True) is 3.7+; set the attribute after for 3.6.
    sub = p.add_subparsers(dest="cmd")
    sub.required = True

    pc = sub.add_parser("compile", help="C -> asm")
    pc.add_argument("input")
    pc.add_argument("-o", "--output", default=None)
    pc.add_argument("--mem-size", type=int, default=1 << 16,
                    help="memory size; _start sets sp to this")
    pc.set_defaults(func=cmd_compile)

    pa = sub.add_parser("asm", help="asm -> .mem + .lst")
    pa.add_argument("input")
    pa.add_argument("-o", "--output", default=None)
    pa.set_defaults(func=cmd_asm)

    pr = sub.add_parser("run", help="simulate an already-built .mem file")
    pr.add_argument("mem")
    _add_run_flags(pr)
    pr.set_defaults(func=cmd_run)

    pb = sub.add_parser("build",
                        help="compile + assemble + simulate a .c (also the "
                             "default when you pass a bare .c file)")
    pb.add_argument("input")
    _add_run_flags(pb)
    pb.add_argument("--no-run", action="store_true",
                    help="just build the .mem, don't simulate it")
    pb.set_defaults(func=cmd_build)

    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
