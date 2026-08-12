# The one place PATH is set, for login shells of any kind and -- via ~/.bashrc
# pulling this file in -- for non-login ones. Kept sh-compatible, since a
# display manager builds the session environment by reading it with /bin/sh.

# Move a directory to the front of PATH, dropping any occurrence it already
# has. Both are needed: macOS path_helper re-appends existing entries behind
# the system ones on every login, so a plain prepend leaves a stale duplicate
# and a skip-if-present check would leave the entry demoted behind /usr/bin.
prepend_path() {
    _rest=""
    _ifs="${IFS}"
    IFS=:
    for _dir in ${PATH}; do
        [ "${_dir}" = "$1" ] || _rest="${_rest:+${_rest}:}${_dir}"
    done
    IFS="${_ifs}"
    PATH="$1${_rest:+:${_rest}}"
    unset _rest _ifs _dir
}

prepend_path "/opt/homebrew/bin"
prepend_path "${HOME}/.cargo/bin"
prepend_path "${HOME}/.local/bin"
export PATH
unset -f prepend_path

# An interactive login shell reads this file instead of ~/.bashrc, so hand it
# the interactive configuration. The login test is what stops the two files
# from sourcing each other: a non-login shell arrives here from ~/.bashrc.
if [ -n "${BASH_VERSION}" ] && shopt -q login_shell; then
    case $- in
        *i*) source "${HOME}/.bashrc" ;;
    esac
fi
