#!/usr/bin/env bash

# -e: exit if one command fails
# -u: treat unset variable as an error
# -f: disable filename expansion upon seeing *, ?, ...
# -o pipefail: causes a pipeline to fail if any command fails
set -e -o pipefail

source ./functions.sh

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Defines passed to the simulation. Read from read_config() config files
DEFINES=""
MAX_TRAFFIC=1000
TIMEOUT=20000

test_ret=0

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {

    echo "INFO: Start AXI-Crossbar Random Testsuite"

    PID=$$
    echo "PID: $PID"

    rm -f simulation.log

    # Get configuration from command line
    get_args "$@"

    for config in ./tb_config/*.cfg; do
        # Grab config name to setup testsuite name
        config_file=$(basename $config)
        config_name=${config_file%%.*}
        # Read testbench configuration and add config from command line
        DEFINES=$(read_config $config)
        DEFINES="$DEFINES;TIMEOUT=$TIMEOUT;MAX_TRAFFIC=$MAX_TRAFFIC;TSNAME=$config_name"
        # Run the simulation
        svutRun -t ./src/axicb_crossbar_top_testbench.sv -define $DEFINES | tee simulation.log
        # Grab the return code used later to determine the compliance status
        test_ret=$((test_ret+$?))
        # mv axicb_*.vcd ${config_name}.vcd
    done

    # Check if errors occured and exit
    check_status

}

main "$@"
