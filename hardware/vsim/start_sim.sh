#!/usr/bin/env bash

set -e
if [ -z "$VSIM" ]; then
    VSIM="vsim-10.7b"
fi
readonly VSIM

if [ -n "$CI" -o -z "$DISPLAY" ]; then
    # Run in console-only mode.
    ${VSIM} -c -do 'source run.tcl; quit -code $quitCode'
else
    # Run in GUI mode and silence console output.
    ${VSIM} -do 'source run.tcl' &>/dev/null
fi
