#!/usr/bin/env bash
#
# provision.sh -- install the tools that the dotfiles configure.
#
# This is the ONE place platform knowledge lives. The config files themselves
# stay platform-agnostic; everything OS-specific is quarantined in here.
#
#   Band 1  evergreen tools from the system package manager. Only the package
#           NAMES differ per platform -- that name map is the entire
#           platform-specific surface (see install_system()).
#   Band 2  the rust toolchain (rust-analyzer, rustfmt, clippy), installed via
#           rustup, which behaves identically on every OS.
#   Band 3  tools no package manager carries: tree-sitter, tmux-mem-cpu-load.
#
# A distribution that cannot supply the rest is the wrong distribution. This
# script reports what is missing rather than working around it.
#
# Supported: macOS (brew), Debian/Ubuntu (apt), Fedora/RHEL (dnf).
# Safe to re-run.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
# $BIN joins PATH only at the next login, so anything placed there this run is
# invisible to `have`. Guard the fetchers with this instead.
installed() { have "$1" || [ -x "$BIN/$1" ]; }

BIN="$HOME/.local/bin"
mkdir -p "$BIN"

# ---------------------------------------------------------------------------
# Platform detection -> package manager
# ---------------------------------------------------------------------------
detect_package_manager() {
  case "$(uname -s)" in
    Darwin) echo brew ;;
    Linux)
      [ -r /etc/os-release ] || die "no /etc/os-release; unsupported Linux"
      # shellcheck disable=SC1091
      . /etc/os-release
      case " ${ID:-} ${ID_LIKE:-} " in
        *" debian "*|*" ubuntu "*)         echo apt ;;
        *" fedora "*|*" rhel "*|*" centos "*) echo dnf ;;
        *) die "unsupported distro: ${ID:-unknown}" ;;
      esac ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
}

PM="$(detect_package_manager)"
log "platform: $(uname -s) / $(uname -m)  ->  package manager: $PM"

# Install packages, tolerating ones this distribution does not carry. A single
# absent package must not abort provisioning: the batch is tried first, and on
# failure each package is attempted alone so the rest still land. What is
# missing is named at the end, and again by doctor.
install_packages() {
  local mgr="$1"; shift
  local failed=() p
  case "$mgr" in
    apt) if sudo apt-get install -y "$@"; then return 0; fi ;;
    dnf) if sudo dnf install -y "$@"; then return 0; fi ;;
  esac
  warn "batch install failed; retrying one package at a time"
  for p in "$@"; do
    case "$mgr" in
      apt) if ! sudo apt-get install -y "$p" >/dev/null 2>&1; then failed+=("$p"); fi ;;
      dnf) if ! sudo dnf install -y "$p" >/dev/null 2>&1; then failed+=("$p"); fi ;;
    esac
  done
  if [ ${#failed[@]} -gt 0 ]; then
    warn "not available from $mgr: ${failed[*]}"
    warn "install these another way if you need them (see doctor's output below)"
  fi
}

# ---------------------------------------------------------------------------
# BAND 1 -- system package manager.
# The three package lists below are the *only* platform-specific knowledge.
# Note the real divergences captured here:
#   - clangd and clang-format are separate from clang on apt.
#   - both live in clang-tools-extra on dnf.
#   - on brew they ride along with the (keg-only) llvm formula.
#   - fd is the 'fd-find' package on apt (binary 'fdfind') -- symlinked below.
# ---------------------------------------------------------------------------
install_system() {
  case "$PM" in
    brew)
      have brew || die "install Homebrew first: https://brew.sh"
      xcode-select -p >/dev/null 2>&1 || { log "installing Xcode CLT (clang)"; xcode-select --install || true; }
      # bash: macOS is frozen at a GPLv2-era 3.2; install a modern 5.x.
      brew install bash bash-completion@2 tmux neovim universal-ctags llvm ripgrep fd git curl make bazelisk gh
      # llvm is keg-only; expose clangd + clang-format on PATH for the LSP/formatter.
      local llvmbin; llvmbin="$(brew --prefix llvm)/bin"
      for b in clangd clang-format; do
        if [ -x "$llvmbin/$b" ]; then ln -sf "$llvmbin/$b" "$BIN/$b"; fi
      done
      ;;
    apt)
      sudo apt-get update
      install_packages apt \
        tmux neovim universal-ctags ripgrep fd-find git curl make cmake \
        bash-completion clang clang-format clangd python3 gh
      # Debian ships fd as 'fdfind'; Telescope expects 'fd'.
      if have fdfind && ! have fd; then ln -sf "$(command -v fdfind)" "$BIN/fd"; fi
      ;;
    dnf)
      install_packages dnf \
        tmux neovim ctags ripgrep fd-find git curl make cmake \
        bash-completion clang clang-tools-extra python3 gh
      ;;
  esac
}

# ---------------------------------------------------------------------------
# macOS only -- make the modern bash selectable. Apple's /bin/bash is frozen at
# 3.2 and cannot be replaced, so Homebrew's 5.x installs alongside it; a
# terminal still launching /bin/bash gets 3.2, where bash-completion@2 (bash 4+)
# silently does nothing. chpass(1) refuses any shell absent from /etc/shells,
# so register it here. Selecting it is left to the user: which shell greets you
# at login is an account decision, not a provisioning one.
# ---------------------------------------------------------------------------
register_modern_bash() {
  [ "$PM" = brew ] || return 0
  local brewbash; brewbash="$(brew --prefix)/bin/bash"
  if [ ! -x "$brewbash" ]; then warn "no Homebrew bash at $brewbash"; return 0; fi
  if ! grep -qxF "$brewbash" /etc/shells 2>/dev/null; then
    log "registering $brewbash in /etc/shells"
    if ! printf '%s\n' "$brewbash" | sudo tee -a /etc/shells >/dev/null; then
      warn "could not write /etc/shells; add $brewbash to it by hand"
      return 0
    fi
  fi
  local current; current="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  if [ "$current" != "$brewbash" ]; then
    log "login shell is ${current:-unknown}; to switch: chsh -s $brewbash"
  fi
}

# ---------------------------------------------------------------------------
# BAND 2a -- rust toolchain via rustup (uniform on every OS).
# Provides rust-analyzer + rustfmt + clippy (your rust_analyzer.lua uses clippy).
# ---------------------------------------------------------------------------
install_rust_tools() {
  if ! have rustup; then
    log "installing rustup"
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
  # shellcheck disable=SC1091
  if [ -r "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
  rustup component add rust-analyzer rustfmt clippy || warn "rustup component add failed"
}

# ---------------------------------------------------------------------------
# BAND 3b -- tree-sitter CLI (nvim-treesitter's main branch compiles parsers
# with it). Distributions lag the plugin by enough that the packaged CLI is
# routinely too old, and the floor the plugin wants keeps moving, so track
# upstream's latest rather than guessing a version.
# ---------------------------------------------------------------------------
install_treesitter_cli() {
  if installed tree-sitter; then log "tree-sitter present"; return; fi
  if [ "$PM" = brew ]; then brew install tree-sitter-cli; return; fi
  local arch
  case "$(uname -m)" in
    x86_64)        arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) warn "no tree-sitter build for $(uname -m)"; return ;;
  esac
  log "installing latest tree-sitter ($arch)"
  local url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$arch.gz"
  if curl -fsSL "$url" | gzip -d > "$BIN/tree-sitter.part"; then
    chmod +x "$BIN/tree-sitter.part"
    mv "$BIN/tree-sitter.part" "$BIN/tree-sitter"
    log "tree-sitter $("$BIN/tree-sitter" --version | awk '{print $2}') installed"
  else
    warn "tree-sitter download failed: $url"
    rm -f "$BIN/tree-sitter.part"
  fi
}

# ---------------------------------------------------------------------------
# BAND 2c -- tmux-mem-cpu-load (CPU%/mem/load for the tmux status bar). In brew
# on macOS; not packaged for apt/dnf, so built from source on Linux, pinned to a
# release tag and installed into ~/.local (no sudo). cmake is in the package
# lists above; clang + make are already there.
# ---------------------------------------------------------------------------
TMCL_TAG=v3.8.3

install_tmux_mem_cpu_load() {
  if installed tmux-mem-cpu-load; then log "tmux-mem-cpu-load present"; return; fi
  if [ "$PM" = brew ]; then
    brew install tmux-mem-cpu-load
    return
  fi
  have cmake || { warn "cmake missing; cannot build tmux-mem-cpu-load"; return; }
  log "building tmux-mem-cpu-load $TMCL_TAG from source"
  local tmp; tmp="$(mktemp -d)"
  if git clone --depth 1 --branch "$TMCL_TAG" https://github.com/thewtex/tmux-mem-cpu-load.git "$tmp/src" >/dev/null 2>&1 \
     && cmake -S "$tmp/src" -B "$tmp/build" -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null \
     && cmake --build "$tmp/build" >/dev/null \
     && cmake --install "$tmp/build" >/dev/null; then
    log "tmux-mem-cpu-load installed to $BIN"
  else
    warn "tmux-mem-cpu-load build failed"
  fi
  rm -rf "$tmp"
}

# A tool that exists is not a tool that runs: a binary built for a newer
# distribution fails in the dynamic loader, which reports the missing symbol
# on stderr and exits 1 -- indistinguishable by status alone from a tool that
# merely dislikes --version. Match what the loader says instead.
report_tool() {
  local name="$1" path="$2" suffix="$3" output
  output="$("$path" --version 2>&1)"
  case "$output" in
    *"error while loading shared libraries"*|*"GLIBC_"*|*"cannot execute"*|*"not found (required by"*)
      printf '  \033[1;31mBROKEN\033[0m %-18s %s\n' "$name" "$path"
      printf '         %s\n' "$(printf '%s' "$output" | head -1)"
      return 1 ;;
  esac
  printf '  \033[1;32m ok \033[0m %-20s %s%s\n' "$name" "$path" "$suffix"
}

# bash is the one tool whose mere presence proves nothing: every macOS has one,
# and it is the 3.2 that the dotfiles' completions cannot use. Report the
# version, and treat a major below 4 as a failure rather than a pass.
check_bash() {
  local path major version
  path="$(command -v bash)" || { printf '  \033[1;31mMISS\033[0m %-20s\n' bash; return 1; }
  major="$("$path" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null || echo 0)"
  version="$("$path" -c 'echo "$BASH_VERSION"' 2>/dev/null || echo unknown)"
  if [ "$major" -ge 4 ]; then
    printf '  \033[1;32m ok \033[0m %-20s %s (%s)\n' bash "$path" "$version"
    return 0
  fi
  printf '  \033[1;31mOLD \033[0m %-20s %s is %s; completions need 4+\n' bash "$path" "$version"
  return 1
}

# ---------------------------------------------------------------------------
# Doctor -- report what actually landed on PATH (verifies parity across hosts).
# ---------------------------------------------------------------------------
# On a first run ~/.local/bin did not exist when the shell started, so the
# tools just installed there are absent from PATH until the next login. Look
# in $BIN too, or every fresh box reports failures for what it just installed.
doctor() {
  log "verifying tools:"
  local ok=1
  check_bash || ok=0
  for t in tmux nvim clangd clang-format ctags rg fd git curl make python3 gh \
           rust-analyzer rustfmt tree-sitter tmux-mem-cpu-load; do
    if have "$t"; then
      report_tool "$t" "$(command -v "$t")" "" || ok=0
    elif [ -x "$BIN/$t" ]; then
      report_tool "$t" "$BIN/$t" " (PATH after next login)" || ok=0
    else
      printf '  \033[1;31mMISS\033[0m %-20s\n' "$t"; ok=0
    fi
  done
  case ":$PATH:" in *":$BIN:"*) : ;; *) warn "$BIN is not on PATH -- add it in your shell rc";; esac
  [ "$ok" = 1 ] || warn "some tools missing; see above"
}

main() {
  install_system
  register_modern_bash
  install_rust_tools
  install_treesitter_cli
  install_tmux_mem_cpu_load
  doctor
  log "done."
}
main "$@"
