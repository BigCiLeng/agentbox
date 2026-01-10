FROM node:22-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

# ---- Optional: proxy for build stage (do NOT hardcode service names) ----
# ARG HTTP_PROXY
# ARG HTTPS_PROXY
# ARG ALL_PROXY
# ARG NO_PROXY

# ENV HTTP_PROXY=${HTTP_PROXY}
# ENV HTTPS_PROXY=${HTTPS_PROXY}
# ENV ALL_PROXY=${ALL_PROXY}
# ENV NO_PROXY=${NO_PROXY}

# ---- System packages ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client ca-certificates curl wget jq less vim \
    ripgrep fd-find tmux \
    python3 python3-venv python3-pip \
    unzip xz-utils \
    gosu \
  && rm -rf /var/lib/apt/lists/*

# fd on Debian is fdfind
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd || true

# ---- Prepare dirs & permissions (node user exists in base image) ----
# Ensure home dirs exist and are owned by node (covers fresh images; volumes handled in entrypoint)
RUN mkdir -p /home/node/.config /home/node/.cache /home/node/.npm /home/node/.npm-global \
 && chown -R node:node /home/node

# ---- Entrypoint (set executable bit at copy-time; avoids chmod permission issues) ----
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# ---- Non-root runtime ----
USER node
WORKDIR /home/node

# npm global install location for non-root
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=/home/node/.npm-global/bin:/home/node/.local/bin:/home/node/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Optional: faster / closer registry (use https)
RUN npm config set registry https://mirrors.cloud.tencent.com/npm/

# --- Install Bun (for bunx) ---
# README recommends bunx for installer; bun install needs unzip (already installed).  [oai_citation:4‡GitHub](https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/refs/heads/master/README.md)
RUN npm i -g bun

# Install CLIs (non-root, goes into ~/.npm-global)
RUN npm i -g @google/gemini-cli opencode-ai @openai/codex

# (Optional but recommended) preinstall oh-my-opencode package so bunx won't download every time
# You can pin a beta version if you want: oh-my-opencode@3.0.0-beta.1  [oai_citation:5‡GitHub](https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/refs/heads/master/README.md)
RUN npm i -g oh-my-opencode

# --- Helper: one-command installer for oh-my-opencode ---
# README: bunx oh-my-opencode install ... and supports --no-tui + subscription flags.  [oai_citation:6‡GitHub](https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/refs/heads/master/README.md)
RUN cat > /home/node/.npm-global/bin/omo-install <<'EOF' && chmod +x /home/node/.npm-global/bin/omo-install
#!/usr/bin/env bash
# Use bunx as recommended by the project README
exec bunx oh-my-opencode install --no-tui --claude="no" --chatgpt="yes" --gemini="yes"
EOF

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]