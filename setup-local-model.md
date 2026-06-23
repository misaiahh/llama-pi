# Setting Up the Local LLM Model for Pi

This guide explains how to configure `~/.pi/agent/models.json` to connect Pi to a locally running llama-server instance.

## Prerequisites
- `llama-server` running locally (typically on `http://localhost:8000`)
- `pi` coding agent installed and accessible via terminal

## Step 1: Start the Local Server
Run the server script from this directory:
```bash
# Default to Q4 (~25 GB RAM)
bash run-server.sh

# Or use Q6 (~38 GB RAM)
bash run-server.sh q6
```

## Step 2: Copy the Model Config
Copy the provided `models.json` to your Pi config directory:
```bash
cp models.json ~/.pi/agent/models.json
```

## Step 3: Verify Settings
Ensure `~/.pi/agent/settings.json` points to the local provider:
```json
{
  "defaultProvider": "llama-cpp",
  "defaultModel": "qwen3.6-35b-a3b"
}
```

## Step 4: Reload Pi
In your active `pi` session, run:
```
/model
```
The local model (`qwen3.6-35b-a3b`) should now appear in the list and auto-select if it matches your `defaultModel` setting.

## Troubleshooting
- **"Which model?" prompt appears:** Ensure `defaultModel` in `settings.json` exactly matches the `id` field in `models.json`.
- **Infinite loop on responses:** This happens when `--reasoning-budget` is set in `run-server.sh` but `reasoning: false` is in `models.json`. Ensure both are set to `true`.
- **Server not responding:** Verify it's running: `curl http://localhost:8000/v1/models`

## Adding Cloud Models (Optional)
To use cloud models alongside the local one, add the `anthropic` provider to `models.json`:
```json
{
  "providers": {
    "llama-cpp": { ... },
    "anthropic": {
      "apiKey": "$ANTHROPIC_API_KEY",
      "api": "anthropic-messages"
    }
  }
}
```
Set your `ANTHROPIC_API_KEY` environment variable, then run `/model` to see both local and cloud options.
