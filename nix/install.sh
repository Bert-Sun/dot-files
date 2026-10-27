#!/usr/bin/bash
# default install script from nixos.org/download 27/10/26

# multi-user install, going to assume I have sudo on any machine I'm migrating workspaces to
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon