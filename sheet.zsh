#!/bin/zsh
# Cheat-sheet panel: logo, agent overview, just recipes of the focused project, herdr and terminal keybindings.
# Rows marked ▸ run on click. Redraws only when something changes. Keys: / = search files,
# r = refresh, b = logo on/off, t = retro/terminal colors, q = close panel, u = update (when available).
H="${HERDR_BIN_PATH:-herdr}"
ROOT="${0:A:h}"
CS_ROOT=$ROOT
source "$ROOT/lib/config.zsh"
source "$ROOT/lib/update.zsh"
CONFIG=$HERDR_CONFIG
LABEL="cheatsheet"
zmodload -F zsh/stat b:zstat

typeset -A KEYS ALIAS
typeset -a OUT ACT PLAIN
B=$'\e[1m' D=$'\e[2m' C=$'\e[36m' Y=$'\e[33m' M=$'\e[35m' R=$'\e[0m'
# Sheet mode: SGR mouse reporting on, auto-wrap off and color-scheme reports on. Without wrap, a line
# wider than the pane is cut at the edge instead of taking a second screen row, which would shift every
# row below (and its click). The reports (CSI ?997;1n dark, ;2n light) come whenever the theme changes.
MOUSE_ON=$'\e[?1000h\e[?1006h\e[?7l\e[?2031h' MOUSE_OFF=$'\e[?1000l\e[?1006l\e[?7h\e[?2031l'

# Colors of the logo rows (BANNER_SGR), keys of clickable rows (K) and group labels (G). "retro" is the
# pastel palette, with deeper tones on light backgrounds; "terminal" uses the theme's own ANSI colors.
# The panel's colors toggle is shared by all panels and wins over CHEATSHEET_COLORS.
APPEARANCE=dark
COLORS_FILE="$CS_STATE_DIR/colors"
colors_mode() {
  local v=$CHEATSHEET_COLORS
  [[ -f $COLORS_FILE ]] && v=$(<$COLORS_FILE)
  [[ $v == terminal ]] && print terminal || print retro
}

toggle_colors() {
  { [[ $(colors_mode) == terminal ]] && print retro || print terminal } > "$COLORS_FILE.tmp" &&
    mv "$COLORS_FILE.tmp" "$COLORS_FILE"
}

apply_palette() {
  local -a sgr
  if [[ $(colors_mode) == terminal ]]; then sgr=(95 35 35 34 36 36 35 34)
  elif [[ $APPEARANCE == light ]]; then sgr=(38\;5\;{162,128,98,62,30,30,162,98})
  else sgr=(38\;5\;{213,177,141,111,87,87,213,141})
  fi
  BANNER_SGR=(${sgr[1,6]})
  K=$'\e['$sgr[7]'m' G=$'\e['$sgr[8]'m'
}

# Sets APPEARANCE from the terminal: its explicit color-scheme report if it sends one, else the
# brightness of its background (the formula herdr uses). herdr answers both for the attached terminal.
query_theme() {
  if [[ $CHEATSHEET_APPEARANCE == (dark|light) ]]; then APPEARANCE=$CHEATSHEET_APPEARANCE; return; fi
  local reply="" c
  printf '\e]11;?\e\\\e[?996n' > /dev/tty
  while read -r -s -k1 -t 0.3 c </dev/tty; do
    reply+=$c
    [[ $reply == *$'\e[?997;'[12]n ]] && break
  done
  if [[ $reply =~ $'\e\\[\\?997;([12])n' ]]; then
    [[ $match[1] == 2 ]] && APPEARANCE=light || APPEARANCE=dark
  elif [[ $reply =~ 'rgb:([0-9a-fA-F]{2})[0-9a-fA-F]*/([0-9a-fA-F]{2})[0-9a-fA-F]*/([0-9a-fA-F]{2})' ]]; then
    (( 16#$match[1] * 299 + 16#$match[2] * 587 + 16#$match[3] * 114 >= 128000 )) && APPEARANCE=light || APPEARANCE=dark
  fi
}

# Control is ⌃ on macOS, like its menus show it; elsewhere the usual ^.
[[ $(cs_os) == macos ]] && CTRL_SYM="⌃" || CTRL_SYM="^"

fmt_key() { # "prefix+alt+r" -> "⌃B ⌥r"
  local k=$1
  k=${k//prefix+/$PREFIX }; k=${k//alt+/⌥}; k=${k//shift+/⇧}; k=${k//cmd+/⌘}; k=${k//super+/⌘}
  while [[ $k =~ 'ctrl\+(.)' ]]; do k=${k/ctrl+$match[1]/$CTRL_SYM${(U)match[1]}}; done
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
COMPACT_LOGO=('┌─┐┬ ┬┌─┐┌─┐┌┬┐┌─┐┬ ┬┌─┐┌─┐┌┬┐' '│  ├─┤├┤ ├─┤ │ └─┐├─┤├┤ ├┤  │ ' '└─┘┴ ┴└─┘┴ ┴ ┴ └─┘┴ ┴└─┘└─┘ ┴ ')

shadow_line() { # text sgr -> line with solid faces and faint shadow lines
  local face=$'\e[0;'$2'm' shade=$'\e[0;2;'$2'm' out="" cur="" ch cls
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
      shadow_line "$text" "$BANNER_SGR[$l]"
    done
  elif (( COLS >= 33 )); then
    for l in {1..3}; do line " "$'\e['$BANNER_SGR[$(( 2 * l - 1 ))]'m'"$COMPACT_LOGO[$l]$R"; done
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

# Only shown for a project with a justfile; it appears and disappears as the focus moves between projects.
render_just() {
  local jf=$(find_up "$1" justfile Justfile .justfile) a c
  [[ -n "$jf" ]] || return
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
  render_keyfile "$TERMKEYS" "$TERMHEAD"
  [[ -n "$TERMHINT" ]] && line "   ${D}$TERMHINT${R}"
}

# A key list as a section of display-only rows: keys|description lines, "## label" starts a group, other
# "#" lines are metadata. App lists use the portable Ctrl+/Alt+/Shift+, shown as ⌃⌥⇧ on macOS.
render_keyfile() { # file heading [portable]
  header "$2"
  local -a keys descs
  local l k PENDING_GROUP=""
  while IFS= read -r l; do
    case $l in
      "## "*) keys+=("##") descs+=("${l#"## "}") ;;
      "#"*|"") ;;
      *)
        k=${l%%|*}
        [[ -n $3 && $CTRL_SYM == "⌃" ]] && { k=${k//Ctrl+/⌃}; k=${k//Alt+/⌥}; k=${k//Shift+/⇧} }
        keys+=("$k") descs+=("${${l#*|}:#$l}") ;;
    esac
  done < "$1"
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
}

# Apps whose keys get a section while they run in this tab: process name -> key list.
typeset -A APP_OF=(
  fresh fresh  vi vim  vim vim  nvim vim  view vim  vimdiff vim  hx helix  helix helix
  micro micro  nano nano  spf superfile  superfile superfile  lazygit lazygit
)
typeset -a APPS

# Sets APPS to the known apps in the foreground of this tab's panes, the focused pane's first.
detect_apps() {
  APPS=()
  [[ $CHEATSHEET_APPS == off ]] && return
  local p n id
  local -a panes=($(tab_panes))
  (( ${panes[(Ie)$TPANE]} )) && panes=($TPANE ${panes:#$TPANE})
  for p in $panes; do
    for n in $("$H" pane process-info --pane "$p" 2>/dev/null |
                 jq -r '.result.process_info.foreground_processes[]? | .argv0, .name' 2>/dev/null); do
      id=$APP_OF[${n:t}]
      # macOS ships UW Pico as /usr/bin/nano; GNU nano's keys don't apply to it
      [[ $id == nano && ${commands[nano]:A:t} == pico ]] && continue
      [[ -n $id ]] && (( ! ${APPS[(Ie)$id]} )) && APPS+=($id)
    done
  done
}

render_apps() {
  local id f
  for id in $APPS; do
    f=$(cs_app_file "$id")
    [[ -n $f ]] || continue
    render_keyfile "$f" "$(sed -n 's/^# name: *//p' "$f" | head -1) ${D}(running)${R}" portable
  done
}

# Collects all sections into OUT/ACT/PLAIN. Runs herdr, jq and just, so only when something changed.
build() {
  OUT=() ACT=() PLAIN=()
  apply_palette
  sync_label
  if (( SEARCH )); then
    render_banner "$1"
    render_search
    return
  fi
  load_herdr_keys
  render_banner "$1"
  render_update
  render_search
  render_apps
  render_just "$1"
  render_herdr
  render_terminal
  render_agents
  render_panel
  render_update_status
}

# File search. While SEARCH is on, the panel shows only the logo and the search, and keys go to QUERY.
# FILES (paths relative to SROOT) is listed once per search; RESULTS is FILES ranked for QUERY.
SEARCH=0 QUERY="" SEL=1 SROOT=""
typeset -a FILES RESULTS

start_search() {
  SROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || SROOT=$DIR
  SEARCH=1 QUERY="" SEL=1 SCROLL=0 FP=""
  search_files
}

stop_search() { SEARCH=0 QUERY="" SCROLL=0 FP="" }

# The key a [[keys.command]] block in herdr's config binds to the given command, if any.
bound_key() { # command
  awk -v want="$1" 'function flush(){ if(k!="" && c==want) print k; k=c="" }
       function val(s){ sub(/^[a-z_]+ *= */,"",s); gsub(/^["\x27]|["\x27] *$/,"",s); return s }
       /^\[\[keys\.command\]\]/{ flush(); b=1; next }
       /^\[/{ flush(); b=0 }
       b && /^key *=/{ k=val($0) } b && /^command *=/{ c=val($0) }
       END{ flush() }' "$CONFIG" 2>/dev/null | head -1
}

# rg and fd skip what .gitignore lists; find skips the usual build and dependency folders.
search_files() {
  local out
  if (( $+commands[rg] )); then out=$(cd "$SROOT" && rg --files 2>/dev/null)
  elif (( $+commands[fd] )); then out=$(cd "$SROOT" && fd --type f 2>/dev/null)
  elif git -C "$SROOT" rev-parse >/dev/null 2>&1; then
    out=$(git -C "$SROOT" ls-files --cached --others --exclude-standard 2>/dev/null)
  else
    out=$(cd "$SROOT" && find . -type d \( -name .git -o -name node_modules -o -name DerivedData \
      -o -name .build -o -name build -o -name Pods \) -prune -o -type f -print 2>/dev/null | sed 's#^\./##')
  fi
  FILES=(${(o)${(f)out}})
}

# fzf ranks fuzzy matches best first. Without it, the query's characters must appear in order, ignoring
# case (logv finds LoginView), and files keep their order. An empty query suggests nothing.
rank() {
  setopt local_options extended_glob
  local pat="*" c
  if [[ -z $QUERY ]]; then RESULTS=()
  elif (( $+commands[fzf] )); then RESULTS=(${(f)"$(print -rl -- $FILES | fzf --filter "$QUERY" 2>/dev/null | head -200)"})
  else
    for c in ${(s::)QUERY}; do pat+="${(b)c}*"; done
    RESULTS=(${${(M)FILES:#(#i)${~pat}}[1,200]})
  fi
}

# A framed field in the accent color, so the search stands out from the rows around it: the entry
# point (clickable anywhere) and, while searching, the query line.
search_box() { # left right [action]  (plain text; right is shown in the accent color)
  local w=$(( COLS - 2 )) left=$1 right=$2
  (( w < 16 )) && w=16
  local inner=$(( w - 4 ))
  (( ${#left} + ${#right} + 1 > inner )) && left="${left[1,inner - ${#right} - 2]}…"
  box_row "$K╭${(l:w - 2::─:)}╮$R" "$3"
  box_row "$K│$R $left${(l:inner - ${#left} - ${#right}:: :)}$K$right$R $K│$R" "$3"
  box_row "$K╰${(l:w - 2::─:)}╯$R" "$3"
}

box_row() { # line action
  setopt local_options extended_glob
  OUT+=(" $1") PLAIN+=(" ${(S)1//$'\e'\[[0-9;]#m/}") ACT+=("$2")
}

render_search() {
  if (( ! SEARCH )); then
    local bound=$(bound_key "$CS_PLUGIN_ID.search") key="/"
    [[ -n $bound ]] && key=$(fmt_key "$bound")
    header "files"
    search_box "search files…" "$key" "files:search"
    render_editor
    return
  fi
  rank
  (( SEL > ${#RESULTS} )) && SEL=${#RESULTS}
  (( SEL < 1 )) && SEL=1
  # suggestions start with the first typed character; until then the count shows what's searchable
  local count="${#RESULTS}/${#FILES}"
  [[ -z $QUERY ]] && count="${#FILES} files"
  header "files ${D}— ${SROOT/#$HOME/~}${R}"
  search_box "$QUERY█" "$count"
  local room=$(( LINES - 1 - ${#OUT} )) i p max=$(( COLS - 5 ))
  (( room < 3 )) && room=3
  local n=$(( ${#RESULTS} < room ? ${#RESULTS} : room ))
  (( n )) || return
  for i in {1..$n}; do
    p=$RESULTS[$i]
    (( ${#p} > max )) && p="…${p[-(max - 1),-1]}"
    if (( i == SEL )); then OUT+=(" ${K}"$'\e[7m'"▸ $p "$'\e[27m'"$R")
    else OUT+=(" ${B}▸${R} $p")
    fi
    PLAIN+=(" ▸ $p") ACT+=("open:$RESULTS[$i]")
  done
}

# Tools the file search opens with: name, command, kind. "terminal" runs in the editor tab, "window" is
# a GUI app with its own window, "manager" is a file manager that opens with the file selected in its
# folder, in the editor tab.
typeset -a EDITOR_TABLE=(
  fresh fresh terminal  nvim nvim terminal  helix hx terminal  micro micro terminal
  emacs "emacs -nw" terminal  kakoune kak terminal  vim vim terminal  nano nano terminal
  code code window  cursor cursor window  zed zed window  sublime subl window  xcode xed window
  windsurf windsurf window  superfile spf manager
)
# The panel's "open with" choice, shared by all panels; it wins over CHEATSHEET_EDITOR.
EDITOR_STATE="$CS_STATE_DIR/editor"
EDITOR_MENU=0

cmd_exists() { # command line
  local -a w=(${(z)1})
  if [[ $w[1] == */* ]]; then [[ -x $w[1] ]]
  else (( $+commands[$w[1]] ))
  fi
}

kind_of() { # command line -> terminal | window | manager
  local -a w=(${(z)1}) t
  local i
  for (( i = 1; i <= ${#EDITOR_TABLE}; i += 3 )); do
    t=(${(z)EDITOR_TABLE[i+1]})
    [[ $t[1] == ${w[1]:t} ]] && { print -r -- $EDITOR_TABLE[i+2]; return }
  done
  [[ ${w[1]:t} == (open|codium) ]] && print window || print terminal
}

editor_label() { # command line -> its name in the table, else the command
  local i
  for (( i = 1; i <= ${#EDITOR_TABLE}; i += 3 )); do
    [[ $EDITOR_TABLE[i+1] == $1 ]] && { print -r -- $EDITOR_TABLE[i]; return }
  done
  [[ $1 == open ]] && print "default app" || print -r -- $1
}

# Sets C_NAME, C_CMD and C_NOTE to what can be picked: configured commands outside the table, the
# installed tools of the table, then the system's own fallbacks (vi; on macOS also the default app).
editor_candidates() {
  C_NAME=() C_CMD=() C_NOTE=()
  local src v i
  for src in CHEATSHEET_EDITOR VISUAL EDITOR; do
    v=${(P)src}
    [[ -n $v ]] && cmd_exists "$v" || continue
    (( ${EDITOR_TABLE[(Ie)$v]} || ${C_CMD[(Ie)$v]} )) && continue
    C_NAME+=("$v") C_CMD+=("$v") C_NOTE+=("\$$src")
  done
  for (( i = 1; i <= ${#EDITOR_TABLE}; i += 3 )); do
    cmd_exists "$EDITOR_TABLE[i+1]" || continue
    C_NAME+=("$EDITOR_TABLE[i]") C_CMD+=("$EDITOR_TABLE[i+1]")
    C_NOTE+=("${${${EDITOR_TABLE[i+2]}:#terminal}/manager/file manager}")
  done
  cmd_exists vi && { C_NAME+=(vi) C_CMD+=(vi) C_NOTE+=(system) }
  [[ $(cs_os) == macos ]] && { C_NAME+=("default app") C_CMD+=(open) C_NOTE+=("system window") }
}
typeset -a C_NAME C_CMD C_NOTE

# The panel's choice, then CHEATSHEET_EDITOR, $VISUAL and $EDITOR, then the first installed terminal
# tool of the table, then vi. A chosen tool that is gone is reported in EDITOR_MISSING, not replaced.
pick_editor() {
  local e i
  EDITOR_MISSING=""
  if [[ -f $EDITOR_STATE ]]; then
    e=$(<$EDITOR_STATE)
    cmd_exists "$e" && { REPLY=$e; return 0 }
    EDITOR_MISSING=$e
  fi
  for e in "$CHEATSHEET_EDITOR" "$VISUAL" "$EDITOR"; do
    [[ -n $e ]] && cmd_exists "$e" && { REPLY=$e; return 0 }
  done
  for (( i = 1; i <= ${#EDITOR_TABLE}; i += 3 )); do
    [[ $EDITOR_TABLE[i+2] == terminal ]] && cmd_exists "$EDITOR_TABLE[i+1]" && { REPLY=$EDITOR_TABLE[i+1]; return 0 }
  done
  cmd_exists vi && { REPLY=vi; return 0 }
  return 1
}

# Nothing chosen or configured, and no terminal editor beyond what ships with the system (vi, vim, nano).
# GUI apps don't count: they are never picked automatically, and macOS ships a stub xed without Xcode.
no_real_editor() {
  [[ -f $EDITOR_STATE || -n $CHEATSHEET_EDITOR || -n $VISUAL || -n $EDITOR ]] && return 1
  local i
  for (( i = 1; i <= ${#EDITOR_TABLE}; i += 3 )); do
    [[ $EDITOR_TABLE[i+2] != terminal || $EDITOR_TABLE[i] == (vim|nano) ]] && continue
    cmd_exists "$EDITOR_TABLE[i+1]" && return 1
  done
  return 0
}

set_editor() { # command line
  print -r -- "$1" > "$EDITOR_STATE.tmp" && mv "$EDITOR_STATE.tmp" "$EDITOR_STATE"
  EDITOR_MENU=0
}

# "open with" row, the list of tools while it's open, and install hints when no real editor is set up.
render_editor() {
  local cur label i
  pick_editor; cur=$REPLY
  label=$(editor_label "$cur")
  [[ -n $EDITOR_MISSING ]] && label="$(editor_label "$EDITOR_MISSING") (missing)"
  row "e" "open with: $label" "$K" "editor:menu"
  if (( EDITOR_MENU )); then
    editor_candidates
    for i in {1..${#C_CMD}}; do
      if [[ $C_CMD[i] == $cur && -z $EDITOR_MISSING ]]; then
        OUT+=(" ${K}✓${R} ${K}${(r:13:)C_NAME[i]}${R} ${D}$C_NOTE[i]${R}") PLAIN+=("") ACT+=("")
      else
        row "$C_NAME[i]" "${D}$C_NOTE[i]${R}" "$K" "editor:set:$C_CMD[i]"
      fi
    done
  fi
  no_real_editor || return
  install_row Fresh fresh "brew install fresh-editor" \
    'curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh'
  install_row superfile spf "brew install superfile" 'bash -c "$(curl -sLo- https://superfile.dev/install.sh)"'
}

# With Homebrew the row runs the install in the panel; otherwise it shows the project's own command.
install_row() { # name command brew-command other-command
  cmd_exists "$2" && return
  if (( $+commands[brew] )); then row "install" "$1  ${D}$3${R}" "$K" "install:$3"
  else line "   ${D}install $1: $4${R}"
  fi
}

# GUI editors open their own window. A terminal editor or superfile (given a file, it opens the folder with
# the file selected) runs in a new
# tab, the plugin's "editor" pane, which closes when it exits.
open_file() { # path relative to SROOT
  local abs="$SROOT/$1" ed out tab target
  if ! pick_editor; then fail "no editor found: pick one under open with, or set CHEATSHEET_EDITOR"; return 1; fi
  ed=$REPLY
  [[ -n $EDITOR_MISSING ]] && fail "$(editor_label "$EDITOR_MISSING") isn't installed, opening with $(editor_label "$ed")"
  case $(kind_of "$ed") in
    window)
      ( cd "$SROOT" && ${=ed} "$abs" >/dev/null 2>&1 & )
      return ;;
    *) target=$abs ;;
  esac
  out=$("$H" plugin pane open --plugin "$CS_PLUGIN_ID" --entrypoint editor --placement tab \
          --workspace "$HERDR_WORKSPACE_ID" --cwd "$SROOT" --env "CHEATSHEET_EDITOR_CMD=$ed" \
          --env "CHEATSHEET_FILE=$target" --focus 2>&1)
  tab=$(print -r -- "$out" | jq -r '.result.plugin_pane.pane.tab_id // empty' 2>/dev/null)
  if [[ -z $tab ]]; then
    fail "can't open $1: $(print -r -- "$out" | jq -r '.error.message // empty' 2>/dev/null || print -r -- "$out")"
    return 1
  fi
  herdr_do tab rename "$tab" "${1:t}"
  herdr_do tab focus "$tab"
}

open_selected() {
  rank
  [[ -n $RESULTS[$SEL] ]] || return
  open_file "$RESULTS[$SEL]" && stop_search
}

# The panel's own controls, laid out like the other sections; r and q also work as keys.
render_panel() {
  header "panel"
  row "r" "refresh" "$K" "panel:refresh"
  if banner_on; then row "b" "hide logo" "$K" "panel:banner"
  else row "b" "show logo" "$K" "panel:banner"
  fi
  if [[ $(colors_mode) == terminal ]]; then row "t" "retro colors" "$K" "panel:colors"
  else row "t" "terminal colors" "$K" "panel:colors"
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
  cs_api "$1" "$2" && return
  if [[ -z $REPLY ]]; then fail "$1: no response from herdr"
  else fail "$1: $(print -r -- "$REPLY" | jq -r '.error.message // empty' 2>/dev/null)"
  fi
  return 1
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
    files:search) start_search ;;
    editor:menu) (( EDITOR_MENU = ! EDITOR_MENU )) ;;
    editor:set:*) set_editor "${a#editor:set:}" ;;
    install:*) run_inline "${a#install:}" wait; rehash ;;
    open:*) open_file "${a#open:}" && stop_search ;;
    panel:refresh) pick_terminal; query_theme; update_check force ;;
    panel:banner) toggle_banner ;;
    panel:colors) toggle_colors ;;
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
      while read -r -s -k1 -t 0.05 c </dev/tty; do
        seq+=$c
        [[ $c == [Mmn~] || $seq == [[O][A-D] || ${#seq} -gt 20 ]] && break
      done
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
      elif [[ $seq =~ '^\[\?997;([12])n$' ]]; then
        [[ $match[1] == 2 ]] && APPEARANCE=light || APPEARANCE=dark
      elif (( SEARCH )); then
        # a lone Esc leaves the search; arrow keys move the selection
        case $seq in
          '') stop_search; focus_main ;;
          [[O]A) (( SEL > 1 )) && (( SEL-- )) ;;
          [[O]B) (( SEL++ )) ;;
        esac
      fi
    elif (( SEARCH )); then
      case $k in
        $'\x7f'|$'\b') QUERY=${QUERY[1,-2]} SEL=1 ;;
        $'\x15'|$'\x06') QUERY="" SEL=1 ;;
        $'\n'|$'\r') open_selected ;;
        [[:print:]]) QUERY+=$k SEL=1 ;;
      esac
    else
      case $k in
        # Ctrl-F comes from the search action (herdr key), / from typing in the panel
        /|$'\x06') start_search ;;
        e) (( EDITOR_MENU = ! EDITOR_MENU )); FP="" ;;
        q) "$H" pane close "$HERDR_PANE_ID" >/dev/null 2>&1; exit ;;
        r) FP=""; pick_terminal; query_theme; update_check force ;;
        b) toggle_banner ;;
        t) toggle_colors ;;
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
query_theme
ROOT_STAMP=$(zstat +mtime "$ROOT_FILE" 2>/dev/null)
update_check
DIR="" LAST_FOCUSED="" TPANE="" FP="" SCROLL=0 VIS_ROWS=0 HINT_TOP=0 HINT_BOTTOM=0
pick_terminal
while :; do
  read -r LINES COLS < <(stty size </dev/tty 2>/dev/null || print "40 60")
  follow_update
  if (( SEARCH )); then
    fp="search|$LINES|$COLS|$APPEARANCE|$QUERY|$SEL|$(stamp "$BANNER_FILE" "$COLORS_FILE")"
    [[ "$fp" != "$FP" ]] && { build "$DIR"; FP=$fp; paint }
    handle_input
    continue
  fi
  locate
  detect_apps
  jf=$(find_up "$DIR" justfile Justfile .justfile)
  agents_fp=$(print -r -- "$ALLPANES" | jq -r '[.result.panes[] | select((.agent // "") != "")
    | "\(.pane_id):\(.agent_status):\(.terminal_title_stripped)"] | join(",")' 2>/dev/null)
  fp="$DIR|$LINES|$COLS|$agents_fp|$APPEARANCE|${APPS[*]}|$(stamp "$CONFIG" "$TERMKEYS" "$UPDATE_FILE" "$BANNER_FILE" "$COLORS_FILE" "$EDITOR_STATE" ${jf:+"$jf"} ${jf:+"${jf:h}/$CHEATSHEET_ALIAS_FILE"})"
  [[ "$fp" != "$FP" ]] && { build "$DIR"; FP=$fp; paint }
  handle_input
done
