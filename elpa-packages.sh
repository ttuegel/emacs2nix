#!/usr/bin/env nix-shell
#!nix-shell -i bash -A env

# usage: ./elpa-packages.sh -o PATH

cabal run elpa2nix -- http://elpa.gnu.org/packages/ "$@"
