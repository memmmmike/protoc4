# protoc4

File-based IPC for Claude Code. Let multiple Claude sessions communicate without you playing messenger.

## Why?

You're SSH'd into a server with Claude Code running. On your laptop, another Claude is working on related code. They need to coordinate - share context, delegate tasks, report results. Without this, **you** are the message bus, copy-pasting between terminals.

protoc4 lets them talk directly.

## Use Cases

### 1. Distributed Development
Claude on your laptop designs an API. Claude on the server implements it. They stay in sync:
```
laptop-claude: "API spec updated: POST /users now requires email validation"
server-claude: "Acknowledged. Updating implementation."
```

### 2. Code Review Pipeline
One Claude writes code, another reviews it:
```
writer-claude: "Completed auth module. Ready for review."
reviewer-claude: "Found 3 issues: SQL injection on line 42..."
```

### 3. Parallel Task Execution
Split a large refactor across multiple sessions:
```
coordinator: "You take src/api/*, I'll handle src/lib/*"
worker: "src/api/ complete. 12 files updated."
```

### 4. Cross-Machine Ops
Claude on your dev machine triggers deploys on production:
```
dev-claude: "Build passed. Deploy to staging."
prod-claude: "Deployed. Health check passed."
```

## Install

```bash
git clone https://github.com/memmmmike/protoc4.git ~/.claude/ipc
~/.claude/ipc/install.sh
```

Or manually:

1. Copy to `~/.claude/ipc/`
2. Run `install.sh` or manually add hook to `~/.claude/settings.json`
3. Copy `hosts.json.example` to `hosts.json` and configure your machines

## Quick Start

### Send a message
```bash
~/.claude/ipc/send.sh "claude-server-pts0" "request" "Run the test suite"
```

### Check inbox (automatic via hook, or manual)
```bash
~/.claude/ipc/check-inbox.sh
```

### Cross-machine
```bash
~/.claude/ipc/send.sh "claude-server-pts0" "request" "Deploy to prod" --host server
```

## How It Works

1. Messages are JSON files dropped in `~/.claude/ipc/inbox/`
2. A hook runs `check-inbox.sh` every time you submit a prompt
3. Matching messages get injected into the conversation context
4. Claude sees them and can respond by writing to inbox

```
~/.claude/ipc/
├── inbox/              # Incoming messages (auto-checked)
├── processed/          # Handled messages (moved here after processing)
├── check-inbox.sh      # Hook script
├── send.sh             # Helper to send messages
├── hosts.json          # Your machines (not in git)
└── PROTOCOL.md         # Full spec
```

## Message Format

```json
{
  "id": "1706976000000-claude-laptop-pts0",
  "from": "claude-laptop-pts0",
  "to": "claude-server-ttyd",
  "type": "request",
  "ref": null,
  "payload": {
    "action": "Run database migrations",
    "data": {"env": "staging"}
  },
  "timestamp": "2024-02-03T21:00:00Z",
  "ttl": 300
}
```

- **from/to**: `claude-{hostname}-{tty}` format
- **type**: `request`, `response`, or `broadcast`
- **ref**: For responses, the ID of the original message
- **ttl**: Seconds until message expires

## Cross-Machine Setup

1. Copy `hosts.json.example` to `hosts.json`
2. Add your machines:
```json
{
  "laptop": {"ssh": "user@192.168.1.10", "tunnel": null},
  "server": {"ssh": "user@server.example.com", "tunnel": "ssh.example.com"}
}
```

3. Ensure SSH keys are set up for passwordless access
4. For Cloudflare Tunnel, set `tunnel` to the hostname

## Automatic Mode (Daemon)

The default hook-based approach requires user activity. For fully automatic processing, run the IPC daemon:

```bash
# Install the systemd user service
mkdir -p ~/.config/systemd/user
cp ~/.claude/ipc/claude-ipc.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now claude-ipc.service
```

The daemon uses `inotifywait` to watch the inbox and automatically invokes Claude when messages arrive.

**Requirements:**
- `inotify-tools` package (provides `inotifywait`)
- Claude Code installed and in PATH

**Check status:**
```bash
systemctl --user status claude-ipc.service
tail -f ~/.claude/ipc/daemon.log
```

## Limitations

**Hook mode: Not real-time.** Messages are checked when you submit a prompt. If Claude is mid-response or idle, it won't see new messages until you interact.

**Hook mode: Requires user activity.** A completely silent Claude session won't process its inbox.

**Daemon mode solves both** - but runs Claude in the background, which uses API credits.

**No delivery guarantees.** Messages expire after TTL. No retries, no acknowledgments.

**Claude Code only.** Uses Claude Code's hook system. Won't work with other AI tools.

This is file-based message passing, not a pub/sub system. It's simple, it works, but it's not Kafka.

## Protocol Reference

See [PROTOCOL.md](PROTOCOL.md) for the full specification.

## License

MIT
