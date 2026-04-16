#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
distributed under the mit license
https://opensource.org/licenses/mit-license.php
"""

import argparse
import json
import sys
from pathlib import Path
from jinja2 import Template

SCRIPTDIR = Path(__file__).resolve().parent


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="Render Jinja2 template with JSON data")
    parser.add_argument("--json", "-j", required=True, help="Path to JSON file")
    parser.add_argument("--type", choices=["axi4", "axi4lite"], default="axi4", help="AXI type")
    args = parser.parse_args()

    json_path = Path(args.json)
    if not json_path.exists():
        print(f"Error: JSON file not found: {json_path}")
        return 1

    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    template_map = {"axi4": "tmpl.axi4_top.sv", "axi4lite": "tmpl.axi4lite_top.sv"}
    template_path = SCRIPTDIR / template_map[args.type]
    if not template_path.exists():
        print(f"Error: Template not found: {template_path}")
        return 1

    tmpl = Template(template_path.read_text(encoding="utf-8"))
    rendered = tmpl.render(**data)

    output_path = json_path.with_suffix(".sv")
    output_path.write_text(rendered, encoding="utf-8")
    print(f"Generated: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
