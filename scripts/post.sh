#!/usr/bin/env bash
set -euo pipefail

repo="${CARBUNCLE_REPO:-$HOME/Development/nix-carbuncle}"
posts="$repo/site/blog/posts"

usage() {
    cat <<'EOF'
post — publish blog posts to the carbuncle repo (site/blog/posts/)

usage:
  post --new <file.md>       validate, add, commit ("Post: Add <title>"), push and deploy
  post --remove <file.md>    remove, commit ("Post: Remove <title>"), push and deploy
  post --list                list current posts

options:
  --no-push                  don't push to the git remote
  --no-deploy                don't deploy to the Pi (still commits + pushes)

repo defaults to ~/Development/nix-carbuncle (override with $CARBUNCLE_REPO).
set $CLOUDFLARE_API_TOKEN and $CLOUDFLARE_ZONE_ID to auto-purge the CDN on deploy.
EOF
}

die() { echo "post: error: $*" >&2; exit 1; }

frontmatter() {
    awk -v k="$2" '
        NR==1 && $0=="---" { fm=1; next }
        fm && $0=="---"    { exit }
        fm {
            i = index($0, ":")
            if (i > 0) {
                key = substr($0, 1, i-1); val = substr($0, i+1)
                gsub(/^[ \t]+|[ \t]+$/, "", key)
                gsub(/^[ \t]+|[ \t]+$/, "", val)
                if (key == k) { print val; exit }
            }
        }' "$1"
}

has_body() {
    awk '
        NR==1 && $0=="---" { fm=1; next }
        fm && $0=="---"    { fm=0; next }
        !fm && NF          { found=1 }
        END { exit(found ? 0 : 1) }' "$1"
}

validate() {
    local f="$1" base title date
    [ -f "$f" ] || die "no such file: $f"

    base="$(basename "$f")"
    [[ "$base" == *.md ]] || die "not a .md file: $base"
    [[ "$base" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.md$ ]] \
        || die "unsafe filename '$base' (use letters, numbers, . _ - only)"

    [ "$(head -n1 "$f")" = "---" ] || die "missing frontmatter: first line must be '---'"
    awk 'NR>1 && $0=="---" { found=1; exit } END { exit(found ? 0 : 1) }' "$f" \
        || die "unterminated frontmatter (no closing '---')"

    title="$(frontmatter "$f" title)"
    [ -n "$title" ] || die "frontmatter is missing 'title:'"

    date="$(frontmatter "$f" date)"
    [ -n "$date" ] || die "frontmatter is missing 'date:'"
    [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "invalid date '$date' (expected YYYY-MM-DD)"

    has_body "$f" || die "post has no body content"
}

purge_cloudflare() {
    if [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && [ -n "${CLOUDFLARE_ZONE_ID:-}" ]; then
        echo "post: purging Cloudflare cache"
        if curl -fsS -X POST \
            "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data '{"purge_everything":true}' >/dev/null; then
            echo "post: cache purged"
        else
            echo "post: warning: Cloudflare purge failed" >&2
        fi
    else
        echo "post: (set \$CLOUDFLARE_API_TOKEN + \$CLOUDFLARE_ZONE_ID to auto-purge the CDN)"
    fi
}

publish() {
    local action="$1" title="$2" path="$3"

    if git -C "$repo" diff --cached --quiet -- "$path"; then
        echo "post: no changes to commit"
    else
        git -C "$repo" commit -q -m "Post: $action $title" -- "$path"
        echo "post: committed \"Post: $action $title\""
    fi

    if [ -z "${no_push:-}" ]; then
        echo "post: pushing"
        if git -C "$repo" push -q; then
            echo "post: pushed"
        else
            echo "post: warning: push failed" >&2
        fi
    fi

    if [ -n "${no_deploy:-}" ]; then
        echo "post: skipping deploy (--no-deploy)"
        return
    fi

    echo "post: deploying"
    ( cd "$repo" && ./deploy )
    purge_cloudflare
    echo "post: done"
}

[ -d "$repo/.git" ] || die "carbuncle repo not found at $repo (set \$CARBUNCLE_REPO)"

no_deploy=""
no_push=""
for a in "$@"; do
    [ "$a" = "--no-deploy" ] && no_deploy=1
    [ "$a" = "--no-push" ] && no_push=1
done

cmd="${1:-}"
case "$cmd" in
    --new)
        src="${2:-}"; [ -n "$src" ] && [[ "$src" != --* ]] || { usage; die "no file given"; }
        validate "$src"
        base="$(basename "$src")"
        dest="$posts/$base"
        title="$(frontmatter "$src" title)"
        mkdir -p "$posts"
        [ -e "$dest" ] && echo "post: updating existing '$base'" || echo "post: adding '$base'"
        cp -- "$src" "$dest"
        git -C "$repo" add -- "$dest"
        publish "Add" "$title" "$dest"
        ;;
    --remove)
        name="${2:-}"; [ -n "$name" ] && [[ "$name" != --* ]] || { usage; die "no file given"; }
        base="$(basename "$name")"
        dest="$posts/$base"
        [ -e "$dest" ] || die "no such post: $base"
        title="$(frontmatter "$dest" title)"; title="${title:-$base}"
        read -r -p "post: remove '$base'? [y/N] " ans
        case "$ans" in
            [yY]*) ;;
            *) echo "post: aborted"; exit 0 ;;
        esac
        if git -C "$repo" ls-files --error-unmatch -- "$dest" >/dev/null 2>&1; then
            git -C "$repo" rm -f -q -- "$dest"
        else
            rm -- "$dest"
            git -C "$repo" add -- "$dest" 2>/dev/null || true
        fi
        publish "Remove" "$title" "$dest"
        ;;
    --list)
        shopt -s nullglob
        for f in "$posts"/*.md; do echo "$(basename "$f")"; done
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        usage
        die "unknown option: $cmd"
        ;;
esac
