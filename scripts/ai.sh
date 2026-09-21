#!/usr/bin/env bash
# ai.sh — Launch the AI workbench in Zellij.
# Runs from the AI root (the grandparent of this repo: /mnt/c/AI, /mnt/d/AI,
# ...) so the layout's panes open there without hardcoding a drive letter.
cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && exec zellij --layout ai-workbench "$@"
