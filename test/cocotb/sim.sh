#!/usr/bin/env bash

# distributed under the mit license
# https://opensource.org/licenses/mit-license.php

# -e: exit if one command fails
# -u: treat unset variable as an error
# -f: disable filename expansion upon seeing *, ?, ...
# -o pipefail: causes a pipeline to fail if any command fails
set -e -o pipefail

# Get current script path (applicable even if is a symlink)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Python virtual environment directory
VENV_DIR="$DIR/venv"

venv() {

    if ! command -v "python3.13"; then
        echo "ERROR: Python 3.13 is not available"
        exit 1
    fi

    # Create virtualenv
    if [ ! -d "$VENV_DIR" ]; then
        echo "🐍 Creating virtual environment in $VENV_DIR..."
        python3.13 -m venv "$VENV_DIR"
    fi

    # Activate venv
    echo "✅ Activating virtual environment..."
    if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
    else
        echo "❌ Could not find virtualenv activation script"
        exit 1
    fi

    # Install Python dependencies
    if [ -f "$DIR/requirements.txt" ]; then
        echo "📦 Installing Python dependencies..."
        if pip install -r "$DIR/requirements.txt" > sim.log 2>&1; then
            echo "✅ Dependencies installed"
        else
            echo "❌ Failed to install some dependencies"
            exit 1
        fi
    fi
}

help() {
    echo "CocoTB Help"
    exit 0;
}

run() {

    echo "INFO: Start CocoTB Testbench"
    venv
    rm -fr ./sim_build
    make
}

main() {

    # Print help
    if [[ $1 == "-h" || $1 == "help" ]]; then
        help
        exit 0
    fi

    run
}

main "$@"
