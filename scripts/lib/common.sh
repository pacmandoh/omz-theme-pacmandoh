#!/usr/bin/env bash

PACMANDOH_GITHUB_REPO="${PACMANDOH_GITHUB_REPO:-https://github.com/pacmandoh/omz-theme-pacmandoh.git}"
PACMANDOH_GITHUB_RAW_BASE="${PACMANDOH_GITHUB_RAW_BASE:-https://raw.githubusercontent.com/pacmandoh/omz-theme-pacmandoh/main}"
PACMANDOH_GITEE_REPO="${PACMANDOH_GITEE_REPO:-https://gitee.com/pacmandoh/omz-theme-pacmandoh.git}"
PACMANDOH_GITEE_RAW_BASE="${PACMANDOH_GITEE_RAW_BASE:-https://gitee.com/pacmandoh/omz-theme-pacmandoh/raw/main}"

DRY_RUN="${DRY_RUN:-no}"
VERBOSE="${VERBOSE:-no}"
ASSUME_YES="${ASSUME_YES:-no}"
INSTALL_PROFILE="${INSTALL_PROFILE:-interactive}"
INSTALL_OMZ="${INSTALL_OMZ:-}"
INSTALL_LAZY="${INSTALL_LAZY:-}"
INSTALL_PLUGINS="${INSTALL_PLUGINS:-}"
PROMPT_STYLE="${PROMPT_STYLE:-default}"
UPDATE_MODE="${UPDATE_MODE:-no}"

PACMANDOH_ICON_STEP=$'➤'
PACMANDOH_ICON_MENU=$'◎'
PACMANDOH_ICON_DONE=$'✓'
PACMANDOH_ICON_CONFIG=$'⚙'

PACMANDOH_CLR_LOGO=$'\033[95m'
PACMANDOH_CLR_OK=$'\033[92m'
PACMANDOH_CLR_WARN=$'\033[93m'
PACMANDOH_CLR_ERR=$'\033[91m'
PACMANDOH_CLR_MENU=$'\033[1;36m'
PACMANDOH_CLR_CONFIG=$'\033[1;34m'
PACMANDOH_CLR_RESET=$'\033[0m'
PACMANDOH_CLR_BOLD=$'\033[1m'

_pacmandoh_icon_color() {
  case "$1" in
  step) printf '%s' "$PACMANDOH_CLR_LOGO" ;;
  done) printf '%s' "$PACMANDOH_CLR_OK" ;;
  menu) printf '%s' "$PACMANDOH_CLR_MENU" ;;
  config) printf '%s' "$PACMANDOH_CLR_CONFIG" ;;
  warn) printf '%s' "$PACMANDOH_CLR_WARN" ;;
  err) printf '%s' "$PACMANDOH_CLR_ERR" ;;
  *) printf '%s' "$PACMANDOH_CLR_RESET" ;;
  esac
}

_pacmandoh_print_icon() {
  local tone=$1
  local glyph=$2

  printf '%b%s%b' "$(_pacmandoh_icon_color "$tone")" "$glyph" "$PACMANDOH_CLR_RESET"
}

step_msg() {
  local tag=$1
  local label=$2

  case "$tag" in
  zshrc | startup)
    printf '\n%s %s\n' \
      "${PACMANDOH_CLR_BOLD}$(_pacmandoh_print_icon config "$PACMANDOH_ICON_CONFIG")${PACMANDOH_CLR_RESET}" \
      "${PACMANDOH_CLR_BOLD}${label}${PACMANDOH_CLR_RESET}"
    ;;
  *)
    printf '\n%s %s\n' \
      "${PACMANDOH_CLR_BOLD}$(_pacmandoh_print_icon step "$PACMANDOH_ICON_STEP")${PACMANDOH_CLR_RESET}" \
      "${PACMANDOH_CLR_BOLD}${label}${PACMANDOH_CLR_RESET}"
    ;;
  esac
}

config_msg() {
  local label=$1
  local tone=${2:-config}

  printf '\n%s %s\n' \
    "${PACMANDOH_CLR_BOLD}$(_pacmandoh_print_icon "$tone" "$PACMANDOH_ICON_CONFIG")${PACMANDOH_CLR_RESET}" \
    "${PACMANDOH_CLR_BOLD}${label}${PACMANDOH_CLR_RESET}"
}

warn_msg() {
  printf '%s %b\n' "$(_pacmandoh_print_icon warn "$PACMANDOH_ICON_CONFIG")" "$*"
}

err_msg() {
  printf '%s %b\n' "$(_pacmandoh_print_icon err "$PACMANDOH_ICON_MENU")" "$*"
}

task_msg() {
  printf "  %s... " "$*"
}

task_done() {
  printf '%s done\n' "$(_pacmandoh_print_icon done "$PACMANDOH_ICON_DONE")"
}

task_skip() {
  printf '%s skipped\n' "$(_pacmandoh_print_icon warn "$PACMANDOH_ICON_MENU")"
}

task_fail() {
  printf '%s failed\n' "$(_pacmandoh_print_icon err "$PACMANDOH_ICON_MENU")"
}

is_dry_run() {
  [ "$DRY_RUN" == yes ]
}

dry_run_msg() {
  printf "${PACMANDOH_CLR_BOLD}[dry-run]${PACMANDOH_CLR_RESET} %s\n" "$*"
}

is_verbose() {
  [ "$VERBOSE" == yes ]
}

run_logged() {
  local log_file

  log_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh-install.XXXXXX.log") || return 1
  if is_verbose; then
    "$@"
  else
    "$@" >"$log_file" 2>&1
  fi
  local status=$?

  if [ $status -ne 0 ] && ! is_verbose; then
    err_msg "Command failed. Log: ${log_file}"
    tail -n 20 "$log_file"
  elif [ $status -eq 0 ] && ! is_verbose; then
    rm -f "$log_file"
  fi

  return $status
}

run_with_timeout() {
  local seconds=$1
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  else
    "$@"
  fi
}

pacmandoh_theme_path() {
  printf "%s/pacmandoh.zsh-theme" "$PACMANDOH_ROOT"
}

pacmandoh_show_help() {
  cat <<'EOF'
Usage: install.sh [options]

Bootstrap a Kali-inspired Oh My Zsh terminal with the pacmandoh theme.

Options:
  -y, --yes              Non-interactive install with defaults
      --minimal          Theme + Oh My Zsh only (no plugins, no lazy loaders)
      --full             Install recommended plugins and lazy conda/nvm loaders
      --plugins=LIST     Comma-separated plugins; third-party (git clone) or built-in OMZ
                         (extract, z, docker, macos, …), e.g.
                         --plugins=zsh-autosuggestions,extract,z,docker
      --no-omz           Skip Oh My Zsh installation
      --no-lazy          Skip conda/nvm lazy loaders
      --prompt=STYLE     multiline (default) or oneline
      --update           Update pacmandoh theme and installed plugins (git pull)
  -n, --dry-run          Preview actions without changing files
  -v, --verbose          Show full command output
  -h, --help             Show this help

Remote install (China — Gitee):
  curl -fsSL https://gitee.com/pacmandoh/omz-theme-pacmandoh/raw/main/install.sh | bash
  curl -fsSL https://gitee.com/pacmandoh/omz-theme-pacmandoh/raw/main/install.sh | bash -s -- --yes --full

Remote install (GitHub):
  curl -fsSL https://raw.githubusercontent.com/pacmandoh/omz-theme-pacmandoh/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/pacmandoh/omz-theme-pacmandoh/main/install.sh | bash -s -- --yes --full

Update theme and plugins:
  ./install.sh --update
  curl -fsSL https://gitee.com/pacmandoh/omz-theme-pacmandoh/raw/main/install.sh | bash -s -- --update

Environment:
  PACMANDOH_ROOT             Local checkout used instead of downloading
  PACMANDOH_GITEE_REPO       Gitee repo used when git clone is available
  PACMANDOH_GITEE_RAW_BASE   Gitee raw URL base for curl fallback
  PACMANDOH_GITHUB_REPO      GitHub repo used when git clone is available
  PACMANDOH_GITHUB_RAW_BASE  GitHub raw URL base for curl fallback
EOF
}

pacmandoh_apply_profile() {
  case "$INSTALL_PROFILE" in
  minimal)
    if [ "$INSTALL_OMZ" != no ]; then
      INSTALL_OMZ=yes
    fi
    INSTALL_LAZY=no
    INSTALL_PLUGINS=none
    ;;
  full)
    if [ "$INSTALL_OMZ" != no ]; then
      INSTALL_OMZ=yes
    fi
    if [ "$INSTALL_LAZY" != no ]; then
      INSTALL_LAZY=yes
    fi
    if [ -z "$INSTALL_PLUGINS" ]; then
      INSTALL_PLUGINS=zsh-autosuggestions,zsh-syntax-highlighting,conda-zsh-completion
    fi
    ;;
  default)
    if [ "$ASSUME_YES" == yes ]; then
      if [ "$INSTALL_OMZ" != no ]; then
        INSTALL_OMZ=yes
      fi
      if [ "$INSTALL_LAZY" != no ]; then
        INSTALL_LAZY=yes
      fi
      if [ -z "$INSTALL_PLUGINS" ]; then
        INSTALL_PLUGINS=zsh-autosuggestions,zsh-syntax-highlighting
      fi
    fi
    ;;
  esac
}
