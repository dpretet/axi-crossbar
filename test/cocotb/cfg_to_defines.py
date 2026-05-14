#!/usr/bin/env python3
# coding: utf-8

# distributed under the mit license
# https://opensource.org/licenses/mit-license.php

""" Load a config file and define parameters for testbench """

import sys

def cfg_to_defines(cfg_file):
    args = []
    with open(cfg_file) as f:
        for line in f:
            if "=" in line:
                line = line.strip()
                args.append(f"-D{line}")
    return args

if __name__ == "__main__":
    cfg_file = sys.argv[1]
    args = cfg_to_defines(cfg_file)

    print(" ".join(args), end="")
