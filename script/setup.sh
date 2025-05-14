#!/usr/bin/env bash

#-------------------------------------------------------------
# Install SVUT from https://github.com/dpretet/svut if missing
#-------------------------------------------------------------
install_svut() {
    if [[ ! $(type svutRun) ]];
    then
        svut_dir="$DIR/.svut"
        if [[ ! -d $svut_dir ]]; then
            echo "INFO: Install SVUT (https://github.com/dpretet/svut)"
            git clone "https://github.com/dpretet/svut.git" "$svut_dir"
        fi
        echo "INFO: Enable SVUT in PATH"
        export PATH=$svut_dir/:$PATH
    fi
}

#-------------------------------------------------------------
# Install Verilator with brew
#-------------------------------------------------------------
install_verilator() {
    if [[ ! $(type verilator) ]];
    then
        echo "INFO: Enable Verilator"
        brew install verilator
        verilator -V
    fi
}

#-------------------------------------------------------------
# Install Icarus-verilog with brew
#-------------------------------------------------------------
install_icarus() {
    if [[ ! $(type iverilog) ]];
    then
        echo "INFO: Enable Icarus-Verilog"
        brew install icarus-verilog
        iverilog -V
    fi
}

#-------------------------------------------------------------
# Install Icarus-verilog with brew
#-------------------------------------------------------------
install_yosys() {
    if [[ ! $(type yosys) ]];
    then
        echo "INFO: Enable Yosys"
        brew install yosys
        yosys --version
    fi
}
