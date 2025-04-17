all: install-scripts configure

configure: bash-config git-config vim-config neovim-config tmux-config ctags-config clang-format-config ack-config input-config

install-scripts:
	mkdir -p ~/.local/bin
	cp scripts/* ~/.local/bin

bash-config:
	cp bashrc ~/.bashrc
	-source ~/.bashrc

tmux-config:
	cp tmux.conf ~/.tmux.conf

git-config:
	cp gitconfig ~/.gitconfig
	cp gitignore ~/.gitignore

vim-config: install-scripts
	cp vimrc ~/.vimrc
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	cp -a vim/* ~/.vim

neovim-config:
	ln -sf ~/.vim ~/.config/nvim 
	ln -sf ~/.vimrc ~/.config/nvim/init.vim

clang-format-config:
	cp clang-format ~/.clang-format

ctags-config:
	mkdir -p ~/.ctags.d
	cp ctags ~/.ctags.d/default.ctags

ack-config:
	cp ackrc ~/.ackrc

input-config:
	cp inputrc ~/.inputrc
