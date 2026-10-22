#!/bin/zsh
# Manages the cheat-sheet pane:
#   ensure   keep one running in tab 1 of each workspace and replace panes restored after a server restart
#   tab      open one in a newly created tab (CHEATSHEET_AUTO_OPEN=all)
#   toggle   open/close it in the current tab
#   replace  swap a cheat-sheet pane that isn't a plugin pane (restored shell, pre-0.5 panel) for one
H="${HERDR_BIN_PATH:-herdr}"
ROOT="${0:A:h}"
CS_ROOT=$ROOT
source "$ROOT/lib/config.zsh"
LABEL="cheatsheet"

panes() { "$H" pane list | jq -c '.result.panes' }

# cheat-sheet panes (labeled or running) matching a jq filter on tab/workspace
cs_panes() { # panes-json filter
  print -r -- "$1" | cs_jq -r "$CS_SHEET_JQ .[] | select($2) | select(sheet) | .pane_id"
}

# The sheet runs as a plugin pane: herdr starts it directly, without the user's shell, and closes the
# pane when it exits. herdr always splits plugin panes 50/50, so the width is applied afterwards.
open_right_of() { # pane
  local new
  new=$("$H" plugin pane open --plugin "$CS_PLUGIN_ID" --entrypoint sheet --placement split \
          --target-pane "$1" --direction right --no-focus | jq -r '.result.plugin_pane.pane.pane_id // empty')
  if [[ -z "$new" ]]; then
    print -u2 "cheatsheet: could not open a plugin pane next to $1"
    return 1
  fi
  size_panel "$1" "$new"
}

# Gives the panel CHEATSHEET_WIDTH content columns, at most 40% of its split, or the fixed share
# CHEATSHEET_RATIO. A pane's frame (border and scrollbar) takes 3 columns of its width. herdr's resize
# amount is a change of the split's ratio, so it is measured from the ratio the two panes have now.
size_panel() { # main-pane panel-pane
  local mw pw w panel want now delta dir=right
  read -r mw pw < <("$H" pane layout --pane "$2" | jq -r --arg a "$1" --arg b "$2" \
    '.result.layout.panes as $p | [($p[] | select(.pane_id == $a) | .rect.width), ($p[] | select(.pane_id == $b) | .rect.width)] | @tsv')
  if [[ -z "$pw" ]] || (( mw + pw <= 0 )); then
    print -u2 "cheatsheet: no layout for $1 and $2, keeping the split as it is"
    return 1
  fi
  w=$(( mw + pw ))
  if [[ -n "$CHEATSHEET_RATIO" ]]; then
    want=$(printf '%.0f' $(( CHEATSHEET_RATIO * 1000 )))
  else
    panel=$(( CHEATSHEET_WIDTH + 3 ))
    (( panel > w * 4 / 10 )) && panel=$(( w * 4 / 10 ))
    # integer division rounds down, so herdr's rounding can only make the panel wider, never narrower
    want=$(( (w - panel) * 1000 / w ))
  fi
  now=$(( mw * 1000 / w ))
  delta=$(( want - now ))
  (( delta < 0 )) && { dir=left; delta=$(( -delta )) }
  (( delta < 3 )) && return
  "$H" pane resize --pane "$1" --direction $dir --amount $(printf '0.%03d' $delta) >/dev/null
}

# Opens a plugin pane in place of a cheat-sheet pane that runs in a shell, then closes that pane.
replace() { # pane
  local all tab target
  all=$(panes)
  tab=$(print -r -- "$all" | jq -r --arg p "$1" '.[] | select(.pane_id == $p) | .tab_id')
  target=$(print -r -- "$all" | cs_jq -r --arg t "$tab" \
    "$CS_SHEET_JQ"' [.[] | select(.tab_id == $t and (sheet | not))][0].pane_id // empty')
  [[ -n "$target" ]] || return
  if [[ "$1" == "$HERDR_PANE_ID" ]]; then
    # a migrating sheet replaces its own pane: closing it ends this script, so the new panel opens first
    open_right_of "$target" && "$H" pane close "$1" >/dev/null
  else
    # closed first, so the new panel is sized against the full width
    "$H" pane close "$1" >/dev/null && open_right_of "$target"
  fi
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
  # herdr restores plugin panes as plain shells after a server restart. Only on startup: a pane opened a
  # moment ago by tab.created hasn't set its title yet and would look the same.
  if [[ "$HERDR_PLUGIN_EVENT" == startup ]]; then
    all=$(panes)
    for p in $(cs_panes "$all" ".workspace_id == \"$ws\""); do
      print -r -- "$all" | jq -e --arg p "$p" --arg l "$LABEL" \
        '.[] | select(.pane_id == $p and .terminal_title_stripped == $l)' >/dev/null || replace "$p"
    done
  fi
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
  replace) replace "$2" ;;
  *) print -u2 "usage: panel.zsh ensure|tab|toggle|replace PANE"; exit 2 ;;
esac
