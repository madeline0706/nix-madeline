#!/usr/bin/env bash
#
# nixclean — NixOS housekeeping: prune old generations, garbage collect the
# store, and deduplicate remaining paths.
#
# By default it removes system/user profile generations (and any store paths
# they were the only thing keeping alive) that are older than one week, then
# hard-links identical files in the store to reclaim space.
#
# Usage:
#   nixclean [--age DURATION] [--no-optimise] [--dry-run]
#   nixclean --help
#
#   --age DURATION   How old a generation must be before it is removed.
#                    Accepts nix's duration syntax (e.g. 7d, 336h, 2w-ish).
#                    Defaults to 7d, or $NIX_CLEAN_AGE if set.
#   --no-optimise    Skip the store-optimise (dedup) pass.
#   --dry-run        Show what would run without changing anything.
#
# The script re-executes itself under sudo when not already root, since both
# GC and bootloader updates require it.

set -euo pipefail

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin:$PATH"

AGE="${NIX_CLEAN_AGE:-7d}"
OPTIMISE=yes
DRY_RUN=no

# --- Logging helpers ---------------------------------------------------------

log()  { printf '\e[1;34m::\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m!!\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31mError:\e[0m %s\n' "${1:-fatal error}" >&2; exit 2; }

# Run a command, or just print it under --dry-run.
run() {
  if [ "$DRY_RUN" = yes ]; then
    printf '   \e[2m(dry-run)\e[0m %s\n' "$*"
  else
    "$@"
  fi
}

usage() {
  sed -n '2,/^set /{/^set /d;s/^# \{0,1\}//;p}' "$0"
  exit "${1:-0}"
}

# Bytes free on the store's filesystem, for before/after reporting.
store_free() {
  df -P --output=avail /nix/store 2>/dev/null | tail -n1 | tr -d ' '
}

human() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || echo "${1:-0}"; }

# --- Argument parsing --------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --age)         shift; [ $# -gt 0 ] || die "--age needs a value"; AGE="$1"; shift ;;
    --no-optimise) OPTIMISE=no; shift ;;
    --dry-run)     DRY_RUN=yes; shift ;;
    -h|--help)     usage 0 ;;
    *)             die "unknown argument: $1 (try --help)" ;;
  esac
done

# --- Privilege check ---------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
  log "Re-executing under sudo…"
  args=(--age "$AGE")
  [ "$OPTIMISE" = no ] && args+=(--no-optimise)
  [ "$DRY_RUN" = yes ] && args+=(--dry-run)
  exec sudo "$0" "${args[@]}"
fi

# --- Main --------------------------------------------------------------------

log "NixOS cleanup starting (removing generations older than $AGE)"
before=$(store_free)

# Delete generations older than $AGE from every profile and collect the store.
# nix-collect-garbage walks all profiles when run as root, so a single call
# prunes both the system generations and per-user profiles.
log "Pruning generations older than $AGE and collecting garbage…"
run nix-collect-garbage --delete-older-than "$AGE"

# Regenerate bootloader entries so the boot menu no longer lists the
# generations we just deleted.
if [ -x /run/current-system/bin/switch-to-configuration ]; then
  log "Refreshing bootloader entries…"
  run /run/current-system/bin/switch-to-configuration boot
else
  warn "switch-to-configuration not found; skipping bootloader refresh"
fi

# Deduplicate the store by hard-linking identical files.
if [ "$OPTIMISE" = yes ]; then
  log "Optimising the store (deduplicating identical files)…"
  run nix-store --optimise
else
  log "Skipping store optimise (--no-optimise)"
fi

after=$(store_free)
if [ "$DRY_RUN" = no ] && [ -n "$before" ] && [ -n "$after" ]; then
  freed=$(( (after - before) * 1024 ))
  log "Done. Free space on /nix: $(human $((before * 1024))) → $(human $((after * 1024))) (reclaimed $(human "$freed"))"
else
  log "Done."
fi
