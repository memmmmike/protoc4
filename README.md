# Claude IPC Protocol (protoc4)

File-based inter-process communication for Claude Code instances.

## Overview

Enables Claude Code sessions to exchange messages without user relay. Works locally (same machine, different terminals) and across machines via SSH.

## Quick Start

1. **Install** - Copy this directory to `~/.claude/ipc/`

2. **Configure hook** - Add to `~/.claude/settings.json`:
```json
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
```

3. **Add to CLAUDE.md** (optional but recommended):
```markdown
## IPC Protocol
Check ~/.claude/ipc/inbox/ at conversation start for messages.
See ~/.claude/ipc/PROTOCOL.md for format.
```

## Directory Structure

```
~/.claude/ipc/
├── README.md           # This file
├── PROTOCOL.md         # Full protocol specification
├── check-inbox.sh      # Hook script (checks inbox on prompt)
├── hosts.json          # Registry of known hosts for cross-machine IPC
├── inbox/              # Incoming messages
├── outbox/             # Drafts (optional)
└── processed/          # Handled messages
```

## Sending a Message

```bash
cat > ~/.claude/ipc/inbox/$(date +%s%3N)-claude-$(hostname).json << 'EOF'
{
  "id": "unique-id",
  "from": "claude-zimaboard-ttyd",
  "to": "claude-zimaboard-pts0",
  "type": "request",
  "ref": null,
  "payload": {
    "action": "What you want",
    "data": {}
  },
  "timestamp": "2026-02-03T21:00:00Z",
  "ttl": 300
}
EOF
```

## Message Types

- `request` - Ask another Claude to do something
- `response` - Reply to a request (set `ref` to original message ID)
- `broadcast` - FYI to all (use `"to": "all"`)

## Cross-Machine

Edit `hosts.json` with SSH connection info:

```json
{
  "zimaboard": {"ssh": "mlayug@192.168.1.187", "tunnel": "ssh.0pon.com"},
  "fedora": {"ssh": "mlayug@192.168.1.105", "tunnel": null}
}
```

Deliver via SSH:

```bash
ssh user@host "cat > ~/.claude/ipc/inbox/FILE.json << 'INNEREOF'
{message json}
INNEREOF"
```

## Limitations

- Not real-time: Messages only processed when user submits a prompt
- Requires user activity: Silent sessions won't check inbox
- No guaranteed delivery: Messages expire after TTL seconds

## License

MIT
