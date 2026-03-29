#!/usr/bin/env python3
"""Extract UK eAIP ENR 2.1 airport controlled-airspace coordinates.

Works with either:
1) A local HTML file path, or
2) A URL (if reachable from your network).
"""

from __future__ import annotations

import argparse
import csv
import html
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

COORD_PATTERN = re.compile(r"\b\d{6}[NS]\s*\d{7}[EW]\b")
TAG_PATTERN = re.compile(r"<[^>]+>")
WHITESPACE_PATTERN = re.compile(r"\s+")


def load_source(source: str) -> str:
    if source.startswith(("http://", "https://")):
        request = Request(source, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urlopen(request, timeout=30) as response:
                return response.read().decode("utf-8", errors="replace")
        except HTTPError as exc:
            raise RuntimeError(f"HTTP error while fetching {source}: {exc.code} {exc.reason}") from exc
        except URLError as exc:
            raise RuntimeError(f"Network error while fetching {source}: {exc.reason}") from exc

    path = Path(source)
    if not path.exists():
        raise RuntimeError(f"Input file not found: {source}")
    return path.read_text(encoding="utf-8", errors="replace")


def html_to_lines(raw_html: str) -> list[str]:
    text = TAG_PATTERN.sub(" ", raw_html)
    text = html.unescape(text)
    lines: list[str] = []
    for part in text.splitlines():
        cleaned = WHITESPACE_PATTERN.sub(" ", part).strip()
        if cleaned:
            lines.append(cleaned)
    return lines


def looks_like_airspace_heading(line: str) -> bool:
    upper = line.upper()
    keywords = ("CTR", "CTA", "TMA", "ATZ", "CONTROL ZONE", "CONTROL AREA")
    if not any(keyword in upper for keyword in keywords):
        return False
    return len(line) <= 120


def extract(lines: list[str]) -> list[tuple[str, str]]:
    current_heading = "UNKNOWN"
    results: list[tuple[str, str]] = []

    for line in lines:
        if looks_like_airspace_heading(line):
            current_heading = line
        for coord in COORD_PATTERN.findall(line):
            results.append((current_heading, coord.replace(" ", "")))
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="Path or URL to ENR 2.1 HTML")
    parser.add_argument("--csv", dest="csv_path", help="Optional CSV output path")
    args = parser.parse_args()

    try:
        raw_html = load_source(args.source)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    rows = extract(html_to_lines(raw_html))
    if not rows:
        print("No coordinates found. The source format may have changed.")
        return 1

    print("airspace,coordinate")
    for airspace, coord in rows:
        print(f"{airspace},{coord}")

    if args.csv_path:
        out_path = Path(args.csv_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", newline="", encoding="utf-8") as fp:
            writer = csv.writer(fp)
            writer.writerow(["airspace", "coordinate"])
            writer.writerows(rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
