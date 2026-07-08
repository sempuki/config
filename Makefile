.PHONY: all configure provision install-scripts bash-config tmux-config \
        git-config neovim-config clang-format-config ctags-config \
        input-config qt-config

all: install-scripts configure

configure: bash-config git-config neovim-config tmux-config ctags-config clang-format-config input-config qt-config

# Provisioning is deliberately NOT part of `all`: it needs network + sudo and
# is slow, whereas `configure` stays fast and offline. Run it explicitly on a
# fresh box. All platform-specific knowledge lives in provision.sh.
provision:
	chmod 755 provision.sh
	./provision.sh

install-scripts:
	mkdir -p ~/.local/bin
	cp scripts/* ~/.local/bin

bash-config:
	cp bashrc ~/.bashrc

tmux-config:
	cp tmux.conf ~/.tmux.conf

git-config:
	cp gitconfig ~/.gitconfig
	cp gitignore ~/.gitignore

neovim-config: install-scripts
	mkdir -p ~/.config/nvim/
	cp -a nvim/* ~/.config/nvim/

clang-format-config:
	cp clang-format ~/.clang-format

ctags-config:
	mkdir -p ~/.ctags.d
	cp ctags ~/.ctags.d/default.ctags

input-config:
	cp inputrc ~/.inputrc

# qt6ct sets QT_QPA_PLATFORMTHEME for Qt theming -- Linux desktop only.
# On macOS (no /etc/profile.d, native Cocoa theme) this is a no-op.
qt-config:
	@if [ "$$(uname -s)" = Linux ]; then \
		sudo cp qt6ct.sh /etc/profile.d/; \
	else \
		echo "qt-config: skipped (qt6ct is Linux-only)"; \
	fi
