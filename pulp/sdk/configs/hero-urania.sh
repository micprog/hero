#!/bin/bash

scriptDir="$(dirname "$(readlink -f "${BASH_SOURCE[0]:-${(%):-%x}}")")"

export PULP_CURRENT_CONFIG=hero-urania@config_file=${scriptDir}/json/hero-urania.json

unset PULP_CURRENT_CONFIG_ARGS

if [ -e ${scriptDir}/../init.sh ]; then
    source ${scriptDir}/../init.sh
fi
