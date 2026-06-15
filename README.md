# nixos-dellpro14
My NixOS configuration for my Dell Pro 14.
I am still learning Nix & NixOS, and this will eventually also serve as the config
for my desktop.

# Design Philosophy

Minimal, with as much TUI as possible!

# Imperative Steps
*I keep forgetting!*

1. Set user password:
``passwd <user>``

2. Logging into tailscale, setting operator:
``sudo tailscale set --operator=$USER`` 
``tailscale up``

3. Recordings / Screenshot uploads:
``aws configure --profile r2``
``mkdir -p ~/.config/grimshot/``
``nano ~/.config/grimshot/env``

Populate:
```
R2_ACCOUNT_ID='"
R2_BUCKET=""
R2_PUBLIC_BASE_URL=""
R2_PREFIX=""
AWS_PROFILE=""
```

# Screenshots
<img width="1923" height="1080" alt="image" src="https://github.com/user-attachments/assets/22e97407-4cee-400d-a12e-f69bb08f0ee3" />

