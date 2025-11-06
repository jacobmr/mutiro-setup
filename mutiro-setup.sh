#!/bin/bash
set -e
echo "=== Mutiro + Claude Setup ==="

# Install Mutiro CLI if not installed
if ! command -v mutiro &> /dev/null; then
  echo "Installing Mutiro CLI..."
  curl -sSL https://mutiro.com/downloads/install.sh | bash
else
  echo "Mutiro CLI already installed."
fi

# Authenticate or sign up
if mutiro whoami > /tmp/mutiro_whoami.txt 2>/dev/null; then
  USERNAME=$(grep -o "@[a-zA-Z0-9_]*" /tmp/mutiro_whoami.txt | head -1)
  echo "✅ Logged in as $USERNAME"
else
  echo "🔐 You need to authenticate with Mutiro."
  read -p "Enter your email for Mutiro: " EMAIL
  read -p "Do you already have a Mutiro account? (y/n): " HAVE_ACCOUNT
  if [[ "$HAVE_ACCOUNT" =~ ^[Yy]$ ]]; then
    mutiro auth login "$EMAIL"
  else
    read -p "Choose a username (letters/numbers only): " NEW_USERNAME
    read -p "Enter your full name: " FULLNAME
    mutiro auth signup "$EMAIL" "$NEW_USERNAME" "$FULLNAME"
  fi
fi

# Fetch user info and API key
echo "Fetching Mutiro config..."
mutiro whoami --json > /tmp/mutiro_info.json || true
API_KEY=$(jq -r '.api_key // empty' /tmp/mutiro_info.json)
AGENT_ID=$(jq -r '.agent.id // empty' /tmp/mutiro_info.json)
AGENT_USERNAME=$(jq -r '.agent.username // empty' /tmp/mutiro_info.json)

# Create agent if none exists
if [[ -z "$AGENT_ID" || -z "$AGENT_USERNAME" ]]; then
  echo "No Claude agent found for your account."
  read -p "Would you like to create a new agent? (y/n): " CREATE_AGENT
  if [[ "$CREATE_AGENT" =~ ^[Yy]$ ]]; then
    read -p "Enter a username for your Claude agent (e.g. my-agent): " NEW_AGENT_USERNAME
    read -p "Enter a display name for your Claude agent: " NEW_AGENT_DISPLAY
    mutiro agents create "$NEW_AGENT_USERNAME" "$NEW_AGENT_DISPLAY"
    # Re-fetch agent info
    mutiro whoami --json > /tmp/mutiro_info.json || true
    API_KEY=$(jq -r '.api_key // empty' /tmp/mutiro_info.json)
    AGENT_ID=$(jq -r '.agent.id // empty' /tmp/mutiro_info.json)
    AGENT_USERNAME=$(jq -r '.agent.username // empty' /tmp/mutiro_info.json)
  fi
fi

# Prompt for API key if still missing
if [[ -z "$API_KEY" ]]; then
  echo "⚠️ Could not auto-detect Mutiro API key. Please paste it manually:"
  read -p "API key: " API_KEY
fi

ENGINE="claude"

# Prepare MCP config
CLAUDE_DIR=".claude/mcp"
CONFIG_FILE="$CLAUDE_DIR/config.json"
mkdir -p "$CLAUDE_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "{}" > "$CONFIG_FILE"
fi

# Write Mutiro server config using jq
jq --arg api "$API_KEY" \
   --arg id "$AGENT_ID" \
   --arg user "$AGENT_USERNAME" \
   --arg eng "$ENGINE" \
   '.mcpServers.mutiro = {
      "command": "/usr/local/bin/mutiro",
      "args": ["mcp","--mode","user"],
      "env": {
        "MUTIRO_API_KEY": $api,
        "MUTIRO_AGENT_ID": $id,
        "MUTIRO_AGENT_USERNAME": $user,
        "MUTIRO_ENGINE": $eng
      }
    }' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo "✅ MCP config ready at $CONFIG_FILE"

# Create start-claude launcher
cat <<'EOL' > start-claude
#!/bin/bash
# Start Mutiro agent daemon if not running and launch Claude Code
pgrep -x "mutiro" >/dev/null || (nohup mutiro agent daemon > ~/.mutiro-daemon.log 2>&1 &)
sleep 2
claude
EOL
chmod +x start-claude
echo "✅ Created start-claude launcher"

# Offer to launch now
read -p "Do you want to launch now? (y/N): " RESP
if [[ "$RESP" =~ ^[Yy]$ ]]; then
  ./start-claude
else
  echo "✅ Setup complete. Next time, just run: ./start-claude"
fi
