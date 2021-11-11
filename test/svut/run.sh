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
MAX_TRAFFIC=1000
TIMEOUT=50000
TC=""
NOVCD=0

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

    rm -f simulation.log
    rm -fr vcd
    rm -f *.txt
    mkdir vcd

    # Get configuration from command line
    get_args "$@"

    if [[ $TC != "" ]]; then
        runner $TC
    else 
        for config in ./tb_config/*.cfg; do
            runner $config
        done
    fi

    # Check if errors occured and exit
    check_status

}

main "$@"
