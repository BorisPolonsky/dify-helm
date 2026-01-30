#!/usr/bin/env python3
"""
Read Trivy JSON scan results (one file per image) and emit a cve-report.md
in the same format as Langgenius/Dify container security scan reports.
"""
from pathlib import Path
import json
import sys
from datetime import datetime
from collections import defaultdict

# Image name prefix for "Langgenius Supported Images"; others go to "Third-Party"
# When ArtifactName is missing we fall back to path.stem, which uses underscores
# (workflow sanitizes / and : to _), so "langgenius/" becomes "langgenius_".
LANGGENIUS_PREFIX = "langgenius/"
LANGGENIUS_PREFIX_FALLBACK = "langgenius_"  # sanitized filename form


def is_langgenius(name: str) -> bool:
    """True if this image name refers to a Langgenius-supported image."""
    return name.startswith(LANGGENIUS_PREFIX) or name.startswith(LANGGENIUS_PREFIX_FALLBACK)


def slug(name: str) -> str:
    """Turn image ref like langgenius/dify-api:1.10.1 into a short display name."""
    # Fallback path.stem is sanitized: langgenius/dify-api:1.10.1 -> langgenius_dify-api_1.10.1-fix.1
    if not ("/" in name or ":" in name) and name.startswith(LANGGENIUS_PREFIX_FALLBACK):
        rest = name[len(LANGGENIUS_PREFIX_FALLBACK) :].replace("_", "-")
        return rest if rest else name
    # Normal repo:tag form
    if ":" in name:
        repo, tag = name.rsplit(":", 1)
    else:
        repo, tag = name, "latest"
    base = repo.split("/")[-1] if "/" in repo else repo
    return f"{base}-{tag}".replace("/", "-").replace(".", "-")


def count_severities(vulns: list) -> tuple[int, int]:
    critical = sum(1 for v in vulns if (v.get("Severity") or "").upper() == "CRITICAL")
    high = sum(1 for v in vulns if (v.get("Severity") or "").upper() == "HIGH")
    return critical, high


def load_result(path: Path) -> tuple[str, int, int] | None:
    """Load one Trivy JSON file. Return (artifact_name, critical, high) or None."""
    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return None
    name = data.get("ArtifactName") or path.stem
    total_c, total_h = 0, 0
    for res in data.get("Results") or []:
        vulns = res.get("Vulnerabilities") or []
        c, h = count_severities(vulns)
        total_c += c
        total_h += h
    return (name, total_c, total_h)


def main():
    if len(sys.argv) < 2:
        print("Usage: trivy-report-to-md.py <dir-with-trivy-*.json> [--version X.Y.Z]", file=sys.stderr)
        sys.exit(1)
    args = sys.argv[1:]
    report_dir = Path(args[0])
    version = "1.0"
    i = 1
    while i < len(args):
        if args[i] == "--version" and i + 1 < len(args):
            version = args[i + 1]
            i += 2
            continue
        i += 1

    if not report_dir.is_dir():
        print(f"Not a directory: {report_dir}", file=sys.stderr)
        sys.exit(1)

    # Collect (display_name, critical, high) per image
    by_image: dict[str, tuple[int, int]] = {}
    for f in sorted(report_dir.glob("*.json")):
        row = load_result(f)
        if row:
            name, c, h = row
            by_image[name] = (c, h)

    langgenius: list[tuple[str, int, int]] = []
    third_party: list[tuple[str, int, int]] = []
    for name in sorted(by_image.keys()):
        c, h = by_image[name]
        display = slug(name)
        if is_langgenius(name):
            langgenius.append((display, c, h))
        else:
            third_party.append((display, c, h))

    scan_date = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "# Container Security Scan Results",
        "",
        f"**Version:** {version}",
        "",
        f"**Scan Date:** {scan_date}",
        "",
        "## Scan Results Summary",
        "",
    ]

    # Langgenius Supported Images
    lines.append("### Langgenius Supported Images")
    lines.append("")
    for display, c, h in langgenius:
        lines.append(f"#### {display}")
        lines.append(f"- **CRITICAL vulnerabilities:** {c}")
        lines.append(f"- **HIGH vulnerabilities:** {h}")
        lines.append("")
    if langgenius:
        tc = sum(x[1] for x in langgenius)
        th = sum(x[2] for x in langgenius)
        lines.append("**Langgenius Supported Images Summary:**")
        lines.append(f"- **CRITICAL:** {tc}")
        lines.append(f"- **HIGH:** {th}")
        lines.append("")
    lines.append("---")
    lines.append("")

    # Third-Party Images
    lines.append("### Third-Party Images")
    lines.append("")
    for display, c, h in third_party:
        lines.append(f"#### {display}")
        lines.append(f"- **CRITICAL vulnerabilities:** {c}")
        lines.append(f"- **HIGH vulnerabilities:** {h}")
        lines.append("")
    if third_party:
        tc = sum(x[1] for x in third_party)
        th = sum(x[2] for x in third_party)
        lines.append("**Third-Party Images Summary:**")
        lines.append(f"- **CRITICAL:** {tc}")
        lines.append(f"- **HIGH:** {th}")
        lines.append("")
    lines.append("---")
    lines.append("")

    # Total Summary
    total_c = sum(x[1] for x in langgenius + third_party)
    total_h = sum(x[2] for x in langgenius + third_party)
    lc = sum(x[1] for x in langgenius)
    lh = sum(x[2] for x in langgenius)
    lines.append("## Total Summary")
    lines.append(f"- **Total CRITICAL vulnerabilities:** {total_c} (Langgenius: {lc}, Third-Party: {total_c - lc})")
    lines.append(f"- **Total HIGH vulnerabilities:** {total_h} (Langgenius: {lh}, Third-Party: {total_h - lh})")
    lines.append("")

    print("\n".join(lines))


if __name__ == "__main__":
    main()
