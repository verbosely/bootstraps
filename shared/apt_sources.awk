# Copyright © 2025 Verbosely.
# All rights reserved.

@include "inplace"

function check_apt_sources(    i) {
    for (i in sources_regex) {
        if (is_enabled(sources_regex[i]))
            handle_found_apt_source(enabled, i)
        if (is_disabled(sources_regex[i])) {
            $0 = gensub(".+("sources_regex[i]").*", "\\1", "g")
            handle_found_apt_source(disabled, i)
        }
    }
    print
}

function handle_found_apt_source(array, i) {
    print
    array[FNR] = i - 1
    delete sources[i]
    delete sources_regex[i]
    next
}

function is_enabled(apt_source) {
    if ($0 ~ "^[[:blank:]]*"apt_source"[[:blank:]]*$")
        return 1
}

function is_disabled(apt_source) {
    if ($0 ~ "^[[:blank:]]*#.*"apt_source"[[:blank:]]*$")
        return 1
}

function add_apt_sources(    i) {
    for (i in sources) {
        FNR++
        absent[FNR] = i - 1
        print sources[i]
    }
}

function print_array_elements(array,    i, j) {
    for (i in array) {
        if (!j) {
            j++
            printf "%s", array[i]
        }
        else
            printf " %s",  array[i]
    }
}

BEGIN {
    PROCINFO["sorted_in"] = "@val_type_asc"
    sources_str = gensub(/(.+)@$/, "\\1", "g", sources_str)
    split(sources_str, sources, "@")
    sources_str = gensub(/([].[])/, "\\\\\\1", "g", sources_str)
    split(sources_str, sources_regex, "@")
}

{ check_apt_sources() }

ENDFILE { add_apt_sources() }

END {
    print_array_elements(enabled)
    printf ":"
    print_array_elements(disabled)
    printf ":"
    print_array_elements(absent)
}
