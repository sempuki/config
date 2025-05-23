# .bashrc
if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# Only configure interactive shells.
case $- in
    *i*) ;;
      *) return;;
esac

# Shell options
shopt -s cdspell       # auto-correct errors on cd
shopt -s histappend    # append not truncate
shopt -s hostcomplete  # complete after '@'
shopt -s extglob       # extending globbing

# Variables
export LD_LIBRARY_PATH=/usr/local/lib
export LIBRARY_PATH=/usr/local/lib
export CPATH=/usr/local/include

export HISTCONTROL=ignoreboth
export HISTFILESIZE=100000
export HISTSIZE=100000

export VIM_COMMAND='nvim'
export DIFF_COMMAND='git diff --'
export FIND_COMMAND='find'
export GREP_COMMAND='grep -Ins --color --exclude=*.tags --exclude-dir={.git,.svn}'
export GIT_GREP_COMMAND='git grep'
export LS_COMMAND='ls -lF --color'

# Aliases
function le() {
    less -R "$@"
}
function d() {
    dirs -p "$@"
}
function pd() {
    pushd "$@" > /dev/null
}
function p() {
    popd "$@" > /dev/null
}
function v() {
    ${VIM_COMMAND} "$@"
}
function df() {
    ${DIFF_COMMAND} "$@"
}
function g() {
    ${GREP_COMMAND} "$@"
}
function gr() {
    ${GREP_COMMAND} -ER "$@" *
}
function gf() {
    ${FIND_COMMAND} . -name "${2}" -exec ${GREP_COMMAND} -E "${1}" {} +
}
function gg() {
    ${GIT_GREP_COMMAND} "$@"
}
function f() {
    ${FIND_COMMAND} "$@"
}
function fn() {
    ${FIND_COMMAND} . -name "$@" | ${GREP_COMMAND} "${1//\*/[^/]*}" # glob->regex
}
function fl() {
    ${FIND_COMMAND} -L . -name "$@" | ${GREP_COMMAND} "${1//\*/[^/]*}" # glob->regex
}
function ll() {
    ${LS_COMMAND} "$@"
}
function cl() {
    clear
}

# VIM integration
export EDITOR=${VIM_COMMAND}
set -o vi 

# Qt Applications
export QT_QPA_PLATFORMTHEME=qt6ct # install and run qt6ct to set themes

# Git integration
has_git_ps1=false

## Fedora
if [ -d /usr/share/git-core/contrib/completion ]; then
  cd /usr/share/git-core/contrib/completion
  if [ -f git-completion.sh ]; then
    source git-completion.sh
  fi
  if [ -f git-prompt.sh ]; then
      source git-prompt.sh
      has_git_ps1=true
  fi
  cd - > /dev/null
fi

## Ubuntu
if [ -f /usr/share/bash-completion/completions/git ]; then
    source /usr/share/bash-completion/completions/git
fi
if [ -f /etc/bash_completion.d/git-prompt ]; then
    source /etc/bash_completion.d/git-prompt
    has_git_ps1=true
fi

if $has_git_ps1 ; then
  export GIT_PS1_SHOWCOLORHINTS=true
  export GIT_PS1_SHOWDIRTYSTATE=true
  export GIT_PS1_SHOWUPSTREAM="auto"
  export PROMPT_COMMAND='__git_ps1 "[\u@\h \w]" "\\\$ ";'
fi

## Homebrew
if [ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]; then
  source "/opt/homebrew/etc/profile.d/bash_completion.sh"
fi
if [ -f "/opt/homebrew/opt/bash-git-prompt/share/gitprompt.sh" ]; then
  GIT_PROMPT_ONLY_IN_REPO=1
  __GIT_PROMPT_DIR="/opt/homebrew/opt/bash-git-prompt/share"
  source "/opt/homebrew/opt/bash-git-prompt/share/gitprompt.sh"
fi

# Per-OS Options
OS=`uname -s`
case "$OS" in
  "Linux" )
    ;;
  "Darwin")
    export CLICOLOR=true
    export LSCOLORS=ExFxBxDxCxegedabagacad
    export LS_COMMAND='ls -lGF'
    ;;
  "MSYS_NT-10.0")
    export FIND_COMMAND='/usr/bin/find' # MS's find is grep
    ;;
  * )
    ;;
esac

# Work
export PATH=${HOME}/.local/bin:/opt/homebrew/bin:${PATH}
export GLOG_logtostderr=1
export GLOG_alsologtostderr=1
export GLOG_stderrthreshold=0
export GLOG_minloglevel=0
