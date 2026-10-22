# herdr-cheatsheet settings. Sourced as zsh; changes apply to newly opened panels
# (toggle the panel off/on or press r for content settings).

# Width split: the main pane keeps this share, the cheat sheet gets the rest (0.80 = 20% panel).
CHEATSHEET_RATIO=0.80

# When the panel opens by itself: all (every new tab), first (tab 1 of each workspace), off (toggle key only).
CHEATSHEET_AUTO_OPEN=all

# Heading and file for the terminal-emulator section ("" hides it).
CHEATSHEET_TERMINAL_NAME="iTerm"
CHEATSHEET_TERMINAL_KEYS="${0:A:h}/terminal-keys.txt"

# Optional file in a project root whose `alias x='just recipe'` lines are shown next to the recipes.
CHEATSHEET_ALIAS_FILE=".project.zsh"
