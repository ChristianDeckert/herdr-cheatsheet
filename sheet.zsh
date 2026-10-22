#!/bin/zsh
# Cheat-sheet panel: just recipes of the focused pane's project, herdr and terminal keybindings.
# Rows marked ▸ run on click. Redraws only when something changes. Keys: r = refresh, q = close panel.
H="${HERDR_BIN_PATH:-herdr}"
ROOT="${0:A:h}"
CS_ROOT=$ROOT
source "$ROOT/lib/config.zsh"
CONFIG=$HERDR_CONFIG
TERMKEYS=$CHEATSHEET_TERMINAL_KEYS
LABEL="cheatsheet"
zmodload -F zsh/stat b:zstat

typeset -A KEYS ALIAS
typeset -a OUT ACT PLAIN
B=$'\e[1m' D=$'\e[2m' C=$'\e[36m' Y=$'\e[33m' M=$'\e[35m' R=$'\e[0m'
MOUSE_ON=$'\e[?1000h\e[?1006h' MOUSE_OFF=$'\e[?1000l\e[?1006l'

fmt_key() { # "prefix+alt+r" -> "^B ⌥r"
  local k=$1
  k=${k//prefix+/$PREFIX }; k=${k//alt+/⌥}; k=${k//shift+/⇧}; k=${k//cmd+/⌘}; k=${k//super+/⌘}
  while [[ $k =~ 'ctrl\+(.)' ]]; do k=${k/ctrl+$match[1]/^${(U)match[1]}}; done
  print -r -- $k
}

load_herdr_keys() {
  KEYS=()
  local name val
  # defaults are the commented `# name = "value"` lines in the [keys] section
  "$H" --default-config | awk '/^\[keys\]/{k=1;next} /^\[/{k=0} k' |
    sed -nE 's/^# ([a-z_]+) = "([^"]*)".*/\1 \2/p' | while read -r name val; do KEYS[$name]=$val; done
  awk '/^\[keys\]/{k=1;next} /^\[/{k=0} k' "$CONFIG" 2>/dev/null |
    sed -nE 's/^([a-z_]+) *= *"([^"]*)".*/\1 \2/p' | while read -r name val; do KEYS[$name]=$val; done
  PREFIX=$(fmt_key "${KEYS[prefix]:-ctrl+b}")
}

row() { # key desc color [action]
  local kw=13 dw=$(( COLS - 17 )) mark=" " desc=$2 key
  (( dw < 8 )) && dw=8
  [[ -n "$4" ]] && mark="▸"
  key=${1[1,kw]} desc=${desc[1,dw]}
  PLAIN+=("$(printf " %s%-${kw}s %s" "$mark" "$key" "$desc")")
  if [[ -n "$4" ]]; then
    OUT+=("$(printf " ${B}%s${R}%s%-${kw}s%s %s" "$mark" "$3" "$key" "$R" "$desc")")
  else
    OUT+=("$(printf "  ${D}%-${kw}s %s${R}" "$key" "$desc")")
  fi
  ACT+=("$4")
}

line() { OUT+=("$1"); PLAIN+=(""); ACT+=("") }

header() { (( ${#OUT} )) && line ""; line "${B}$1${R}" }

# Sets DIR (project dir to show) and TPANE (main pane in this tab that actions target).
locate() {
  local all p d
  all=$("$H" pane list 2>/dev/null) || return
  read -r p d < <(print -r -- "$all" | jq -r --arg w "$HERDR_WORKSPACE_ID" --arg s "$HERDR_PANE_ID" \
    '.result.panes[] | select(.focused and .workspace_id == $w and .pane_id != $s and .label != "cheatsheet")
     | "\(.pane_id) \(.foreground_cwd // .cwd)"' | head -1)
  [[ -n "$d" ]] && { DIR=$d; LAST_FOCUSED=$p }
  # actions need a pane in this tab: the last focused one if it lives here, else the first non-sheet pane
  TPANE=$(print -r -- "$all" | jq -r --arg t "$HERDR_TAB_ID" --arg s "$HERDR_PANE_ID" --arg l "$LAST_FOCUSED" \
    '[.result.panes[] | select(.tab_id == $t and .pane_id != $s and .label != "cheatsheet")]
     | (map(select(.pane_id == $l)) + .) | first | .pane_id // empty')
  if [[ -z "$DIR" ]]; then
    DIR=$(print -r -- "$all" | jq -r --arg p "$TPANE" '.result.panes[] | select(.pane_id == $p) | .foreground_cwd // .cwd' | head -1)
  fi
  DIR=${DIR:-$PWD}
}

find_up() { # dir name... -> first match walking up
  local d=$1; shift
  while :; do
    for n in "$@"; do [[ -f "$d/$n" ]] && { print -r -- "$d/$n"; return }; done
    [[ "$d" == / ]] && return 1
    d=${d:h}
  done
}

render_just() {
  local jf=$(find_up "$1" justfile Justfile .justfile) a c
  if [[ -z "$jf" ]]; then
    header "just"; line " ${D}no justfile in ${1/#$HOME/~}${R}"; return
  fi
  header "just — ${jf:h:t}"
  (( $+commands[just] )) || { line " ${D}install just to list recipes${R}"; return }
  ALIAS=()
  local af="${jf:h}/$CHEATSHEET_ALIAS_FILE"
  [[ -n "$CHEATSHEET_ALIAS_FILE" && -f "$af" ]] && sed -nE "s/^alias ([^=]+)='just ([^' ]+)'.*/\1 \2/p" "$af" |
    while read -r a c; do ALIAS[$c]=$a; done
  just --justfile "$jf" --list --list-heading '' --color never 2>/dev/null | while IFS= read -r l; do
    local -a sig=(${=${l%%\#*}})
    local doc=""
    [[ $l == *\#* ]] && doc=${${l#*\#}# }
    (( ${#sig} )) || continue
    doc=${doc:-${sig[2,-1]}}
    [[ -n "${ALIAS[$sig[1]]}" ]] && doc="[${ALIAS[$sig[1]]}] $doc"
    row "$sig[1]" "$doc" "$C" "run:just $sig[1]"
  done
}

render_herdr() {
  header "herdr ${D}(prefix $PREFIX)${R}"
  # name, label, click action ("" = UI-only or destructive, shown dimmed)
  local -a curated=(
    help "help (all keys)" ""
    new_tab "new tab" herdr:new_tab
    next_tab "next tab" herdr:next_tab
    previous_tab "prev tab" herdr:prev_tab
    rename_tab "rename tab" herdr:rename:tab
    switch_tab "go to tab" ""
    split_vertical "split right" herdr:split:right
    split_horizontal "split down" herdr:split:down
    zoom "zoom pane" herdr:zoom
    rename_pane "rename pane" herdr:rename:pane
    close_pane "close pane" ""
    workspace_picker "workspaces" ""
    new_workspace "new workspace" herdr:new_workspace
    rename_workspace "rename workspace" herdr:rename:workspace
    goto "goto" ""
    toggle_sidebar "sidebar" ""
    edit_scrollback "scrollback → editor" ""
    detach "detach" ""
  )
  local name desc act k d t c
  for name desc act in "${curated[@]}"; do
    [[ -n "${KEYS[$name]}" ]] && row "$(fmt_key "${KEYS[$name]}")" "$desc" "$Y" "$act"
  done
  [[ -n "${KEYS[focus_pane_left]}" ]] && row "$(fmt_key "${KEYS[focus_pane_left]}")…${KEYS[focus_pane_right]##*+}" "focus pane h/j/k/l" "$Y"
  # custom [[keys.command]] bindings: key, description, type, command
  awk 'function flush(){ if(k!="") print k"\t"d"\t"t"\t"c; k=d=t=c="" }
       function val(s){ sub(/^[a-z_]+ *= */,"",s); if(s ~ /^'"'''"'/){ sub(/^'"'''"'/,"",s); sub(/'"'''"' *$/,"",s) }
                        else if(s ~ /^"/){ sub(/^"/,"",s); sub(/" *$/,"",s) } else if(s ~ /^'"'"'/){ sub(/^'"'"'/,"",s); sub(/'"'"' *$/,"",s) }
                        return s }
       /^\[\[keys\.command\]\]/{ flush(); b=1; next }
       /^\[/{ flush(); b=0 }
       b && /^key *=/{ k=val($0) } b && /^description *=/{ d=val($0) }
       b && /^type *=/{ t=val($0) } b && /^command *=/{ c=val($0) }
       END{ flush() }' "$CONFIG" 2>/dev/null |
    while IFS=$'\t' read -r k d t c; do
      case $t in
        plugin_action) act="plugin:$c" ;;
        pane|popup) act="cmd:$c" ;;
        shell) act="bg:$c" ;;
        *) act="" ;;
      esac
      row "$(fmt_key "$k")" "${d:-custom command}" "$Y" "$act"
    done
}

render_terminal() {
  [[ -n "$CHEATSHEET_TERMINAL_NAME" && -s "$TERMKEYS" ]] || return
  header "$CHEATSHEET_TERMINAL_NAME"
  grep -v '^#' "$TERMKEYS" | while IFS='|' read -r k d; do [[ -n "$k" ]] && row "$k" "$d" "$M"; done
}

draw() {
  OUT=() ACT=() PLAIN=()
  load_herdr_keys
  render_just "$1"
  render_herdr
  render_terminal
  line ""
  line " ${D}click ▸ to run · r refresh · q close${R}"
  # never print past the pane: screen row N must stay OUT[N] for click mapping
  local max=$(( LINES - 1 ))
  (( ${#OUT} > max )) && OUT=("${(@)OUT[1,max]}") ACT=("${(@)ACT[1,max]}") PLAIN=("${(@)PLAIN[1,max]}")
  printf '\e]0;%s\a\e[H\e[2J%s' "$LABEL" "${(pj:\n:)OUT}"
}

focus_main() { "$H" pane focus --pane "$HERDR_PANE_ID" --direction left >/dev/null 2>&1 }

drain() { # seconds of silence that end the drain
  local c
  while read -r -s -k1 -t "$1" c </dev/tty; do :; done
}

# Runs a command inside this pane, then waits for a key (unless the command waits itself).
run_inline() { # command [wait]
  printf '%s\e[?25h\e[H\e[2J' "$MOUSE_OFF"
  printf "${B}\$ %s${R}  ${D}(in %s, Ctrl-C stops)${R}\n\n" "$1" "${DIR/#$HOME/~}"
  trap ':' INT
  ( cd "$DIR" && HERDR_ACTIVE_PANE_CWD="$DIR" HERDR_ACTIVE_PANE_ID="$TPANE" zsh -lc "$1" )
  local rc=$?
  trap - INT
  if [[ "$2" == wait ]]; then
    printf "\n${D}exit %s — press any key to return${R}" "$rc"
    drain 0.05
    local k
    # a late mouse report (ESC sequence) must not count as the key press
    while read -r -s -k1 k </dev/tty; do
      [[ $k == $'\e' ]] && { drain 0.05; continue }
      break
    done
  fi
  printf '\e[?25l%s' "$MOUSE_ON"
  FP=""
  focus_main
}

# Asks for a new name in this pane; the pane target is the tab's main pane, never the sheet itself.
rename_prompt() { # tab | workspace | pane
  local id cur new
  case $1 in
    tab) id=$HERDR_TAB_ID; cur=$("$H" tab get "$id" | jq -r '.result.tab.label // empty') ;;
    workspace) id=$HERDR_WORKSPACE_ID; cur=$("$H" workspace get "$id" | jq -r '.result.workspace.label // empty') ;;
    pane) id=$TPANE; cur=$("$H" pane get "$id" | jq -r '.result.pane.label // .result.pane.terminal_title_stripped // empty') ;;
  esac
  [[ -n "$id" ]] || return
  printf '%s\e[?25h\e[H\e[2J' "$MOUSE_OFF"
  printf "${B}Rename %s${R}\n${D}current: %s — Enter on empty keeps it${R}\n\n> " "$1" "${cur:-—}"
  drain 0.05
  read -r new </dev/tty
  [[ -n "$new" ]] && "$H" "$1" rename "$id" "$new" >/dev/null
  printf '\e[?25l%s' "$MOUSE_ON"
  FP=""
  focus_main
}

tab_neighbor() { # +1 | -1
  local -a tabs=($("$H" tab list --workspace "$HERDR_WORKSPACE_ID" | jq -r '.result.tabs[].tab_id'))
  local i=${tabs[(i)$HERDR_TAB_ID]}
  (( i > ${#tabs} )) && return
  "$H" tab focus "${tabs[$(( (i - 1 + $1 + ${#tabs}) % ${#tabs} + 1 ))]}" >/dev/null
}

execute() { # action
  local a=$1
  case $a in
    run:*) run_inline "${a#run:}" wait ;;
    cmd:*) run_inline "${a#cmd:}" ;;
    bg:*) ( cd "$DIR" && HERDR_ACTIVE_PANE_CWD="$DIR" zsh -lc "${a#bg:}" >/dev/null 2>&1 & ) ; focus_main ;;
    "plugin:$CS_PLUGIN_ID.toggle") "$H" pane close "$HERDR_PANE_ID" >/dev/null 2>&1; exit ;;
    # plugin actions resolve their tab from the focused pane, so focus this tab's main pane first
    plugin:*) focus_main; "$H" plugin action invoke "${a#plugin:}" >/dev/null 2>&1 ;;
    herdr:new_tab) "$H" tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$DIR" --focus >/dev/null ;;
    herdr:next_tab) tab_neighbor 1 ;;
    herdr:prev_tab) tab_neighbor -1 ;;
    herdr:split:*) [[ -n "$TPANE" ]] && "$H" pane split "$TPANE" --direction "${a##*:}" --cwd "$DIR" --focus >/dev/null ;;
    herdr:zoom) focus_main; [[ -n "$TPANE" ]] && "$H" pane zoom "$TPANE" >/dev/null ;;
    herdr:new_workspace) "$H" workspace create --cwd "$DIR" --focus >/dev/null ;;
    herdr:rename:*) rename_prompt "${a##*:}" ;;
  esac
}

click() { # row
  local a=${ACT[$1]}
  [[ -n "$a" ]] || return
  printf '\e[%d;1H\e[7m%s\e[0m' "$1" "${PLAIN[$1]}"
  drain 0.15   # swallows the button-release report that follows the press
  FP=""
  execute "$a"
}

# Reads one input event: sets KEY for keys, or handles a mouse click.
handle_input() {
  local k seq c
  read -r -s -k1 -t 2 k </dev/tty || return
  if [[ $k == $'\e' ]]; then
    while read -r -s -k1 -t 0.05 c </dev/tty; do seq+=$c; [[ $c == [Mm~] || ${#seq} -gt 20 ]] && break; done
    # SGR mouse report: [<button;column;row(M=press|m=release)
    if [[ $seq =~ '^\[<([0-9]+);([0-9]+);([0-9]+)M$' ]] && (( match[1] == 0 )); then
      click "$match[3]"
    fi
    return
  fi
  case $k in
    q) "$H" pane close "$HERDR_PANE_ID" >/dev/null 2>&1; exit ;;
    r) FP="" ;;
  esac
}

stamp() { local f; for f; do zstat +mtime "$f" 2>/dev/null; print -n .; done }

printf '\e[?25l%s' "$MOUSE_ON"
trap 'printf "%s\e[?25h" "$MOUSE_OFF"' EXIT
trap 'FP=' WINCH
DIR="" LAST_FOCUSED="" TPANE="" FP=""
while :; do
  read -r LINES COLS < <(stty size </dev/tty 2>/dev/null || print "40 60")
  locate
  jf=$(find_up "$DIR" justfile Justfile .justfile)
  fp="$DIR|$LINES|$COLS|$(stamp "$CONFIG" "$TERMKEYS" ${jf:+"$jf"} ${jf:+"${jf:h}/$CHEATSHEET_ALIAS_FILE"})"
  [[ "$fp" != "$FP" ]] && { draw "$DIR"; FP=$fp }
  handle_input
done
