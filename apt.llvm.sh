#!/usr/bin/env bash

# Copyright © 2025 Verbosely.
# All rights reserved.

usage() {
    cat <<- USAGE
		Usage: ./$(basename "${0}") [OPTION...]

		Summary:
		    Purge and/or install LLVM packages for Debian-based Linux.

		    The following LLVM tools will be purged and/or installed:
		    clang: an "LLVM native" C/C++/Objective-C compiler
		    lldb: a C/C++/Objective-C debugger
		    lld: the LLVM linker

		    Refer here for more info: https://llvm.org

		Package management options:
		    -p | --purge    purge all existing LLVM packages
		    -i | --install  install LLVM packages for the current stable version
		    -r | --replace  purge all existing LLVM packages, then install the
		                    current stable version; equivalent to running
		                    "./$(basename "${0}") -pi" (default)

		Other options:
		    -h | --help     display this help text, and exit
	USAGE
    unset -f usage
}

needed_binaries() {
    echo "apt-get dpkg getopt gpg grep lsb_release sed wget"
    unset -f needed_binaries
}

define_constants() {
    declare -gr STABLE_VERSION=19
    declare -agr LLVM_PACKAGES=(clang)
    declare -gr ARCH=$(dpkg --print-architecture)
    declare -gr BASE_URL="https://apt.llvm.org"
    declare -gr PPA_DIR="/etc/apt/sources.list.d/"
    declare -gr GPG_DIR="/usr/share/keyrings/"
    declare -gr GPG_PATH="/llvm-snapshot.gpg.key"
    declare -gr LLVM_GPG_BASENAME="llvm.gpg"
    [[ $(lsb_release --codename) =~ [[:blank:]]([[:alpha:]]+)$ ]]
    declare -gr CODENAME="${BASH_REMATCH[1]}"
    declare -gr LLVM_SOURCE_FILE="llvm.list"
    declare -gr TYPE="deb"
    declare -gr OPTIONS="[arch=${ARCH} signed-by=${GPG_DIR}${LLVM_GPG_BASENAME}]"
    declare -gr URI="${BASE_URL}/${CODENAME}/"
    declare -gr SUITE="llvm-toolchain-${CODENAME}-${STABLE_VERSION}"
    declare -gr COMPONENTS="main"
    declare -gr REPO="${TYPE} ${OPTIONS} ${URI} ${SUITE} ${COMPONENTS}"
    unset -f define_constants
}

download_public_key() {
    wget --quiet --output-document="${GPG_DIR}${LLVM_GPG_BASENAME}" \
            ${BASE_URL}${GPG_PATH} &&
        cat ${GPG_DIR}${LLVM_GPG_BASENAME} |
            gpg --yes --output "${GPG_DIR}${LLVM_GPG_BASENAME}" --dearmor &&
        chmod 0644 ${GPG_DIR}${LLVM_GPG_BASENAME} &&
        print_public_key_progress "no key" "${BASE_URL}${GPG_PATH}" \
            "${GPG_DIR}" ||
        {
            local -ir WGET_EXIT_STATUS=$? &&
            rm ${GPG_DIR}${LLVM_GPG_BASENAME} &&
            terminate "${BASE_URL}${GPG_PATH}" "${WGET_EXIT_STATUS}"
        }
}

apt_get() {
    case "${FUNCNAME[1]}" in
        'install_llvm')
            print_apt_progress "update"
            apt-get --quiet update || terminate "update" $?
            print_apt_progress "install" "${INSTALL_PKGS[*]}"
            apt-get --quiet --yes install "${INSTALL_PKGS[@]}" ||
                terminate "install" $?
            print_apt_progress "autoremove"; apt-get --quiet --yes autoremove
        ;;
        'purge_llvm')
            print_apt_progress "purge" "${PURGE_PKGS[*]}"
            apt-get --quiet --yes purge "${PURGE_PKGS[@]}"
            print_apt_progress "autoremove"; apt-get --quiet --yes autoremove
            print_apt_progress "autoclean"; apt-get --quiet --yes autoclean
        ;;
    esac
}

install_llvm() {
    local -ar INSTALL_PKGS=($(echo "${LLVM_PACKAGES[@]/%/-${STABLE_VERSION}}"))
    if [ -f "${GPG_DIR}${LLVM_GPG_BASENAME}" ]; then
        print_public_key_progress "key found" "${GPG_DIR}"
    else
        download_public_key
    fi
    grep --quiet --no-messages --fixed-strings "${REPO}" \
            "${PPA_DIR}${LLVM_SOURCE_FILE}" &&
        print_source_list_progress "source found" \
            "${PPA_DIR}${LLVM_SOURCE_FILE}" ||
        {
            bash -c "echo ${REPO} >> ${PPA_DIR}${LLVM_SOURCE_FILE}"
            print_source_list_progress "no source" \
                "${PPA_DIR}${LLVM_SOURCE_FILE}"
        }
    apt_get
}

purge_llvm() {
    local -r REGEXP=$(IFS='|'
        echo "^((${LLVM_PACKAGES[*]})-[[:digit:]]+)[[:blank:]]+install$")
    local -ar PURGE_PKGS=($(dpkg --get-selections |
        sed --quiet --regexp-extended "s/${REGEXP}/\1/p"))
    [ -f "${PPA_DIR}${LLVM_SOURCE_FILE}" ] &&
        rm ${PPA_DIR}${LLVM_SOURCE_FILE} &&
        print_source_list_progress "remove source" \
            "${PPA_DIR}${LLVM_SOURCE_FILE}"
    [ -f "${GPG_DIR}${LLVM_GPG_BASENAME}" ] &&
        rm ${GPG_DIR}${LLVM_GPG_BASENAME} &&
        print_public_key_progress "remove key" "${GPG_DIR}"
    ! (( ${#PURGE_PKGS[@]} )) || apt_get
}

main() {
    . "$(dirname ${BASH_SOURCE[0]})/shared/checks.sh"
    check_binaries $(needed_binaries) ; check_params $* "usage"
    check_root_user; define_constants
    if [ ${INSTALL} ]; then
        [ -z ${PURGE} ] && install_llvm || { purge_llvm && install_llvm; }
    else
        purge_llvm; [ ${PURGE} ] || install_llvm
    fi
}

main $*
