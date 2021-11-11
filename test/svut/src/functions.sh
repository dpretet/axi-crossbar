#!usr/bin/env bash

#------------------------------------------------------------------------------
# Helper
#------------------------------------------------------------------------------
usage()
{
cat << EOF
usage: bash ./run.sh ...
        --tc                (optional)            Path to a testbench setup (located in tb_config)
-m    | --maxtraffic        (optional)            Maximun number of requests injected by the drivers
-t    | --timeout           (optional)            Timeout in number of cycles (10000 by default)
-n    | --no-vcd            (optional)            Don't dump VCD file
-h    | --help                                    Brings up this menu
EOF
}
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# Check the execution ran well
#------------------------------------------------------------------------------
check_status() {

    echo "INFO: Check testsuite status"

    # Exit if execution failed.
    # Double check the execution status by parsing the log
    ec=$(grep -c "ERROR:" simulation.log)

    if [[ $ec != 0 || $test_ret != 0 ]]; then
        echo "error count: $ec"
        echo "test_ret: $test_ret"
        echo -e "${RED}ERROR: Testsuite failed!${NC}"
        grep -i "Failling" simulation.log
        echo $fails
        exit 1
    fi

    echo -e "${GREEN}INFO: Testsuites executed successfully!${NV}"
    exit 0
}


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
            --tc )
                shift
                TC=$1
            ;;
            -t | --timeout )
                shift
                TIMEOUT=$1
            ;;
            -n | --no-vcd )
                shift
                NOVCD=1
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

#------------------------------------------------------------------------------
# Read a configuration file listing parameters and values, comma separated
#------------------------------------------------------------------------------
read_config() {

    DEFINES=""

    while IFS=, read -r name value; do
        DEFINES="${DEFINES}${name}=${value};"
    done < $1

    echo "$DEFINES"
}

#------------------------------------------------------------------------------
# Run function targeting a specific configuration
#------------------------------------------------------------------------------

runner() {

    # Grab config name to setup testsuite name
    config_file=$(basename $1)
    config_name=${config_file%%.*}

    # Read testbench configuration and add config from command line
    DEFINES=$(read_config $1)
    DEFINES="$DEFINES;TIMEOUT=$TIMEOUT;MAX_TRAFFIC=$MAX_TRAFFIC;TSNAME=$config_name"

    if [ $NOVCD != 0 ]; then
        DEFINES="$DEFINES;NOVCD=1"
    fi

    # Run the simulation
    time svutRun -t ./src/axicb_crossbar_top_testbench.sv -define $DEFINES | tee simulation.log
    ret=$?
    if [[ $ret != 0 ]]; then
        fails="$fails "
    fi

    # Grab the return code used later to determine the compliance status
    test_ret=$((test_ret+$ret))

    if [ $NOVCD == 0 ]; then
        mv axicb_*.vcd vcd/${config_name}.vcd
    fi
}
