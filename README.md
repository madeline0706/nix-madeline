# madeline-nix
A work in progress Nix configuration aiming to support all of my machines.

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
R2_ACCOUNT_ID=""
R2_BUCKET=""
R2_PUBLIC_BASE_URL=""
R2_PREFIX=""
AWS_PROFILE=""
```

4. Immich sync (Screenshots + wallpapers):
``mkdir -p ~/.config/immich/``
``nano ~/.config/immich/env``

Populate (URL must end in `/api`):
```
IMMICH_INSTANCE_URL="https://photos.example.com/api"
IMMICH_API_KEY=""
```

Create the key under Immich → Account Settings → API Keys with these permissions:
`user.read`, `asset.upload`, `album.read`, `album.create`, `albumAsset.create`.
Use the same Immich user on every machine so uploads share the `Screenshots` / `Wallpapers` albums. An `immich-sync.timer` then syncs hourly (run `immich-sync` to sync now).

# Screenshots
<img width="1923" height="1080" alt="image" src="https://github.com/user-attachments/assets/22e97407-4cee-400d-a12e-f69bb08f0ee3" />

