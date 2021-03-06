#!/bin/zsh

### include shared git configuration into ~/.gitconfig
[[ -f ~/dotfiles/gitconfig-shared ]] && git config --global include.path ~/dotfiles/gitconfig-shared

### setup global gitignore
if [ ! -f ~/.gitignore_global ]
then
    echo "global gitignore not found, creating..."
    echo "*.DS_Store" > ~/.gitignore_global
    echo ".trash" >> ~/.gitignore_global
fi
git config --global core.excludesfile ~/.gitignore_global

### set up some personal executables
mkdir -p ~/bin

if brew list -q tmux >/dev/null 2>&1
then
  ### tmux is installed, set up tmux configuration
  [[ -f ~/dotfiles/tmux.conf ]] && ln -sf ~/dotfiles/tmux.conf ~/.tmux.conf
  [[ -f ~/dotfiles/tat ]] && ln -sf ~/dotfiles/tat ~/bin/tat
fi

### if on Spin, pull in Spin configuration
[[ "$SPIN" ]] && [[ -f ~/dotfiles/spin.sh ]] && ~/dotfiles/spin.sh

### add lines to .zshrc to include personalization on shell creation
cat << BLOCK >> ~/.zshrc

### Pull personalization from dotfiles
[[ -f ~/dotfiles/zshrc-shared ]] && source ~/dotfiles/zshrc-shared
BLOCK
