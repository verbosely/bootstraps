# Copyright © 2025 Verbosely.
# All rights reserved.

params_to_csv_string() {
    local -i i ; local str
    for (( i=1; $# + 1 - i; i++ )); do
        [ -n "${!i}" ] && {
            [ -z "$str" ] && str="${!i}" || str+=", ${!i}"
        }
    done
    [ -n "$str" ] && echo "$str"
}

sort_and_filter() {
    printf "%s\n" "${@}" | sort --numeric-sort --unique
}
