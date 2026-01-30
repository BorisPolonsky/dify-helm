#!/usr/bin/env python3
"""
Extract default container images from the Dify Helm chart (values.yaml + Chart.yaml).
Outputs one image reference per line: repository:tag
Used by CVE scan workflow to know which images to scan when Chart/values change.
"""
from pathlib import Path
import sys
import yaml

# Keys that use Chart.AppVersion as default tag in templates (api, web, pluginDaemon)
APPVERSION_KEYS = ("api", "web", "pluginDaemon")

def main():
    repo_root = Path(__file__).resolve().parents[2]
    chart_dir = repo_root / "charts" / "dify"
    values_path = chart_dir / "values.yaml"
    chart_path = chart_dir / "Chart.yaml"

    if not values_path.exists():
        print("values.yaml not found", file=sys.stderr)
        sys.exit(1)
    if not chart_path.exists():
        print("Chart.yaml not found", file=sys.stderr)
        sys.exit(1)

    with open(values_path) as f:
        values = yaml.safe_load(f)
    with open(chart_path) as f:
        chart = yaml.safe_load(f)

    app_version = (chart.get("appVersion") or "").strip().strip('"')
    image_config = values.get("image") or {}

    images = []
    for key in ("api", "web", "sandbox", "proxy", "ssrfProxy", "pluginDaemon"):
        block = image_config.get(key)
        if not block:
            continue
        repo = (block.get("repository") or "").strip()
        tag = (block.get("tag") or "").strip().strip('"')
        if key in APPVERSION_KEYS and not tag:
            tag = app_version
        if repo:
            images.append(f"{repo}:{tag or 'latest'}")

    for img in sorted(set(images)):
        print(img)

if __name__ == "__main__":
    main()
