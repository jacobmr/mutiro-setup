# Mutiro Setup Script

Automated installer for [Mutiro](https://mutiro.com) + Claude Code integration.

## Features

- Installs Mutiro CLI if not installed  
- Logs into Mutiro with user email  
- Fetches API key and agent details and writes `.claude/mcp/config.json`  
- Creates a `start-claude` launcher script to run Mutiro agent and Claude environment  

## Prerequisites

- Bash environment (Linux or macOS)  
- `curl` and `jq` installed  
- Mutiro account  

## Usage

1. Download the installer script:  
   ```bash
   curl -O https://raw.githubusercontent.com/jacobmr/mutiro-setup/main/mutiro-setup.sh
   ```  
2. Make it executable:  
   ```bash
   chmod +x mutiro-setup.sh
   ```  
3. Run the script:  
   ```bash
   ./mutiro-setup.sh
   ```  

The script will:  

- Install the Mutiro CLI if it isn't already on your system.  
- Prompt you to log in to Mutiro if necessary.  
- Attempt to auto-detect your Mutiro API key and prompt you if it can't.  
- Generate the `.claude/mcp/config.json` file with the necessary environment variables.  
- Create a `start-claude` launcher that starts the Mutiro agent daemon and then launches Claude.  

After running `mutiro-setup.sh`, you can launch Claude with:  

```bash
./start-claude
```  

If you choose not to launch immediately when prompted, you can run `./start-claude` later.  

## License

This project is provided under the MIT License.
