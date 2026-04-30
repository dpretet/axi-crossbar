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
import shutil


SCRIPTDIR = Path(__file__).resolve().parent


def gen(template_path, data, path):

    if not template_path.exists():
        print(f"Error: Template not found: {template_path}")
        return 1

    tmpl = Template(template_path.read_text(encoding="utf-8"))
    rendered = tmpl.render(**data)

    p = Path(path)
    p.write_text(rendered, encoding="utf-8")
    print(f"Generated: {path}")
    return 0


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="Render Jinja2 template with JSON data")
    parser.add_argument("--json", "-j", required=True, help="Path to JSON file")
    args = parser.parse_args()

    json_path = Path(args.json)
    if not json_path.exists():
        print(f"Error: {json_path} file not found")
        return 1

    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    iptype = data["axi_type"]

    template_map = {"axi4": "tmpl.axi4_top.sv", "axi4lite": "tmpl.axi4lite_top.sv"}
    template_path = SCRIPTDIR / template_map[iptype]

    # First generate the AXI4-lite version is requested
    if iptype == "axi4lite":
        # Generate
        gen(template_path, data, "axicb_crossbar_lite_top.sv")
        # Then prepare the AXI4 submodule
        data["axi_type"] = "axi4lite"
        data["global"]["AXI_SIGNALING"] = "1"

    # Then, anyway generate an AXI4 version
    template_path = SCRIPTDIR / template_map[iptype]
    gen(template_path, data, "axicb_crossbar_top.sv")

    return 0


if __name__ == "__main__":
    sys.exit(main())
