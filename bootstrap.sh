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

# ─── derived paths ────────────────────────────────────────────────────────────
# source: committed templates with BOOTSTRAP_* placeholders
HM_SRC="${REPO_DIR}/home-manager"
DOOM_SRC="${REPO_DIR}/doom"
GIT_SRC="${REPO_DIR}/git"
NIX_SRC="${REPO_DIR}/nix"

# compiled: gitignored stamped copies — symlinks point here
COMPILED="${REPO_DIR}/compiled"
HM_COMPILED="${COMPILED}/home-manager"
DOOM_COMPILED="${COMPILED}/doom"
GIT_COMPILED="${COMPILED}/git"

# destinations: where tools expect config to live
HM_DEST="${HOME}/.config/home-manager"
DOOM_DEST="${HOME}/.config/doom"

# ─── helpers ──────────────────────────────────────────────────────────────────

# safe_symlink SOURCE DEST
# DEST -> SOURCE; backs up DEST if it exists and isn't already correct
safe_symlink() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    ok "symlink ok: $dest -> $src"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    warn "backing up $dest to ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  ok "symlinked $dest -> $src"
}

# compile_file TEMPLATE DEST
# copies template to dest, replacing BOOTSTRAP_* tokens
# always rewrites so re-running with new username/email is safe
compile_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  sed \
    -e "s/BOOTSTRAP_GIT_USER/${GIT_USER}/g" \
    -e "s/BOOTSTRAP_EMAIL/${EMAIL}/g" \
    "$src" > "$dest"
  ok "compiled $(basename "$src") -> $dest"
}

# compile_dir TEMPLATE_DIR COMPILED_DIR
# compiles every file in a template dir into the compiled dir
compile_dir() {
  local src_dir="$1" dest_dir="$2"
  mkdir -p "$dest_dir"
  for src_file in "$src_dir"/*; do
    [[ -f "$src_file" ]] || continue
    compile_file "$src_file" "${dest_dir}/$(basename "$src_file")"
  done
}

# ─── preflight ────────────────────────────────────────────────────────────────
section "preflight"
[[ "$EUID" -eq 0 ]] && die "do not run as root"
command -v curl >/dev/null || die "curl required: sudo apt install curl"
command -v git  >/dev/null || die "git required:  sudo apt install git"
# [[ -d "$HM_SRC" ]]   || die "repo missing home-manager/ — is REPO_DIR correct? ($REPO_DIR)"
# [[ -d "$DOOM_SRC" ]] || die "repo missing doom/"
# [[ -d "$GIT_SRC" ]]  || die "repo missing git/"
ok "running as ${GIT_USER}, repo at ${REPO_DIR}"

# ─── compile templates → compiled/ ────────────────────────────────────────────
section "compile templates"
info "stamping username=${GIT_USER} email=${EMAIL}"
# compile_dir "${HM_SRC}"   "${HM_COMPILED}"
# compile_dir "${DOOM_SRC}" "${DOOM_COMPILED}"
# compile_dir "${GIT_SRC}"  "${GIT_COMPILED}"
ok "all templates compiled to ${COMPILED}/"

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