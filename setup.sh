#!/bin/zsh

### include shared git configuration into ~/.gitconfig
[[ -f ~/dotfiles/gitconfig-shared ]] && git config --global include.path ~/dotfiles/gitconfig-shared

### set up tmux configuration
[[ -f ~/dotfiles/tmux.conf ]] && ln -sf ~/dotfiles/tmux.conf ~/.tmux.conf

### set up some personal executables
mkdir -p ~/bin
[[ -f ~/dotfiles/tat ]] && ln -sf ~/dotfiles/tat ~/bin/tat

### add lines to .zshrc to include personalization on shell creation
echo "### Pull personalization from dotfiles" >> ~/.zshrc
echo "[[ -f ~/dotfiles/zshrc-shared ]] && source ~/dotfiles/zshrc-shared" >> ~/.zshrc
