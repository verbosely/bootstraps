# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/term_output.sh"

validate_install_versions() {
    local -i i response ; local -a client_error server_error success
    for (( i=2; $# + 1 - i; i++ )); do
        response=$(curl --head --output /dev/null --retry 6 --silent \
            --write-out "%{http_code}\n" "${1}${!i}/")
        [[ ${response} =~ 2[[:digit:]]{2} ]] && success+=(${!i})
        [[ ${response} =~ 4[[:digit:]]{2} ]] && client_error+=(${!i})
        [[ ${response} =~ 5[[:digit:]]{2} ]] && server_error+=(${!i})
    done
    (( ${#client_error[@]} )) &&
        print_invalid_versions "4xx" "${client_error[@]}"
    (( ${#server_error[@]} )) &&
        print_invalid_versions "5xx" "${server_error[@]}"
    declare -agr INSTALL_VERSIONS=("${success[@]}")
    unset -f validate_install_versions
}
