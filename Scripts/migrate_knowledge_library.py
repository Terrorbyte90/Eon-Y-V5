#!/usr/bin/env python3
"""Extract the legacy KnowledgeArticle Swift literals to normalized JSONL."""
import hashlib
import json
import re
import sys
from pathlib import Path


def swift_string(text, start):
    if text.startswith('"""', start):
        end = text.find('"""', start + 3)
        if end < 0:
            raise ValueError("unterminated multiline string")
        return text[start + 3:end], end + 3
    if text[start] != '"':
        raise ValueError("expected Swift string")
    out, i = [], start + 1
    while i < len(text):
        if text[i] == '\\' and i + 1 < len(text):
            out.append(text[i:i + 2]); i += 2; continue
        if text[i] == '"':
            raw = ''.join(out)
            raw = raw.replace('\\"', '"').replace('\\\\', '\\').replace('\\n', '\n').replace('\\t', '\t')
            return raw, i + 1
        out.append(text[i]); i += 1
    raise ValueError("unterminated string")


def extract(text):
    records = []
    for match in re.finditer(r"KnowledgeArticle\(\s*title:\s*", text):
        i = match.end()
        title, i = swift_string(text, i)
        fields = {}
        for field in ("content", "summary", "domain", "source"):
            found = re.search(rf"\b{field}:\s*", text[i:])
            if not found: raise ValueError(f"missing {field} for {title}")
            i += found.end()
            fields[field], i = swift_string(text, i)
        key = hashlib.sha256((title + "\n" + fields["content"]).encode()).hexdigest()[:24]
        records.append({"id": f"legacy-{key}", "language": "sv", "domain": fields["domain"], "title": title, "text": fields["content"], "source": fields["source"]})
    return records


def main():
    source, target = map(Path, sys.argv[1:3])
    records = extract(source.read_text(encoding="utf-8"))
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8") as out:
        for record in records: out.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"exported {len(records)} records to {target}")


if __name__ == "__main__": main()
