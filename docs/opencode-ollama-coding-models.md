# Local coding models with Ollama

This machine uses local Ollama models for coding through OpenCode and Aider.

Hardware:

- GPU: RTX 3070 8GB
- RAM: 46GB
- Ollama API: `http://localhost:11434`
- Ollama OpenAI-compatible API: `http://localhost:11434/v1`

## Current Recommendation

Use Aider for local coding edits and OpenCode as a secondary option.

Default verified model:

```text
qwen35:4b-opencode
```

Why:

- Fits this GPU better than 8B-12B models at 64k context.
- Works with Aider through Ollama.
- Works with OpenCode after creating a clean Ollama alias.
- Passed a real Go hello-world edit and `go run main.go` test.

## Model Results

| Model | Result |
| --- | --- |
| `qwen35:4b-opencode` | Best default. File edits work and Go hello world compiled. |
| `gemma4:12b-opencode-64k` | Tool calls work, but it is slow and partly CPU-offloaded. |
| `lfm2.5:8b-opencode-64k` | Tool calls work, but it wrote invalid Go with literal `\n`. |
| `qwen2.5-coder:7b*` | Not reliable with OpenCode tools; it printed fake JSON tool calls. |

Avoid local 14B+ and 30B+ coding models on this GPU unless slowness is acceptable. They will spill to CPU or need much smaller context.

## Ollama Model Alias

Do not point OpenCode directly at `qwen3.5:4b-q4_K_M`. In testing, OpenCode treated the raw model as a 4096-token model and stopped with `finish: length` before it could call tools.

Create a clean alias with explicit context:

```bash
cat > /tmp/qwen35-4b-opencode.Modelfile <<'EOF'
FROM qwen3.5:4b-q4_K_M
PARAMETER num_ctx 65536
EOF

ollama create qwen35:4b-opencode -f /tmp/qwen35-4b-opencode.Modelfile
```

Check it:

```bash
ollama show qwen35:4b-opencode
ollama ps
nvidia-smi
```

## OpenCode Config

Config path:

```text
~/.config/opencode/opencode.jsonc
```

Minimal useful config:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "ollama/qwen35:4b-opencode",
  "small_model": "ollama/qwen35:4b-opencode",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "qwen35:4b-opencode": {
          "name": "Qwen 3.5 4B opencode 64k (local)",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 65536,
            "input": 32768,
            "output": 8192
          }
        },
        "gemma4:12b-opencode-64k": {
          "name": "Gemma 4 12B opencode 64k (local)",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 65536,
            "input": 32768,
            "output": 8192
          }
        }
      }
    }
  }
}
```

Restart OpenCode after changing this file.

Test OpenCode:

```bash
opencode run "Create main.go with a minimal Go program that prints Hello, World!" --print-logs --log-level INFO
go run main.go
```

If OpenCode does nothing, export the session:

```bash
opencode export <session-id>
```

Bad context symptom:

```json
"input": 4095,
"output": 1,
"finish": "length"
```

Fix: use an alias with larger `num_ctx`, like `qwen35:4b-opencode`.

## Aider Config

Aider worked more reliably than OpenCode for local file edits.

Global config path:

```text
~/.aider.conf.yml
```

Config:

```yaml
model: ollama/qwen35:4b-opencode
set-env:
  - OLLAMA_API_BASE=http://localhost:11434
auto-commits: false
analytics-disable: true
```

Use Aider in a project:

```bash
cd ~/path/to/project
aider
```

One-shot task:

```bash
aider --message "Create a README for this project"
```

Edit specific files:

```bash
aider main.go README.md
```

Run with tests:

```bash
aider --test-cmd "go test ./..." --auto-test
```

Small verified example:

```bash
aider --message "Create main.go with a minimal Go program that prints Hello, World! using real newlines. Also create README.md with one sentence describing the project." --test-cmd "go run main.go" --auto-test
```

## Practical Notes

- Ask for file edits explicitly. Chat-only prompts often produce chat-only answers.
- Keep local-model tasks small and concrete.
- Use `qwen35:4b-opencode` for normal coding.
- Try `gemma4:12b-opencode-64k` only for occasional deeper writing; it is slow on this GPU.
- Check `ollama ps` to see whether a model is CPU-offloaded.
