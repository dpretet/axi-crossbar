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

# Number of rd/wr requests injected by the drivers
MAX_TRAFFIC=1000

# Timeout upon which the simulation is ran
TIMEOUT=10000

# Defines passed to the simulation
DEFINES=""
DEFINES="${DEFINES}TIMEOUT=$TIMEOUT;"
DEFINES="${DEFINES}MAX_TRAFFIC=$MAX_TRAFFIC;"

test_ret=0

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {

    echo "INFO: Start AXI-Crossbar Random Testsuite"

    PID=$$
    echo "PID: $PID"

    # Get configuration from command line
    get_args "$@"

    # Run the simulation
    svutRun -t ./axicb_crossbar_top_testbench.sv -define $DEFINES | tee simulation.log

    # Grab the return code used later to determine the compliance status
    test_ret=$((test_ret+$?))

    # Check if errors occured and exit
    check_status

}

main "$@"
