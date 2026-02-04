#!/usr/bin/env bash
# protoc4: Check inbox for IPC messages
# Called by Claude Code hook on UserPromptSubmit

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INBOX="$SCRIPT_DIR/inbox"
PROCESSED="$SCRIPT_DIR/processed"

# Determine our identity
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
TTY=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '-' || echo "unknown")
MY_ID="claude-${HOSTNAME}-${TTY}"

# Ensure directories exist
mkdir -p "$INBOX" "$PROCESSED"

# Find messages for us
NOW=$(date +%s)
MESSAGES=""

for msg in "$INBOX"/*.json 2>/dev/null; do
    [ -f "$msg" ] || continue
    
    # Parse message
    TO=$(grep -o '"to"[[:space:]]*:[[:space:]]*"[^"]*"' "$msg" 2>/dev/null | head -1 | cut -d'"' -f4)
    TTL=$(grep -o '"ttl"[[:space:]]*:[[:space:]]*[0-9]*' "$msg" 2>/dev/null | head -1 | grep -o '[0-9]*$')
    TIMESTAMP=$(grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' "$msg" 2>/dev/null | head -1 | cut -d'"' -f4)
    
    # Default TTL
    [ -z "$TTL" ] && TTL=300
    
    # Check expiry (if we can parse timestamp)
    if [ -n "$TIMESTAMP" ]; then
        MSG_TIME=$(date -d "$TIMESTAMP" +%s 2>/dev/null || echo "0")
        if [ "$MSG_TIME" -gt 0 ] && [ $((NOW - MSG_TIME)) -gt "$TTL" ]; then
            # Expired - move to processed
            mv "$msg" "$PROCESSED/" 2>/dev/null || true
            continue
        fi
    fi
    
    # Check if message is for us
    if [ "$TO" = "all" ] || [ "$TO" = "$MY_ID" ] || [[ "$TO" == *"$HOSTNAME"* ]] || [[ "$TO" == *"$TTY"* ]]; then
        FROM=$(grep -o '"from"[[:space:]]*:[[:space:]]*"[^"]*"' "$msg" 2>/dev/null | head -1 | cut -d'"' -f4)
        TYPE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$msg" 2>/dev/null | head -1 | cut -d'"' -f4)
        ACTION=$(grep -o '"action"[[:space:]]*:[[:space:]]*"[^"]*"' "$msg" 2>/dev/null | head -1 | cut -d'"' -f4)
        
        MESSAGES="${MESSAGES}
---
**IPC ${TYPE^^} from ${FROM}**
${ACTION}
$(cat "$msg")
---
"
        # Move to processed
        mv "$msg" "$PROCESSED/" 2>/dev/null || true
    fi
done

# Output messages to Claude
if [ -n "$MESSAGES" ]; then
    echo "=== INCOMING IPC MESSAGES ==="
    echo "$MESSAGES"
    echo ""
    echo "Process these messages. Respond via ~/.claude/ipc/send.sh if needed."
fi

exit 0
