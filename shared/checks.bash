# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/io_utils.bash"
. "$(dirname ${BASH_SOURCE[0]})/params_utils.bash"
. "$(dirname ${BASH_SOURCE[0]})/term_output.bash"

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
        '-i'|'--install'|'-P'|'--purge-all-except'|'-r'|'--replace-all-with')
            [[ "$2" =~ ^(([[:digit:]]+\.)*[[:digit:]]+)?$ ]] || terminate "$2"
        ;;&
        '-i'|'--install')
            [ -z "$2" ] && install_versions+=("stable") ||
                install_versions+=("$2");;
        '-P'|'--purge-all-except')
            [ -z "$2" ] && keep_versions+=("highest") || keep_versions+=("$2");;
        '-r'|'--replace-all-with')
            [ -z "$2" ] && install_versions+=("stable") &&
                keep_versions+=("stable") ||
                { install_versions+=("$2") && keep_versions+=("$2") ; };;
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

check_params() {
    local temp ; local -r USAGE="${!#}" ; local -i getopt_exit_status
    local -a keep_versions install_versions
    check_binaries "getopt" ; define_valid_option_params $*
    (( ${getopt_exit_status} )) && terminate ${getopt_exit_status}
    eval set -- "${temp}" ; unset temp getopt_exit_status
    while true; do
        case "$1" in
            '-h'|'--help')
                eval ${USAGE} ; exit 0;;
            '-i'|'--install')
                [ -z "${INSTALL}" ] && declare -gr INSTALL="yes";;&
            '-p'|'--purge-all')
                [ -z "${PURGE}" ] && declare -gr PURGE="yes" ; shift;;
            '-P'|'--purge-all-except')
                [ -z "${PAX}" ] && declare -gr PAX="yes";;&
            '-r'|'--replace-all-with')
                [ -z "${REPLACE}" ] && declare -gr REPLACE="yes";;&
            '-i'|'--install'|'-P'|'--purge-all-except'|\
                    '-r'|'--replace-all-with')
                check_param_args "$1" "$2"
                shift 2;;
            '--')
                shift ; break;;
        esac ; check_conflicting_params
    done ; (( $# )) && eval ${USAGE} >&2 && exit 1
    [ -z "${INSTALL}${PURGE}${PAX}${REPLACE}" ] && declare -gr REPLACE="yes" &&
        check_param_args "-r"
    declare -ag keep_versions=($(sort_and_filter "${keep_versions[@]}"))
    declare -ag install_versions=($(sort_and_filter "${install_versions[@]}"))
    unset -f check_conflicting_params check_param_args check_params
}

check_duplicate_versions() {
    [ "${install_versions[0]}" = "stable" ] && install_versions[0]=$1 &&
        install_versions=($(sort_and_filter "${install_versions[@]}"))
}

check_install_versions() {
    local -i i ; local error_msg exit_code http_code ; local -a success
    local -A curl_errors err_code_msgs http_errors
    for (( i=2; $# + 1 - i; i++ )); do
        send_http_request "HEAD" "${1}${!i}/"
        if (( exit_code )); then
            curl_errors["$exit_code"]="$(
                params_to_csv_string "${curl_errors["$exit_code"]}" "${!i}")"
        else
            [[ ${http_code} =~ 2[[:digit:]]{2} ]] && success+=(${!i}) ||
                http_errors["$http_code"]=$(
                    params_to_csv_string "${http_errors["$http_code"]}" "${!i}")
        fi
    done
    (( ${#curl_errors[@]} )) && {
        for exit_code in ${!curl_errors[@]}; do
            print_invalid_versions "curl" "$exit_code" \
                "${curl_errors["$exit_code"]}" "${err_code_msgs["$exit_code"]}"
        done ; }
    (( ${#http_errors[@]} )) && {
        for http_code in ${!http_errors[@]}; do
            print_invalid_versions "http" "$http_code" \
                "${http_errors["$http_code"]}"
        done ; }
    declare -agr INSTALL_VERSIONS=("${success[@]}")
    unset -f check_install_versions
}

check_gpg_key() {
    [ -f "$1" ] &&
        [ "$(file --brief --mime-type "$1")" = "application/octet-stream" ] &&
        print_public_key_progress "found" "$(dirname "$1")/"
}
