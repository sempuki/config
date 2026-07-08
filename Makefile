.PHONY: all configure provision install-scripts bash-config profile-config \
        tmux-config git-config ssh-config neovim-config clang-format-config \
        ctags-config input-config qt-config github-identity github-keys

all: install-scripts configure

configure: bash-config profile-config git-config ssh-config neovim-config tmux-config ctags-config clang-format-config input-config qt-config

provision:
	chmod 755 provision.sh
	./provision.sh

install-scripts:
	mkdir -p ~/.local/bin
	cp scripts/* ~/.local/bin

bash-config:
	cp bashrc ~/.bashrc

profile-config:
	cp profile ~/.profile

tmux-config:
	cp tmux.conf ~/.tmux.conf

git-config:
	cp gitconfig ~/.gitconfig
	cp gitignore ~/.gitignore

neovim-config: install-scripts
	mkdir -p ~/.config/nvim
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

ssh-config: ssh-keys
	mkdir -p ~/.ssh
	cp -a ssh/* ~/.ssh/
	chmod 700 ~/.ssh ~/.ssh/config.d
	chmod 600 ~/.ssh/config ~/.ssh/config.d/*.config

ssh-keys:
	@test -f ~/.ssh/id_ed25519_self || ssh-keygen -t ed25519 -C self -f ~/.ssh/id_ed25519_self
	@test -f ~/.ssh/id_ed25519_work || ssh-keygen -t ed25519 -C work -f ~/.ssh/id_ed25519_work
	@echo "-- self --: "; cat ~/.ssh/id_ed25519_self.pub
	@echo "-- work --: "; cat ~/.ssh/id_ed25519_work.pub
