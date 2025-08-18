#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Helper
#------------------------------------------------------------------------------
usage()
{
cat << EOF
usage: bash ./run.sh ...
     --tc                (optional)            Path to a testbench setup (located in tb_config)
-m | --max-traffic       (optional)            Maximun number of requests injected by the drivers
-t | --timeout           (optional)            Timeout in number of cycles (10000 by default)
     --no-wave           (optional)            Don't dump waveform
-h | --help                                    Brings up this menu

If no config is passed, all files listed in ./tb_config will be executed

EOF
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Check the execution ran well
#------------------------------------------------------------------------------
check_status() {

    echo "INFO: Check testsuite status"

    # Double check the execution status by parsing the log
    ec=$(grep -c "ERROR:" simulation.log)

    if [[ $ec != 0 || $test_ret != 0 ]]; then
        echo "error count: $ec"
        echo "test_ret: $test_ret"
        echo -e "${RED}ERROR: Testsuite failed!${NC}"
        grep -i "Failling" simulation.log
        echo "$fails"
        exit 1
    fi

    echo -e "${GREEN}INFO: Testsuites executed successfully!${NC}"
    exit 0
}


#------------------------------------------------------------------------------
# Grab arguments and values
#------------------------------------------------------------------------------
get_args() {
    while [ "$1" != "" ]; do
        case $1 in
            -m | --max-traffic )
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
            --no-wave )
                NOWAVE=1
            ;;
            --no-debug-log )
                NODEBUG=1
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
    done < "$1"

    echo "$DEFINES"
}


#------------------------------------------------------------------------------
# Run function targeting a specific configuration
#------------------------------------------------------------------------------
runner() {

    # Grab config name to setup testsuite name
    config_file=$(basename "$1")
    config_name=${config_file%%.*}

    # Read testbench configuration and add config from command line
    DEFINES=$(read_config "$1")
    DEFINES="$DEFINES;TIMEOUT=$TIMEOUT;MAX_TRAFFIC=$MAX_TRAFFIC;TSNAME=$config_name"

    if [ "$NOWAVE" != 0 ]; then
        DEFINES="$DEFINES;NOWAVE=1"
    fi

    # Don't dump log, useful for Github actions which may use icarus 10 not supporting SVLogger
    if [ "$NODEBUG" != 0 ]; then
        DEFINES="$DEFINES;NODEBUG=1"
    fi

    # Run the simulation
    svutRun -t ./src/axicb_crossbar_top_testbench.sv \
            -define "$DEFINES" \
            -fst \
            | tee -a simulation.log
    ret=$?
    if [[ $ret != 0 ]]; then
        fails="$fails $config_name"
    fi

    # Gathers the return code to check later a bunch of simulation status
    test_ret=$((test_ret+$ret))

    # Backup FST file of current test
    if [ "$NOWAVE" == 0 ]; then
        cp axicb_*.fst "wave/${config_name}.fst"
    fi
}
