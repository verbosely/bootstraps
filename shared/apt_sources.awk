# Copyright © 2025 Verbosely.
# All rights reserved.

@include "inplace"

function enable_apt_sources(    i) {
    for (i in sources_regex) {
        if ($0 ~ "^[[:blank:]]*"sources_regex[i]"[[:blank:]]*$") {
            print
            enabled[FNR] = i - 1
            delete sources[i] ; delete sources_regex[i] ; next
        }
        if ($0 ~ "^[[:blank:]]*#.*"sources_regex[i]"[[:blank:]]*$") {
            $0 = gensub(".+("sources_regex[i]").*", "\\1", "g")
            print
            disabled[FNR] = i - 1
            delete sources[i] ; delete sources_regex[i] ; next
        }
    }
    print
}

function add_apt_sources(    i) {
    for (i in sources) {
        FNR++ ; absent[FNR] = i - 1 ; print sources[i]
    }
}

function print_indices(    i, j) {
    j = 0
    for (i in enabled) {
        if (!j) { j++ ; printf "Enabled:" }
        printf " %s", enabled[i]
    }
    if (j) { print "" ; j = 0 }
    for (i in disabled) {
        if (!j) { j++ ; printf "Disabled:" }
        printf " %s",  disabled[i]
    }
    if (j) { print "" ; j = 0 }
    for (i in absent) {
        if (!j) { j++ ; printf "Absent:" }
        printf " %s", absent[i]
    }
}

BEGIN {
    sources_str = gensub(/(.+)@$/, "\\1", "g", sources_str)
    split(sources_str, sources, "@")
    sources_str = gensub(/([].[])/, "\\\\\\1", "g", sources_str)
    split(sources_str, sources_regex, "@")
}

{ enable_apt_sources() }

ENDFILE { add_apt_sources() }

END { print_indices() }
