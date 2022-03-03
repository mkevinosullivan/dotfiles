#!/bin/zsh
gpgconf --launch dirmngr
gpg --keyserver keys.openpgp.org --recv 391216FE3E5DF76A8471752C007E424BF5756CFC
git config --global user.signingkey 007E424BF5756CFC