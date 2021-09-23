#!/usr/bin/env bash

# -e: exit if one command fails
# -o pipefail: causes a pipeline to fail if any command fails
# set -e -o pipefail


#------------------------------------------------------------------------------
# Helper
#------------------------------------------------------------------------------
usage()
{
cat << EOF
usage: bash ./run.sh ...
-m    | --maxtraffic        (optional)            Maximun number of requests injected by the drivers
-t    | --timeout           (optional)            Timeout in number of cycles (10000 by default)
-h    | --help                                    Brings up this menu
EOF
}
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# Check the execution ran well
#------------------------------------------------------------------------------
check_status() {
    # Exit if execution failed.
    # Double check the execution status by parsing the log
    ec=$(grep -c "ERROR:" simulation.log)
    if [[ $ec != 0 || $test_ret != 0 ]]; then
        echo -e "${RED}ERROR: Testsuite failed!${NC}"
        grep -i "Failling" simulation.log
        exit 1
    fi
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Grab arguments and values
#------------------------------------------------------------------------------

get_args() {
    # First handle the arguments
    while [ "$1" != "" ]; do
        case $1 in
            -m | --maxtraffic )
                shift
                MAX_TRAFFIC=$1
            ;;
            -t | --timeout )
                TIMEOUT=$1
            ;;
            -h | --help )
                usage
                exit 0
            ;;
            * )
                usage
                exit 1
            ;;
        esac
        shift
    done
}
