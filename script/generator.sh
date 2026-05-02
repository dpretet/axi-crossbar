#!/usr/bin/env bash

# distributed under the mit license
# https://opensource.org/licenses/mit-license.php

# -e: exit if one command fails
# -u: treat unset variable as an error
# -f: disable filename expansion upon seeing *, ?, ...
# -o pipefail: causes a pipeline to fail if any command fails
set -e -o pipefail


generate_rtl() {

    local input_file="config.json"
    local output_file=""
    local tui=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                input_file="$2"
                shift 2
                ;;
            --tui)
                tui=1
                shift 1
                ;;
        esac
    done

    if [[ $tui -eq 1 && -n $input_file ]]; then
        echo "ERROR: TUI can't be used with a JSON file"
        exit 1
    fi

    if [[ $tui -eq 0 && -z $input_file ]]; then
        echo "ERROR: no config file passed to the RTL generator"
        exit 1
    fi

    # Activate virtual env
    venv

    # Launch the TUI if invocated
    if [[ $tui -eq 1 ]]; then
        python3 "$DIR/script/tui.py" -o "$input_file"
    fi
    # Launch the RTL generator
    python3 "$DIR/script/template_top_level.py" --json $input_file

    # If used the TUI, rename the configuration file
    if [[ $tui -eq 1  ]]; then
        if grep -q "axi4lite" config.json; then
            mv "config.json" "axicb_crossbar_lite_top.json"
        else
            mv "config.json" "axicb_crossbar_top.json"
        fi
    fi
}
