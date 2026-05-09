# Setting Up llama.cpp + Pi on a New MacBook Pro M5 (48 GB)

> All scripts and configs in `~/Projects/llama-pi/`.
>
> **Goal:** Reproduce the current llama.cpp + Pi setup on a brand-new MacBook Pro M5 (48 GB, **not** M5 Max).

---

## 1. System Requirements

| Item | Current Machine (M5 Max) | Target Machine (M5) |
|------|--------------------------|---------------------|
| Chip | M5 Max | M5 (base) |
| GPU | 40-core GPU | 24-core GPU |
| Memory | 48 GB unified | 48 GB unified |
| Model that fits | ✅ Qwen3.6-35B-A3B (Q4) | ✅ Same — memory is identical |
| Speed | ~94 tok/s decode | ~60-70 tok/s decode (fewer GPU cores) |

The M5 (non-Max) has **fewer GPU cores** (24 vs 40) but the **same memory**, so the model loads identically — just slower. All flags and configs below apply as-is.

---

## 2. Install Base Software

### 2.1 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2.2 Git

```bash
brew install git
```

---

## 3. Install llama.cpp

llama.cpp is installed via Homebrew, which bundles Metal support automatically:

```bash
brew install llama.cpp
```

Verify Metal is detected:

```bash
llama-server --help 2>&1 | grep -i metal
# Should show: ggml_metal_init: detected: Apple M5, ...
```

---

## 4. Clone the Project Repository

```bash
cd ~/Projects
git clone <your-repo-url> llama.cpp  # if not already cloned
```

---

## 5. Start the Server

### 5.1 Start the Server

```bash
bash ~/Projects/llama-pi/run-server.sh q4
```

Or with the Q6_K_XL variant (higher quality, ~38 GB — tight fit on 48 GB):

```bash
bash ~/Projects/llama-pi/run-server.sh q6
```

### 5.3 Verify

The first lines of output should show Metal being used:

```
ggml_metal_init: detected: Apple M5, ...
```

The server should be accessible at `http://localhost:8000`:

```bash
curl http://localhost:8000/v1/models
```

### 5.4 Stopping the Server

```bash
curl -X POST http://localhost:8000/stop
```

Or kill it directly:

```bash
pkill llama-server
```

---

## 6. Install & Configure Pi Coding Agent

### 6.1 Install Pi

```bash
npm install -g @mariozechner/pi-coding-agent
```

### 6.2 Create `~/.pi/agent/settings.json`

```json
{
  "lastChangelogVersion": "0.72.1",
  "defaultProvider": "llama-cpp",
  "defaultModel": "qwen3.6-35b-a3b",
  "packages": [
    "npm:@juicesharp/rpiv-web-tools",
    "npm:@juicesharp/rpiv-pi",
    "npm:@juicesharp/rpiv-ask-user-question",
    "npm:@tintinweb/pi-subagents",
    "npm:@juicesharp/rpiv-todo",
    "npm:@juicesharp/rpiv-advisor",
    "npm:@juicesharp/rpiv-btw",
    "npm:@juicesharp/rpiv-i18n",
    "npm:@juicesharp/rpiv-args"
  ]
}
```

### 6.3 Create `~/.pi/agent/models.json`

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
          "reasoning": false,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 131072,
          "maxTokens": 8192
        }
      ]
    }
  }
}
```

### 6.4 Verify Pi Connectivity

```bash
pi --help
```

---

## 7. Auto-Start on Login

Create a launch agent to start the server when you log in:

```bash
mkdir -p ~/Library/LaunchAgents
```

Create `~/Library/LaunchAgents/com.llama-server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.llama-server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/mickers/Projects/docker-llama-pi/run-server.sh</string>
        <string>q4</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/llama-server-launch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/llama-server-launch-err.log</string>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.llama-server.plist
```

---

## 8. Quick Reference: Start / Stop

```bash
# Start the server
bash ~/Projects/docker-llama-pi/run-server.sh q4

# Stop the server
curl -X POST http://localhost:8000/stop

# Test the API
curl http://localhost:8000/v1/models

# Test a completion
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "local", "prompt": "The capital of France is", "max_tokens": 10}'
```

---

## 9. Expected Performance on M5 (vs M5 Max)

| Metric | M5 Max (40-core GPU) | M5 (24-core GPU) |
|--------|----------------------|------------------|
| Decode throughput | ~94 tok/s | ~60-70 tok/s |
| Prefill throughput | ~3,000 tok/s | ~1,800-2,200 tok/s |
| Full turn (8K in, 500 out) | ~8s | ~12-15s |
| Memory usage | ~25 GB | ~25 GB (same) |

The M5 will be noticeably slower but fully functional. The 48 GB memory is the critical resource for model size, and both chips share it.

---

## 10. Troubleshooting

| Problem | Solution |
|---------|----------|
| Server runs on CPU, not GPU | Verify Metal: `llama-server --help 2>&1 | grep metal`. If missing, `brew reinstall llama.cpp` |
| OOM / crashes on startup | Try Q4_K_M instead of Q6_K_XL; ensure no other apps are consuming memory |
| Pi can't connect | Verify `http://localhost:8000/v1/models` returns JSON; check `models.json` baseUrl |
| Port 8000 already in use | Kill existing: `pkill llama-server`, then restart |
| Server won't start after reboot | Set up the launch agent (section 7) |
| Model fails to load | Check `~/.cache/huggingface/hub/` — the model downloads automatically on first run |

---

## 11. One-Command Setup Summary

For a completely fresh machine, the full setup in order:

```bash
# 1. Base tools
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git llama.cpp
npm install -g @mariozechner/pi-coding-agent

# 2. Code
cd ~/Projects
git clone <repo-url> llama.cpp

# 3. Configure Pi
mkdir -p ~/.pi/agent
# Write settings.json and models.json (see sections 6.2-6.3)

# 4. Start the server (model auto-downloads on first run)
bash ~/Projects/llama-pi/run-server.sh q4

# 5. Verify
curl http://localhost:8000/v1/models
```
