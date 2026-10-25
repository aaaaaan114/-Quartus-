#!/usr/bin/env python3
"""Run the self-checking HDL suite. Requires Icarus Verilog (iverilog + vvp)."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'simulation' / 'build'
BENCHES = ['tb_time_alarm_chime', 'tb_buzzer', 'tb_top', 'tb_clk_divider']


def check_project():
    qsf = (ROOT / 'digital_clock.qsf').read_text(encoding='utf-8')
    assignments = re.findall(r'^set_location_assignment (PIN_\w+) -to (\S+)', qsf, re.M)
    pins = [pin for pin, port in assignments]
    ports = [port.strip('{}') for pin, port in assignments]
    expected = {'CLOCK_50', 'BUZZER'}
    expected.update(f'KEY[{i}]' for i in range(4))
    expected.update(f'SW[{i}]' for i in range(2))
    expected.update(f'LEDR[{i}]' for i in range(3))
    expected.update(f'HEX{digit}[{bit}]' for digit in range(6) for bit in range(7))
    if len(set(pins)) != len(pins) or len(set(ports)) != len(ports) or set(ports) != expected:
        raise RuntimeError('Pin assignments are duplicated, missing, or unexpected')
    sources = re.findall(r'^set_global_assignment -name VERILOG_FILE (\S+)', qsf, re.M)
    for source in sources:
        if not (ROOT / source).is_file():
            raise RuntimeError('Missing Quartus source: ' + source)
    if not sources or not (ROOT / 'digital_clock.sdc').is_file():
        raise RuntimeError('Project is missing RTL or timing constraints')
    print(f'PASS project: {len(ports)} unique board pins, {len(sources)} RTL files', flush=True)
    return sources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bench', choices=BENCHES, action='append', help='Run selected bench(es) only')
    args = parser.parse_args()
    sources = check_project()
    env = os.environ.copy()
    if env.get('IVERILOG_BIN'):
        env['PATH'] = env['IVERILOG_BIN'] + os.pathsep + env.get('PATH', '')
    compiler = shutil.which('iverilog', path=env.get('PATH'))
    runner = shutil.which('vvp', path=env.get('PATH'))
    if not compiler or not runner:
        raise RuntimeError('Install Icarus Verilog or set IVERILOG_BIN to its bin directory')
    BUILD.mkdir(parents=True, exist_ok=True)
    # Check synthesizable sources independently in Verilog-2005 mode.
    subprocess.run([compiler, '-g2005', '-Wall', '-s', 'digital_clock_top', '-t', 'null', *sources],
                   cwd=ROOT, env=env, check=True, timeout=60)
    results = []
    for bench in args.bench or BENCHES:
        target = f'simulation/build/{bench}.vvp'
        subprocess.run([compiler, '-g2012', '-Wall', '-s', bench, '-o', target,
                        *sources, f'simulation/{bench}.sv'],
                       cwd=ROOT, env=env, check=True, timeout=60)
        print('RUN ' + bench, flush=True)
        started = time.monotonic()
        completed = subprocess.run([runner, target], cwd=ROOT, env=env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
        output = completed.stdout
        print(output, end='', flush=True)
        (BUILD / f'{bench}.log').write_text(output, encoding='utf-8')
        if completed.returncode or f'PASS {bench}:' not in output:
            raise RuntimeError('Failed bench: ' + bench)
        results.append({'bench': bench, 'status': 'passed',
                        'elapsed_seconds': round(time.monotonic() - started, 3)})
    (BUILD / 'results.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {len(results)} HDL benches', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
