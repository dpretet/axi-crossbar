#!/usr/bin/env bash

# -e: exit if one command fails
# -u: treat unset variable as an error
# -f: disable filename expansion upon seeing *, ?, ...
# -o pipefail: causes a pipeline to fail if any command fails
# set -e -o pipefail

source ./src/functions.sh

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Defines passed to the simulation. Read from read_config() config files
DEFINES=""
MAX_TRAFFIC=5000
TIMEOUT=100000
TC="./tb_config/*.cfg"
NOWAVE=0
NODEBUG=0

test_ret=0
ret=0
fails="Fails: "

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {

    echo "INFO: Start AXI-Crossbar Random Testsuite"

    PID=$$
    echo "PID: $PID"

    rm -fr simulation.log
    rm -fr wave
    rm -fr ./*.fst
    rm -fr ./*.txt
    mkdir wave

    # Get configuration from command line
    get_args "$@"

    # Run all configurations one by one
    for config in $TC; do
        runner $config
    done

    # Check if errors occured and exit
    check_status
}

main "$@"
