#!/usr/bin/env python3
"""Sync translations between Flutter ARB files (lib/l10n/) and Google Sheets CSV.

Usage:
  # Export all keys & existing translations from lib/l10n/*.arb into the CSV:
  python scripts/sync_translations.py export

  # Import translations from a local CSV or Google Sheets export URL into lib/l10n/*.arb:
  python scripts/sync_translations.py import "scripts/Chef&Cost Translations - App Translations.csv"
  python scripts/sync_translations.py import "https://docs.google.com/spreadsheets/d/<ID>/export?format=csv&gid=0"
"""

import argparse
import csv
import io
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
L10N_DIR = ROOT_DIR / "lib" / "l10n"
DEFAULT_CSV = ROOT_DIR / "scripts" / "Chef&Cost Translations - App Translations.csv"

# Map CSV column codes to ARB file locale suffixes where they differ
CSV_TO_ARB_LOCALE = {
    "pt-PT": "pt_PT",
    "zh-Hant": "zh_Hant",
    "fil": "tl",
    "aze": "az",
    "hat": "ht",
    "cat": "ca",
}


def csv_col_to_arb_path(col: str) -> Path:
    arb_locale = CSV_TO_ARB_LOCALE.get(col, col)
    return L10N_DIR / f"app_{arb_locale}.arb"


def load_arb(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_arb(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def export_csv(csv_path: Path) -> None:
    if not csv_path.exists():
        print(f"Reference CSV not found: {csv_path}", file=sys.stderr)
        sys.exit(1)

    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))

    if len(rows) < 2:
        print("Reference CSV must have at least 2 header rows.", file=sys.stderr)
        sys.exit(1)

    header_codes = rows[0]
    header_names = rows[1]

    en_arb = load_arb(L10N_DIR / "app_en.arb")
    keys = [k for k in en_arb.keys() if not k.startswith("@")]

    # Load all existing ARB files matching the CSV columns
    arb_cache: dict[str, dict] = {}
    for col in header_codes[1:]:
        arb_cache[col] = load_arb(csv_col_to_arb_path(col))

    out_rows = [header_codes, header_names]
    for key in keys:
        row = [key]
        for col in header_codes[1:]:
            val = arb_cache[col].get(key, "")
            row.append(val if isinstance(val, str) else "")
        out_rows.append(row)

    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(out_rows)

    print(f"Exported {len(keys)} keys across {len(header_codes) - 1} languages to {csv_path}")


def read_csv_source(source: str) -> list[list[str]]:
    if source.startswith("http://") or source.startswith("https://"):
        with urllib.request.urlopen(source) as resp:
            text = resp.read().decode("utf-8-sig")
        return list(csv.reader(io.StringIO(text)))
    path = Path(source)
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.reader(f))


def import_csv(source: str, run_gen: bool = True) -> None:
    rows = read_csv_source(source)
    if len(rows) < 3:
        print("CSV has no data rows.", file=sys.stderr)
        sys.exit(1)

    header_codes = rows[0]
    data_rows = rows[2:]  # skip row 0 (codes) and row 1 (N/A, English, ...)

    en_arb = load_arb(L10N_DIR / "app_en.arb")

    for col_idx, col in enumerate(header_codes[1:], start=1):
        arb_path = csv_col_to_arb_path(col)
        arb_data = load_arb(arb_path)
        arb_locale = CSV_TO_ARB_LOCALE.get(col, col)
        if "@@locale" not in arb_data:
            arb_data["@@locale"] = arb_locale

        updated = 0
        for row in data_rows:
            if not row or not row[0].strip():
                continue
            key = row[0].strip()
            val = row[col_idx] if col_idx < len(row) else ""
            if val:
                arb_data[key] = val
                updated += 1
                # Preserve @key metadata in app_en.arb
                if col == "en" and f"@{key}" in en_arb:
                    arb_data[f"@{key}"] = en_arb[f"@{key}"]

        if updated > 0:
            save_arb(arb_path, arb_data)
            print(f"Updated {arb_path.name}: {updated} keys")

    if run_gen:
        print("Running flutter gen-l10n...")
        subprocess.run(["flutter", "gen-l10n"], cwd=ROOT_DIR, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync translations between ARB files and Google Sheets CSV.")
    sub = parser.add_subparsers(dest="command", required=True)

    exp = sub.add_parser("export", help="Export all keys and existing translations from ARB files to CSV.")
    exp.add_argument("--csv", default=str(DEFAULT_CSV), help="Path to the target CSV file.")

    imp = sub.add_parser("import", help="Import translations from a CSV file or Google Sheets export URL.")
    imp.add_argument("source", help="Local CSV path or Google Sheets /export?format=csv URL.")
    imp.add_argument("--no-gen", action="store_true", help="Skip running flutter gen-l10n.")

    args = parser.parse_args()
    if args.command == "export":
        export_csv(Path(args.csv))
    elif args.command == "import":
        import_csv(args.source, run_gen=not args.no_gen)


if __name__ == "__main__":
    main()
