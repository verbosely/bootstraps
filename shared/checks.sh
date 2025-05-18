# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/notifications.sh"

check_root_user() {
    ! (( ${EUID} )) || terminate
    unset -f check_root_user
}

check_binaries() {
    local -a missing_binaries=()
    which which &> /dev/null || terminate "which"
    for (( i=1; $# + 1 - i; i++ )); do
        [[ $i -eq $# ]] && [[ ${!i} = u ]] && continue
        which ${!i} &> /dev/null || missing_binaries+=(${!i})
    done
    ! (( ${#missing_binaries[*]} )) || terminate "${missing_binaries[*]}"
    [[ ${!#} = u ]] && unset -f check_binaries
}

check_conflicting_params() {
    local conflicting_opts
    if [ ${REPLACE} ]; then {
        [ ${INSTALL} ] && conflicting_opts="-r|--replace, -i|--install"
    } || {
        [ -z ${PURGE} ] || conflicting_opts="-r|--replace, -p|--purge-all"
    }
    fi
    [ -z "${conflicting_opts}" ] || terminate "${conflicting_opts}"
}

check_param_args() {
    case "$1" in
        'pax')
            [[ "$2" =~ ^([[:digit:]]+\.)*[[:digit:]]+$ ]] &&
                keep_versions+=("$2") || terminate "$2"
        ;;
    esac
}

check_params() {
    local temp ; local -a keep_versions ; local -r USAGE=${!#}
    check_binaries getopt
    temp=$(getopt --options 'hipP::r' \
        --longoptions 'help,install,purge-all,purge-all-except::,replace' \
        --name $(basename "${0}") -- "${@:1:$#-1}")
    local -i getopt_exit_status=$?
    echo $temp
    (( ${getopt_exit_status} )) && terminate ${getopt_exit_status}
    eval set -- "${temp}" ; unset temp
    while true; do
        case "$1" in
            '-h'|'--help')
                eval ${USAGE}
                exit 0
            ;;
            '-i'|'--install')
                [ -z "${INSTALL}" ] && declare -gr INSTALL="yes"
                shift
            ;;
            '-p'|'--purge-all')
                [ -z "${PURGE}" ] && declare -gr PURGE="yes"
                shift
            ;;
            '-P'|'--purge-all-except')
                [ -z "${PAX}" ] && declare -gr PAX="yes"
                shift
                [ -z "$1" ] && keep_versions+=("-") ||
                    check_param_args "pax" "$1"
                shift
            ;;
            '-r'|'--replace')
                [ -z "${REPLACE}" ] && declare -gr REPLACE="yes"
                shift
            ;;
            '--')
                shift
                break
            ;;
        esac
        check_conflicting_params
    done
    ! (( $# )) || { eval ${USAGE} >&2 && exit 1; }
    declare -agr KEEP_VERSIONS=($(
        printf "%s\n" "${keep_versions[@]}" | sort --numeric-sort --unique))
    [ -z "${INSTALL}" -a -z "${PURGE}" -a -z "${REPLACE}" ] &&
        declare -gr REPLACE="yes"
    unset -f check_conflicting_params check_param_args check_params
}
