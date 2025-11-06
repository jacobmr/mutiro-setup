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

# Ensure user is authenticated
if mutiro whoami &> /tmp/mutiro_whoami.txt; then
  USERNAME=$(grep -o "[a-zA-Z0-9_]*" /tmp/mutiro_whoami.txt | head -1)
  echo "✅ Logged in as $USERNAME"
else
  echo "🔐 You need to authenticate with Mutiro."
  read -p "Enter your email for Mutiro: " EMAIL
  read -p "Do you already have a Mutiro account? (y/n): " HAVE_ACCOUNT
  if [ "$HAVE_ACCOUNT" = "y" ] || [ "$HAVE_ACCOUNT" = "Y" ]; then
    mutiro auth login "$EMAIL"
  else
    read -p "Choose a username: " NEW_USERNAME
    read -p "Enter your full name: " FULLNAME
    echo "Signing up for a new Mutiro account..."
    mutiro auth signup "$EMAIL" "$NEW_USERNAME" "$FULLNAME"
  fi
fi

# Fetch account details
echo "Fetching Mutiro config..."
mutiro whoami --json > /tmp/mutiro_info.json || true
API_KEY=$(jq -r '.api_key' /tmp/mutiro_info.json 2>/dev/null || echo "")
AGENT_ID=$(jq -r '.agent.id' /tmp/mutiro_info.json 2>/dev/null || echo "")
AGENT_USERNAME=$(jq -r '.agent.username' /tmp/mutiro_info.json 2>/dev/null || echo "")
ENGINE="claude"

# If no agent is configured, offer to create one
if [ -z "$AGENT_ID" ] || [ -z "$AGENT_USERNAME" ]; then
  echo "🔧 No Mutiro agent found for this account."
  read -p "Would you like to create a new Claude agent now? (y/n): " CREATE_AGENT
  if [ "$CREATE_AGENT" = "y" ] || [ "$CREATE_AGENT" = "Y" ]; then
    read -p "Enter agent username (e.g., claude_assistant): " AGENT_USERNAME
    read -p "Enter agent display name: " AGENT_NAME
    mutiro agents create "$AGENT_USERNAME" "$AGENT_NAME" --engine "$ENGINE"
    # Re-fetch the agent info
    mutiro whoami --json > /tmp/mutiro_info.json || true
    API_KEY=$(jq -r '.api_key' /tmp/mutiro_info.json 2>/dev/null || echo "")
    AGENT_ID=$(jq -r '.agent.id' /tmp/mutiro_info.json 2>/dev/null || echo "")
  else
    echo "Please create an agent later using: mutiro agents create <username> \"<Display Name>\" --engine claude"
  fi
fi

# Prompt for API key if still missing
if [ -z "$API_KEY" ]; then
  echo "⚠️  Could not auto-detect Mutiro API key. Please paste it manually:"
  read -p "API key: " API_KEY
fi

# Create Claude MCP config
CLAUDE_DIR=".claude/mcp"
CONFIG_FILE="$CLAUDE_DIR/config.json"
mkdir -p "$CLAUDE_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "{}" > "$CONFIG_FILE"
fi

# Update MCP configuration with Mutiro server details
jq --arg api "$API_KEY" \
   --arg id "$AGENT_ID" \
   --arg user "$AGENT_USERNAME" \
   --arg eng "$ENGINE" \
   '.mcpServers.mutiro = {command: "mutiro", args: ["mcp", "--mode", "user"], env: {MUTIRO_API_KEY: $api, MUTIRO_AGENT_ID: $id, MUTIRO_AGENT_USERNAME: $user, MUTIRO_ENGINE: $eng}}' \
   "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

# Create start-claude script
cat > start-claude <<'EOF'
#!/bin/bash
# Start the Mutiro agent daemon and launch Claude
mutiro start &
claude
EOF
chmod +x start-claude

echo ""
echo "✅ Setup complete!"
echo "Run ./start-claude to launch Claude with your Mutiro agent."
echo "You can also chat in your terminal using 'mutiro chat' or download the Mutiro mobile app to talk to your agent on the go."
