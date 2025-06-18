# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/term_output.bash"

get_gpg_key() {
    local error_msg exit_code http_code
    send_http_request "GET" "$1" "$2"
    (( exit_code )) && rm --force "$1" &&
        terminate "curl" "$exit_code" "$2" "$error_msg"
    [[ ${http_code} =~ [^2][[:digit:]]{2} ]] && rm --force "$1" &&
        terminate "http" "$http_code" "$2"
    gpg --yes --output "$1" --dearmor < <(cat "$1")
    chmod 0644 "$1"
    print_public_key_progress "added" "$2" "$(dirname "$1")/"
    unset -f get_gpg_key
}

send_http_request() {
    local -a options=("--retry" "5")
    options+=("--silent" "--write-out" "%{errormsg}|%{exitcode}|%{http_code}")
    case "$1" in
        'HEAD')
            local -a head_options=("--head" "--output" "/dev/null")
            options=("${head_options[@]}" "${options[@]}") ;;
        'GET')
            local -a get_options=("--output" "$2")
            options=("${get_options[@]}" "${options[@]}") ;;
    esac
    IFS='|' read -d '' -r error_msg exit_code http_code < <(
        curl "${options[@]}" "${!#}")
    (( exit_code )) && ! [ -v err_code_msgs["$exit_code"] ] &&
        err_code_msgs["$exit_code"]="$error_msg"
}
