#  _______________________________________________________________________________ 
# (  ____                                             ____            __          )
# ( /\  _`\                                          /\  _`\         /\ \         )
# ( \ \ \L\ \ __      ___    ___ ___      __      ___\ \ \/\ \    ___\ \ \___     )
# (  \ \ ,__/'__`\   /'___\/' __` __`\  /'__`\  /' _ `\ \ \ \ \  / __`\ \  _ `\   )
# (   \ \ \/\ \L\.\_/\ \__//\ \/\ \/\ \/\ \L\.\_/\ \/\ \ \ \_\ \/\ \L\ \ \ \ \ \  )
# (    \ \_\ \__/.\_\ \____\ \_\ \_\ \_\ \__/.\_\ \_\ \_\ \____/\ \____/\ \_\ \_\ )
# (     \/_/\/__/\/_/\/____/\/_/\/_/\/_/\/__/\/_/\/_/\/_/\/___/  \/___/  \/_/\/_/ )
# (                                                                               )
# (                                                                               )
#  ------------------------------------------------------------------------------- 

# virt env
virtualenv_info() {
    if [ -z "$VIRTUAL_ENV" ]; then
        echo -n ""
    else
        if [ -O "$(pwd)" ]; then
            echo -n "%{$reset_color%}(%{$terminfo[bold]%}📦 $(basename $VIRTUAL_ENV)%{$reset_color%})-%{$reset_color%}"
        else
            echo -n "%{$FG[033]%}(%{$reset_color%}%{$terminfo[bold]%}📦 $(basename $VIRTUAL_ENV)%{$reset_color$FG[033]%})-%{$reset_color%}"
        fi
    fi
}

# prompt char
prompt_char() {
    local symbol
    if git branch >/dev/null 2>/dev/null; then
        symbol='øø'
    else
        symbol=':>'
    fi
    local color
    if [ -O "$(pwd)" ]; then
        color="%{$terminfo[bold]$FG[033]%}"
    else
        color="%{$terminfo[bold]$fg[red]%}"
    fi
    echo -n "${color}${symbol}%{$reset_color%}"
}

# conda env
conda_prompt_info() {
    if [[ -z ${CONDA_DEFAULT_ENV} ]]; then
        echo -n ""
    else
        local color
        if [ -O "$(pwd)" ]; then
            color="%{$reset_color%}"
        else
            color="%{$reset_color$FG[033]%}"
        fi
        echo -n "${color}-{%{$terminfo[bold]$fg[magenta]%}%{🅒%} $CONDA_DEFAULT_ENV%{$color%}}"
    fi
}

# usr info
root_info() {
    if [ -O "$(pwd)" ]; then
        echo -n "(%{$terminfo[bold]$FG[033]%}%n<@>doh's MacBook-Pro%{$reset_color%})$(conda_prompt_info)%{$reset_color%}"
    else
        echo -n "%{$FG[033]%}(%{$terminfo[bold]$fg[red]%}root%{💀%}doh's MacBook-Pro%{$reset_color$FG[033]%})$(conda_prompt_info)%{$reset_color%}"
    fi
}

# dir col
function dir_info {
    if [ -O "$(pwd)" ]; then
        echo -n "%{$terminfo[bold]$FG[202]%}%~%{$reset_color%}"
    else
        echo -n "%{$terminfo[bold]%}%~%{$reset_color%}"
    fi
}

# line/sign color
sign_status() {
    local color
    if [ $1 -eq 1 ]; then
        if [ -O "$(pwd)" ]; then
            color="%{$reset_color%}"
        else
            color="%{$FG[033]%}"
        fi
    else
        if [ -O "$(pwd)" ]; then
            color="%{$FG[033]%}"
        else
            color="%{$fg[red]%}"
        fi
    fi 
    echo "${color}$2%{$reset_color%}"
}

# exit status
check_exit_status() {
    if [ $status -ne 0 ]; then
        echo "%{$fg[red]%} [✘] %{$reset_color%}"
    else
        echo "%{$FG[040]%} [✔] %{$reset_color%}"
    fi
}

# prompt
PROMPT="\$(sign_status 1 ╭──)\$(root_info)\$(git_prompt_info)\$(ruby_prompt_info)
\$(sign_status 1 ├)\$(sign_status 2 ' ➜ ')[\$(dir_info)]
\$(sign_status 1 ╰)\$(virtualenv_info)\$(prompt_char) "
RPROMPT="\$(check_exit_status)%{$fg[blue]$terminfo[bold]%}⧀ %* ⧁%{$reset_color%}"

# git
ZSH_THEME_GIT_PROMPT_PREFIX=" %{$FG[239]%}on%{$reset_color%} %{$fg[255]%}git@"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$FG[202]%}✘✘✘"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$FG[040]%}✔"
