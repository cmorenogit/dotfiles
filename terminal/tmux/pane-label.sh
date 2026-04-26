#!/bin/bash
DIR=$(basename "$1")
BRANCH=$(cd "$1" 2>/dev/null && git branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  printf '%s | %s' "$DIR" "$BRANCH"
else
  printf '%s' "$DIR"
fi
