#!/bin/zsh
# Cheat-sheet panel: logo, agent overview, just recipes of the focused project, herdr and terminal keybindings.
# Rows marked ▸ run on click. Redraws only when something changes. Keys: r = refresh, q = close panel.
H="${HERDR_BIN_PATH:-herdr}"
ROOT="${0:A:h}"
CS_ROOT=$ROOT
source "$ROOT/lib/config.zsh"
CONFIG=$HERDR_CONFIG
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
  local kw=${KW:-13} mark=" " desc=$2 key
  local dw=$(( COLS - kw - 4 ))
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

# "ANSI Shadow" letters with single-width strokes: █ is the letter face, the box-drawing lines are its
# drop shadow. Six rows; CHEATSHEET is 52 columns wide.
typeset -A GLYPH=(
  C1 ' ███╗' C2 '█╔══╝' C3 '█║   ' C4 '█║   ' C5 '╚███╗' C6 ' ╚══╝'
  H1 '█╗ █╗' H2 '█║ █║' H3 '████║' H4 '█╔═█║' H5 '█║ █║' H6 '╚╝ ╚╝'
  E1 '████╗' E2 '█╔══╝' E3 '███╗ ' E4 '█╔═╝ ' E5 '████╗' E6 '╚═══╝'
  A1 ' ██╗ ' A2 '█╔═█╗' A3 '████║' A4 '█╔═█║' A5 '█║ █║' A6 '╚╝ ╚╝'
  T1 '█████╗' T2 '╚═█╔═╝' T3 '  █║  ' T4 '  █║  ' T5 '  █║  ' T6 '  ╚╝  '
  S1 '████╗' S2 '█╔══╝' S3 '████╗' S4 '╚══█║' S5 '████║' S6 '╚═══╝'
)
# 256-color retro gradient per row (pink → lavender → aqua); shadow lines use the row color, faint
BANNER_COLORS=(213 177 141 111 87 87)
COMPACT_LOGO=('┌─┐┬ ┬┌─┐┌─┐┌┬┐┌─┐┬ ┬┌─┐┌─┐┌┬┐' '│  ├─┤├┤ ├─┤ │ └─┐├─┤├┤ ├┤  │ ' '└─┘┴ ┴└─┘┴ ┴ ┴ └─┘┴ ┴└─┘└─┘ ┴ ')

shadow_line() { # text color -> line with solid faces and faint shadow lines
  local face=$'\e[0;38;5;'$2'm' shade=$'\e[0;2;38;5;'$2'm' out="" cur="" ch cls
  for ch in ${(s::)1}; do
    case $ch in
      █) cls=$face ;;
      ' ') cls=$cur ;;
      *) cls=$shade ;;
    esac
    [[ $cls != $cur ]] && { out+=$cls; cur=$cls }
    out+=$ch
  done
  line " $out$R"
}

render_banner() {
  [[ $CHEATSHEET_BANNER == off ]] && return
  local where=${1/#$HOME/~} l ch text
  if (( COLS >= 54 )); then
    for l in {1..6}; do
      text=""
      for ch in C H E A T S H E E T; do text+=${GLYPH[$ch$l]}; done
      shadow_line "$text" $BANNER_COLORS[$l]
    done
  elif (( COLS >= 33 )); then
    for l in {1..3}; do line " "$'\e[38;5;'$BANNER_COLORS[$(( 2 * l - 1 ))]'m'"$COMPACT_LOGO[$l]$R"; done
  else
    line " ${B}cheatsheet${R}"
  fi
  (( ${#where} > COLS - 2 )) && where="…${where[-(COLS - 3),-1]}"
  line " ${D}$where${R}"
}

typeset -A AGENT_LABEL=(blocked "● blocked" done "✓ done" working "◐ working" idle "○ idle")
typeset -A AGENT_COLOR=(blocked $'\e[31m' done $'\e[32m' working $'\e[33m' idle $'\e[2m')

# Agent panes across all workspaces, most urgent first; clicking one jumps there.
render_agents() {
  [[ $CHEATSHEET_AGENTS == off ]] && return
  local agents
  agents=$(print -r -- "$ALLPANES" | jq -c --arg m "$CHEATSHEET_AGENTS" '
    [.result.panes[] | select((.agent // "") != "")
     | select($m != "attention" or .agent_status == "blocked" or .agent_status == "done")
     | . + {rank: ({blocked: 0, done: 1, working: 2, idle: 3}[.agent_status] // 4)}]
    | sort_by(.rank, .workspace_id)' 2>/dev/null)
  local n=$(print -r -- "${agents:-[]}" | jq length)
  (( n )) || return
  typeset -A wsl
  local id lbl p st tab ws title desc max=${CHEATSHEET_AGENTS_MAX:-8} counts
  "$H" workspace list 2>/dev/null | jq -r '.result.workspaces[] | "\(.workspace_id)\t\(.label)"' |
    while IFS=$'\t' read -r id lbl; do wsl[$id]=$lbl; done
  counts=$(print -r -- "$agents" | jq -r 'group_by(.agent_status) | map("\(length) \(.[0].agent_status)") | join(" · ")')
  header "agents ${D}($counts)${R}"
  print -r -- "$agents" | jq -r --argjson max "$max" \
    '.[:$max][] | [.pane_id, .agent_status, .tab_id, .workspace_id, (.terminal_title_stripped // .agent)] | @tsv' |
    while IFS=$'\t' read -r p st tab ws title; do
      desc="${wsl[$ws]:-$ws} · $title"
      [[ $tab == $HERDR_TAB_ID ]] && desc+=" (here)"
      KW=10 row "${AGENT_LABEL[$st]:-· $st}" "$desc" "${AGENT_COLOR[$st]:-$D}" "agent:$p"
    done
  (( n > max )) && line "  ${D}+$(( n - max )) more${R}"
}

# Sets DIR (project dir to show) and TPANE (main pane in this tab that actions target).
locate() {
  local all p d
  all=$("$H" pane list 2>/dev/null) || return
  ALLPANES=$all
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

# Sets TERMKEYS (shortcut list to show) and TERMHEAD (its heading) for the detected terminal.
pick_terminal() {
  local id note name
  TERMKEYS="" TERMHEAD="" TERMHINT=""
  if [[ -n "$CHEATSHEET_TERMINAL_KEYS" ]]; then
    TERMKEYS=$CHEATSHEET_TERMINAL_KEYS TERMHEAD=${CHEATSHEET_TERMINAL_NAME:-Terminal}
    return
  fi
  id=$(cs_detect_terminal)
  [[ "$id" == off ]] && return
  TERMKEYS=$(cs_terminal_file "$id")
  [[ -n "$TERMKEYS" ]] || return
  name=$(sed -n 's/^# name: *//p' "$TERMKEYS" | head -1)
  if [[ "${CHEATSHEET_TERMINAL:-auto}" != auto ]]; then note=configured
  elif [[ "$id" == generic ]]; then note="terminal not recognized"; TERMHINT="set CHEATSHEET_TERMINAL in config.zsh"
  else note=detected
  fi
  TERMHEAD="${name:-$id} ${D}($note)${R}"
}

render_terminal() {
  [[ -s "$TERMKEYS" ]] || return
  header "$TERMHEAD"
  local -a keys descs
  local k d
  grep -v '^#' "$TERMKEYS" | while IFS='|' read -r k d; do [[ -n "$k" ]] && { keys+=("$k"); descs+=("$d") }; done
  # Linux-style keys (Ctrl+Shift+…) are longer than the default column
  local KW=${#${(O@)keys//?/x}[1]} i
  (( KW < 13 )) && KW=13
  (( KW > 18 )) && KW=18
  for i in {1..${#keys}}; do row "$keys[$i]" "$descs[$i]" "$M"; done
  [[ -n "$TERMHINT" ]] && line "  ${D}$TERMHINT${R}"
}

draw() {
  OUT=() ACT=() PLAIN=()
  load_herdr_keys
  render_banner "$1"
  render_just "$1"
  render_herdr
  render_terminal
  render_agents
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
    agent:*) "$H" agent focus "${a#agent:}" >/dev/null 2>&1 ;;
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
    r) FP=""; pick_terminal ;;
  esac
}

stamp() { local f; for f; do zstat +mtime "$f" 2>/dev/null; print -n .; done }

printf '\e[?25l%s' "$MOUSE_ON"
trap 'printf "%s\e[?25h" "$MOUSE_OFF"' EXIT
trap 'FP=' WINCH
DIR="" LAST_FOCUSED="" TPANE="" FP=""
pick_terminal
while :; do
  read -r LINES COLS < <(stty size </dev/tty 2>/dev/null || print "40 60")
  locate
  jf=$(find_up "$DIR" justfile Justfile .justfile)
  agents_fp=$(print -r -- "$ALLPANES" | jq -r '[.result.panes[] | select((.agent // "") != "")
    | "\(.pane_id):\(.agent_status):\(.terminal_title_stripped)"] | join(",")' 2>/dev/null)
  fp="$DIR|$LINES|$COLS|$agents_fp|$(stamp "$CONFIG" "$TERMKEYS" ${jf:+"$jf"} ${jf:+"${jf:h}/$CHEATSHEET_ALIAS_FILE"})"
  [[ "$fp" != "$FP" ]] && { draw "$DIR"; FP=$fp }
  handle_input
done
