#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
distributed under the mit license
https://opensource.org/licenses/mit-license.php
"""

# pylint: disable=C0103

import os
import sys
from pathlib import Path
from jinja2 import Template


SCRIPTDIR = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))


def dump_template(file_name, tmpl):
    """
    Store the template after substitution
    """
    try:
        with open(file_name, "w", encoding="utf-8") as ofile:
            ofile.write(tmpl)
    except OSError:
        print("Can't store template")
        sys.exit(1)
    return 0


def generate_address_ranges(slv_nb, addr_w=8):
    """
    Generate address ranges for slaves based on address width and number of slaves
    """
    addr_size = 2 ** addr_w
    slave_addr_size = addr_size // slv_nb

    ranges = []
    for i in range(slv_nb):
        # Use fixed ranges for addr_w=8 (original behavior)
        if addr_w == 8:
            if i == 0:
                start, end = 0, 4095
            elif i == 1:
                start, end = 4096, 8191
            elif i == 2:
                start, end = 8192, 12287
            elif i == 3:
                start, end = 12288, 16383
            else:
                start = i * slave_addr_size
                end = ((i + 1) * slave_addr_size) - 1
        else:
            start = i * slave_addr_size
            end = ((i + 1) * slave_addr_size) - 1
        ranges.append((start, end))
    return ranges


def generate_routes_string(slv_nb):
    """
    Generate routes string like "4'b1_1_1_1" for given number of slaves
    """
    routes_bits = "1" * slv_nb
    return f"{slv_nb}'b" + "_".join(routes_bits)


def generate_masters_config(mst_nb, slv_nb, axi_type="axi4"):
    """
    Generate masters configuration list
    AXI4 has OSTDREQ_SIZE, AXI4-lite does not
    """
    masters = []
    for i in range(mst_nb):
        master = {
            "CDC": 0,
            "OSTDREQ_NUM": 4,
            "PRIORITY": 0,
            "ROUTES": generate_routes_string(slv_nb),
            "ID_MASK": 0x10 * (i + 1),
            "RW": 0,
        }
        if axi_type == "axi4":
            master["OSTDREQ_SIZE"] = 1
        masters.append(master)
    return masters


def generate_slaves_config(slv_nb, addr_w=8, axi_type="axi4"):
    """
    Generate slaves configuration list
    AXI4 has OSTDREQ_SIZE, AXI4-lite does not
    """
    address_ranges = generate_address_ranges(slv_nb, addr_w)
    slaves = []
    for _, (start, end) in enumerate(address_ranges):
        slave = {
            "CDC": 0,
            "START_ADDR": start,
            "END_ADDR": end,
            "OSTDREQ_NUM": 4,
            "KEEP_BASE_ADDR": 0,
        }
        if axi_type == "axi4lite":
            slave["OSTDREQ_SIZE"] = 1
        slaves.append(slave)
    return slaves


def generate_config(mst_nb, slv_nb, addr_w=8, id_w=8, data_w=8, axi_type="axi4"):
    """
    Generate a configuration dictionary with custom number of masters and slaves

    Args:
        mst_nb: Number of masters
        slv_nb: Number of slaves
        addr_w: Address width in bits
        id_w: ID width in bits
        data_w: Data width in bits
        axi_type: "axi4" or "axi4lite"
    """
    masters = generate_masters_config(mst_nb, slv_nb, axi_type)
    slaves = generate_slaves_config(slv_nb, addr_w, axi_type)

    config = {
        "global": {
            "AXI_ADDR_W": addr_w,
            "AXI_ID_W": id_w,
            "AXI_DATA_W": data_w,
            "MST_NB": mst_nb,
            "SLV_NB": slv_nb,
            "OR_NUM_W": 8,
            "MST_PIPELINE": 0,
            "SLV_PIPELINE": 0,
            "USER_SUPPORT": 0,
            "AXI_AUSER_W": 1,
            "AXI_WUSER_W": 1,
            "AXI_BUSER_W": 1,
            "AXI_RUSER_W": 1,
            "TIMEOUT_VALUE": 10000,
            "TIMEOUT_ENABLE": 1,
            "NUM_PRIORITY_LVL": 4,
        },
        "masters": masters,
        "slaves": slaves,
    }

    # AXI4-specific global parameters
    if axi_type == "axi4":
        config["global"]["AXI_SIGNALING"] = 1

    return config


def generate_default_config(axi_type="axi4"):
    """
    Generate a default configuration dictionary (4 masters, 4 slaves)

    Args:
        axi_type: "axi4" or "axi4lite"
    """
    return generate_config(4, 4, 8, 8, 8, axi_type)


def get_template_path(axi_type):
    """
    Get the template file path based on AXI type
    """
    if axi_type == "axi4":
        return os.path.join(SCRIPTDIR, "tmpl.axi4_top.sv")
    elif axi_type == "axi4lite":
        return os.path.join(SCRIPTDIR, "tmpl.axi4lite_top.sv")
    else:
        print(f"Unknown AXI type: {axi_type}")
        sys.exit(1)


def get_default_output_filename(axi_type):
    """
    Get the default output filename based on AXI type
    """
    if axi_type == "axi4":
        return "axicb_crossbar_top.sv"
    elif axi_type == "axi4lite":
        return "axicb_crossbar_lite_top.sv"
    else:
        print(f"Unknown AXI type: {axi_type}")
        sys.exit(1)


def main(args):
    """
    Main function

    Usage:
        python template_top_level.py [--type axi4|axi4lite] [output_file] [mst_nb] [slv_nb]

        If no arguments: generates default config (4 masters, 4 slaves) for AXI4
        --type: specify axi4 or axi4lite (default: axi4)
        output_file: output filename (optional)
        mst_nb: number of masters (optional, default: 4)
        slv_nb: number of slaves (optional, default: 4)
    """
    # Parse arguments
    axi_type = "axi4"
    output_file = None
    mst_nb = None
    slv_nb = None

    i = 0
    while i < len(args):
        if args[i] == "--type" and i + 1 < len(args):
            axi_type = args[i + 1]
            if axi_type not in ["axi4", "axi4lite"]:
                print(f"Error: Invalid AXI type '{axi_type}'. Use 'axi4' or 'axi4lite'.")
                sys.exit(1)
            i += 2
        elif args[i].startswith("--"):
            print(f"Error: Unknown option '{args[i]}'")
            sys.exit(1)
        else:
            if output_file is None:
                output_file = args[i]
            elif mst_nb is None:
                mst_nb = int(args[i])
            elif slv_nb is None:
                slv_nb = int(args[i])
            else:
                print("Error: Too many arguments")
                sys.exit(1)
            i += 1

    # Set defaults
    if output_file is None:
        output_file = get_default_output_filename(axi_type)
    if mst_nb is None:
        mst_nb = 4
    if slv_nb is None:
        slv_nb = 4

    # Generate configuration
    config = generate_config(mst_nb, slv_nb, 8, 8, 8, axi_type)

    # Load the template
    tmpl_path = get_template_path(axi_type)
    tmpl = Path(tmpl_path).read_text(encoding="utf-8")

    # Render the template
    rendered = Template(tmpl).render(**config)

    # Write the output
    dump_template(output_file, rendered)

    axi_label = "AXI4" if axi_type == "axi4" else "AXI4-lite"
    print(f"Generated {output_file} with {mst_nb} masters and {slv_nb} slaves ({axi_label})")


if __name__ == '__main__':
    main(sys.argv[1:])
