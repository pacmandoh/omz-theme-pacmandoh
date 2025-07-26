#!/bin/bash

#                                               _________     ______
# ______________ _____________ _________ _____________  /________  /_
# ___  __ \  __ `/  ___/_  __ `__ \  __ `/_  __ \  __  /_  __ \_  __ \
# __  /_/ / /_/ // /__ _  / / / / / /_/ /_  / / / /_/ / / /_/ /  / / /
# _  .___/\__,_/ \___/ /_/ /_/ /_/\__,_/ /_/ /_/\__,_/  \____//_/ /_/
# /_/

#%% ============= utils ============= %%#
select_option() {
  mapfile -t choices < <(printf "%s\n" "$@" | grep -vE "^multi$")
  selected=0
  typeset -A multi_selected=()
  tput sc

  while true; do
    tput rc
    for index in "${!choices[@]}"; do
      if [[ " ${multi_selected[*]} " == *" $index "* ]]; then
        if [ "$index" -eq $selected ]; then
          printf "\033[1m\033[4m\033[34m\u25CF %s\033[0m\n" "${choices[$index]}"
        else
          printf "\033[1m\033[34m\u25CF %s\033[0m\n" "${choices[$index]}"
        fi
      elif [ "$index" -eq $selected ]; then
        if printf '%s\n' "$@" | grep -q "multi"; then
          if [ "$selected" -eq "$((${#choices[@]} - 1))" ]; then
            printf "\033[1m\033[4m\033[92m✔ \033[34m%s\033[0m\n" "${choices[$index]}"
          else
            printf "\033[4m\033[34m○ %s\033[0m\n" "${choices[$index]}"
          fi
        else
          printf "\033[1m\033[4m\033[34m\u25CF %s\033[0m\n" "${choices[$index]}"
        fi
      else
        echo -e "○ ${choices[$index]}"
      fi
    done

    read -rn1 -s key
    case "$key" in
    A)
      if [ $selected -gt 0 ]; then
        selected=$((selected - 1))
      fi
      ;;
    B)
      if [ $selected -lt $((${#choices[@]} - 1)) ]; then
        selected=$((selected + 1))
      fi
      ;;
    "")
      if printf '%s\n' "$@" | grep -q "multi"; then
        if [ "${choices[$selected]}" == "apply" ]; then
          break
        elif [ "${choices[$selected]}" == "all" ]; then
          unset "choices[0]"
          unset "choices[${#choices[@]}]"
          for index in "${!choices[@]}"; do
            multi_selected["${choices[$index]}"]=$index
          done
          break
        else
          if [[ " ${multi_selected[*]} " == *" $selected "* ]]; then
            unset "multi_selected[${choices[$selected]}]"
          else
            multi_selected["${choices[$selected]}"]="$selected"
          fi
        fi
      else
        break
      fi
      ;;
    esac
  done

  if printf '%s\n' "$@" | grep -q "multi"; then
    multi_selected_option=("${!multi_selected[@]}")
  else
    selected_option="${choices[$selected]}"
  fi
  tput rc && tput ed
}
#%% ================================= %%#

clear
tput civis
printf "\033[1mWelcome to PacmanDoh's installer!\n\n"

echo -e '\033[95m                                              _________     ______'
sleep 0.05
echo '______________ _____________ _________ _____________  /________  /_'
sleep 0.05
# shellcheck disable=SC2016
# shellcheck disable=SC1003
echo '___  __ \  __ `/  ___/_  __ `__ \  __ `/_  __ \  __  /_  __ \_  __ \'
sleep 0.05
echo '__  /_/ / /_/ // /__ _  / / / / / /_/ /_  / / / /_/ / / /_/ /  / / /'
sleep 0.05
echo '_  .___/\__,_/ \___/ /_/ /_/ /_/\__,_/ /_/ /_/\__,_/  \____//_/ /_/'
sleep 0.05
echo -e '/_/\033[0m'
sleep 0.05
echo

printf "\033[1mOperate:\033[0m\n"
printf "\033[1m▲ ▼ to select | ↵ to apply\033[0m\n\n"
printf "\033[1m1. Need to install \033[93moh-my-zsh\033[0m\033[1m?\033[0m\n"
need_omz=(no yes)
select_option "${need_omz[@]}"
printf "\033[1A\033[K"

#================================== omz install ==================================#
if [ "$selected_option" == yes ]; then
  printf "\033[1mInstallation \033[91msource\033[0m\033[1m:\033[0m\n"
  # printf "+--------------------------------------------+\n"
  # printf "* github_installer: source repository        *\n"
  # printf "* mirrors_tsinghua: for China                *\n"
  # printf "* outside_installer: mirrored outside github *\n"
  # printf "+--------------------------------------------+\n"
  _source=("github" "mirrors_tsinghua" "outside_installer")
  select_option "${_source[@]}"
  tput cuu 1 && tput ed
  # check zsh
  if ! command -v zsh >/dev/null 2>&1; then
    printf "\033[1m\033[91mZsh is not installed!\033[0m \033[91m✘\033[0m\n"
    printf "\033[1mPlease install \033[95mzsh\033[0m \033[1mbefore continuing this installer.\033[0m\n"
    printf "\033[1mExample (Ubuntu/Debian):\033[0m sudo apt install zsh\n"
    printf "\033[1mThen re-run: \033[93m./install.sh\033[0m\n"
    sleep 2
    exit 1
  fi
  if [ "$selected_option" == "mirrors_tsinghua" ]; then
    # tsinghua installer!
    if [ -d "$HOME/.oh-my-zsh" ]; then
      printf "\033[1m\033[91mOh-My-Zsh already exists! \033[91m✘\033[0m\n"
      sleep 1
      tput cuu 1 && tput ed
    else
      printf "\033[1m\033[92mInstalling...\033[0m\n"
      git clone https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git "$HOME/ohmyzsh" &>/dev/null &&
      REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git RUNZSH=no bash ~/ohmyzsh/tools/install.sh < /dev/null &>/dev/null &&
    [ -d "$HOME/ohmyzsh" ] && rm -rf "$HOME/ohmyzsh"
      tput cuu 1 && tput ed
      printf "\033[1mDone!\033[92m ✔\033[0m\n"
      sleep 1 
      tput cuu 1 && tput ed
    fi
  else
    _selected_option="$selected_option"
    printf "\033[1mInstallation \033[92mtool\033[0m\033[1m:\033[0m\n"
    # printf "+-----------------------------------------------+\n"
    # printf "* curl: installed by default on MacOS and Linux *\n"
    # printf "* wget: MacOS needs to be installed by yourself *\n"
    # printf "* fetch: for BSDs                               *\n"
    # printf "+-----------------------------------------------+\n"
    tools=("curl" "wget" "fetch")
    select_option "${tools[@]}"
    while ! $selected_option --version >/dev/null 2>/dev/null; do
      tput cuu 1 && tput ed
      printf "\033[1m\033[91mTool isn't installed! ✘\033[0m\n"
      select_option "${tools[@]}"
    done
    tput cuu 1 && tput ed
    # github/outside downloader!
    if [ -d "$HOME/.oh-my-zsh" ]; then
      printf "\033[1m\033[91mOh-My-Zsh already exists! \033[91m✘\033[0m\n"
      sleep 1
      tput cuu 1 && tput ed
    else
      printf "\033[1m\033[92mInstalling...\033[0m\n"
      exec &>/dev/null
      if [ "$_selected_option" == github ]; then
        [ "$selected_option" == curl ] && RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        [ "$selected_option" == wget ] && RUNZSH=no sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        [ "$selected_option" == fetch ] && RUNZSH=no sh -c "$(fetch -o - https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      else
        [ "$selected_option" == curl ] && RUNZSH=no sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
        [ "$selected_option" == wget ] && RUNZSH=no sh -c "$(wget -O- https://install.ohmyz.sh/)"
        [ "$selected_option" == fetch ] && RUNZSH=no sh -c "$(fetch -o - https://install.ohmyz.sh/)"
      fi
      exec &>/dev/tty
      tput cuu 1 && tput ed
      printf "\033[1mDone!\033[92m ✔\033[0m\n"
      sleep 1 && tput cuu 1 && tput ed
    fi
  fi
fi
#=================================================================================#

#============================= install theme-pacmandoh ===========================#
printf "\033[1m2. Installing \033[95mpacmandoh...\033[0m\n"
sleep 1
tput cuu 1 && tput ed
[ ! -d "$HOME/.oh-my-zsh" ] && printf "\033[1m\033[91mOh-My-Zsh isn't installed! ✘\n" && exit
cp ./pacmandoh.zsh-theme "$HOME/.oh-my-zsh/custom/themes"
printf "\033[1mDone!\033[92m ✔\033[0m\n" && sleep 1 && tput cuu 1 && tput ed

printf "\033[1m2. Modify \033[93mZSH_THEME\033[0m \033[1min .zshrc?\033[0m\n"
config_zshrc=("auto" "manual")
select_option "${config_zshrc[@]}"
if [ "$selected_option" == auto ]; then
  [ "$ZSH_THEME" != "random" ] && tput cuu 1 && tput ed &&
    sed -i -E 's/^ZSH_THEME=.*/ZSH_THEME="pacmandoh"/' "$HOME/.zshrc" &&
    printf "\033[1mDone!\033[92m ✔\033[0m\n" &&
    sleep 1 &&
    tput cuu 1 && tput ed

  [ "$ZSH_THEME" == "random" ] &&
    # TODO: added automatic addition of "pacmandoh" to ZSH_THEME_RANDOM_CANDIDATES
    printf "\033[1mCurrent theme is \"random\" \033[91m✘\033[0m\n" && sleep 1 &&
    tput cuu 1 && tput ed
else
  tput cuu 1 && tput ed
  printf "\033[1mAdd theme to .zshrc manually\033[93m ⚠️\033[0m\n"
  sleep 1
  tput cuu 1 && tput ed
fi
#=================================================================================#

#============================== pacmandoh optional ===============================#
printf "\033[1m3. Additional config options:\033[0m\n"
# printf "+-----------------------------------------+\n"
# printf "* multi or oneline ? default: multiline   *\n"
# printf "* need timer ? default: yes               *\n"
# printf "* newline before prompt ? default: yes    *\n"
# printf "+-----------------------------------------+\n"

printf "\033[1m- multiline or oneline?\033[0m\n"
options=("oneline" "default")
select_option "${options[@]}"
! grep -q "PACMANDOH_PROMPT_ALTERNATIVE" "$HOME/.zshrc" && [ "$selected_option" == oneline ] && echo -e \
  "\nPACMANDOH_PROMPT_ALTERNATIVE=oneline" >>"$HOME/.zshrc"

if [ "$selected_option" == oneline ]; then
  tput cuu 2 && tput ed
  printf "\033[1mBoth is \033[91mno\033[0m \033[1min oneline!\033[0m\n" &&
    sleep 1 &&
    tput cuu 1 && tput ed
else
  tput cuu 1 && tput ed
  options=("no" "yes")
  printf "\033[1m- Need timer?\033[0m\n"
  select_option "${options[@]}"
  ! grep -q "PACMANDOH_NEED_TIMER" "$HOME/.zshrc" && [ "$selected_option" == no ] && echo -e \
    "\nPACMANDOH_NEED_TIMER=no" >>"$HOME/.zshrc"
  tput cuu 1 && tput ed

  printf "\033[1m- Newline before PROMPT?\033[0m\n"
  select_option "${options[@]}"
  ! grep -q "PACMANDOH_NEWLINE_BEFORE_PROMPT" "$HOME/.zshrc" && [ "$selected_option" == no ] && echo -e \
    "\nPACMANDOH_NEWLINE_BEFORE_PROMPT=no" >>"$HOME/.zshrc"
  tput cuu 2 && tput ed
fi
#=================================================================================#

#============================ custom oh-my-zsh plugins ===========================#
printf "\033[1m4. Oh-My-Zsh plugins you need:\033[0m\n"
# printf "+-----------------------------------------+\n"
# printf "* If you want to install them all, select *\n"
# printf "* all without clicking apply. In other    *\n"
# printf "* cases, you can select the ones you want *\n"
# printf "* to install (multiple choices)           *\n"
# printf "+-----------------------------------------+\n"
plugins=("all" "zsh-autosuggestions" "zsh-syntax-highlighting" "conda-zsh-completion" "apply")
select_option "${plugins[@]}" "multi"
tput cuu 1 && tput ed

if [ ${#multi_selected_option[@]} -ne 0 ]; then
  git_source=("github" "gitee")
  printf "\033[1mSelect git repository:\033[0m\n"
  select_option "${git_source[@]}"
  tput cuu 1 && tput ed
  # git clone plugins
  if [ "$selected_option" == gitee ]; then
    [ ${#multi_selected_option[@]} -ne 0 ] &&
      for i in "${multi_selected_option[@]}"; do
        if [ -d "${HOME}/.oh-my-zsh/custom/plugins/$i" ]; then
          printf "\033[1m%s already exists \033[91m✘\033[0m\n" "$i" && sleep 1 &&
            tput cuu 1 && tput ed
        else
          printf "\033[1mInstalling...\033[0m\n"
          exec &>/dev/null &&
          git clone "https://gitee.com/dou-aqqq/${i}.git" "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/${i}" &&
          exec &>/dev/tty && tput cuu 1 && tput ed &&
          printf "\033[1m%s installed\033[92m ✔\033[0m\n" "${i}" && sleep 1 && tput cuu 1 && tput ed
        fi
      done
  else
    [ ${#multi_selected_option[@]} -ne 0 ] &&
      for i in "${multi_selected_option[@]}"; do
        if [ -d "${HOME}/.oh-my-zsh/custom/plugins/$i" ]; then
          printf "\033[1m%s already exists \033[91m✘\033[0m\n" "$i" && sleep 1 &&
            tput cuu 1 && tput ed
        else
          printf "\033[1mInstalling...\033[0m\n"
          exec &>/dev/null
          [ "$i" == "zsh-autosuggestions" ] && 
            git clone https://github.com/zsh-users/zsh-autosuggestions.git \
            "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" && tput cuu 1 && tput ed &&
            printf "\033[1m%s installed\033[92m ✔\033[0m\n" "${i}" && sleep 1 && tput cuu 1 && tput ed
          [ "$i" == "zsh-syntax-highlighting" ] && 
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" && tput cuu 1 && tput ed &&
            printf "\033[1m%s installed\033[92m ✔\033[0m\n" "${i}" && sleep 1 && tput cuu 1 && tput ed
          [ "$i" == "conda-zsh-completion" ] && 
            git clone https://github.com/conda-incubator/conda-zsh-completion.git \
            "${ZSH_CUSTOM:=${HOME}/.oh-my-zsh/custom}/plugins/conda-zsh-completion" && tput cuu 1 && tput ed &&
            printf "\033[1m%s installed\033[92m ✔\033[0m\n" "${i}" && sleep 1 && tput cuu 1 && tput ed
          exec &>/dev/tty
        fi
      done
  fi
fi

printf "\033[1mAdd plugins to ~/.zshrc?\033[0m\n"
select_option "${config_zshrc[@]}"
[ ${#multi_selected_option[@]} -ne 0 ] && [ "$selected_option" == auto ] &&
  for i in "${multi_selected_option[@]}"; do
    sed -i "s/\(plugins=([^)]*\))/\1 $i)/" "$HOME/.zshrc"
  done

printf "\n\033[1mDone! 🎉\033[92m ✔\033[0m\n"
sleep 1
clear
tput init
zsh
