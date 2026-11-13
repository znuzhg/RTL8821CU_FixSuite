#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RTL8821CU WSL2 log analiz aracı.

Kullanım:
  python3 ai_helper.py summarize <logfile> [--target <dir>]

Çıktı:
  Hata/uyarı listeleri, uygulanmış yamalar, DKMS make.log özeti ve son DONE
  kaydından türetilen çalışma durumu.
"""

import argparse
import json
import os
import re
import sys
from collections import deque
from datetime import datetime, timezone
from pathlib import Path


ERROR_PATTERNS = [
    r"\bfatal error\b",
    r"\berror:",
    r"\bfailed\b",
    r"No rule to make target",
    r"no makefile found|makefile.*not found",
    r"modpost:.*Undefined",
    r"KERNEL_SOURCE_DIR",
    r"PWD: not found",
    r"implicit declaration",
    r"undefined reference",
    r"make:\s+\*\*\*",
]

WARN_PATTERNS = [
    r"\bwarn(?:ing)?:",
    r"\bdeprecated\b",
    r"will be ignored",
    r"\bincompatible\b",
    r"\bmismatch\b",
    r"no symbol version for module_layout",
    r"taints kernel",
]

SUGGESTION_RULES = [
    (
        r"no makefile found|makefile.*not found",
        "Çekirdek kaynak ağacı hazır değil. KERNEL_SRC yolunu doğrulayın ve "
        "çekirdek ağacında modules_prepare çalıştırın.",
    ),
    (
        r"No rule to make target",
        "Çekirdek başlıkları/kaynakları eksik veya uyumsuz. Doğru KERNEL_SRC "
        "yolunu seçip modules_prepare çalıştırın.",
    ),
    (
        r"Module\.symvers|modpost",
        "Module.symvers/modpost uyarılarını inceleyin. WSL çekirdeğinde "
        "Module.symvers bulunmayabilir; MODPOST_WARN ile derleme sonucunu "
        "ve modülün yüklenmesini ayrıca doğrulayın.",
    ),
    (
        r"KERNEL_SOURCE_DIR|PWD",
        "dkms.conf içindeki değişken genişletmesini kontrol edin; "
        "DKMS MAKE satırında kernel_source_dir kullanımını doğrulayın.",
    ),
    (
        r"implicit declaration",
        "Sürücü kaynak kodu çekirdek API'siyle uyumsuz olabilir. İlgili "
        "başlıkları ve çekirdek sürümüne uygun sürücü yamalarını kontrol edin.",
    ),
    (
        r"undefined reference|modpost:.*Undefined",
        "Eksik sembol dışa aktarımını ve çekirdek kaynak ağacının sürümünü "
        "kontrol edin. Module.symvers yoksa WSL çekirdeği sınırlamalarını "
        "göz önünde bulundurun.",
    ),
]


def tail_lines(path: Path, count: int = 200) -> str:
    """Dosyanın son satırlarını bellek tüketimini sınırlayarak okur."""
    try:
        lines = deque(maxlen=count)
        with path.open("r", encoding="utf-8", errors="replace") as stream:
            lines.extend(stream)
        return "".join(lines)
    except OSError:
        return ""


def extract_matches(lines, patterns):
    """Eşleşen satırları tekrarları kaldırarak sırasını koruyarak döndürür."""
    matches = []
    for line in lines:
        clean_line = line.strip()
        if any(re.search(pattern, clean_line, re.IGNORECASE) for pattern in patterns):
            matches.append(clean_line)
    return list(dict.fromkeys(matches))


def load_applied_patches(target_dir: Path):
    record = target_dir / "PATCHES_APPLIED"
    if not record.is_file():
        return []
    try:
        return record.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []


def find_dkms_make_log():
    """DKMS'nin eski ve yeni make.log dizin düzenlerini birlikte tarar."""
    base = Path("/var/lib/dkms/8821cu")
    if not base.is_dir():
        return None

    candidates = []
    try:
        for candidate in base.rglob("make.log"):
            if candidate.is_file():
                try:
                    candidates.append((candidate.stat().st_mtime, candidate))
                except OSError:
                    continue
    except OSError:
        return None

    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0])
    return candidates[-1][1]


def latest_done_status(lines):
    """Son DONE satırını esas alır; önceki çalışmalardan durum devralmaz."""
    for line in reversed(lines):
        match = re.search(r"\bDONE\s+(success|failure)\b", line, re.IGNORECASE)
        if match:
            return match.group(1).lower()
    return "unknown"


def summarize_log(logfile: str, target_dir: str):
    result = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "logfile": logfile,
        "errors": [],
        "warnings": [],
        "notes": [],
        "suggested_fixes": [],
        "dkms_make_log": "",
        "dkms_make_log_tail": "",
        "applied_patches": [],
        "status": "unknown",
    }

    try:
        with Path(logfile).open("r", encoding="utf-8", errors="replace") as stream:
            lines = stream.readlines()
    except OSError as error:
        result["notes"].append(f"Log dosyası okunamadı: {error}")
        return result

    result["errors"] = extract_matches(lines, ERROR_PATTERNS)
    result["warnings"] = extract_matches(lines, WARN_PATTERNS)

    suggestions = []
    for line in lines:
        for pattern, suggestion in SUGGESTION_RULES:
            if re.search(pattern, line, re.IGNORECASE):
                suggestions.append(suggestion)
    result["suggested_fixes"] = list(dict.fromkeys(suggestions))

    make_log = find_dkms_make_log()
    if make_log:
        result["dkms_make_log"] = str(make_log)
        result["dkms_make_log_tail"] = tail_lines(make_log, 200)
    else:
        result["notes"].append("DKMS make.log bulunamadı.")
        joined = "".join(lines).lower()
        if "step2" in joined or "dkms build" in joined:
            result["suggested_fixes"].append(
                "DKMS make.log bulunamadı. DKMS build çıktısını, DKMS sürümünü "
                "ve /var/lib/dkms/8821cu dizin izinlerini kontrol edin."
            )

    result["applied_patches"] = load_applied_patches(Path(target_dir))
    result["status"] = latest_done_status(lines)

    if result["errors"] and not result["suggested_fixes"]:
        result["suggested_fixes"].append(
            "Hata satırlarını ve varsa DKMS make.log dosyasını inceleyin; "
            "çekirdek kaynak sürümü ile çalışan KVER değerinin eşleştiğini doğrulayın."
        )

    if result["status"] == "unknown":
        result["notes"].append(
            "Log içinde DONE success/failure kaydı bulunamadı; durum unknown bırakıldı."
        )

    return result


def main():
    parser = argparse.ArgumentParser(
        description="RTL8821CU WSL2 log dosyalarını JSON olarak özetler"
    )
    subparsers = parser.add_subparsers(dest="command")
    summarize_parser = subparsers.add_parser(
        "summarize", help="Bir run.log dosyasını özetle"
    )
    summarize_parser.add_argument("logfile", help="run.log dosyasının yolu")
    summarize_parser.add_argument(
        "--target",
        default=os.environ.get("RTL8821CU_WSL_TARGET", ""),
        help="PATCHES_APPLIED dosyasının bulunduğu proje dizini",
    )

    args = parser.parse_args()
    if args.command != "summarize":
        parser.print_help()
        return 1

    target_dir = args.target or str(Path(sys.argv[0]).resolve().parent)
    result = summarize_log(args.logfile, target_dir)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
