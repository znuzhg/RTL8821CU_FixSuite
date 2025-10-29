#!/usr/bin/env python3

"""
===========================================================
🤖 AI HELPER — RTL8821CU WSL2 LOG ANALYZER
===========================================================
Amaç:
  rtl8821cu_wsl_fix.sh tarafından üretilen logları analiz ederek
  hata, uyarı ve önerileri JSON formatında özetler.

Kullanım:
  python3 ai_helper.py summarize <logfile> [--target <dir>]

Örnek:
  python3 ai_helper.py summarize logs/latest/run.log

Çıktı:
  {
    "timestamp": "...",
    "errors": [...],
    "warnings": [...],
    "suggested_fixes": [...],
    "dkms_make_log_tail": "...",
    "applied_patches": [...]
  }

Not:
  TARGET klasöründe PATCHES_APPLIED bulunuyorsa otomatik okunur.
===========================================================
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

def tail_lines(path, n=200):
    try:
        with open(path, 'r', errors='replace') as f:
            lines = f.readlines()
        return ''.join(lines[-n:])
    except Exception:
        return ''

ERROR_PATTERNS = [
    r'error:',
    r'failed',
    r'No rule to make target',
    r'Module\.symvers',
    r'modpost:.*Undefined',
    r'KERNEL_SOURCE_DIR',
    r'PWD: not found',
]

WARN_PATTERNS = [
    r'warn(ing)?:',
    r'deprecated',
    r'will be ignored',
]

SUGGESTION_RULES = [
    (r'Module\.symvers', 'Copy Module.symvers from kernel source or run: make modules_prepare in kernel tree.'),
    (r'modpost.*Undefined', 'Re-run kernel prepare and ensure correct KERNEL_SRC. Try: make modules_prepare; then DKMS build again.'),
    (r'KERNEL_SOURCE_DIR|PWD', 'Rewrite dkms.conf to avoid add-time variable expansion issues.'),
    (r'No rule to make target', 'Ensure kernel headers/source present. Set KERNEL_SRC properly and run modules_prepare.'),
]

def extract_matches(lines, patterns):
    out = []
    for ln in lines:
        l = ln.strip()
        for pat in patterns:
            if re.search(pat, l, flags=re.IGNORECASE):
                out.append(l)
                break
    return list(dict.fromkeys(out))  # dedupe preserve order


def load_applied_patches(target_dir: Path):
    rec = target_dir / 'PATCHES_APPLIED'
    if rec.is_file():
        try:
            return rec.read_text(errors='replace').splitlines()
        except Exception:
            return []
    return []


def find_dkms_make_log():
    base = Path('/var/lib/dkms/8821cu')
    if not base.is_dir():
        return None
    candidates = []
    for verdir in base.iterdir():
        b = verdir / 'build' / 'make.log'
        if b.is_file():
            try:
                candidates.append((b.stat().st_mtime, str(b)))
            except Exception:
                pass
    if not candidates:
        return None
    candidates.sort()
    return candidates[-1][1]


def summarize_log(logfile: str, target_dir: str):
    result = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'logfile': logfile,
        'errors': [],
        'warnings': [],
        'notes': [],
        'suggested_fixes': [],
        'dkms_make_log_tail': '',
        'applied_patches': [],
    }
    lines = []
    try:
        with open(logfile, 'r', errors='replace') as f:
            lines = f.readlines()
    except Exception as e:
        result['notes'].append(f'Could not read logfile: {e}')
    result['errors'] = extract_matches(lines, ERROR_PATTERNS)
    result['warnings'] = extract_matches(lines, WARN_PATTERNS)

    # Suggestions
    sugg = []
    for ln in lines:
        for pat, tip in SUGGESTION_RULES:
            if re.search(pat, ln, flags=re.IGNORECASE):
                sugg.append(tip)
    result['suggested_fixes'] = list(dict.fromkeys(sugg))

    dkms_log = find_dkms_make_log()
    if dkms_log:
        result['dkms_make_log_tail'] = tail_lines(dkms_log, 200)
    else:
        result['notes'].append('No DKMS make.log found.')

    result['applied_patches'] = load_applied_patches(Path(target_dir))
    return result


def main():
    p = argparse.ArgumentParser(description='Summarize RTL8821CU WSL fix logs into JSON')
    sub = p.add_subparsers(dest='cmd')
    sp = sub.add_parser('summarize', help='Summarize a log file to JSON')
    sp.add_argument('logfile', help='Path to run.log or similar')
    sp.add_argument('--target', default=os.environ.get('RTL8821CU_WSL_TARGET', ''), help='Target folder containing PATCHES_APPLIED (optional)')

    args = p.parse_args()
    if args.cmd != 'summarize':
        p.print_help()
        return 1

    target_dir = args.target or str(Path(sys.argv[0]).resolve().parent)
    data = summarize_log(args.logfile, target_dir)
    print(json.dumps(data, ensure_ascii=False))
    return 0

if __name__ == '__main__':
    sys.exit(main())
