#!/usr/bin/bash
# bootstrap.sh — idempotent setup for workspace tools
#
# template files live in the repo (committed, contain BOOTSTRAP_* placeholders)
# compiled/ holds stamped copies (gitignored)
# symlinks point at compiled/ so the repo files are never mutated
#
# usage:
#   bash bootstrap.sh [options]
#
# options:
#   --username  NAME   git username
#   --email     EMAIL  git email address
#   --repo-dir  PATH   where this dotfiles repo lives (default: dir of this script)

set -euo pipefail

# ─── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC}  $*"; }
ok()      { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
die()     { echo -e "${RED}[error]${NC} $*"; exit 1; }
section() { echo -e "\n${BLUE}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ─── defaults ─────────────────────────────────────────────────────────────────
GIT_USER="Bert-Sun"
EMAIL="bertsunjc@gmail.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}"
DOOM_REPO="https://github.com/doomemacs/doomemacs"

# ─── args ─────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --username) GIT_USER="$2"; shift 2 ;;
    --email)    EMAIL="$2";    shift 2 ;;
    --repo-dir) REPO_DIR="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# ─── preflight ────────────────────────────────────────────────────────────────
section "preflight"
[[ "$EUID" -eq 0 ]] && die "do not run as root"
command -v curl >/dev/null || die "curl required: sudo apt install curl"
command -v git  >/dev/null || die "git required:  sudo apt install git"
ok "running as ${GIT_USER}, repo at ${REPO_DIR}"

# ─── compile + symlink ────────────────────────────────────────────────────────
section "compile + symlink"
bash "${REPO_DIR}/dot-file-compile.sh" \
  --username "${GIT_USER}" \
  --email    "${EMAIL}"    \
  --repo-dir "${REPO_DIR}"

# ─── nix ──────────────────────────────────────────────────────────────────────
section "nix"
if command -v nix >/dev/null 2>&1; then
  ok "nix already installed ($(nix --version))"
else
  info "installing nix (daemon mode)..."
  sh "${NIX_SRC}/install.sh"
  # shellcheck disable=SC1091
  source /etc/profile.d/nix.sh 2>/dev/null \
    || source "${HOME}/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null \
    || die "nix installed but could not source — open a new shell and rerun"
  ok "nix installed"
fi

# ─── flakes ───────────────────────────────────────────────────────────────────
section "nix flakes"
NIX_CONF="${HOME}/.config/nix/nix.conf"
mkdir -p "$(dirname "$NIX_CONF")"
if grep -qE "^\s*experimental-features\s*=.*\bflakes\b" "$NIX_CONF" 2>/dev/null; then
  ok "flakes already enabled"
else
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
  ok "flakes enabled"
fi

