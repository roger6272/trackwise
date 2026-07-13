#!/usr/bin/env python3
"""Generate docs/*.html from docs/*.md.

WHY THIS EXISTS
---------------
The HTML docs are how the firmware engineer reads the spec — he does not have the
repo. They used to be hand-maintained alongside the markdown, and they drifted badly:
on 2026-07-12, BLE_PROTOCOL.html contained ZERO mentions of `ota_start` while the
markdown had 17, and TROUBLESHOOTING.html had none of the OTA section at all. The
person who most needed the OTA protocol was reading a copy that didn't contain it.

A hand-maintained second copy of a document is a drift generator. So: the markdown is
the source of truth, and the HTML is BUILD OUTPUT. Never edit docs/*.html by hand.

    python scripts/build_docs.py            # regenerate all
    python scripts/build_docs.py --check    # CI: fail if any HTML is stale

Requires: pip install markdown pymdown-extensions
"""
import argparse
import hashlib
import pathlib
import re
import sys

import markdown

DOCS = pathlib.Path(__file__).resolve().parent.parent / "docs"
CSS = pathlib.Path(__file__).resolve().parent / "_docs_style.css"

# Only these. Explicitly NOT everything in docs/ — LAUNCH_CHECKLIST, the store-setup
# guides and the UX specs are internal and have no business in a file you hand to an
# outside contractor. These six are the ones the firmware engineer actually needs.
PUBLISHED = [
    "BLE_PROTOCOL",      # normative — the conformance spec for his nRF port
    "DATA_FLOW",
    "DEVICE_DISPLAY",
    "PRODUCT_OVERVIEW",
    "TROUBLESHOOTING",
    "USER_GUIDE",
]

# GitHub alert syntax ( > [!WARNING] ) is not standard markdown and carries the
# safety-critical text in these docs (e.g. "do NOT power-cycle mid-swap"). Lower it
# into a styled div BEFORE the markdown pass, or it renders as a limp blockquote.
ALERT_STYLES = {
    "NOTE":      ("#2563eb", "#eff6ff", "Note"),
    "TIP":       ("#059669", "#ecfdf5", "Tip"),
    "IMPORTANT": ("#7c3aed", "#f5f3ff", "Important"),
    "WARNING":   ("#d97706", "#fffbeb", "Warning"),
    "DANGER":    ("#dc2626", "#fef2f2", "Danger"),
    "CAUTION":   ("#dc2626", "#fef2f2", "Caution"),
}

ALERT_CSS = """
.alert { border-left: 5px solid; border-radius: 6px; padding: 12px 16px; margin: 18px 0; }
.alert .alert-title { font-weight: 700; margin-bottom: 6px; letter-spacing: .02em; }
.alert > :last-child { margin-bottom: 0; }
.generated-banner { background:#f1f5f9; border:1px solid #cbd5e1; border-radius:6px;
  padding:10px 14px; margin-bottom:24px; font-size:.9em; color:#475569; }
"""


def convert_alerts(md_text: str) -> str:
    """Turn `> [!WARNING]` blockquote alerts into raw HTML divs."""
    lines = md_text.split("\n")
    out, i = [], 0
    while i < len(lines):
        m = re.match(r"^>\s*\[!(\w+)\]\s*$", lines[i])
        if not m or m.group(1).upper() not in ALERT_STYLES:
            out.append(lines[i])
            i += 1
            continue
        kind = m.group(1).upper()
        border, bg, label = ALERT_STYLES[kind]
        i += 1
        body = []
        while i < len(lines) and lines[i].startswith(">"):
            body.append(re.sub(r"^>\s?", "", lines[i]))
            i += 1
        inner = markdown.markdown(
            "\n".join(body),
            extensions=["tables", "fenced_code", "sane_lists", "attr_list"],
        )
        out.append(
            f'<div class="alert" style="border-color:{border};background:{bg}">'
            f'<div class="alert-title" style="color:{border}">{label}</div>'
            f"{inner}</div>"
        )
    return "\n".join(out)


def render(md_path: pathlib.Path) -> str:
    raw = md_path.read_text(encoding="utf-8")
    title = next(
        (l.lstrip("# ").strip() for l in raw.split("\n") if l.startswith("# ")),
        md_path.stem,
    )
    body = markdown.markdown(
        convert_alerts(raw),
        extensions=["tables", "fenced_code", "toc", "sane_lists", "attr_list", "md_in_html"],
    )
    css = CSS.read_text(encoding="utf-8") if CSS.exists() else ""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} - Traxelos</title>
<style>
{css}
{ALERT_CSS}
</style>
</head>
<body>
<div class="container">
<div class="generated-banner">
  <strong>Generated file — do not edit.</strong>
  Built from <code>docs/{md_path.name}</code> by <code>scripts/build_docs.py</code>.
  Edit the markdown and re-run the script.
</div>
{body}
</div>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if any HTML is out of date (for CI)")
    args = ap.parse_args()

    stale = []
    for name in PUBLISHED:
        md_path = DOCS / f"{name}.md"
        if not md_path.exists():
            print(f"  MISSING    {md_path.name} (listed in PUBLISHED but not on disk)")
            return 1
        html_path = md_path.with_suffix(".html")
        new = render(md_path)
        old = html_path.read_text(encoding="utf-8") if html_path.exists() else ""
        same = hashlib.sha256(old.encode()).digest() == hashlib.sha256(new.encode()).digest()
        if args.check:
            if not same:
                stale.append(html_path.name)
            continue
        if same:
            print(f"  unchanged  {html_path.name}")
        else:
            html_path.write_text(new, encoding="utf-8")
            print(f"  WROTE      {html_path.name}")

    if args.check:
        if stale:
            print("STALE (run: python scripts/build_docs.py):", ", ".join(stale))
            return 1
        print("all HTML docs are up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
