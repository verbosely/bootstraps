# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/notifications.sh"

check_root_user() {
    ! (( ${EUID} )) || terminate
    unset -f check_root_user
}

check_binaries() {
    local -a missing_binaries=() ; local -i i
    which which &> /dev/null || terminate "which"
    for (( i=1; $# + 1 - i; i++ )); do
        [[ $i -eq $# ]] && [[ ${!i} = u ]] && continue
        which ${!i} &> /dev/null || missing_binaries+=(${!i})
    done
    ! (( ${#missing_binaries[*]} )) || terminate "${missing_binaries[@]}"
    [[ ${!#} = u ]] && unset -f check_binaries
}

check_conflicting_params() {
    local illegal
    [ -n "${PURGE}" -a -n "${PAX}" ] && {
        illegal="-p|--purge-all, -P[version]|--purge-all-except[=version]"
        terminate "${illegal}" ; }
    [ -n "${REPLACE}" -a -n "${INSTALL}" ] && {
        illegal="-r[version]|--replace-all-with[=version], "
        illegal+="-i[version]|--install[=version]"
        terminate "${illegal}" ; }
    [ -n "${REPLACE}" -a -n "${PURGE}" ] && {
        illegal="-r[version]|--replace-all-with[=version], -p|--purge-all"
        terminate "${illegal}" ; }
    [ -n "${REPLACE}" -a -n "${PAX}" ] && {
        illegal="-r[version]|--replace-all-with[=version], "
        illegal+="-P[version]|--purge-all-except[=version]"
        terminate "${illegal}" ; }
}

check_param_args() {
    case "$1" in
        'i'|'P'|'r')
            [[ "$2" =~ ^([[:digit:]]+\.)*[[:digit:]]+$ ]] || terminate "$2"
        ;;&
        'i'|'r')
            install+=("$2")
        ;;&
        'P'|'r')
            keep+=("$2")
        ;;
    esac
}

define_valid_option_params() {
    temp=$(getopt --options 'hi::pP::r::' \
        --longoptions 'help,install::,purge-all,purge-all-except::' \
        --longoptions 'replace-all-with::' \
        --name $(basename "${0}") -- "${@:1:$#-1}")
    getopt_exit_status=$?
    unset -f define_valid_option_params
}

process_param_args_arrays() {
    (( ${#keep[@]} )) && declare -ag keep_versions=($(
        printf "%s\n" "${keep[@]}" | sort --numeric-sort --unique))
    (( ${#install[@]} )) && declare -ag install_versions=($(
        printf "%s\n" "${install[@]}" | sort --numeric-sort --unique))
    unset -f process_param_args_arrays
}

check_params() {
    local temp ; local -r USAGE="${!#}" ; local -i getopt_exit_status
    local -a keep install
    check_binaries "getopt" ; define_valid_option_params $*
    (( ${getopt_exit_status} )) && terminate ${getopt_exit_status}
    eval set -- "${temp}" ; unset temp getopt_exit_status
    while true; do
        case "$1" in
            '-h'|'--help')
                eval ${USAGE}
                exit 0
            ;;
            '-i'|'--install')
                [ -z "${INSTALL}" ] && declare -gr INSTALL="yes" ; shift
                [ -z "$1" ] && install+=("stable") || check_param_args "i" "$1"
                shift
            ;;
            '-p'|'--purge-all')
                [ -z "${PURGE}" ] && declare -gr PURGE="yes" ; shift
            ;;
            '-P'|'--purge-all-except')
                [ -z "${PAX}" ] && declare -gr PAX="yes" ; shift
                [ -z "$1" ] && keep+=("highest") || check_param_args "P" "$1"
                shift
            ;;
            '-r'|'--replace-all-with')
                [ -z "${REPLACE}" ] && declare -gr REPLACE="yes" ; shift
                [ -z "$1" ] && install+=("stable") && keep+=("stable") ||
                    check_param_args "r" "$1"
                shift
            ;;
            '--')
                shift ; break
            ;;
        esac
        check_conflicting_params
    done
    (( $# )) && { eval ${USAGE} >&2 && exit 1; }
    [ -z "${INSTALL}" -a -z "${PURGE}" -a -z "${PAX}" -a -z "${REPLACE}" ] &&
        declare -gr REPLACE="yes" && keep+=("stable") && install+=("stable")
    process_param_args_arrays
    unset -f check_conflicting_params check_param_args check_params
}

check_install_versions() {
    local -i i response ; local -a bad_versions bad_indices
    [ "${install_versions[0]}" = "stable" ] && install_versions[0]=$2 &&
        install_versions=($(printf "%s\n" "${install_versions[@]}" |
            sort --numeric-sort --unique))
    for (( i=0; ${#install_versions[@]} - i; i++ )); do
        response=$(curl --head --output /dev/null --retry 5 --silent \
            --write-out "%{http_code}\n" "${1}${install_versions[i]}/")
        [[ ${response} =~ 2[[:digit:]]{2} ]] || {
            bad_versions+=(${install_versions[i]}) ; bad_indices+=($i) ; }
    done
    (( ${#bad_versions[@]} )) && print_invalid_versions "${bad_versions[@]}"
    for i in ${bad_indices[@]}; do
        unset install_versions[$i]
    done
}
