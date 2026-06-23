# Fix: Local LLM Infinite Loop in Pi

**Symptom:** Pi enters an infinite retry loop when using a local llama-server instance. The server outputs thinking/reasoning content but pi doesn't know how to parse it.

## Root Cause
`run-server.sh` uses `--reasoning-budget 4096`, which tells llama-server to emit thinking blocks. But `models.json` has `"reasoning": false`, so pi treats the thinking content as malformed and retries indefinitely.

## The Fix

### 1. Update `~/.pi/agent/models.json`
```json
{
  "providers": {
    "llama-cpp": {
      "baseUrl": "http://localhost:8000/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "models": [
        {
          "id": "qwen3.6-35b-a3b",
          "name": "Qwen3.6-35B-A3B (local)",
          "reasoning": true,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 131072,
          "maxTokens": 8192,
          "compat": {
            "thinkingFormat": "openai"
          }
        }
      ]
    }
  }
}
```

**Key changes:**
- `"reasoning": true` — tells pi to expect and properly parse thinking blocks
- `"thinkingFormat": "openai"` — tells pi that llama.cpp sends thinking via `reasoning_content` chunks over the OpenAI-compatible API

### 2. Verify `~/.pi/agent/settings.json`
```json
{
  "defaultProvider": "llama-cpp",
  "defaultModel": "qwen3.6-35b-a3b"
}
```

### 3. Restart the server
```bash
pkill llama-server
bash ~/Projects/llama-pi/run-server.sh q4
```

### 4. Reload in pi
Run `/model` to pick up the new config.

## Why This Works
llama.cpp's `--reasoning-budget` flag causes the server to stream thinking content as `reasoning_content` fields in each chunk. Without `reasoning: true` + `thinkingFormat: "openai"`, pi sees this as unexpected output, fails to parse the response, and retries — creating the loop. With both flags set, pi correctly extracts and renders the thinking process before the final answer.

## Quick Diagnostic
If you ever see this loop again, check that `--reasoning-budget` in `run-server.sh` matches `"reasoning": true` in `models.json`. They must be in sync.
