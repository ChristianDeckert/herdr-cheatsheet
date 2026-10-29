# herdr-cheatsheet settings (sourced as zsh). Uncomment a line to change it.
# Content settings apply within seconds (or press r in the panel); width and auto-open
# apply to newly opened panels.

# Panel width in content columns; 54 fits the full logo. Capped at 40% of the tab.
# CHEATSHEET_WIDTH=54
# Or a fixed share kept by the main pane instead (0.80 = 20% wide panel):
# CHEATSHEET_RATIO=0.80

# Logo banner at the top: on, off. The panel's "b" toggle overrides this for all panels.
# CHEATSHEET_BANNER=on

# Agent overview: all, attention (only blocked/done agents), off. At most this many rows:
# CHEATSHEET_AGENTS=all
# CHEATSHEET_AGENTS_MAX=8

# Other tabs offer to follow tab 1 when it moved to another directory: a click restarts their lazygit
# and cd's their shells at a prompt there. ask, off.
# CHEATSHEET_FOLLOW=ask

# Update notice: on (ask GitHub for a newer version when a panel starts and on refresh), off.
# CHEATSHEET_UPDATE_CHECK=on

# Colors: retro (pastel palette, deeper on light backgrounds) or terminal (the theme's own colors).
# The panel's "t" toggle overrides this for all panels.
# CHEATSHEET_COLORS=retro
# Light or dark background: auto (ask the terminal), dark, light.
# CHEATSHEET_APPEARANCE=auto

# Editor for files opened from the search (/): a terminal editor opens in a new tab, a GUI editor
# (code, zed, subl, xed, ...) in its own window. The panel's "open with" choice overrides this.
# Without either: $VISUAL, $EDITOR, the first installed terminal editor, vi.
# CHEATSHEET_EDITOR=vim

# Key sections for apps running in the tab (editors, file managers, git and DevOps tools, system
# monitors, AI agents; see the README for the list): on, off.
# To change a list, copy it from the plugin's defaults/apps/ into an apps/ folder next to this file.
# CHEATSHEET_APPS=on

# Tools, devtools and packages sections with ready-made commands (ffmpeg, compression; iOS, Android,
# languages, docker, git; Homebrew, apt, pacman, ...): on, off. Single sections and groups can also be hidden in the panel. A click types
# the command at a shell prompt in the tab. To change a list, copy the plugin's defaults/tools.txt or
# defaults/devtools.txt or defaults/packages.txt next to this file and edit it there.
# CHEATSHEET_TOOLS=on

# When the panel opens by itself: all (every new tab), first (tab 1 of each workspace), off (toggle key only).
# CHEATSHEET_AUTO_OPEN=all

# Terminal shortcut section: auto (detect), off, or a terminal id:
# iterm, apple-terminal, ghostty, wezterm, kitty, alacritty, hyper, gnome-terminal, konsole,
# windows-terminal, vscode, generic. To customize a list, copy it from the plugin's
# defaults/terminals/ into the terminals/ folder next to this file and edit it there.
# CHEATSHEET_TERMINAL=auto

# Or show your own file instead, under your own heading:
# CHEATSHEET_TERMINAL_KEYS="${0:A:h}/my-keys.txt"
# CHEATSHEET_TERMINAL_NAME="My terminal"

# Optional file in a project root whose `alias x='just recipe'` lines appear next to the recipes.
# CHEATSHEET_ALIAS_FILE=".project.zsh"
