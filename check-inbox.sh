#!/bin/bash
# Check IPC inbox and inject messages into conversation

INBOX="$HOME/.claude/ipc/inbox"
PROCESSED="$HOME/.claude/ipc/processed"
HOSTNAME=$(hostname)
MY_TTY=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '-' || echo "unknown")
MY_ID="claude-${HOSTNAME}-${MY_TTY}"

mkdir -p "$PROCESSED"

shopt -s nullglob
FOUND=""
for msg in "$INBOX"/*.json; do
  [ -f "$msg" ] || continue

  TO=$(grep -o '"to"[[:space:]]*:[[:space:]]*"[^"]*"' "$msg" | cut -d'"' -f4)

  if [ "$TO" = "all" ] || [ "$TO" = "$MY_ID" ] || [[ "$TO" == *"$HOSTNAME"* ]] || [[ "$TO" == *"fedora"* ]]; then
    FOUND="$FOUND$(cat "$msg")\n---\n"
    mv "$msg" "$PROCESSED/"
  fi
done

if [ -n "$FOUND" ]; then
  echo "=== IPC MESSAGES RECEIVED ==="
  echo -e "$FOUND"
  echo "Process these messages before continuing with user request."
fi

exit 0
