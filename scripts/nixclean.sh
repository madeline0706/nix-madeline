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

# /run/wrappers/bin must come first — that is where the setuid sudo lives.
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

AGE="${NIX_CLEAN_AGE:-7d}"
OPTIMISE=yes
DRY_RUN=no

# --- Logging helpers ---------------------------------------------------------

log()  { printf '\e[1;34m::\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m!!\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31mError:\e[0m %s\n' "${1:-fatal error}" >&2; exit 2; }

usage() {
  sed -n '2,/^set /{/^set /d;s/^# \{0,1\}//;p}' "$0"
  exit "${1:-0}"
}

# KiB free on the store's filesystem, for best-effort before/after reporting.
# Never fails the script: on any error it just yields an empty string.
store_free() {
  df --output=avail /nix/store 2>/dev/null | tail -n1 | tr -d ' ' || true
}

human() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || echo "${1:-0}"; }

# Convert a nix-style duration (e.g. 7d, 12h, 2w) to seconds. Prints nothing
# if the unit isn't understood, so callers can skip the preview gracefully.
age_to_seconds() {
  local a="$1" n unit
  n="${a%%[a-zA-Z]*}"
  unit="${a##*[0-9]}"
  [[ "$n" =~ ^[0-9]+$ ]] || return 0
  case "$unit" in
    s)     echo $(( n )) ;;
    m)     echo $(( n * 60 )) ;;
    h)     echo $(( n * 3600 )) ;;
    d|"")  echo $(( n * 86400 )) ;;
    w)     echo $(( n * 604800 )) ;;
  esac
}

# List profile generations older than the cutoff — i.e. the ones a real run
# would remove. Reads the world-readable profile symlinks directly, so it
# works without root. Excludes each profile's *current* generation, which
# nix-collect-garbage never deletes regardless of age.
preview_generations() {
  local cutoff_s now base tgt gen ts count=0
  cutoff_s=$(age_to_seconds "$AGE")
  if [ -z "$cutoff_s" ]; then
    warn "Couldn't parse age '$AGE'; skipping generation preview."
    return
  fi
  now=$(date +%s)

  # Map of currently-active generation links (never removed).
  declare -A current=()
  shopt -s nullglob
  for base in /nix/var/nix/profiles/* /nix/var/nix/profiles/per-user/*/*; do
    [ -L "$base" ] || continue
    case "$base" in *-[0-9]*-link) continue ;; esac   # skip generation links
    tgt=$(readlink "$base") || continue
    current["$(dirname "$base")/$tgt"]=1
  done

  local lines=()
  for gen in /nix/var/nix/profiles/*-[0-9]*-link \
             /nix/var/nix/profiles/per-user/*/*-[0-9]*-link; do
    [ -L "$gen" ] || continue
    [ -n "${current[$gen]:-}" ] && continue          # keep current generation
    ts=$(stat -c %Y "$gen" 2>/dev/null) || continue
    if [ $(( now - ts )) -gt "$cutoff_s" ]; then
      lines+=("$(printf '   %-18s (%s)' "$(basename "$gen")" "$(date -d "@$ts" '+%Y-%m-%d')")")
      count=$(( count + 1 ))
    fi
  done
  shopt -u nullglob

  log "Generations older than $AGE that would be removed:"
  if [ "$count" -eq 0 ]; then
    printf '   (none)\n'
  else
    printf '%s\n' "${lines[@]}" | sort -V
  fi
  log "$count generation(s) would be removed."
}

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

# A dry run only prints; it never needs root. Everything else does.
if [ "$DRY_RUN" = no ] && [ "$(id -u)" -ne 0 ]; then
  log "Re-executing under sudo…"
  args=(--age "$AGE")
  [ "$OPTIMISE" = no ] && args+=(--no-optimise)
  exec sudo "$0" "${args[@]}"
fi

# --- Dry run -----------------------------------------------------------------
# Report what a real run would do — which generations disappear and how many
# store paths GC would free — without touching anything.

if [ "$DRY_RUN" = yes ]; then
  log "Dry run: nothing will be changed (age threshold $AGE)"
  preview_generations
  log "Calculating store paths garbage collection would free…"
  nix-collect-garbage --delete-older-than "$AGE" --dry-run 2>&1 \
    | grep -E 'store paths would be deleted' \
    | sed 's/^/   /' \
    || printf '   (nothing to collect)\n'
  log "A real run would then refresh bootloader entries$([ "$OPTIMISE" = yes ] && echo ' and optimise the store')."
  exit 0
fi

# --- Main --------------------------------------------------------------------

log "NixOS cleanup starting (removing generations older than $AGE)"
before=$(store_free)

# Delete generations older than $AGE from every profile and collect the store.
# nix-collect-garbage walks all profiles when run as root, so a single call
# prunes both the system generations and per-user profiles.
log "Pruning generations older than $AGE and collecting garbage…"
nix-collect-garbage --delete-older-than "$AGE"

# Regenerate bootloader entries so the boot menu no longer lists the
# generations we just deleted.
if [ -x /run/current-system/bin/switch-to-configuration ]; then
  log "Refreshing bootloader entries…"
  /run/current-system/bin/switch-to-configuration boot
else
  warn "switch-to-configuration not found; skipping bootloader refresh"
fi

# Deduplicate the store by hard-linking identical files.
if [ "$OPTIMISE" = yes ]; then
  log "Optimising the store (deduplicating identical files)…"
  nix-store --optimise
else
  log "Skipping store optimise (--no-optimise)"
fi

after=$(store_free)
if [ -n "$before" ] && [ -n "$after" ]; then
  freed=$(( (after - before) * 1024 ))
  log "Done. Free space on /nix: $(human $((before * 1024))) → $(human $((after * 1024))) (reclaimed $(human "$freed"))"
else
  log "Done."
fi
