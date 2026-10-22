#!/bin/zsh
# Manages the cheat-sheet pane:
#   ensure  keep one running in tab 1 of each workspace and restart panes restored after a server restart
#   tab     open one in a newly created tab (CHEATSHEET_AUTO_OPEN=all)
#   toggle  open/close it in the current tab
H="${HERDR_BIN_PATH:-herdr}"
ROOT="${0:A:h}"
CS_ROOT=$ROOT
source "$ROOT/lib/config.zsh"
LABEL="cheatsheet"

panes() { "$H" pane list | jq -c '.result.panes' }

# cheat-sheet panes (labeled or running) matching a jq filter on tab/workspace
cs_panes() { # panes-json filter
  print -r -- "$1" | jq -r --arg l "$LABEL" ".[] | select($2) |
    select(.label == \$l or .terminal_title_stripped == \$l) | .pane_id"
}

# The sheet runs as a plain pane process, so it gets the plugin context through its command line.
start() { # pane
  "$H" pane rename "$1" "$LABEL" >/dev/null
  "$H" pane run "$1" "CHEATSHEET_PLUGIN_ID=${(q)CS_PLUGIN_ID} CHEATSHEET_CONFIG_DIR=${(q)CS_CONFIG_DIR} CHEATSHEET_STATE_DIR=${(q)CS_STATE_DIR} zsh ${(q)ROOT}/sheet.zsh" >/dev/null
}

open_right_of() { # pane
  local new
  new=$("$H" pane split "$1" --direction right --ratio "$CHEATSHEET_RATIO" --no-focus | jq -r '.result.pane.pane_id')
  [[ -n "$new" && "$new" != null ]] && start "$new"
}

ensure_tab() { # tab
  local tab=$1 all target lock="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}}/lock-${1//:/_}"
  # workspace.created and tab.created fire together for tab 1: serialize per tab so only one panel opens
  for _ in {1..50}; do mkdir "$lock" 2>/dev/null && break; sleep 0.1; done
  all=$(panes)
  if [[ -z "$(cs_panes "$all" ".tab_id == \"$tab\"")" ]]; then
    target=$(print -r -- "$all" | jq -r --arg t "$tab" '[.[] | select(.tab_id == $t)][0].pane_id // empty')
    [[ -n "$target" ]] && open_right_of "$target"
  fi
  rmdir "$lock" 2>/dev/null
}

ensure_ws() { # workspace
  local ws=$1 all tab1 p
  all=$(panes)
  # restored panes come back as idle shells: restart the sheet in them
  for p in $(cs_panes "$all" ".workspace_id == \"$ws\""); do
    print -r -- "$all" | jq -e --arg p "$p" --arg l "$LABEL" \
      '.[] | select(.pane_id == $p and .terminal_title_stripped == $l)' >/dev/null || start "$p"
  done
  [[ "$CHEATSHEET_AUTO_OPEN" == off ]] && return
  tab1=$("$H" tab list --workspace "$ws" | jq -r '.result.tabs[] | select(.number == 1) | .tab_id')
  [[ -n "$tab1" ]] && ensure_tab "$tab1"
}

case "$1" in
  ensure)
    if [[ "$HERDR_PLUGIN_EVENT" == startup ]]; then
      for ws in $("$H" workspace list | jq -r '.result.workspaces[].workspace_id'); do ensure_ws "$ws"; done
    else
      ws="${HERDR_WORKSPACE_ID:-$(print -r -- "$HERDR_PLUGIN_EVENT_JSON" |
            jq -r '.workspace.workspace_id // .workspace_id // empty')}"
      [[ -n "$ws" ]] && ensure_ws "$ws"
    fi ;;
  tab)
    [[ "$CHEATSHEET_AUTO_OPEN" == all ]] || exit 0
    tab=$(print -r -- "$HERDR_PLUGIN_EVENT_JSON" | jq -r '.tab.tab_id // .tab_id // empty' 2>/dev/null)
    tab="${tab:-$HERDR_TAB_ID}"
    [[ -n "$tab" ]] && ensure_tab "$tab" ;;
  toggle)
    tab="${HERDR_TAB_ID:-$("$H" pane list | jq -r '.result.panes[] | select(.focused) | .tab_id')}"
    all=$(panes)
    existing=($(cs_panes "$all" ".tab_id == \"$tab\""))
    if (( ${#existing} )); then
      for p in $existing; do "$H" pane close "$p" >/dev/null; done
    else
      target="${HERDR_PANE_ID:-$(print -r -- "$all" | jq -r --arg t "$tab" '[.[] | select(.tab_id == $t)][0].pane_id // empty')}"
      [[ -n "$target" ]] && open_right_of "$target"
    fi ;;
  *) print -u2 "usage: panel.zsh ensure|tab|toggle"; exit 2 ;;
esac
