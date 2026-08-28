#!/usr/bin/env bash

PACMANDOH_UI_GRAY=$'\033[90m'
PACMANDOH_UI_CYAN=$PACMANDOH_CLR_MENU
PACMANDOH_UI_BLUE=$PACMANDOH_CLR_CONFIG
PACMANDOH_UI_RESET=$PACMANDOH_CLR_RESET
PACMANDOH_UI_ICON_EMPTY='○'
PACMANDOH_UI_ICON_SOLID='●'

_PACMANDOH_MENU_LINES=0

_pacmandoh_ui_hide_cursor() {
  tput civis 2>/dev/null || printf '\033[?25l'
}

_pacmandoh_ui_show_cursor() {
  tput cnorm 2>/dev/null || printf '\033[?25h'
}

_pacmandoh_ui_restore_terminal() {
  _pacmandoh_ui_show_cursor
  if [[ -n "${_PACMANDOH_UI_STTY:-}" ]]; then
    stty "${_PACMANDOH_UI_STTY}" 2>/dev/null || stty sane 2>/dev/null || true
  else
    stty sane 2>/dev/null || true
  fi
}

_pacmandoh_menu_term_lines() {
  local lines=24

  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    lines=$(tput lines 2>/dev/null || echo 24)
  fi
  [[ "$lines" =~ ^[0-9]+$ ]] || lines=24
  if ((lines < 8)); then
    lines=24
  fi
  printf '%s' "$lines"
}

_pacmandoh_menu_items_per_page() {
  local term_lines=$(_pacmandoh_menu_term_lines)
  local available=$((term_lines - 18))

  if ((available < 3)); then
    available=3
  elif ((available > 50)); then
    available=50
  fi
  printf '%s' "$available"
}

_pacmandoh_menu_track_line() {
  _PACMANDOH_MENU_LINES=$((_PACMANDOH_MENU_LINES + 1))
}

_pacmandoh_menu_print_line() {
  printf '\r\033[2K%b\n' "$1"
  _pacmandoh_menu_track_line
}

_pacmandoh_menu_format_title() {
  local title=$1
  local scroll=$2
  local suffix=${3:-}

  printf '%s %b%s%b%s' \
    "$(_pacmandoh_print_icon menu "$PACMANDOH_ICON_MENU")" \
    "$PACMANDOH_UI_BLUE" "${title}${scroll}" "$PACMANDOH_UI_RESET" \
    "$suffix"
}

_pacmandoh_menu_erase() {
  local i

  if ((_PACMANDOH_MENU_LINES > 0)); then
    for ((i = 0; i < _PACMANDOH_MENU_LINES; i++)); do
      printf '\033[1A\033[2K'
    done
  fi
  _PACMANDOH_MENU_LINES=0
}

_pacmandoh_menu_clamp_view() {
  local total=$1
  local items_per_page=$2
  local -n _top_index=$3
  local -n _cursor_pos=$4
  local max_top=0
  local visible_count=0

  if ((total > items_per_page)); then
    max_top=$((total - items_per_page))
  fi
  if ((_top_index > max_top)); then
    _top_index=$max_top
  fi
  if ((_top_index < 0)); then
    _top_index=0
  fi

  visible_count=$((total - _top_index))
  if ((visible_count > items_per_page)); then
    visible_count=$items_per_page
  fi
  if ((visible_count < 1)); then
    visible_count=1
  fi

  if ((_cursor_pos >= visible_count)); then
    _cursor_pos=$((visible_count - 1))
  fi
  if ((_cursor_pos < 0)); then
    _cursor_pos=0
  fi
}

_pacmandoh_menu_move_up() {
  local total=$1
  local items_per_page=$2
  local -n _top_index=$3
  local -n _cursor_pos=$4

  if ((_cursor_pos > 0)); then
    _cursor_pos=$((_cursor_pos - 1))
    return
  fi
  if ((_top_index > 0)); then
    _top_index=$((_top_index - 1))
  fi
}

_pacmandoh_menu_move_down() {
  local total=$1
  local items_per_page=$2
  local -n _top_index=$3
  local -n _cursor_pos=$4
  local absolute_index=0
  local visible_count=0

  absolute_index=$((_top_index + _cursor_pos))
  if ((absolute_index >= total - 1)); then
    return
  fi

  visible_count=$((total - _top_index))
  if ((visible_count > items_per_page)); then
    visible_count=$items_per_page
  fi

  if ((_cursor_pos < visible_count - 1)); then
    _cursor_pos=$((_cursor_pos + 1))
  elif ((_top_index + visible_count < total)); then
    _top_index=$((_top_index + 1))
  fi
}

_pacmandoh_menu_page_left() {
  local items_per_page=$1
  local -n _top_index=$2
  local -n _cursor_pos=$3

  if ((_top_index > 0)); then
    _top_index=$((_top_index - items_per_page))
    if ((_top_index < 0)); then
      _top_index=0
    fi
    _cursor_pos=0
  fi
}

_pacmandoh_menu_page_right() {
  local total=$1
  local items_per_page=$2
  local -n _top_index=$3
  local -n _cursor_pos=$4
  local remaining=0

  if ((_top_index + items_per_page < total)); then
    _top_index=$((_top_index + items_per_page))
    remaining=$((total - _top_index))
    if ((remaining < items_per_page)); then
      _top_index=$((total - items_per_page))
      if ((_top_index < 0)); then
        _top_index=0
      fi
    fi
    _cursor_pos=0
  fi
}

_pacmandoh_menu_abort() {
  _pacmandoh_menu_erase
  _pacmandoh_ui_restore_terminal
}

_pacmandoh_menu_begin() {
  _PACMANDOH_MENU_LINES=0

  if [[ -t 0 ]] && command -v stty >/dev/null 2>&1; then
    _PACMANDOH_UI_STTY=$(stty -g 2>/dev/null || true)
    stty -echo -icanon 2>/dev/null || true
  fi

  _pacmandoh_ui_hide_cursor
  trap '_pacmandoh_menu_abort' EXIT INT TERM
}

_pacmandoh_menu_finish() {
  _pacmandoh_menu_erase
  trap - EXIT INT TERM
  _pacmandoh_ui_restore_terminal
}

_pacmandoh_read_key() {
  local key rest rest2

  IFS= read -r -s -n 1 key </dev/tty 2>/dev/null || IFS= read -r -s -n 1 key || {
    echo "QUIT"
    return 0
  }

  if [[ -z "$key" ]]; then
    echo "ENTER"
    return 0
  fi

  case "$key" in
  $'\n' | $'\r')
    echo "ENTER"
    ;;
  ' ')
    echo "SPACE"
    ;;
  q | Q)
    echo "QUIT"
    ;;
  a | A)
    echo "ALL"
    ;;
  n | N)
    echo "NONE"
    ;;
  j | J)
    echo "DOWN"
    ;;
  k | K)
    echo "UP"
    ;;
  h | H)
    echo "PAGE_LEFT"
    ;;
  l | L)
    echo "PAGE_RIGHT"
    ;;
  $'\x03')
    echo "QUIT"
    ;;
  $'\x1b')
    if IFS= read -r -s -n 1 -t 0.01 rest </dev/tty 2>/dev/null || IFS= read -r -s -n 1 -t 0.01 rest; then
      if [[ "$rest" == "[" ]]; then
        if IFS= read -r -s -n 1 -t 0.01 rest2 </dev/tty 2>/dev/null || IFS= read -r -s -n 1 -t 0.01 rest2; then
          case "$rest2" in
          A) echo "UP" ;;
          B) echo "DOWN" ;;
          C) echo "PAGE_RIGHT" ;;
          D) echo "PAGE_LEFT" ;;
          *) echo "OTHER" ;;
          esac
        else
          echo "QUIT"
        fi
      elif [[ "$rest" == "O" ]]; then
        if IFS= read -r -s -n 1 -t 0.01 rest2 </dev/tty 2>/dev/null || IFS= read -r -s -n 1 -t 0.01 rest2; then
          case "$rest2" in
          A) echo "UP" ;;
          B) echo "DOWN" ;;
          *) echo "OTHER" ;;
          esac
        else
          echo "OTHER"
        fi
      else
        echo "QUIT"
      fi
    else
      echo "QUIT"
    fi
    ;;
  *)
    echo "OTHER"
    ;;
  esac
}

_pacmandoh_menu_draw_footer() {
  local mode=$1
  local paginated=$2

  if [[ "$mode" == multi ]]; then
    if [[ "$paginated" == yes ]]; then
      _pacmandoh_menu_print_line "${PACMANDOH_UI_GRAY}↑↓ move | ←→ page | Space | A all | N clear | Enter | Q quit${PACMANDOH_UI_RESET}"
    else
      _pacmandoh_menu_print_line "${PACMANDOH_UI_GRAY}↑↓ move | Space | A all | N clear | Enter | Q quit${PACMANDOH_UI_RESET}"
    fi
  else
    if [[ "$paginated" == yes ]]; then
      _pacmandoh_menu_print_line "${PACMANDOH_UI_GRAY}↑↓ move | ←→ page | Enter | Q quit${PACMANDOH_UI_RESET}"
    else
      _pacmandoh_menu_print_line "${PACMANDOH_UI_GRAY}↑↓ move | Enter | Q quit${PACMANDOH_UI_RESET}"
    fi
  fi
}

_pacmandoh_menu_draw_items_single() {
  local -n _items=$1
  local total=$2
  local items_per_page=$3
  local top_index=$4
  local cursor_pos=$5
  local i=0
  local rel_pos=0
  local end_index=0
  local visible_count=0
  local line=''

  visible_count=$((total - top_index))
  if ((visible_count > items_per_page)); then
    visible_count=$items_per_page
  fi
  end_index=$((top_index + visible_count))

  for ((i = top_index; i < end_index; i++)); do
    rel_pos=$((i - top_index))
    if [[ $rel_pos -eq $cursor_pos ]]; then
      line="${PACMANDOH_UI_CYAN}${PACMANDOH_ICON_STEP} ${_items[$i]}${PACMANDOH_UI_RESET}"
    else
      line="  ${_items[$i]}"
    fi
    _pacmandoh_menu_print_line "$line"
  done
}

_pacmandoh_menu_draw_items_multi() {
  local -n _items=$1
  local -n _selected=$2
  local total=$3
  local items_per_page=$4
  local top_index=$5
  local cursor_pos=$6
  local i=0
  local rel_pos=0
  local end_index=0
  local visible_count=0
  local mark=$PACMANDOH_UI_ICON_EMPTY
  local line=''

  visible_count=$((total - top_index))
  if ((visible_count > items_per_page)); then
    visible_count=$items_per_page
  fi
  end_index=$((top_index + visible_count))

  for ((i = top_index; i < end_index; i++)); do
    rel_pos=$((i - top_index))
    mark=$PACMANDOH_UI_ICON_EMPTY
    if [[ ${_selected[$i]} == true ]]; then
      mark=$PACMANDOH_UI_ICON_SOLID
    fi
    if [[ $rel_pos -eq $cursor_pos ]]; then
      line="${PACMANDOH_UI_CYAN}${PACMANDOH_ICON_STEP} ${mark} ${_items[$i]}${PACMANDOH_UI_RESET}"
    else
      line="  ${mark} ${_items[$i]}"
    fi
    _pacmandoh_menu_print_line "$line"
  done
}

_pacmandoh_menu_single() {
  local title=$1
  shift
  local -a items=("$@")
  local total=${#items[@]}
  local key
  local items_per_page=0
  local top_index=0
  local cursor_pos=0
  local current_pos=0
  local scroll_indicator=''
  local paginated=no

  [[ $total -gt 0 ]] || return 1

  _pacmandoh_menu_begin
  items_per_page=$(_pacmandoh_menu_items_per_page)
  if ((total > items_per_page)); then
    paginated=yes
  else
    items_per_page=$total
  fi

  while true; do
    _pacmandoh_menu_clamp_view "$total" "$items_per_page" top_index cursor_pos
    _pacmandoh_menu_erase

    scroll_indicator=""
    if [[ "$paginated" == yes ]]; then
      current_pos=$((top_index + cursor_pos + 1))
      scroll_indicator=" ${PACMANDOH_UI_GRAY}[${current_pos}/${total}]${PACMANDOH_UI_RESET}"
    fi
    if [[ -n "$title" ]]; then
      _pacmandoh_menu_print_line "$(_pacmandoh_menu_format_title "$title" "$scroll_indicator")"
    fi

    _pacmandoh_menu_draw_items_single items "$total" "$items_per_page" "$top_index" "$cursor_pos"
    _pacmandoh_menu_draw_footer single "$paginated"

    key=$(_pacmandoh_read_key)
    case "$key" in
    UP)
      _pacmandoh_menu_move_up "$total" "$items_per_page" top_index cursor_pos
      ;;
    DOWN)
      _pacmandoh_menu_move_down "$total" "$items_per_page" top_index cursor_pos
      ;;
    PAGE_LEFT)
      if [[ "$paginated" == yes ]]; then
        _pacmandoh_menu_page_left "$items_per_page" top_index cursor_pos
      fi
      ;;
    PAGE_RIGHT)
      if [[ "$paginated" == yes ]]; then
        _pacmandoh_menu_page_right "$total" "$items_per_page" top_index cursor_pos
      fi
      ;;
    ENTER)
      PACMANDOH_MENU_RESULT="${items[$((top_index + cursor_pos))]}"
      _pacmandoh_menu_finish
      return 0
      ;;
    QUIT)
      _pacmandoh_menu_finish
      return 1
      ;;
    esac
  done
}

_pacmandoh_menu_multi() {
  local title=$1
  shift
  local -a items=("$@")
  local total=${#items[@]}
  local key
  local -a selected=()
  local i selected_count
  local items_per_page=0
  local top_index=0
  local cursor_pos=0
  local current_pos=0
  local scroll_indicator=''
  local paginated=no

  [[ $total -gt 0 ]] || return 1

  for ((i = 0; i < total; i++)); do
    selected[i]=false
  done

  _pacmandoh_menu_begin
  items_per_page=$(_pacmandoh_menu_items_per_page)
  if ((total > items_per_page)); then
    paginated=yes
  else
    items_per_page=$total
  fi

  while true; do
    _pacmandoh_menu_clamp_view "$total" "$items_per_page" top_index cursor_pos
    _pacmandoh_menu_erase

    selected_count=0
    for ((i = 0; i < total; i++)); do
      if [[ ${selected[$i]} == true ]]; then
        selected_count=$((selected_count + 1))
      fi
    done

    scroll_indicator=""
    if [[ "$paginated" == yes ]]; then
      current_pos=$((top_index + cursor_pos + 1))
      scroll_indicator=" ${PACMANDOH_UI_GRAY}[${current_pos}/${total}]${PACMANDOH_UI_RESET}"
    fi

    _pacmandoh_menu_print_line "$(_pacmandoh_menu_format_title "$title" "$scroll_indicator" " ${PACMANDOH_UI_GRAY}(${selected_count}/${total} selected)${PACMANDOH_UI_RESET}")"
    _pacmandoh_menu_draw_items_multi items selected "$total" "$items_per_page" "$top_index" "$cursor_pos"
    _pacmandoh_menu_draw_footer multi "$paginated"

    key=$(_pacmandoh_read_key)
    case "$key" in
    UP)
      _pacmandoh_menu_move_up "$total" "$items_per_page" top_index cursor_pos
      ;;
    DOWN)
      _pacmandoh_menu_move_down "$total" "$items_per_page" top_index cursor_pos
      ;;
    PAGE_LEFT)
      if [[ "$paginated" == yes ]]; then
        _pacmandoh_menu_page_left "$items_per_page" top_index cursor_pos
      fi
      ;;
    PAGE_RIGHT)
      if [[ "$paginated" == yes ]]; then
        _pacmandoh_menu_page_right "$total" "$items_per_page" top_index cursor_pos
      fi
      ;;
    SPACE)
      i=$((top_index + cursor_pos))
      if [[ ${selected[$i]} == true ]]; then
        selected[$i]=false
      else
        selected[$i]=true
      fi
      ;;
    ALL)
      for ((i = 0; i < total; i++)); do
        selected[i]=true
      done
      ;;
    NONE)
      for ((i = 0; i < total; i++)); do
        selected[i]=false
      done
      ;;
    ENTER)
      PACMANDOH_MENU_RESULT_ITEMS=()
      for i in "${!items[@]}"; do
        if [[ ${selected[$i]} == true ]]; then
          PACMANDOH_MENU_RESULT_ITEMS+=("${items[$i]}")
        fi
      done
      _pacmandoh_menu_finish
      return 0
      ;;
    QUIT)
      PACMANDOH_MENU_RESULT_ITEMS=()
      _pacmandoh_menu_finish
      return 1
      ;;
    esac
  done
}

pacmandoh_print_banner() {
  clear
  _pacmandoh_ui_show_cursor
  printf "\033[1mPacmanDoh Terminal Installer\n\n"
  is_dry_run && printf "\033[1mDry-run mode: no files will be changed and no repositories will be cloned.\033[0m\n"
  is_verbose && printf "\033[1mVerbose mode: command output will be shown.\033[0m\n"
  printf "\n"

  echo -e '\033[95m                                              _________     ______'
  echo '______________ _____________ _________ _____________  /________  /_'
  echo '___  __ \  __ `/  ___/_  __ `__ \  __ `/_  __ \  __  /_  __ \_  __ \'
  echo '__  /_/ / /_/ // /__ _  / / / / / /_/ /_  / / / /_/ / / /_/ /  / / /'
  echo '_  .___/\__,_/ \___/ /_/ /_/ /_/\__,_/ /_/ /_/\__,_/  \____//_/ /_/'
  echo -e '/_/\033[0m'
  echo
  printf "\033[1mOperate:\033[0m\n"
  printf '%s install step  %s select  %s configure  %s done\n' \
    "$(_pacmandoh_print_icon step "$PACMANDOH_ICON_STEP")" \
    "$(_pacmandoh_print_icon menu "$PACMANDOH_ICON_MENU")" \
    "$(_pacmandoh_print_icon config "$PACMANDOH_ICON_CONFIG")" \
    "$(_pacmandoh_print_icon done "$PACMANDOH_ICON_DONE")"
  printf "\033[1m↑↓ move | Enter confirm | Space multi-select | Q quit\033[0m\n"
  printf '\n'
}
