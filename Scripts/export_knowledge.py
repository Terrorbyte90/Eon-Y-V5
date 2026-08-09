#!/usr/bin/env python3
"""Export JSONL knowledge resources without embedding corpus text in Swift.

The script intentionally accepts normalized records from stdin or a JSON file;
the app's legacy Swift library can be converted once with a dedicated parser,
then future additions should use this stable format directly.
"""
import argparse
import hashlib
import json
from pathlib import Path


def normalize(record):
    required = ("id", "language", "domain", "title", "text")
    missing = [key for key in required if not record.get(key)]
    if missing:
        raise ValueError(f"missing fields: {', '.join(missing)}")
    return {key: record.get(key) for key in (*required, "source")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    records = json.loads(args.input.read_text(encoding="utf-8"))
    normalized = [normalize(record) for record in records]
    if len({record["id"] for record in normalized}) != len(normalized):
        raise ValueError("duplicate knowledge id")
    payload = "".join(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n" for record in normalized).encode("utf-8")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(payload)
    print(json.dumps({"version": 1, "recordCount": len(normalized), "sha256": hashlib.sha256(payload).hexdigest()}))


if __name__ == "__main__":
    main()
