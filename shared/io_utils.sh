# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/term_output.sh"

get_gpg_key() {
    local code
    code=$(curl --output "$1" --retry 6 --silent \
        --write-out "%{http_code}\n" "$2")
    [[ ${code} =~ [^2][[:digit:]]{2} ]] &&
        rm --force "$1" && terminate "$2" "$code"
    cat "$1" | gpg --yes --output "$1" --dearmor ; chmod 0644 "$1"
    print_public_key_progress "added" "$2" "$(dirname "$1")/"
    unset -f get_gpg_key
}

validate_install_versions() {
    local -i i code ; local -a success ; local -A failures
    for (( i=2; $# + 1 - i; i++ )); do
        code=$(curl --head --output /dev/null --retry 6 --silent \
            --write-out "%{http_code}\n" "${1}${!i}/")
        [[ ${code} =~ 2[[:digit:]]{2} ]] && success+=(${!i}) || {
            [ -v failures["$code"] ] && failures["$code"]+=", ${!i}" ||
                failures["$code"]="${!i}" ; }
    done
    (( ${#failures[@]} )) && {
        for code in ${!failures[@]}; do
            print_invalid_versions "$code" "${failures["$code"]}"
        done ; }
    declare -agr INSTALL_VERSIONS=("${success[@]}")
    unset -f validate_install_versions
}
