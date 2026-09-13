#!/usr/bin/env python3
"""Generate app/assets/quran/quran_index.json.

The bundled corpus (quran.json) carries verse text but no position in the
printed Mushaf, which the page reader needs. This script imports page, juz and
hizb-quarter numbers for all 6,236 ayahs from the alquran.cloud Quran API
(Uthmani edition) and records provenance plus a checksum alongside them.

The output is data, not generated content: nothing here invents Quran text or
positions. Re-run it only when you intend to refresh the imported index.

Usage:
    python tools/build_quran_index.py
    python tools/build_quran_index.py --source https://api.alquran.cloud/v1/quran/quran-uthmani
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_SOURCE = "https://api.alquran.cloud/v1/quran/quran-uthmani"
REPO_ROOT = Path(__file__).resolve().parent.parent
CORPUS_PATH = REPO_ROOT / "app" / "assets" / "quran" / "quran.json"
OUTPUT_PATH = REPO_ROOT / "app" / "assets" / "quran" / "quran_index.json"
EXPECTED_AYAH_COUNT = 6236


def fetch(source: str) -> dict:
    print(f"Fetching {source} ...", file=sys.stderr)
    request = urllib.request.Request(source, headers={"User-Agent": "tilawa-index-builder"})
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 200:
            raise SystemExit(f"Source returned HTTP {response.status}")
        return json.loads(response.read().decode("utf-8"))


def build_rows(payload: dict) -> list[dict]:
    surahs = payload.get("data", {}).get("surahs")
    if not surahs:
        raise SystemExit("Unexpected payload shape: no data.surahs")

    rows: list[dict] = []
    for surah in surahs:
        surah_number = int(surah["number"])
        for ayah in surah["ayahs"]:
            rows.append(
                {
                    "surah": surah_number,
                    "ayah": int(ayah["numberInSurah"]),
                    "page": int(ayah["page"]),
                    "juz": int(ayah["juz"]),
                    "hizbQuarter": int(ayah["hizbQuarter"]),
                }
            )
    return rows


def verify_against_corpus(rows: list[dict]) -> None:
    """Every verse in the bundled corpus must get exactly one position."""
    if not CORPUS_PATH.exists():
        print(f"warning: {CORPUS_PATH} missing, skipping cross-check", file=sys.stderr)
        return

    corpus = json.loads(CORPUS_PATH.read_text(encoding="utf-8"))
    corpus_refs = {(int(v["surah"]), int(v["ayah"])) for v in corpus}
    index_refs = {(r["surah"], r["ayah"]) for r in rows}

    missing = corpus_refs - index_refs
    extra = index_refs - corpus_refs
    if missing:
        raise SystemExit(f"Index is missing {len(missing)} corpus verses, e.g. {sorted(missing)[:5]}")
    if extra:
        raise SystemExit(f"Index has {len(extra)} verses absent from the corpus, e.g. {sorted(extra)[:5]}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=DEFAULT_SOURCE)
    parser.add_argument("--output", default=str(OUTPUT_PATH))
    args = parser.parse_args()

    rows = build_rows(fetch(args.source))
    if len(rows) != EXPECTED_AYAH_COUNT:
        raise SystemExit(f"Expected {EXPECTED_AYAH_COUNT} ayahs, got {len(rows)}")
    verify_against_corpus(rows)

    rows.sort(key=lambda r: (r["surah"], r["ayah"]))
    payload_body = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
    document = {
        "schema": "tilawa/quran-index@1",
        "source": args.source,
        "edition": "quran-uthmani",
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "ayahCount": len(rows),
        "sha256": hashlib.sha256(payload_body.encode("utf-8")).hexdigest(),
        "ayahs": rows,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(document, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    size_kb = output.stat().st_size / 1024
    print(f"Wrote {output} ({len(rows)} ayahs, {size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
