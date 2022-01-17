#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.."
[ -d tmp ] || rm -rf tmp
mkdir -p tmp
