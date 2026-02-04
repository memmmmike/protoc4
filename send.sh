#!/bin/bash
# protoc4: Send IPC message
# Usage: send.sh <to> <type> <action> [--host <hostname>] [--data <json>] [--ref <msg-id>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_FILE="$SCRIPT_DIR/hosts.json"

# Parse args
TO=""
TYPE=""
ACTION=""
HOST=""
DATA="{}"
REF="null"

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --data)
            DATA="$2"
            shift 2
            ;;
        --ref)
            REF="\"$2\""
            shift 2
            ;;
        *)
            if [ -z "$TO" ]; then
                TO="$1"
            elif [ -z "$TYPE" ]; then
                TYPE="$1"
            elif [ -z "$ACTION" ]; then
                ACTION="$1"
            fi
            shift
            ;;
    esac
done

# Validate
if [ -z "$TO" ] || [ -z "$TYPE" ] || [ -z "$ACTION" ]; then
    echo "Usage: send.sh <to> <type> <action> [--host <hostname>] [--data <json>] [--ref <msg-id>]"
    echo ""
    echo "  to:      Recipient (e.g., 'claude-server-pts0' or 'all')"
    echo "  type:    Message type (request, response, broadcast)"
    echo "  action:  What you want (human-readable)"
    echo ""
    echo "Options:"
    echo "  --host   Send to remote host (from hosts.json)"
    echo "  --data   JSON data payload"
    echo "  --ref    Reference to original message (for responses)"
    echo ""
    echo "Examples:"
    echo "  send.sh all broadcast 'Build complete'"
    echo "  send.sh claude-server-pts0 request 'Run tests' --data '{\"suite\":\"unit\"}'"
    echo "  send.sh claude-laptop-ttyd response 'Tests passed' --ref 123456-claude-server"
    exit 1
fi

# Validate type
case "$TYPE" in
    request|response|broadcast) ;;
    *)
        echo "Error: type must be 'request', 'response', or 'broadcast'"
        exit 1
        ;;
esac

# Build message
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
TTY=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '-' || echo "script")
TIMESTAMP=$(date +%s%3N)
MSG_ID="${TIMESTAMP}-claude-${HOSTNAME}-${TTY}"
ISO_TIME=$(date -Iseconds)

MESSAGE=$(cat << EOF
{
  "id": "${MSG_ID}",
  "from": "claude-${HOSTNAME}-${TTY}",
  "to": "${TO}",
  "type": "${TYPE}",
  "ref": ${REF},
  "payload": {
    "action": "${ACTION}",
    "data": ${DATA}
  },
  "timestamp": "${ISO_TIME}",
  "ttl": 300
}
EOF
)

# Determine target
if [ -n "$HOST" ]; then
    # Remote delivery
    if [ ! -f "$HOSTS_FILE" ]; then
        echo "Error: hosts.json not found. Create it from hosts.json.example"
        exit 1
    fi
    
    SSH_TARGET=$(grep -A2 "\"$HOST\"" "$HOSTS_FILE" | grep '"ssh"' | cut -d'"' -f4)
    TUNNEL=$(grep -A3 "\"$HOST\"" "$HOSTS_FILE" | grep '"tunnel"' | cut -d'"' -f4)
    
    if [ -z "$SSH_TARGET" ]; then
        echo "Error: Host '$HOST' not found in hosts.json"
        exit 1
    fi
    
    FILENAME="${MSG_ID}.json"
    
    if [ -n "$TUNNEL" ] && [ "$TUNNEL" != "null" ]; then
        # Via Cloudflare Tunnel
        ssh -o ProxyCommand="cloudflared access ssh --hostname $TUNNEL" \
            -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=/dev/null \
            "$SSH_TARGET" "mkdir -p ~/.claude/ipc/inbox && cat > ~/.claude/ipc/inbox/$FILENAME" << EOF
$MESSAGE
EOF
    else
        # Direct SSH
        ssh -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=/dev/null \
            "$SSH_TARGET" "mkdir -p ~/.claude/ipc/inbox && cat > ~/.claude/ipc/inbox/$FILENAME" << EOF
$MESSAGE
EOF
    fi
    
    echo "Sent to $HOST ($SSH_TARGET): $MSG_ID"
else
    # Local delivery
    mkdir -p "$SCRIPT_DIR/inbox"
    echo "$MESSAGE" > "$SCRIPT_DIR/inbox/${MSG_ID}.json"
    echo "Sent locally: $MSG_ID"
fi
