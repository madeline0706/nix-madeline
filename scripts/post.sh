#!/usr/bin/env bash
set -euo pipefail

repo="${CARBUNCLE_REPO:-$HOME/Development/nix-carbuncle}"
posts="$repo/site/blog/posts"

usage() {
    cat <<'EOF'
post — manage blog posts in the carbuncle repo (site/blog/posts/)

usage:
  post --new <file.md>       validate <file.md> and add it to the posts folder
  post --remove <file.md>    remove a post from the posts folder
  post --list                list current posts

repo location defaults to ~/Development/nix-carbuncle (override with $CARBUNCLE_REPO).
after --new / --remove, deploy the repo to publish (then purge the Cloudflare cache).
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

[ -d "$repo/.git" ] || die "carbuncle repo not found at $repo (set \$CARBUNCLE_REPO)"

cmd="${1:-}"
case "$cmd" in
    --new)
        src="${2:-}"; [ -n "$src" ] || { usage; die "no file given"; }
        validate "$src"
        base="$(basename "$src")"
        dest="$posts/$base"
        mkdir -p "$posts"
        [ -e "$dest" ] && echo "post: updating existing '$base'" || echo "post: adding '$base'"
        cp -- "$src" "$dest"
        git -C "$repo" add -- "$dest"
        echo "post: staged $dest"
        echo "post: deploy the repo to publish"
        ;;
    --remove)
        name="${2:-}"; [ -n "$name" ] || { usage; die "no file given"; }
        base="$(basename "$name")"
        dest="$posts/$base"
        [ -e "$dest" ] || die "no such post: $base"
        read -r -p "post: remove '$base'? [y/N] " ans
        case "$ans" in
            [yY]*) ;;
            *) echo "post: aborted"; exit 0 ;;
        esac
        if git -C "$repo" ls-files --error-unmatch -- "$dest" >/dev/null 2>&1; then
            git -C "$repo" rm -f -q -- "$dest"
        else
            rm -- "$dest"
        fi
        echo "post: removed $base"
        echo "post: deploy the repo to publish"
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
