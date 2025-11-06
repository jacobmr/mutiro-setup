#!/bin/bash
set -e
echo "=== Mutiro + Claude Setup ==="

if ! command -v mutiro &> /dev/null; then
  echo "Installing Mutiro CLI..."
  curl -sSL https://mutiro.com/downloads/install.sh | bash
else
  echo "Mutiro CLI already installed."
fi

if mutiro whoami &> /tmp/mutiro_whoami.txt; then
  USERNAME=$(grep -o "@[a-zA-Z0-9_]*" /tmp/mutiro_whoami.txt | head -1)
  echo "✅ Logged in as $USERNAME"
else
  echo "🔐 Logging into Mutiro..."
  read -p "Enter your email for Mutiro: " EMAIL
  mutiro auth login "$EMAIL"
fi

echo "Fetching Mutiro config..."
mutiro whoami --json > /tmp/mutiro_info.json || true
API_KEY=$(jq -r '.api_key' /tmp/mutiro_info.json 2>/dev/null || echo "")
AGENT_ID=$(jq -r '.agent.id' /tmp/mutiro_info.json 2>/dev/null || echo "")
AGENT_USERNAME=$(jq -r '.agent.username' /tmp/mutiro_info.json 2>/dev/null || echo "")
ENGINE="claude"

if [ -z "$API_KEY" ]; then
  echo "⚠️ Could not auto-detect Mutiro API key. Please paste it manually:"
  read -p "API key: " API_KEY
fi

CLAUDE_DIR=".claude/mcp"
CONFIG_FILE="$CLAUDE_DIR/config.json"
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "{}" > "$CONFIG_FILE"
fi

jq --arg api "$API_KEY" \
   --arg id "$AGENT_ID" \
   --arg user "$AGENT_USERNAME" \
   --arg eng "$ENGINE" \
   '.mcpServers.mutiro = {
      "command": "/usr/local/bin/mutiro",
      "args": ["mcp", "--mode", "user"],
      "env": {
        "MUTIRO_API_KEY": $api,
        "MUTIRO_AGENT_ID": $id,
        "MUTIRO_AGENT_USERNAME": $user,
        "MUTIRO_ENGINE": $eng
      }
    }' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo "✅ MCP config ready at $CONFIG_FILE"

cat <<'EOL' > start-claude
#!/bin/bash
pgrep -x "mutiro" >/dev/null || (nohup mutiro agent daemon > ~/.mutiro-daemon.log 2>&1 &)
sleep 2
claude
EOL
chmod +x start-claude
echo "✅ Created start-claude launcher"

read -p "Do you want to launch now? (y/N): " RESP
if [[ "$RESP" =~ ^[Yy]$ ]]; then
  ./start-claude
else
  echo "✅ Setup complete. Next time, just run: ./start-claude"
fi
