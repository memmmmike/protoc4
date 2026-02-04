#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "Installing protoc4..."

# Create directories
mkdir -p "$SCRIPT_DIR/inbox" "$SCRIPT_DIR/processed" "$SCRIPT_DIR/outbox"

# Make scripts executable
chmod +x "$SCRIPT_DIR/check-inbox.sh" "$SCRIPT_DIR/send.sh" 2>/dev/null || true

# Create hosts.json from example if it doesn't exist
if [ ! -f "$SCRIPT_DIR/hosts.json" ] && [ -f "$SCRIPT_DIR/hosts.json.example" ]; then
    cp "$SCRIPT_DIR/hosts.json.example" "$SCRIPT_DIR/hosts.json"
    echo "Created hosts.json from example - edit with your machines"
fi

# Add hook to settings.json
if [ -f "$SETTINGS" ]; then
    # Check if hook already exists
    if grep -q "check-inbox.sh" "$SETTINGS" 2>/dev/null; then
        echo "Hook already configured in settings.json"
    else
        echo "Warning: settings.json exists but hook not found."
        echo "Add this to your settings.json manually:"
        echo ""
        cat << 'HOOK'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/ipc/check-inbox.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
HOOK
    fi
else
    # Create new settings.json with hook
    cat > "$SETTINGS" << 'JSON'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/ipc/check-inbox.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
JSON
    echo "Created settings.json with IPC hook"
fi

# Suggest CLAUDE.md addition
echo ""
echo "Optional: Add this to ~/.claude/CLAUDE.md:"
echo ""
cat << 'CLAUDEMD'
## IPC Protocol
Check ~/.claude/ipc/inbox/ for messages from other Claude instances.
See ~/.claude/ipc/PROTOCOL.md for format.
CLAUDEMD

echo ""
echo "Done! protoc4 installed."
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude/ipc/hosts.json with your machines"
echo "  2. Test with: ~/.claude/ipc/send.sh all broadcast 'Hello world'"
