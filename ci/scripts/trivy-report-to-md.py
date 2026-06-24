#!/usr/bin/env python3
"""
Read Trivy JSON scan results (one file per image) and emit a cve-report.md
in the same format as Langgenius/Dify container security scan reports.
"""
from pathlib import Path
import json
import sys
from datetime import datetime, timezone
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
    # Fallback path.stem (workflow tr '/:' '__'): langgenius/dify-api:1.10.1 -> langgenius_dify-api_1.10.1 -> dify-api-1.10.1
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


def escape_md_cell(value: str) -> str:
    """Escape characters that break markdown table cells."""
    return value.replace("|", "\\|").replace("\n", " ")


def extract_critical_vulns(data: dict) -> list[dict]:
    """Collect CRITICAL vulnerabilities from all Trivy result targets."""
    critical: list[dict] = []
    for res in data.get("Results") or []:
        for v in res.get("Vulnerabilities") or []:
            if (v.get("Severity") or "").upper() != "CRITICAL":
                continue
            critical.append(
                {
                    "cve": v.get("VulnerabilityID") or "UNKNOWN",
                    "pkg": v.get("PkgName") or "—",
                    "installed": v.get("InstalledVersion") or "—",
                    "fixed": v.get("FixedVersion") or "—",
                    "status": v.get("Status") or "—",
                    "title": v.get("Title") or v.get("Description") or "—",
                    "url": v.get("PrimaryURL") or "",
                }
            )
    critical.sort(key=lambda row: (row["cve"], row["pkg"], row["installed"]))
    return critical


def format_critical_table(critical: list[dict]) -> list[str]:
    """Render a markdown table of critical vulnerabilities."""
    lines = [
        "**Critical vulnerabilities:**",
        "",
        "| CVE | Package | Installed | Fixed | Status | Title |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for row in critical:
        cve = row["cve"]
        if row["url"]:
            cve = f"[{cve}]({row['url']})"
        cells = [
            cve,
            escape_md_cell(row["pkg"]),
            escape_md_cell(row["installed"]),
            escape_md_cell(row["fixed"]),
            escape_md_cell(row["status"]),
            escape_md_cell(row["title"]),
        ]
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    return lines


def load_result(path: Path) -> tuple[str, int, int, list[dict]] | None:
    """Load one Trivy JSON file. Return (artifact_name, critical, high, critical_details) or None."""
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
    return (name, total_c, total_h, extract_critical_vulns(data))


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

    # Collect (display_name, critical, high, critical_details) per image
    by_image: dict[str, tuple[int, int, list[dict]]] = {}
    for f in sorted(report_dir.glob("*.json")):
        row = load_result(f)
        if row:
            name, c, h, critical = row
            by_image[name] = (c, h, critical)

    langgenius: list[tuple[str, int, int, list[dict]]] = []
    third_party: list[tuple[str, int, int, list[dict]]] = []
    for name in sorted(by_image.keys()):
        c, h, critical = by_image[name]
        display = slug(name)
        if is_langgenius(name):
            langgenius.append((display, c, h, critical))
        else:
            third_party.append((display, c, h, critical))

    scan_date = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
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
    for display, c, h, critical in langgenius:
        lines.append(f"#### {display}")
        lines.append(f"- **CRITICAL vulnerabilities:** {c}")
        lines.append(f"- **HIGH vulnerabilities:** {h}")
        lines.append("")
        if critical:
            lines.extend(format_critical_table(critical))
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
    for display, c, h, critical in third_party:
        lines.append(f"#### {display}")
        lines.append(f"- **CRITICAL vulnerabilities:** {c}")
        lines.append(f"- **HIGH vulnerabilities:** {h}")
        lines.append("")
        if critical:
            lines.extend(format_critical_table(critical))
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
