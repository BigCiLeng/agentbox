#!/usr/bin/env bash
set -euo pipefail

# Fix permissions for mounted volumes if running as root
if [ "$(id -u)" = "0" ]; then
  for d in /home/node/.config /home/node/.cache /home/node/.npm /home/node/.npm-global /home/node/clash-for-linux /home/node/.bash_config; do
    mkdir -p "$d"
    chown -R node:node "$d" || true
  done
  # Also make sure workspace is accessible (if you mount something writable)
  if [ -d /workspace ]; then
    chown -R node:node /workspace 2>/dev/null || true
  fi

  # Drop privileges to node for the actual command
  exec gosu node "$0" "$@"
fi

# Setup persistent .bashrc
# Link .bashrc to the persistent volume directory
if [ ! -f /home/node/.bash_config/.bashrc ]; then
  # If persistent .bashrc doesn't exist, create a default one
  cat > /home/node/.bash_config/.bashrc << 'EOF'
# ~/.bashrc
# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User specific environment and startup programs
EOF
fi
# Create symlink if .bashrc doesn't exist or is not already a symlink to the persistent location
if [ ! -e /home/node/.bashrc ]; then
  ln -sf /home/node/.bash_config/.bashrc /home/node/.bashrc 2>/dev/null || true
elif [ -f /home/node/.bashrc ] && [ ! -L /home/node/.bashrc ]; then
  # If .bashrc exists as a regular file, backup to volume and replace with symlink
  cp /home/node/.bashrc /home/node/.bash_config/.bashrc 2>/dev/null || true
  rm -f /home/node/.bashrc 2>/dev/null || true
  ln -sf /home/node/.bash_config/.bashrc /home/node/.bashrc 2>/dev/null || true
elif [ -L /home/node/.bashrc ]; then
  # If it's already a symlink, ensure it points to the persistent location
  TARGET=$(readlink -f /home/node/.bashrc 2>/dev/null || true)
  if [ "$TARGET" != "/home/node/.bash_config/.bashrc" ]; then
    rm -f /home/node/.bashrc 2>/dev/null || true
    ln -sf /home/node/.bash_config/.bashrc /home/node/.bashrc 2>/dev/null || true
  fi
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