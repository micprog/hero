#!/bin/bash

scriptDir="$(dirname "$(readlink -f "${BASH_SOURCE[0]:-${(%):-%x}}")")"

export PULP_CURRENT_CONFIG=pulpissimo-microriscy@config_file=${scriptDir}/json/pulpissimo-microriscy.json

unset PULP_CURRENT_CONFIG_ARGS

if [ -e ${scriptDir}/../init.sh ]; then
    source ${scriptDir}/../init.sh
fi
