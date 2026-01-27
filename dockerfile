FROM node:22-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

# Optional: proxy for build stage (do NOT hardcode service names)
# ARG HTTP_PROXY
# ARG HTTPS_PROXY
# ARG ALL_PROXY
# ARG NO_PROXY
# ENV HTTP_PROXY=${HTTP_PROXY}
# ENV HTTPS_PROXY=${HTTPS_PROXY}
# ENV ALL_PROXY=${ALL_PROXY}
# ENV NO_PROXY=${NO_PROXY}
# Replace apt sources with Chinese mirror (Tsinghua)
RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources || \
    sed -i 's|http://deb.debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list || \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# Install system packages and create necessary directories in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client ca-certificates curl wget jq less vim procps \
    ripgrep fd-find tmux \
    python3 python3-venv python3-pip \
    unzip xz-utils \
    gosu \
  && ln -sf "$(command -v fdfind)" /usr/local/bin/fd || true \
  && mkdir -p /home/node/.config /home/node/.cache /home/node/.npm /home/node/.npm-global \
  && chown -R node:node /home/node \
  && rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch to non-root user
USER node
WORKDIR /home/node

# Set npm global install location and PATH for non-root user
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global \
    PATH=/home/node/.npm-global/bin:/home/node/.local/bin:/home/node/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Configure npm registry and install global packages in one layer for better caching
RUN npm config set registry https://mirrors.cloud.tencent.com/npm/ \
  && npm i -g bun @google/gemini-cli opencode-ai @openai/codex @anthropic-ai/claude-code \
  && npx oh-my-opencode install --no-tui --claude="yes" --chatgpt="yes" --gemini="yes" || true

# Create helper script for oh-my-opencode installer
RUN cat > /home/node/.npm-global/bin/omo-install <<'EOF' && chmod +x /home/node/.npm-global/bin/omo-install
#!/usr/bin/env bash
exec npx oh-my-opencode install --no-tui --claude="yes" --chatgpt="yes" --gemini="yes"
EOF

# Set working directory
WORKDIR /workspace

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node --version || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]