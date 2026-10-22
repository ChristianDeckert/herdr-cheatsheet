#!/bin/zsh
# Cheat-sheet panel: logo, agent overview, just recipes of the focused project, herdr and terminal keybindings.
# Rows marked ▸ run on click. Redraws only when something changes. Keys: r = refresh, b = logo on/off,
# q = close panel, u = update (when one is available).
H="${HERDR_BIN_PATH:-herdr}"
ROOT="${0:A:h}"
CS_ROOT=$ROOT
source "$ROOT/lib/config.zsh"
source "$ROOT/lib/update.zsh"
CONFIG=$HERDR_CONFIG
LABEL="cheatsheet"
zmodload -F zsh/stat b:zstat
zmodload zsh/net/socket

typeset -A KEYS ALIAS
typeset -a OUT ACT PLAIN
B=$'\e[1m' D=$'\e[2m' C=$'\e[36m' Y=$'\e[33m' M=$'\e[35m' R=$'\e[0m'
# keys of clickable rows: the pastel pink of the logo's top line
K=$'\e[38;5;213m'
# group labels: the lavender of the logo's middle line
G=$'\e[38;5;141m'
# Sheet mode: SGR mouse reporting on and auto-wrap off. Without wrap, a line wider than the pane is cut
# at the edge instead of taking a second screen row, which would shift every row below (and its click).
MOUSE_ON=$'\e[?1000h\e[?1006h\e[?7l' MOUSE_OFF=$'\e[?1000l\e[?1006l\e[?7h'

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
  local dw=$(( COLS - kw - 5 ))
  (( dw < 8 )) && dw=8
  [[ -n "$4" ]] && mark="▸"
  key=${1[1,kw]} desc=${desc[1,dw]}
  PLAIN+=("$(printf " %s %-${kw}s %s" "$mark" "$key" "$desc")")
  if [[ -n "$4" ]]; then
    OUT+=("$(printf " ${B}%s${R} %s%-${kw}s%s %s" "$mark" "$3" "$key" "$R" "$desc")")
  else
    OUT+=("$(printf "   ${D}%-${kw}s %s${R}" "$key" "$desc")")
  fi
  ACT+=("$4")
}

line() { OUT+=("$1"); PLAIN+=(""); ACT+=("") }

header() { (( ${#OUT} )) && line ""; line "${B}$1${R}" }

# A group inside a section: a colored label and a dim rule to the panel edge.
group() { # label color
  local rule=$(( COLS - ${#1} - 3 ))
  (( rule < 1 )) && rule=1
  line " $2$1$R ${D}${(l:rule::─:)}${R}"
}

# Sections set PENDING_GROUP at a group marker; the label is printed before the group's first row, so a
# group whose keys are all unbound doesn't show up at all.
flush_group() { # color
  [[ -n $PENDING_GROUP ]] && { group "$PENDING_GROUP" "$1"; PENDING_GROUP="" }
}

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

# The logo toggle in the panel section is shared by all panels and wins over CHEATSHEET_BANNER.
BANNER_FILE="$CS_STATE_DIR/banner"
banner_on() {
  local v=$CHEATSHEET_BANNER
  [[ -f $BANNER_FILE ]] && v=$(<$BANNER_FILE)
  [[ $v != off ]]
}

toggle_banner() {
  { banner_on && print off || print on } > "$BANNER_FILE.tmp" && mv "$BANNER_FILE.tmp" "$BANNER_FILE"
}

# herdr shows a pane's label in its frame. The logo already names the panel, so the label is only set
# while the logo is hidden.
LABEL_SHOWN=""
sync_label() {
  local want=on
  banner_on && want=off
  [[ $want == $LABEL_SHOWN ]] && return
  if [[ $want == on ]]; then herdr_do pane rename "$HERDR_PANE_ID" "$LABEL"
  else herdr_do pane rename "$HERDR_PANE_ID" --clear
  fi && LABEL_SHOWN=$want
}

render_banner() {
  banner_on || return
  local where="${1/#$HOME/~}" l ch text
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
  (( n > max )) && line "   ${D}+$(( n - max )) more${R}"
}

# Sets DIR (project dir to show) and TPANE (main pane in this tab that actions target).
locate() {
  local all p d
  all=$("$H" pane list 2>/dev/null) || return
  ALLPANES=$all
  read -r p d < <(print -r -- "$all" | cs_jq -r --arg w "$HERDR_WORKSPACE_ID" --arg s "$HERDR_PANE_ID" \
    "$CS_SHEET_JQ"' .result.panes[] | select(.focused and .workspace_id == $w and .pane_id != $s and (sheet | not))
     | "\(.pane_id) \(.foreground_cwd // .cwd)"' | head -1)
  [[ -n "$d" ]] && { DIR=$d; LAST_FOCUSED=$p }
  # actions need a pane in this tab: the last focused one if it lives here, else the first non-sheet pane
  TPANE=$(print -r -- "$all" | cs_jq -r --arg t "$HERDR_TAB_ID" --arg s "$HERDR_PANE_ID" --arg l "$LAST_FOCUSED" \
    "$CS_SHEET_JQ"' [.result.panes[] | select(.tab_id == $t and .pane_id != $s and (sheet | not))]
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
    row "$sig[1]" "$doc" "$K" "run:just $sig[1]"
  done
}

render_herdr() {
  header "herdr ${D}(prefix $PREFIX)${R}"
  # name, label, click action ("" = only reachable from herdr's UI, shown dimmed)
  local -a curated=(
    "## tabs" "" ""
    new_tab "new tab" herdr:new_tab
    next_tab "next tab" herdr:next_tab
    previous_tab "prev tab" herdr:prev_tab
    switch_tab "go to tab" ""
    move_tab_previous "move tab left" herdr:move_tab:-1
    move_tab_next "move tab right" herdr:move_tab:1
    rename_tab "rename tab" herdr:rename:tab
    close_tab "close tab" herdr:close_tab
    "## panes" "" ""
    split_vertical "split right" herdr:split:right
    split_horizontal "split down" herdr:split:down
    focus_pane_hjkl "focus pane h/j/k/l" ""
    cycle_pane_next "next pane" herdr:pane:1
    cycle_pane_previous "prev pane" herdr:pane:-1
    last_pane "last pane" ""
    zoom "zoom pane" herdr:zoom
    resize_mode "resize mode" ""
    rename_pane "rename pane" herdr:rename:pane
    clear_pane "clear pane" herdr:clear_pane
    edit_scrollback "scrollback → editor" herdr:scrollback
    close_pane "close pane" herdr:close_pane
    "## workspaces" "" ""
    workspace_picker "workspace picker" ""
    new_workspace "new workspace" herdr:new_workspace
    next_workspace "next workspace" herdr:workspace:1
    previous_workspace "prev workspace" herdr:workspace:-1
    switch_workspace "go to workspace" ""
    rename_workspace "rename workspace" herdr:rename:workspace
    close_workspace "close workspace" herdr:close_workspace
    new_worktree "new worktree" herdr:new_worktree
    open_worktree "open worktree" ""
    "## agents" "" ""
    next_agent "next agent" herdr:agent:1
    previous_agent "prev agent" herdr:agent:-1
    focus_agent "go to agent" ""
    open_notification_target "jump to notification" ""
    "## herdr" "" ""
    help "help (all keys)" ""
    goto "goto" ""
    toggle_sidebar "sidebar" ""
    settings "settings" ""
    reload_config "reload config" herdr:reload_config
    detach "detach" ""
  )
  local name desc act k d t c PENDING_GROUP=""
  for name desc act in "${curated[@]}"; do
    if [[ $name == "## "* ]]; then PENDING_GROUP=${name#"## "}; continue; fi
    if [[ $name == focus_pane_hjkl ]]; then
      [[ -n "${KEYS[focus_pane_left]}" ]] || continue
      flush_group "$G"
      row "$(fmt_key "${KEYS[focus_pane_left]}")…${KEYS[focus_pane_right]##*+}" "$desc" "$Y"
      continue
    fi
    [[ -n "${KEYS[$name]}" ]] || continue
    flush_group "$G"
    row "$(fmt_key "${KEYS[$name]}")" "$desc" "$K" "$act"
  done
  PENDING_GROUP="your keys"
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
      flush_group "$G"
      row "$(fmt_key "$k")" "${d:-custom command}" "$K" "$act"
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
  # keys|description lines; "## label" starts a group (stored as key "##"), other "#" lines are metadata
  local -a keys descs
  local l PENDING_GROUP=""
  while IFS= read -r l; do
    case $l in
      "## "*) keys+=("##") descs+=("${l#"## "}") ;;
      "#"*|"") ;;
      *) keys+=("${l%%|*}") descs+=("${${l#*|}:#$l}") ;;
    esac
  done < "$TERMKEYS"
  # Linux-style keys (Ctrl+Shift+…) are longer than the default column
  local -a widths=(${${keys:#"##"}//?/x})
  local KW=${#${(O@)widths}[1]} i
  (( KW < 13 )) && KW=13
  (( KW > 18 )) && KW=18
  for i in {1..${#keys}}; do
    if [[ $keys[$i] == "##" ]]; then PENDING_GROUP=$descs[$i]; continue; fi
    flush_group "$G"
    row "$keys[$i]" "$descs[$i]" "$M"
  done
  [[ -n "$TERMHINT" ]] && line "   ${D}$TERMHINT${R}"
}

# Collects all sections into OUT/ACT/PLAIN. Runs herdr, jq and just, so only when something changed.
build() {
  OUT=() ACT=() PLAIN=()
  sync_label
  load_herdr_keys
  render_banner "$1"
  render_update
  render_just "$1"
  render_herdr
  render_terminal
  render_agents
  render_panel
  render_update_status
}

# The panel's own controls, laid out like the other sections; r and q also work as keys.
render_panel() {
  header "panel"
  row "r" "refresh" "$K" "panel:refresh"
  if banner_on; then row "b" "hide logo" "$K" "panel:banner"
  else row "b" "show logo" "$K" "panel:banner"
  fi
  row "q" "close panel" "$K" "panel:close"
}

# Sets REPLY to the line cut to the pane width; color codes are copied, only visible characters count.
fit() { # line
  setopt local_options extended_glob
  local s=$1 out="" esc n=0 max=$(( COLS - 1 ))
  if (( ${#${(S)s//$'\e'\[[0-9;]#m/}} <= max )); then REPLY=$s; return; fi
  while [[ -n $s ]] && (( n < max )); do
    esc=${(M)s#$'\e'\[[0-9;]#m}
    if [[ -n $esc ]]; then out+=$esc s=${s#$esc}
    else out+=${s[1]} s=${s[2,-1]}; (( n++ ))
    fi
  done
  REPLY="$out$R"
}

# Prints the visible slice: screen row N shows OUT[SCROLL + N], which is what clicks map to.
# When content continues above/below, the first/last row becomes a dim hint instead.
paint() {
  local vis=$(( LINES - 1 )) total=${#OUT}
  (( vis < 1 )) && vis=1
  (( SCROLL > total - vis )) && SCROLL=$(( total - vis ))
  (( SCROLL < 0 )) && SCROLL=0
  local -a view=("${(@)OUT[SCROLL + 1, SCROLL + vis]}")
  local i
  for i in {1..${#view}}; do fit "$view[$i]"; view[$i]=$REPLY; done
  VIS_ROWS=${#view} HINT_TOP=0 HINT_BOTTOM=0
  (( SCROLL > 0 )) && { view[1]=" ${D}↑ more${R}"; HINT_TOP=1 }
  (( SCROLL + vis < total )) && { view[-1]=" ${D}↓ more${R}"; HINT_BOTTOM=1 }
  printf '\e]0;%s\a\e[H\e[2J%s' "$LABEL" "${(pj:\n:)view}"
}

# The sheet keeps the tty silent (no echo, byte-wise input) so mouse reports that arrive while it is
# busy are never echoed onto the panel. Commands and prompts get the normal mode back.
quiet_tty() { stty -echo -icanon </dev/tty 2>/dev/null }
normal_tty() { [[ -n $TTY_SAVED ]] && stty "$TTY_SAVED" </dev/tty 2>/dev/null }

focus_main() { "$H" pane focus --pane "$HERDR_PANE_ID" --direction left >/dev/null 2>&1 }

drain() { # seconds of silence that end the drain
  local c
  while read -r -s -k1 -t "$1" c </dev/tty; do :; done
}

# Runs a command inside this pane, then waits for a key (unless the command waits itself).
run_inline() { # command [wait]
  printf '%s\e[?25h\e[H\e[2J' "$MOUSE_OFF"
  printf "${B}\$ %s${R}  ${D}(in %s, Ctrl-C stops)${R}\n\n" "$1" "${DIR/#$HOME/~}"
  normal_tty
  trap ':' INT
  ( cd "$DIR" && HERDR_ACTIVE_PANE_CWD="$DIR" HERDR_ACTIVE_PANE_ID="$TPANE" zsh -lc "$1" )
  local rc=$?
  trap 'exit 130' INT
  quiet_tty
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

# Asks for one line inside this pane; REPLY is empty when the user just presses Enter.
prompt_line() { # title hint
  printf '%s\e[?25h\e[H\e[2J' "$MOUSE_OFF"
  printf "${B}%s${R}\n${D}%s${R}\n\n> " "$1" "$2"
  drain 0.05
  normal_tty
  read -r REPLY </dev/tty
  quiet_tty
  printf '\e[?25l%s' "$MOUSE_ON"
  FP=""
}

# Asks for a new name in this pane; the pane target is the tab's main pane, never the sheet itself.
rename_prompt() { # tab | workspace | pane
  local id cur
  case $1 in
    tab) id=$HERDR_TAB_ID; cur=$("$H" tab get "$id" | jq -r '.result.tab.label // empty') ;;
    workspace) id=$HERDR_WORKSPACE_ID; cur=$("$H" workspace get "$id" | jq -r '.result.workspace.label // empty') ;;
    pane) id=$TPANE; cur=$("$H" pane get "$id" | jq -r '.result.pane.label // .result.pane.terminal_title_stripped // empty') ;;
  esac
  [[ -n "$id" ]] || return
  prompt_line "Rename $1" "current: ${cur:-—} — Enter on empty keeps it"
  [[ -n "$REPLY" ]] && "$H" "$1" rename "$id" "$REPLY" >/dev/null
  focus_main
}

new_worktree() {
  prompt_line "New worktree" "branch for a worktree of ${DIR/#$HOME/~} — Enter on empty cancels"
  [[ -n "$REPLY" ]] && run_inline "${(q)H} worktree create --cwd ${(q)DIR} --branch ${(q)REPLY} --focus" wait
}

# Shows an error in the panel's last row for a moment.
fail() { # message
  printf '\e[%d;1H\e[2K\e[31m %s\e[0m' "$LINES" "${1[1,COLS-2]}"
  sleep 2
  FP=""
}

# Runs a herdr CLI command and shows its error if it fails.
herdr_do() { # args...
  local out
  out=$("$H" "$@" 2>&1) && return
  fail "$(print -r -- "$out" | jq -r '.error.message // empty' 2>/dev/null || print -r -- "$out")"
  return 1
}

# Calls herdr's socket API, for actions its CLI doesn't have. Shows the error if the call fails.
api() { # method params-json
  local fd line
  if ! zsocket "$HERDR_SOCKET_PATH" 2>/dev/null; then
    fail "$1: can't reach herdr's socket"
    return 1
  fi
  fd=$REPLY
  print -r -- "{\"id\":\"cheatsheet\",\"method\":\"$1\",\"params\":$2}" >&$fd
  read -r -t 5 line <&$fd
  exec {fd}>&-
  if [[ -z $line ]] || print -r -- "$line" | jq -e '.error' >/dev/null; then
    fail "$1: $(print -r -- "$line" | jq -r '.error.message // empty' 2>/dev/null || print -r -- "no response")"
    return 1
  fi
}

# Non-sheet panes of this tab, in herdr's order.
tab_panes() {
  print -r -- "$ALLPANES" | cs_jq -r --arg t "$HERDR_TAB_ID" --arg s "$HERDR_PANE_ID" \
    "$CS_SHEET_JQ"' .result.panes[] | select(.tab_id == $t and .pane_id != $s and (sheet | not)) | .pane_id'
}

# Prints the item $1 steps away from $2 among the remaining arguments, wrapping around. Without a
# current item, +1 gives the first and -1 the last.
step() { # +1|-1 current items...
  local d=$1 cur=$2; shift 2
  (( $# )) || return 1
  local i=${@[(i)$cur]}
  (( i > $# )) && { (( d > 0 )) && i=0 || i=$(( $# + 1 )) }
  print -r -- ${@[$(( (i - 1 + d + $# * 2) % $# + 1 ))]}
}

pane_neighbor() { # +1 | -1
  local next
  next=$(step $1 "$TPANE" $(tab_panes)) || return
  api pane.focus "{\"pane_id\":\"$next\"}"
}

# herdr closes a tab together with its last pane; the sheet doesn't count, so do the same.
close_pane() {
  [[ -n "$TPANE" ]] || return
  local -a ps=($(tab_panes))
  if (( ${#ps} <= 1 )); then herdr_do tab close "$HERDR_TAB_ID"
  else herdr_do pane close "$TPANE"
  fi
}

move_tab() { # +1 | -1
  local -a tabs=($("$H" tab list --workspace "$HERDR_WORKSPACE_ID" | jq -r '.result.tabs[].tab_id'))
  local i=${tabs[(i)$HERDR_TAB_ID]} n=${#tabs} to
  (( i <= n )) || return
  # herdr inserts before the tab at insert_index, counted while the moved tab is still in place
  if (( $1 > 0 )); then (( i < n )) || return; to=$(( i + 1 ))
  else (( i > 1 )) || return; to=$(( i - 2 ))
  fi
  api tab.move "{\"tab_id\":\"$HERDR_TAB_ID\",\"insert_index\":$to}"
}

workspace_neighbor() { # +1 | -1
  local next
  next=$(step $1 "$HERDR_WORKSPACE_ID" $("$H" workspace list | jq -r '.result.workspaces[].workspace_id')) || return
  herdr_do workspace focus "$next"
}

# Relative to the agent in this tab's main pane, else from the start of the list.
agent_neighbor() { # +1 | -1
  local next
  next=$(step $1 "$TPANE" $(print -r -- "$ALLPANES" | jq -r '.result.panes[] | select((.agent // "") != "") | .pane_id')) || return
  herdr_do agent focus "$next"
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
    herdr:reload_config) "$H" server reload-config >/dev/null ;;
    herdr:close_tab) herdr_do tab close "$HERDR_TAB_ID" ;;
    herdr:close_pane) close_pane ;;
    herdr:close_workspace) herdr_do workspace close "$HERDR_WORKSPACE_ID" ;;
    herdr:pane:*) pane_neighbor "${a##*:}" ;;
    herdr:move_tab:*) move_tab "${a##*:}" ;;
    herdr:workspace:*) workspace_neighbor "${a##*:}" ;;
    herdr:agent:*) agent_neighbor "${a##*:}" ;;
    herdr:clear_pane) [[ -n "$TPANE" ]] && api pane.clear "{\"pane_id\":\"$TPANE\"}" ;;
    herdr:scrollback) [[ -n "$TPANE" ]] && api pane.edit_scrollback "{\"pane_id\":\"$TPANE\"}" ;;
    herdr:new_worktree) new_worktree ;;
    herdr:rename:*) rename_prompt "${a##*:}" ;;
    agent:*) "$H" agent focus "${a#agent:}" >/dev/null 2>&1 ;;
    panel:refresh) pick_terminal; update_check force ;;
    panel:banner) toggle_banner ;;
    panel:update) update_now ;;
    panel:close) "$H" pane close "$HERDR_PANE_ID" >/dev/null 2>&1; exit ;;
  esac
}

click() { # screen row
  (( $1 == 1 && HINT_TOP || $1 == VIS_ROWS && HINT_BOTTOM )) && return
  local i=$(( SCROLL + $1 ))
  local a=${ACT[$i]}
  [[ -n "$a" ]] || return
  printf '\e[%d;1H\e[7m%s\e[0m' "$1" "${PLAIN[$i]}"
  drain 0.15   # swallows the button-release report that follows the press
  FP=""
  execute "$a"
}

scroll_by() { (( $1 )) || return; SCROLL=$(( SCROLL + $1 )); paint }

# Handles everything that is queued: keys, clicks and wheel bursts (the scroll is painted once).
handle_input() {
  local k c seq n=0 delta=0 b
  read -r -s -k1 -t 2 k </dev/tty || return
  while :; do
    if [[ $k == $'\e' ]]; then
      seq=""
      while read -r -s -k1 -t 0.05 c </dev/tty; do seq+=$c; [[ $c == [Mm~] || ${#seq} -gt 20 ]] && break; done
      # SGR mouse report: [<button;column;row then M (press) or m (release)
      if [[ $seq =~ '^\[<([0-9]+);([0-9]+);([0-9]+)([Mm])$' ]]; then
        b=$(( match[1] & ~28 ))   # without the shift/alt/ctrl bits
        if (( b == 64 )); then (( delta -= 3 ))
        elif (( b == 65 )); then (( delta += 3 ))
        elif (( b == 0 )) && [[ $match[4] == M ]]; then
          scroll_by $delta
          click "$match[3]"
          return
        fi
      fi
    else
      case $k in
        q) "$H" pane close "$HERDR_PANE_ID" >/dev/null 2>&1; exit ;;
        r) FP=""; pick_terminal; update_check force ;;
        b) toggle_banner ;;
        u) update_available && { update_now; FP="" } ;;
      esac
    fi
    (( ++n < 200 )) || break
    read -r -s -k1 -t 0.01 k </dev/tty || break
  done
  scroll_by $delta
}

stamp() { local f; for f; do zstat +mtime "$f" 2>/dev/null; print -n .; done }

# Panels started by 0.4.x and older run inside the user's shell (a pane labeled "cheatsheet" that isn't
# a plugin pane); swap this one for a plugin pane. On success that closes this pane and ends the sheet.
if [[ -z $HERDR_PLUGIN_ENTRYPOINT_ID && -n $CS_PLUGIN_ID && -n $HERDR_PANE_ID ]] &&
   [[ $("$H" pane list | jq -r --arg p "$HERDR_PANE_ID" '.result.panes[] | select(.pane_id == $p) | .label // ""') == $LABEL ]]; then
  zsh "$ROOT/panel.zsh" replace "$HERDR_PANE_ID"
fi

TTY_SAVED=$(stty -g </dev/tty 2>/dev/null)
quiet_tty
printf '\e[?25l%s' "$MOUSE_ON"
trap 'printf "%s\e[?25h" "$MOUSE_OFF"; normal_tty' EXIT
trap 'exit 130' INT TERM HUP
trap 'FP=' WINCH
ROOT_STAMP=$(zstat +mtime "$ROOT_FILE" 2>/dev/null)
update_check
DIR="" LAST_FOCUSED="" TPANE="" FP="" SCROLL=0 VIS_ROWS=0 HINT_TOP=0 HINT_BOTTOM=0
pick_terminal
while :; do
  read -r LINES COLS < <(stty size </dev/tty 2>/dev/null || print "40 60")
  follow_update
  locate
  jf=$(find_up "$DIR" justfile Justfile .justfile)
  agents_fp=$(print -r -- "$ALLPANES" | jq -r '[.result.panes[] | select((.agent // "") != "")
    | "\(.pane_id):\(.agent_status):\(.terminal_title_stripped)"] | join(",")' 2>/dev/null)
  fp="$DIR|$LINES|$COLS|$agents_fp|$(stamp "$CONFIG" "$TERMKEYS" "$UPDATE_FILE" "$BANNER_FILE" ${jf:+"$jf"} ${jf:+"${jf:h}/$CHEATSHEET_ALIAS_FILE"})"
  [[ "$fp" != "$FP" ]] && { build "$DIR"; FP=$fp; paint }
  handle_input
done
