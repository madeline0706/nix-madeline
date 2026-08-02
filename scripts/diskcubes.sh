#!/usr/bin/env bash
#
# diskcubes — visualize large files as a squarified treemap of colored cubes,
# WinDirStat-style, entirely in the terminal.
#
# Each file becomes a box whose area is proportional to its size and whose
# colour encodes its category (video, disk image, archive, cache, …). Below
# the map is a legend, a ranked list of the biggest offenders (with full
# paths, age, and junk/stale markers), and a summary of what is safely
# reclaimable. It never deletes anything — it only shows you where the space
# went so you can act.
#
# Usage:
#   diskcubes N [PATH] [--top K] [--width W] [--height H] [--no-color]
#   diskcubes --help
#
#   N            Minimum file size to include, in MB (required).
#   PATH         Directory to scan (default: /, the whole system).
#   --top K      How many of the largest files to draw as boxes (default 24).
#   --width W    Treemap width in columns   (default: fit terminal).
#   --height H   Treemap height in rows     (default: derived from width).
#   --no-color   Disable ANSI colour.
#
# Scanning outside your home directory needs root to read everything, so the
# script re-executes itself under sudo in that case (the default / scan does).
# /nix/store is included but flagged separately — prune it with `nixclean`,
# not by hand.

set -euo pipefail

export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

ORIG=("$@")

TOP=24
WIDTH=""
HEIGHT=""
COLOR=auto

die() { printf '\e[1;31mError:\e[0m %s\n' "${1:-fatal error}" >&2; exit 2; }

usage() {
  sed -n '2,/^set /{/^set /d;s/^# \{0,1\}//;p}' "$0"
  exit "${1:-0}"
}

# --- Argument parsing --------------------------------------------------------

pos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --top)      shift; [ $# -gt 0 ] || die "--top needs a value"; TOP="$1"; shift ;;
    --width)    shift; [ $# -gt 0 ] || die "--width needs a value"; WIDTH="$1"; shift ;;
    --height)   shift; [ $# -gt 0 ] || die "--height needs a value"; HEIGHT="$1"; shift ;;
    --no-color) COLOR=no; shift ;;
    -h|--help)  usage 0 ;;
    -*)         die "unknown option: $1 (try --help)" ;;
    *)          pos+=("$1"); shift ;;
  esac
done

THRESH="${pos[0]:-}"
SCAN="${pos[1]:-/}"

[ -n "$THRESH" ] || usage 1
[[ "$THRESH" =~ ^[0-9]+$ ]] || die "N must be a whole number of MB (got '$THRESH')"
[[ "$TOP" =~ ^[0-9]+$ ]] && [ "$TOP" -ge 1 ] || die "--top must be a positive integer"
[ -e "$SCAN" ] || die "no such path: $SCAN"
SCAN="$(realpath "$SCAN")"

# --- Privilege check ---------------------------------------------------------
# Reading anything outside $HOME reliably needs root. Re-exec under sudo.

case "$SCAN" in
  "$HOME"|"$HOME"/*) needroot=no ;;
  *)                 needroot=yes ;;
esac
if [ "$needroot" = yes ] && [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "${ORIG[@]}"
fi

# --- Terminal geometry & colour ----------------------------------------------

if [ "$COLOR" = auto ]; then
  [ -t 1 ] && COLOR=yes || COLOR=no
fi

if [ -z "$WIDTH" ]; then
  cols=$(tput cols 2>/dev/null || echo 80)
  WIDTH=$(( cols > 100 ? 98 : cols - 2 ))
fi
[ "$WIDTH" -lt 24 ] && WIDTH=24
if [ -z "$HEIGHT" ]; then
  HEIGHT=$(( WIDTH * 2 / 5 ))
fi
[ "$HEIGHT" -lt 10 ] && HEIGHT=10
[ "$HEIGHT" -gt 40 ] && HEIGHT=40

NOW=$(date +%s)

printf 'Scanning %s for files larger than %s MB…\n' "$SCAN" "$THRESH" >&2

# --- Scan + render -----------------------------------------------------------

find "$SCAN" \
  \( -path /proc -o -path /sys -o -path /dev -o -path /run \
     -o -path /var/run -o -path /var/lock -o -path '*/lost+found' \) -prune \
  -o -type f -size +"${THRESH}"M -printf '%s\t%T@\t%p\n' 2>/dev/null \
| gawk -F'\t' \
    -v W="$WIDTH" -v H="$HEIGHT" -v NOW="$NOW" -v TOP="$TOP" \
    -v COLOR="$COLOR" -v THRESH="$THRESH" -v SCANP="$SCAN" '
# ---------------------------------------------------------------- helpers ----
function base(p,   a,n) { sub(/\/+$/,"",p); n=split(p,a,"/"); return a[n] }

function human(b,   u,i) {
  split("B KB MB GB TB PB", u, " "); i=1
  while (b >= 1024 && i < 6) { b/=1024; i++ }
  return sprintf((b>=100 || b==int(b)) ? "%.0f%s" : "%.1f%s", b, u[i])
}

function humanage(d) {
  if (d < 1)   return "today"
  if (d < 30)  return d "d"
  if (d < 365) return int(d/30) "mo"
  return int(d/365) "y"
}

function trunc(s,w) {
  if (w <= 0) return ""
  if (length(s) <= w) return s
  if (w == 1) return substr(s,1,1)
  return substr(s,1,w-1) "\xe2\x80\xa6"          # ellipsis
}

function categorize(p,   lp) {
  lp = tolower(p)
  if (index(lp,"/nix/store/"))                                   return "nixstore"
  if (lp ~ /\/(\.cache|cache|\.thumbnails)\// ||
      index(lp,"/.local/share/trash/") || index(lp,"coredump")) return "cache"
  if (lp ~ /\/(node_modules|\.venv|__pycache__|target|\.cargo|dist|build)\//) return "build"
  if (lp ~ /\.(mkv|mp4|mov|avi|webm|m4v|wmv|flv)$/)              return "video"
  if (lp ~ /\.(iso|img|qcow2|vdi|vmdk|raw|dmg)$/)                return "diskimg"
  if (lp ~ /\.(zip|tar|gz|xz|zst|bz2|7z|rar|tgz)$/)             return "archive"
  if (lp ~ /\.(mp3|flac|wav|ogg|opus|m4a|aac)$/)                return "audio"
  if (lp ~ /\.(png|jpe?g|gif|webp|tiff?|bmp|svg|psd|cr2|nef)$/) return "image"
  if (lp ~ /\.(log|journal)$/ || index(lp,"/var/log/"))        return "log"
  return "other"
}

function col(c) { return (COLOR=="yes") ? "\033[" c "m" : "" }
function rst()  { return (COLOR=="yes") ? "\033[0m"    : "" }

# ------------------------------------------------------ treemap: add a box ---
# Record border segments so shared edges/junctions merge into clean lines.
# Bits: N=1 E=2 S=4 W=8.
function seg(y,x,b) { SEG[y SUBSEP x] = or(SEG[y SUBSEP x]+0, b) }
function addbox(bx,by,bw,bh,   bx2,by2,c,r) {
  bx2 = bx+bw-1; by2 = by+bh-1
  for (c=bx; c<bx2; c++) { seg(by,c,2);  seg(by,c+1,8);  seg(by2,c,2);  seg(by2,c+1,8) }
  for (r=by; r<by2; r++) { seg(r,bx,4);  seg(r+1,bx,1);  seg(r,bx2,4);  seg(r+1,bx2,1) }
}

# --------------------------------------- squarified treemap layout engine ---
function worst(rmax,rmin,s,side,   hi,lo) {
  hi = (side*side*rmax)/(s*s)
  lo = (s*s)/(side*side*rmin)
  return (hi>lo) ? hi : lo
}
function layout(m,   fx,fy,fw,fh,i,k,side,horiz,rowsum,rmax,rmin,cnt,a,ns,nmax,nmin,
                     remLong,isLast,thick,pos,acc,t,frac,end,len) {
  fx=0; fy=0; fw=W; fh=H; i=1
  while (i<=m && fw>0 && fh>0) {
    side  = (fw<fh) ? fw : fh
    horiz = (fw<fh) ? 1  : 0                      # lay row across the short side
    rowsum=0; rmax=0; rmin=1e30; cnt=0; k=i
    while (k<=m) {
      a=A[k]; nmax=(a>rmax?a:rmax); nmin=(a<rmin?a:rmin); ns=rowsum+a
      if (cnt==0) { rowsum=ns; rmax=nmax; rmin=nmin; cnt++; k++; continue }
      if (worst(nmax,nmin,ns,side) <= worst(rmax,rmin,rowsum,side)) {
        rowsum=ns; rmax=nmax; rmin=nmin; cnt++; k++
      } else break
    }
    remLong = horiz ? fh : fw
    isLast  = (k>m)
    thick   = int(rowsum/side + 0.5); if (thick<1) thick=1
    if (thick>remLong) thick=remLong
    if (isLast)        thick=remLong
    pos=0; acc=0
    for (t=i; t<k; t++) {
      acc += A[t]/rowsum
      end  = int(side*acc + 0.5); if (t==k-1) end=side
      len  = end-pos; if (len<1) len=1
      if (horiz) { TX[t]=fx+pos; TY[t]=fy;     TW[t]=len;   TH[t]=thick }
      else       { TX[t]=fx;     TY[t]=fy+pos; TW[t]=thick; TH[t]=len   }
      pos=end
    }
    if (horiz) { fy+=thick; fh-=thick } else { fx+=thick; fw-=thick }
    i=k
  }
  return i-1
}

# --------------------------------------------------------------- read data ---
BEGIN {
  # category -> colour (ANSI SGR foreground)
  CC["video"]="95"; CC["image"]="94"; CC["audio"]="96"; CC["archive"]="93"
  CC["diskimg"]="91"; CC["build"]="92"; CC["log"]="33"; CC["cache"]="31"
  CC["nixstore"]="90"; CC["other"]="37"
  LABEL="1;97"; BORDER="38;5;240"

  # display order for the legend
  split("video image audio archive diskimg build log cache nixstore other", ORDER, " ")

  # segment bitmask -> box-drawing glyph
  bc[0]=" ";  bc[1]="\xe2\x95\xb5"; bc[2]="\xe2\x95\xb6"; bc[3]="\xe2\x94\x94"
  bc[4]="\xe2\x95\xb7"; bc[5]="\xe2\x94\x82"; bc[6]="\xe2\x94\x8c"; bc[7]="\xe2\x94\x9c"
  bc[8]="\xe2\x95\xb4"; bc[9]="\xe2\x94\x98"; bc[10]="\xe2\x94\x80"; bc[11]="\xe2\x94\xb4"
  bc[12]="\xe2\x94\x90"; bc[13]="\xe2\x94\xa4"; bc[14]="\xe2\x94\xac"; bc[15]="\xe2\x94\xbc"
  FULL="\xe2\x96\x88"                                              # full block
}
{
  n++
  SIZE[n]=$1+0; MT[n]=int($2); PATHS[n]=$3
  c=categorize($3); CAT[n]=c
  total += SIZE[n]; CATTOTAL[c] += SIZE[n]
}

# ------------------------------------------------------------------ render ---
END {
  if (n==0) {
    printf "No files larger than %s MB under %s.\n", THRESH, SCANP
    exit 0
  }

  # sort indices by size, descending
  for (i=1;i<=n;i++) pk[i]=sprintf("%020d|%08d", SIZE[i], i)
  m=asort(pk)
  for (i=1;i<=n;i++) { split(pk[n-i+1],p2,"|"); R[i]=p2[2]+0 }

  # take the top-K largest for the treemap
  K = (n<TOP)?n:TOP
  sumTop=0
  for (t=1;t<=K;t++) { S[t]=SIZE[R[t]]; P[t]=PATHS[R[t]]; TC[t]=CAT[R[t]]; sumTop+=S[t] }
  for (t=1;t<=K;t++) A[t] = S[t]/sumTop * (W*H)

  laid = layout(K)

  # fill interiors + labels (borders were recorded as segments during layout)
  for (t=1; t<=laid; t++) {
    bw=TW[t]; bh=TH[t]; if (bw<1||bh<1) continue
    addbox(TX[t],TY[t],bw,bh)
    iw=bw-2; ih=bh-2; if (iw<1||ih<1) continue
    name = trunc(base(P[t]), iw)
    sz   = human(S[t])
    shownm = (iw>=4)
    for (yy=0; yy<ih; yy++) for (xx=0; xx<iw; xx++) {
      cx=TX[t]+1+xx; cy=TY[t]+1+yy; ch=FULL; fg=CC[TC[t]]
      if (shownm && yy==0)            { c=substr(name,xx+1,1); ch=(c==""?" ":c); fg=LABEL }
      else if (shownm && ih>=3 && yy==1) { c=substr(sz,xx+1,1); ch=(c==""?" ":c); fg=LABEL }
      CH[cy SUBSEP cx]=ch; FG[cy SUBSEP cx]=fg
    }
  }

  # header
  printf "\n%s%d files%s > %s%s MB%s under %s%s%s  (total %s%s%s)\n\n",
    col("1"), n, rst(), col("1"), THRESH, rst(), col("1"), SCANP, rst(),
    col("1"), human(total), rst()

  # draw the grid
  for (y=0; y<H; y++) {
    line=""; prev="__"
    for (x=0; x<W; x++) {
      key=y SUBSEP x
      if (key in CH)       { ch=CH[key]; fg=FG[key] }
      else if ((key in SEG) && SEG[key]>0) { ch=bc[SEG[key]]; fg=BORDER }
      else                 { ch=" "; fg="" }
      if (COLOR=="yes" && fg!=prev) { line=line (fg==""?rst():col(fg)); prev=fg }
      line=line ch
    }
    print line rst()
  }

  # legend (only categories present)
  print ""
  leg=""
  for (i=1;i<=length(ORDER);i++) {
    c=ORDER[i]; if (!(c in CATTOTAL)) continue
    leg=leg col(CC[c]) FULL rst() " " c " " col("2") "(" human(CATTOTAL[c]) ")" rst() "   "
  }
  print leg

  # ranked list of the biggest files
  L=(n<20)?n:20
  printf "\n%sLargest %d files%s\n", col("1"), L, rst()
  for (i=1;i<=L;i++) {
    idx=R[i]; c=CAT[idx]; flag=""
    if (c=="cache")         flag=flag " " col("32") "[junk]" rst()
    if (c=="nixstore")      flag=flag " " col("90") "[store: use nixclean]" rst()
    if ((NOW-MT[idx])/86400 > 90) flag=flag " " col("33") "[stale]" rst()
    printf "%s%2d.%s %s%7s%s  %s%-4s%s  %s%-8s%s %s%s\n",
      col("2"), i, rst(),
      col("1"), human(SIZE[idx]), rst(),
      col("2"), humanage(int((NOW-MT[idx])/86400)), rst(),
      col(CC[c]), c, rst(),
      PATHS[idx], flag
  }

  # summary / reclaimable
  printf "\n%sSummary%s\n", col("1"), rst()
  printf "  matched:      %d files, %s\n", n, human(total)
  if ("cache" in CATTOTAL)
    printf "  %sreclaimable:  %s%s in caches / trash / coredumps (safe to delete)\n",
      col("32"), human(CATTOTAL["cache"]), rst()
  if ("nixstore" in CATTOTAL)
    printf "  %snix store:    %s%s under /nix/store — prune with `nixclean`\n",
      col("90"), human(CATTOTAL["nixstore"]), rst()
}
'
