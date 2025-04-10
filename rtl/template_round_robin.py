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
from jinja2 import Template, FileSystemLoader, Environment


SCRIPTDIR = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))

def dump_template(file_name, tmpl):
    """
    Store the template transformated after substitution
    """
    try:
        # Store the testbench
        with open(file_name, "w", encoding="utf-8") as ofile:
            ofile.write(tmpl)
            ofile.close()
    except OSError:
        print("Can't store template")
        sys.exit(1)

    return 0


def main(args):
    """
    Main function
    """

    # Load the system verilog template and substitute
    tmpl = Path(SCRIPTDIR+"/tmpl.axicb_round_robin_core.sv").read_text(encoding="utf-8")
    # Generate the final file
    tmpl = Template(tmpl).render({"num": int(args[0])})
    # Write the file
    dump_template("axicb_round_robin_core.sv", tmpl)


if __name__ == '__main__':
    main(sys.argv[1:])
