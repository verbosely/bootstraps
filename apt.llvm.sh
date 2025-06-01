#!/usr/bin/env bash

# Copyright © 2025 Verbosely.
# All rights reserved.

# This program purges and/or installs LLVM packages via APT for
# Debian-based Linux. During installation, the LLVM source for
# Debian-based packages and the OpenPGP public key are added to
# /etc/apt/sources.list.d/ and /usr/share/keyrings/ directories,
# respectively, if they are not already located there. During purging,
# the LLVM source and public key are removed, and APT storage areas
# (/var/cache/apt/archives/ and /var/lib/apt/lists/) are cleaned of
# obsolete files.

usage() {
    cat <<- USAGE
		Usage: ./$(basename "${0}") [OPTION]...

		Summary:
		    Purge and/or install LLVM packages via APT for Debian-based Linux.

		    The following LLVM packages and their dependencies will be purged
		    and/or installed:

		    clang: an "LLVM native" C/C++/Objective-C compiler
		    llvm: modular compiler and toolchain technologies

		    Refer here for more info: https://llvm.org

		Package management options:
		    -p, --purge-all
		            purge all existing LLVM packages
		    -P[version], --purge-all-except[=version]
		            purge all existing LLVM packages except those of the given
		            version; use multiple times to specify multiple versions to
		            keep; when a version is not specified, keep the highest
		            version found
		    -i[version], --install[=version]
		            install LLVM packages for the given version, or for the
		            current stable version if no version is specified; use
		            multiple times to specify multiple versions to install
		    -r[version], --replace-all-with[=version]
		            install the given version of LLVM packages, then purge all
		            other existing versions; use multiple times to specify
		            multiple versions to install and to keep after purging; when
		            a version is not specified, install the current stable
		            version; equivalent to running
		            "./$(basename "${0}") -i[version_a] -P[version_a]" (default)

		Other options:
		    -h | --help
		            display this help text, and exit
	USAGE
    unset -f usage
}

needed_binaries() {
    echo "apt-get dpkg file sed"
    [ -n "${INSTALL}${REPLACE}" ] && echo "curl gpg grep lsb_release"
    #[ -n "${PAX}${PURGE}${REPLACE}" ] && echo "sed"
    unset -f needed_binaries
}

define_constants() {
    declare -gr STABLE_VERSION=19
    declare -agr LLVM_PACKAGES=(clang llvm)
    declare -gr GPG_DIR="/usr/share/keyrings/"
    declare -gr LLVM_GPG_BASENAME="llvm.gpg"
    declare -gr PPA_DIR="/etc/apt/sources.list.d/"
    declare -gr LLVM_SOURCE_FILE="llvm.list"
    [ -n "${INSTALL}${REPLACE}" ] && {
        declare -gr TYPE="deb"
        declare -gr ARCH=$(dpkg --print-architecture)
        declare -gr OPTIONS="\
            [arch=${ARCH} signed-by=${GPG_DIR}${LLVM_GPG_BASENAME}]"
        declare -gr BASE_URL="https://apt.llvm.org"
        [[ $(lsb_release --codename) =~ [[:blank:]]([[:alpha:]]+)$ ]]
        declare -gr CODENAME="${BASH_REMATCH[1]}"
        declare -gr URI="${BASE_URL}/${CODENAME}/"
        declare -gr SUITE="llvm-toolchain-${CODENAME}-"
        declare -gr COMPONENTS="main"
        declare -gr REPO="${TYPE} ${OPTIONS} ${URI} ${SUITE} ${COMPONENTS}"
        declare -gr GPG_PATH="/llvm-snapshot.gpg.key"
    }
    unset -f define_constants
}

apt_get() {
    case "${FUNCNAME[1]}" in
        'install_llvm')
            print_apt_progress "update"
            apt-get --quiet update || terminate "update" $?
            print_apt_progress "install" "${INSTALL_PKGS[*]}"
            apt-get --yes install "${INSTALL_PKGS[@]}" || terminate "install" $?
            print_apt_progress "autoremove"; apt-get --quiet --yes autoremove
        ;;
        'purge_llvm')
            print_apt_progress "purge" "${PURGE_PKGS[*]}"
            apt-get --quiet --yes purge "${PURGE_PKGS[@]}"
            print_apt_progress "autoremove"; apt-get --quiet --yes autoremove
            print_apt_progress "autoclean"; apt-get --quiet --yes autoclean
            print_apt_progress "update"
            apt-get --quiet update || terminate "update" $?
        ;;
    esac
}

install_llvm() {
    check_duplicate_versions "${STABLE_VERSION}"
    validate_install_versions "${URI}dists/${SUITE}" "${install_versions[@]}"
    unset install_versions ; (( ${#INSTALL_VERSIONS[@]} )) || return 0
    local -ar INSTALL_PKGS=($(
        for ver in ${INSTALL_VERSIONS[@]}; do
            echo "${LLVM_PACKAGES[@]/%/-${ver}}"
        done))
    declare -p INSTALL_PKGS
    check_gpg_key "${GPG_DIR}${LLVM_GPG_BASENAME}" ||
        get_gpg_key "${GPG_DIR}${LLVM_GPG_BASENAME}" "${BASE_URL}${GPG_PATH}"
#    grep --quiet --no-messages --fixed-strings "${REPO}" \
#            "${PPA_DIR}${LLVM_SOURCE_FILE}" &&
#        print_source_list_progress "source found" \
#            "${PPA_DIR}${LLVM_SOURCE_FILE}" ||
#        {
#            bash -c "echo ${REPO} >> ${PPA_DIR}${LLVM_SOURCE_FILE}"
#            print_source_list_progress "no source" \
#                "${PPA_DIR}${LLVM_SOURCE_FILE}"
#        }
#    apt_get
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

unset_functions() {
    [ -n "${INSTALL}" -a -z "${PAX}${PURGE}" ] && unset -f purge_llvm
    [ -z "${INSTALL}${REPLACE}" ] && unset -f install_llvm
    unset -f unset_functions
}

main() {
    . "$(dirname ${BASH_SOURCE[0]})/shared/checks.sh"
    . "$(dirname ${BASH_SOURCE[0]})/shared/io_utils.sh"
    . "$(dirname ${BASH_SOURCE[0]})/shared/term_output.sh"
    check_params $* "usage" ; declare -p keep_versions install_versions ; check_root_user
    check_binaries $(needed_binaries) u
    print_program_lifecycle "start" "${0}" ; unset_functions ; define_constants
    [ -n "${INSTALL}" -a -z "${PAX}${PURGE}" ] && install_llvm
    #[ -n "${INSTALL}" -a -n "${PURGE}" -o -n "${REPLACE}" ] &&
    #    purge_llvm && install_llvm
    #[ -z "${INSTALL}" -a -n "${PURGE}" ] && purge_llvm
    print_program_lifecycle "end" "${0}"
}

main $*
