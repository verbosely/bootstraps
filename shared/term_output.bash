# Copyright © 2025 Verbosely.
# All rights reserved.

. "$(dirname ${BASH_SOURCE[0]})/params_utils.bash"

# Functions for crafting messages corresponding to various common phases of
# Linux package management and for writing to standard output and standard
# error.

########################################################################
# Print a colorized message to stdout or stderr.
# 
# Screen operations are performed by manipulating the terminfo database
# via terminal-independent ncurses routines.
#
# Arguments:
#   1: An integer, which indicates to which data stream to send the
#      message: zero for stdout, non-zero for stderr.
#   2: The foreground color for the message. The color may be a name or
#      an integer. If an integer, it will be the argument to the
#      "setaf" terminal capability. 
#   3: A message to print.
#
# Outputs:
#   Writes $3 to stdout if $1 is zero.
#   Writes $3 to stderr if $1 is non-zero.
#
# Returns:
#   0
########################################################################
print_message() {
    local -r MESSAGE="\n${3}"
    local -i foreground_color=7
    case "${2}" in
        'black')
            foreground_color=0
        ;;
        'red')
            foreground_color=1
        ;;
        'green')
            foreground_color=2
        ;;
        'yellow')
            foreground_color=3
        ;;
        'blue')
            foreground_color=4
        ;;
        'magenta')
            foreground_color=5
        ;;
        'cyan')
            foreground_color=6
        ;;
        'white')
            foreground_color=7
        ;;
        'gold')
            foreground_color=11
        ;;
        [[:digit:]]*)
            foreground_color=${2}
        ;;
    esac
    tput sgr0 2> /dev/null                          # Turn off all attributes
    (( ${1} )) && tput rev 2> /dev/null             # Turn on reverse video mode
    tput bold 2> /dev/null                          # Turn on bold mode
    tput setaf ${foreground_color} 2> /dev/null     # Set foreground color
    (( ${1} )) && echo -e "${MESSAGE}" >&2 || echo -e "${MESSAGE}"
    tput sgr0 2> /dev/null                          # Turn off all attributes
    return 0
}

terminate() {
    local error_msg ; local -i exit_status=1
    case "${FUNCNAME[1]}" in
        'check_binaries')
            error_msg="You must install the following tools "
            error_msg+="to run this script: $(params_to_csv_string ${@})" ;;
        'check_conflicting_params')
            error_msg="Illegal combination of options: ${1}" ;;
        'check_root_user')
            error_msg="This script must be run as root!" ;;
        'check_params')
            error_msg="Terminating..."
            exit_status=${1} ;;
        'check_param_args')
            error_msg="Invalid version: '${1}'" ;;
        'get_gpg_key')
            case "$1" in
                'curl')
                    error_msg="Curl returned an exit status of $2 "
                    error_msg+="when attempting to download the OpenPGP "
                    error_msg+="public key from $3"
                    error_msg+="\nCurl error message: \"${4}\"" ;;
                'http')
                    error_msg="An HTTP $2 response was returned during an "
                    error_msg+="attempt to download the OpenPGP public key "
                    error_msg+="from ${3}\nTerminating..." ;;
            esac ;;
        'download_source')
            error_msg="Could not download ${1} from ${2}"
            error_msg+="\nTerminating..."
            exit_status=${3} ;;
        'apt_get')
            error_msg="\"apt-get ${1}\" failed!\nTerminating..."
            exit_status=${2} ;;
        'check_distributor_id')
            error_msg="This script is not compatible with the "
            error_msg+="following distribution: ${1}" ;;
        'check_matching_package_versions')
            error_msg="Could not find matching versions for the "
            error_msg+="following packages: ${*:1}\nTerminating..." ;;
        *)
            case "${1}" in
                'configure')
                    error_msg="Something went wrong during the configuration "
                    error_msg+="of ${2} source code!\nTerminating..."
                    exit_status=${3} ;;
                'make')
                    error_msg="Something went wrong during \"make\"!"
                    error_msg+="\nTerminating..."
                    exit_status=${2} ;;
                'make test')
                    error_msg="Something went wrong during \"make test\"!"
                    error_msg+="\nTerminating..."
                    exit_status=${2} ;;
            esac ;;
    esac
    print_message 1 "red" "${error_msg}"
    exit ${exit_status}
}

print_apt_progress() {
    local progress_msg="Running apt-get ${1}..."
    case "${1}" in
        'build-dep')
            progress_msg+="\nSatisfying build dependencies "
            progress_msg+="for the following packages: ${2}"
        ;;
        'install')
            progress_msg+="\nInstalling the following packages: ${2}"
        ;;
        'purge')
            progress_msg+="\nPurging the following packages: ${2}"
        ;;
    esac
    print_message 0 "cyan" "${progress_msg}"
}

print_source_list_progress() {
    local progress_msg
    case "${1}" in
        'source found')
            progress_msg="Found entry in ${2}"
        ;;
        'no source')
            progress_msg="Added entry to ${2}"
        ;;
        'remove source')
            progress_msg="Removed ${2}"
        ;;
        'enable deb-src')
            progress_msg="Found disabled deb-src type entry in ${2}"
            progress_msg+="\nEnabling to fetch source archives..."
        ;;
        'deb-src')
            progress_msg="Found enabled deb-src type entry in ${2}"
        ;;
        'no deb-src')
            progress_msg="No deb-src type entry found in ${2}"
            progress_msg+="\nAdding to fetch source archives..."
        ;;
        'restore deb-src')
            progress_msg="Restoring deb-src type entry to "
            progress_msg+="original state in ${2}"
        ;;
    esac
    print_message 0 "cyan" "${progress_msg}"
}

print_public_key_progress() {
    local progress_msg
    case "${1}" in
        'found')
            progress_msg="Found OpenPGP public key in ${2}"
        ;;
        'added')
            progress_msg="Added OpenPGP public key from ${2} to ${3}"
        ;;
        'remove key')
            progress_msg="Removed OpenPGP public key from ${2}"
        ;;
    esac
    print_message 0 "cyan" "${progress_msg}"
}

print_build_progress() {
    local progress_msg
    case "${1}" in
        'fetch')
            progress_msg="Fetching ${2} from ${3}"
        ;;
        'extract')
            progress_msg="Uncompressing ${2}, and extracting files..."
        ;;
        'configure')
            progress_msg="Running configuration script for ${2} source code..."
        ;;
        'make')
            progress_msg="Running GNU \"make\" to build ${2} executable "
            progress_msg+="and extension modules..."
        ;;
        'make test')
            progress_msg="Running Makefile test suite..."
        ;;
        'make altinstall'|'make install')
            progress_msg="Installing built files in ${2}"
        ;;
    esac
    print_message 0 "cyan" "${progress_msg}"
}

print_program_lifecycle() {
    case "${1}" in
        'start')
            print_message 0 "blue" "Running $(basename "${2}")..."
        ;;
        'end')
            print_message 0 "blue" "$(basename "${2}") completed."
        ;;
    esac
}

print_invalid_versions() {
    local msg
    case "$1" in
        'curl')
            msg="Curl returned an exit status of $2 when attempting to fetch "
            msg+="HTTP headers for the following versions: ${3}.\n"
            msg+="These versions will not be installed."
            msg+="\nCurl error message: \"${4}\""
        ;;
        'http')
            msg="The following versions returned HTTP $2 responses "
            msg+="and will not be installed: $3"
        ;;
    esac
    print_message 1 "yellow" "$msg"
}
