#!/bin/bash
# IPC Daemon - watches inbox and invokes Claude to process messages automatically
# Requires: inotify-tools (inotifywait)

INBOX="$HOME/.claude/ipc/inbox"
PROCESSED="$HOME/.claude/ipc/processed"
HOSTNAME=$(hostname)
LOG="$HOME/.claude/ipc/daemon.log"

log() {
  echo "$(date -Iseconds): $1" >> "$LOG"
}

log "IPC daemon started on $HOSTNAME"
log "Watching: $INBOX"

# Check if inotifywait is available
if ! command -v inotifywait &> /dev/null; then
  log "ERROR: inotifywait not found. Install inotify-tools."
  echo "ERROR: inotifywait not found. Install inotify-tools."
  echo "  Debian/Ubuntu: sudo apt install inotify-tools"
  echo "  Fedora: sudo dnf install inotify-tools"
  echo "  NixOS: nix-env -iA nixos.inotify-tools"
  exit 1
fi

mkdir -p "$INBOX" "$PROCESSED"

inotifywait -m -e create -e moved_to "$INBOX" 2>/dev/null | while read dir action file; do
  if [[ "$file" == *.json ]]; then
    MSG_PATH="$INBOX/$file"

    # Parse message metadata for logging
    FROM=$(grep -o '"from"[[:space:]]*:[[:space:]]*"[^"]*"' "$MSG_PATH" 2>/dev/null | cut -d'"' -f4)
    TO=$(grep -o '"to"[[:space:]]*:[[:space:]]*"[^"]*"' "$MSG_PATH" 2>/dev/null | cut -d'"' -f4)
    ACTION=$(grep -o '"action"[[:space:]]*:[[:space:]]*"[^"]*"' "$MSG_PATH" 2>/dev/null | cut -d'"' -f4)

    log "New message: $file (from=$FROM to=$TO action='$ACTION')"
    log "Invoking Claude to process message..."

    # Invoke Claude to process the message
    claude -p --dangerously-skip-permissions \
      "Check ~/.claude/ipc/inbox/ and process any messages per PROTOCOL.md. Handle requests and send responses back via SSH." \
      >> "$LOG" 2>&1

    log "Processing complete for $file"
  fi
done
