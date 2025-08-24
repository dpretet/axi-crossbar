#!/usr/bin/env bash

# -e: exit if one command fails
# -o pipefail: causes a pipeline to fail if any command fails
set -e -o pipefail

design="./axicb_axi4.ys"

# Check if a design is specified
if [[ -n $1 ]]; then
    echo "INFO: will start $1 synthesis"
    design="$1"
fi

echo "INFO: Start synthesis flow"
yosys -V

yosys "$design" > "$design.log"

exit 0
