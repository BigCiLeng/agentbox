#!/usr/bin/env bash
set -euo pipefail

# Fix permissions for mounted volumes if running as root
if [ "$(id -u)" = "0" ]; then
  # Ensure /home/node directory exists and has correct permissions
  mkdir -p /home/node
  chown -R node:node /home/node || true
  
  # Also make sure workspace is accessible (if you mount something writable)
  if [ -d /workspace ]; then
    chown -R node:node /workspace 2>/dev/null || true
  fi

  # Drop privileges to node for the actual command
  exec gosu node "$0" "$@"
fi

cd /workspace || true

# Optional auto tmux
if [[ "${AUTO_TMUX:-0}" == "1" ]]; then
  SESSION="${TMUX_SESSION:-agent}"
  if command -v tmux >/dev/null 2>&1; then
    tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION"
    exec tmux attach -t "$SESSION"
  fi
fi

exec "$@"