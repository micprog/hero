THIS_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]:-${(%):-%x}}")")

source ${THIS_DIR}/exilzcu102.sh
export PULP_CURRENT_CONFIG=hero-sim@config_file=${HERO_PULP_SDK_DIR}/configs/json/hero-urania.json
