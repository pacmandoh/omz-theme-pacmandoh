#!/usr/bin/env bash
set -euo pipefail

PACMANDOH_GITHUB_REPO="${PACMANDOH_GITHUB_REPO:-https://github.com/pacmandoh/omz-theme-pacmandoh.git}"
PACMANDOH_GITHUB_RAW_BASE="${PACMANDOH_GITHUB_RAW_BASE:-https://raw.githubusercontent.com/pacmandoh/omz-theme-pacmandoh/main}"
PACMANDOH_GITEE_REPO="${PACMANDOH_GITEE_REPO:-https://gitee.com/pacmandoh/omz-theme-pacmandoh.git}"
PACMANDOH_GITEE_RAW_BASE="${PACMANDOH_GITEE_RAW_BASE:-https://gitee.com/pacmandoh/omz-theme-pacmandoh/raw/main}"

DRY_RUN=no
VERBOSE=no
ASSUME_YES=no
UPDATE_MODE=no
INSTALL_PROFILE=interactive
INSTALL_OMZ=
INSTALL_LAZY=
INSTALL_PLUGINS=""
PROMPT_STYLE=default
SHOW_HELP=no

pacmandoh_fetch_remote_file() {
  local path=$1
  local dest=$2

  curl -fsSL "$PACMANDOH_GITEE_RAW_BASE/$path" -o "$dest" 2>/dev/null ||
    curl -fsSL "$PACMANDOH_GITHUB_RAW_BASE/$path" -o "$dest"
}

pacmandoh_fetch_remote_root() {
  local root tmp repo

  root=$(mktemp -d "${TMPDIR:-/tmp}/pacmandoh-install.XXXXXX")

  if command -v git >/dev/null 2>&1; then
    for repo in "$PACMANDOH_GITEE_REPO" "$PACMANDOH_GITHUB_REPO"; do
      if git clone --depth=1 "$repo" "$root/repo" >/dev/null 2>&1; then
        printf "%s/repo" "$root"
        return 0
      fi
    done
  fi

  tmp="$root/checkout"
  mkdir -p "$tmp/scripts/lib"
  pacmandoh_fetch_remote_file "pacmandoh.zsh-theme" "$tmp/pacmandoh.zsh-theme"
  pacmandoh_fetch_remote_file "install.sh" "$tmp/install.sh"
  pacmandoh_fetch_remote_file "scripts/main.sh" "$tmp/scripts/main.sh"
  for module in common ui zshrc omz plugins; do
    pacmandoh_fetch_remote_file "scripts/lib/${module}.sh" "$tmp/scripts/lib/${module}.sh"
  done
  printf "%s" "$tmp"
}

pacmandoh_resolve_root() {
  local script_path candidate

  if [ -n "${PACMANDOH_ROOT:-}" ] && [ -f "$PACMANDOH_ROOT/pacmandoh.zsh-theme" ]; then
    printf "%s" "$PACMANDOH_ROOT"
    return 0
  fi

  script_path="${BASH_SOURCE[0]:-}"
  if [ -n "$script_path" ] && [ "$script_path" != bash ] && [ -f "$script_path" ]; then
    candidate=$(cd "$(dirname "$script_path")" && pwd)
    if [ -f "$candidate/pacmandoh.zsh-theme" ]; then
      printf "%s" "$candidate"
      return 0
    fi
  fi

  pacmandoh_fetch_remote_root
}

while [ $# -gt 0 ]; do
  case "$1" in
  -n | --dry-run)
    DRY_RUN=yes
    ;;
  -v | --verbose)
    VERBOSE=yes
    ;;
  -y | --yes)
    ASSUME_YES=yes
    INSTALL_PROFILE=default
    ;;
  --minimal)
    INSTALL_PROFILE=minimal
    ;;
  --full)
    INSTALL_PROFILE=full
    ;;
  --plugins=*)
    INSTALL_PLUGINS="${1#*=}"
    ;;
  --no-omz)
    INSTALL_OMZ=no
    ;;
  --no-lazy)
    INSTALL_LAZY=no
    ;;
  --prompt=*)
    PROMPT_STYLE="${1#*=}"
    ;;
  --update)
    UPDATE_MODE=yes
    ;;
  -h | --help)
    SHOW_HELP=yes
    ;;
  *)
    printf "Unknown option: %s\n" "$1" >&2
    exit 1
    ;;
  esac
  shift
done

PACMANDOH_ROOT=$(pacmandoh_resolve_root)
export PACMANDOH_ROOT DRY_RUN VERBOSE ASSUME_YES UPDATE_MODE INSTALL_PROFILE INSTALL_OMZ INSTALL_LAZY INSTALL_PLUGINS PROMPT_STYLE SHOW_HELP

# shellcheck disable=SC1091
. "$PACMANDOH_ROOT/scripts/lib/common.sh"
# shellcheck disable=SC1091
. "$PACMANDOH_ROOT/scripts/lib/ui.sh"
# shellcheck disable=SC1091
. "$PACMANDOH_ROOT/scripts/lib/zshrc.sh"
# shellcheck disable=SC1091
. "$PACMANDOH_ROOT/scripts/lib/omz.sh"
# shellcheck disable=SC1091
. "$PACMANDOH_ROOT/scripts/lib/plugins.sh"
# shellcheck disable=SC1091
. "$PACMANDOH_ROOT/scripts/main.sh"

if [ "$SHOW_HELP" == yes ]; then
  pacmandoh_show_help
  exit 0
fi

pacmandoh_main
