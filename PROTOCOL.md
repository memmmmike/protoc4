# Claude IPC Protocol v1

## Overview
File-based message passing between Claude instances. Each Claude checks inbox at conversation start and periodically during long tasks.

## Directory Structure
```
~/.claude/ipc/
├── PROTOCOL.md      # This file
├── inbox/           # Incoming messages (all Claudes read from here)
├── outbox/          # Drafts (optional, for debugging)
└── processed/       # Handled messages (move here after processing)
```

## Message Format
Filename: `{unix_timestamp_ms}-{sender_id}.json`

```json
{
  "id": "1706976000000-claude-ttyd",
  "from": "claude-ttyd",
  "to": "claude-pts0" | "all",
  "type": "request" | "response" | "broadcast",
  "ref": null | "id-of-message-being-replied-to",
  "payload": {
    "action": "string describing what's needed",
    "data": {}
  },
  "timestamp": "2026-02-03T21:40:00Z",
  "ttl": 300
}
```

## Fields
- **id**: Unique message ID (timestamp-sender)
- **from**: Sender identifier (use terminal name: claude-ttyd, claude-pts0, etc.)
- **to**: Recipient ("all" for broadcast)
- **type**: request (need something), response (answering), broadcast (FYI)
- **ref**: If responding, the ID of the original message
- **payload.action**: Human-readable description of request/response
- **payload.data**: Structured data if needed
- **timestamp**: ISO 8601
- **ttl**: Seconds until message expires (default 300)

## Sender ID Convention
Use `claude-{tty}` where tty is:
- `pts0`, `pts1`, etc. for SSH sessions
- `ttyd` for web terminal
- `local` for direct console

Detect with: `tty | sed 's|/dev/||' | tr '/' '-'`

## Behavior
1. **On conversation start**: Check inbox, process any messages addressed to you or "all"
2. **After processing**: Move message to `processed/`
3. **When sending**: Write to `inbox/` (not outbox - that's just for drafts)
4. **Expired messages**: Delete if `now > timestamp + ttl`

## Example: Request/Response

Claude-A sends request:
```json
{
  "id": "1706976000000-claude-ttyd",
  "from": "claude-ttyd",
  "to": "claude-pts0",
  "type": "request",
  "ref": null,
  "payload": {
    "action": "What's the GitHub Actions error?",
    "data": {"repo": "memmmmike/witch_at"}
  },
  "timestamp": "2026-02-03T21:40:00Z",
  "ttl": 300
}
```

Claude-B responds:
```json
{
  "id": "1706976030000-claude-pts0",
  "from": "claude-pts0",
  "to": "claude-ttyd",
  "type": "response",
  "ref": "1706976000000-claude-ttyd",
  "payload": {
    "action": "GitHub Actions error details",
    "data": {"error": "SSH host key verification failed", "suggestion": "Add fingerprint"}
  },
  "timestamp": "2026-02-03T21:40:30Z",
  "ttl": 300
}
```

## Cross-Machine Communication

Each machine has its own `~/.claude/ipc/inbox/`. To send messages across machines:

### Host Registry
Store in `~/.claude/ipc/hosts.json`:
```json
{
  "fedora": {
    "ssh": "mlayug@192.168.1.105",
    "tunnel": null
  },
  "zimaboard": {
    "ssh": "mlayug@192.168.1.187",
    "tunnel": "ssh.0pon.com"
  }
}
```

### Sender ID for Cross-Machine
Include hostname: `claude-{hostname}-{tty}`
- `claude-fedora-pts0`
- `claude-zimaboard-ttyd`

### Delivery
To send to a remote host:
```bash
# Direct SSH
ssh user@host "cat > ~/.claude/ipc/inbox/FILENAME.json << 'EOF'
{json}
EOF"

# Via Cloudflare Tunnel
ssh -o ProxyCommand="cloudflared access ssh --hostname TUNNEL" user@host "cat > ~/.claude/ipc/inbox/FILENAME.json << 'EOF'
{json}
EOF"
```

### Routing Logic
1. If `to` matches local hostname or tty → deliver locally
2. If `to` matches remote host → SSH deliver to that host's inbox
3. If `to` is "all" → deliver to all known hosts

## CLAUDE.md Integration
Add to project or user CLAUDE.md:

```markdown
## IPC Protocol
Check ~/.claude/ipc/inbox/ at conversation start for messages from other Claude instances.
See ~/.claude/ipc/PROTOCOL.md for format. Process messages addressed to you or "all",
then move to processed/. Respond by writing to inbox/.
For cross-machine messaging, see hosts.json and deliver via SSH.
```
