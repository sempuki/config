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
#
# Supported: macOS (brew), Debian/Ubuntu (apt), Fedora/RHEL (dnf).
# Safe to re-run.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

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
      # bash: macOS is frozen at a GPLv2-era 3.2; install a modern 5.x. Linux bash
      # is already current, so this is macOS-only. bash-completion@2 + bash-git-prompt
      # back the sources bashrc already expects under /opt/homebrew.
      brew install bash bash-completion@2 bash-git-prompt \
        tmux neovim universal-ctags llvm ripgrep fd git curl make
      # llvm is keg-only; expose clangd + clang-format on PATH for the LSP/formatter.
      local llvmbin; llvmbin="$(brew --prefix llvm)/bin"
      for b in clangd clang-format; do
        [ -x "$llvmbin/$b" ] && ln -sf "$llvmbin/$b" "$BIN/$b"
      done
      ;;
    apt)
      sudo apt-get update
      sudo apt-get install -y \
        tmux neovim universal-ctags ripgrep fd-find git curl make cmake \
        bash-completion clang clang-format clangd
      # Debian ships fd as 'fdfind'; Telescope expects 'fd'.
      if have fdfind && ! have fd; then ln -sf "$(command -v fdfind)" "$BIN/fd"; fi
      ;;
    dnf)
      sudo dnf install -y \
        tmux neovim ctags ripgrep fd-find git curl make cmake \
        bash-completion clang clang-tools-extra
      ;;
  esac
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
  [ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  rustup component add rust-analyzer rustfmt clippy || warn "rustup component add failed"
}

# ---------------------------------------------------------------------------
# BAND 2b -- tree-sitter CLI (nvim-treesitter's main branch compiles parsers
# with it). Install from the system package manager like everything else --
# signed, verified, and updated by the OS. Debian/Ubuntu *stable* can ship a
# version older than the plugin wants; if so we say so plainly and let you
# decide, rather than dropping an unmanaged binary onto the box.
# ---------------------------------------------------------------------------
TS_MIN=0.25   # nvim-treesitter main needs this floor (its README says 0.26.1)

install_treesitter_cli() {
  if ! have tree-sitter; then
    case "$PM" in
      brew) brew install tree-sitter-cli ;;
      apt)  sudo apt-get install -y tree-sitter-cli ;;
      dnf)  sudo dnf install -y tree-sitter-cli ;;
    esac
  fi
  if ! have tree-sitter; then
    warn "tree-sitter CLI unavailable from $PM; see the nvim-treesitter README to install it"
    return
  fi
  local v; v="$(tree-sitter --version 2>/dev/null | awk '{print $2}')"
  if printf '%s\n%s\n' "$TS_MIN" "$v" | sort -V -C 2>/dev/null; then
    log "tree-sitter CLI $v (>= $TS_MIN)"
  else
    warn "tree-sitter CLI $v is below the $TS_MIN nvim-treesitter needs."
    warn "On Debian/Ubuntu stable: enable backports, move to a newer release, or 'cargo install tree-sitter-cli'."
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
  if have tmux-mem-cpu-load; then log "tmux-mem-cpu-load present"; return; fi
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

# ---------------------------------------------------------------------------
# Doctor -- report what actually landed on PATH (verifies parity across hosts).
# ---------------------------------------------------------------------------
doctor() {
  log "verifying tools:"
  local ok=1
  for t in tmux nvim clangd clang-format ctags rg fd git curl make \
           rust-analyzer rustfmt tree-sitter tmux-mem-cpu-load; do
    if have "$t"; then
      printf '  \033[1;32m ok \033[0m %-20s %s\n' "$t" "$(command -v "$t")"
    else
      printf '  \033[1;31mMISS\033[0m %-20s\n' "$t"; ok=0
    fi
  done
  case ":$PATH:" in *":$BIN:"*) : ;; *) warn "$BIN is not on PATH -- add it in your shell rc";; esac
  [ "$ok" = 1 ] || warn "some tools missing; see above"
}

main() {
  install_system
  install_rust_tools
  install_treesitter_cli
  install_tmux_mem_cpu_load
  doctor
  log "done."
}
main "$@"
