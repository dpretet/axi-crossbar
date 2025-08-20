#!/usr/bin/env bash

# -e: exit if one command fails
# -u: treat unset variable as an error
# -f: disable filename expansion upon seeing *, ?, ...
# -o pipefail: causes a pipeline to fail if any command fails
set -e -o pipefail

#-------------------------------------------------------------
# Get current script path (applicable even if is a symlink)
#-------------------------------------------------------------

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Functions to install the flow
source script/setup.sh

ret=0

# Bash color codes
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
# Reset
NC='\033[0m'

function printerror {
    echo -e "${Red}ERROR: ${1}${NC}"
}

function printwarning {
    echo -e "${Yellow}WARNING: ${1}${NC}"
}

function printinfo {
    echo -e "${Blue}INFO: ${1}${NC}"
}

function printsuccess {
    echo -e "${Green}SUCCESS: ${1}${NC}"
}

help() {
    echo -e "${Blue}"
    echo ""
    echo "NAME"
    echo ""
    echo "      AXI4-Crossbar Flow"
    echo ""
    echo "SYNOPSIS"
    echo ""
    echo "      ./flow.sh -h"
    echo ""
    echo "      ./flow.sh help"
    echo ""
    echo "      ./flow.sh syn"
    echo ""
    echo "      ./flow.sh sim"
    echo ""
    echo "DESCRIPTION"
    echo ""
    echo "      This flow handles the different operations available:"
    echo ""
    echo "      ./flow.sh help|-h"
    echo ""
    echo "      Print the help menu"
    echo ""
    echo "      ./flow.sh syn"
    echo ""
    echo "      ./flow.sh syn axi4"
    echo ""
    echo "      ./flow.sh syn axi4lite"
    echo ""
    echo "      Launch the synthesis script relying on Yosys"
    echo ""
    echo "      ./flow.sh sim"
    echo ""
    echo "      ./flow.sh sim axi4"
    echo ""
    echo "      ./flow.sh sim axi4lite"
    echo ""
    echo "      Launch all available testsuites"
    echo ""
    echo "      ./flow.sh lint"
    echo ""
    echo "      Launch lint analysis with Verilator"
    echo ""
    echo -e "${NC}"
}

main() {

    echo ""
    printinfo "Start AXI4-Crossbar Flow"

    # If no argument provided, print help and exit
    if [[ $# -eq 0 ]]; then
        help
        exit 1
    fi

    # Print help
    if [[ $1 == "-h" || $1 == "help" ]]; then
        help
        exit 0
    fi


    if [[ $1 == "lint" ]]; then

        install_verilator
        # Disable break on error bc Verilator exit with 1 with warnings
        set +e

        printinfo "Start Verilator lint"
        verilator --lint-only +1800-2017ext+sv \
            -Wall -Wpedantic \
            -Wno-VARHIDDEN \
            -Wno-PINCONNECTEMPTY \
            -Wno-TIMESCALEMOD \
            -I./rtl\
            ./rtl/axicb_mst_if.sv\
            ./rtl/axicb_slv_if.sv\
            ./rtl/axicb_slv_ooo.sv\
            ./rtl/axicb_slv_switch.sv\
            ./rtl/axicb_slv_switch_rd.sv\
            ./rtl/axicb_slv_switch_wr.sv\
            ./rtl/axicb_pipeline.sv\
            ./rtl/axicb_mst_switch.sv\
            ./rtl/axicb_mst_switch_rd.sv\
            ./rtl/axicb_mst_switch_wr.sv\
            ./rtl/axicb_switch_top.sv\
            ./rtl/axicb_round_robin.sv\
            ./rtl/axicb_round_robin_core.sv\
            ./rtl/axicb_crossbar_top.sv\
            ./rtl/axicb_crossbar_lite_top.sv\
            --top-module axicb_crossbar_lite_top &> lint.log

        verilator --lint-only +1800-2017ext+sv \
            -Wall -Wpedantic \
            -Wno-VARHIDDEN \
            -Wno-PINCONNECTEMPTY \
            -Wno-TIMESCALEMOD \
            -I./rtl\
            ./rtl/axicb_mst_if.sv\
            ./rtl/axicb_slv_if.sv\
            ./rtl/axicb_slv_ooo.sv\
            ./rtl/axicb_slv_switch.sv\
            ./rtl/axicb_slv_switch_rd.sv\
            ./rtl/axicb_slv_switch_wr.sv\
            ./rtl/axicb_pipeline.sv\
            ./rtl/axicb_mst_switch.sv\
            ./rtl/axicb_mst_switch_rd.sv\
            ./rtl/axicb_mst_switch_wr.sv\
            ./rtl/axicb_switch_top.sv\
            ./rtl/axicb_round_robin.sv\
            ./rtl/axicb_round_robin_core.sv\
            ./rtl/axicb_crossbar_top.sv\
            ./rtl/axicb_crossbar_lite_top.sv\
            --top-module axicb_crossbar_top &> lint.log
        set -e
    fi

    if [[ $1 == "sim" ]]; then
        # Install SVUT and Icarus Verilog if needed
        install_svut
        install_icarus
        # Run all testsuites
        cd "$DIR/test/svut"
        if [[ $2 == "axi4" ]]; then
            ./run.sh --no-debug-log --no-wave -m 10000 -t 0 --tc "tb_config/axi4_*.cfg"
        elif  [[ $2 == "axi4lite" ]]; then
            ./run.sh --no-debug-log --no-wave -m 10000 -t 0 --tc "tb_config/axi4lite_*.cfg"
        else
            ./run.sh --no-debug-log --no-wave -m 10000 -t 0
        fi
        ret=$?
        echo "Execution status: $ret"
        exit $ret
    fi

    if [[ $1 == "syn" ]]; then
        install_yosys
        printinfo "Start synthesis flow"
        ret=0
        cd "$DIR/syn/yosys"

        # AXI4 synthesis
        if [[ $2 == "axi4" || -z $2 ]]; then
            ./syn_asic.sh axicb_axi4.ys | tee axi4.log
            ret=$?
        fi
        # AXI4-lite synthesis
        if  [[ $2 == "axi4lite" || -z $2 ]]; then
            ./syn_asic.sh axicb_axi4lite.ys | tee axi4lite.log
            ret=$((ret+$?))
        fi

        echo "Execution status: $ret"
        exit $ret
    fi
}

main "$@"
