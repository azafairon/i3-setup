# OpenCode with local Ollama coding models

This documents the local OpenCode + Ollama setup used on this machine, including model selection for an RTX 3070 8GB, GPU checks, context length fixes, tool calling, and file writes.

## Current Result

- Main OpenCode model: `ollama/gemma4:e4b-opencode`
- Small OpenCode model: `ollama/qwen2.5-coder:7b-opencode`
- Ollama provider URL: `http://localhost:11434/v1`
- GPU: NVIDIA RTX 3070, verified with `nvidia-smi` and `ollama ps`
- Tool calling: enabled in OpenCode model metadata with `tool_call: true`
- Context fix: custom Ollama model variants with larger `num_ctx`
- Thinking status: stock Gemma 4 thinking cannot currently be disabled through OpenCode's Ollama OpenAI-compatible provider path

## Model recommendation for RTX 3070 8GB

Best default for real OpenCode file-editing on this machine:

```text
gemma4:e4b-opencode
```

Why this is the current default:

- It has been tested to make real OpenCode `Write` tool calls.
- It stays on GPU with `num_ctx 32768` on the RTX 3070.
- It is much faster than `gemma4:12b-opencode`.
- It supports tools according to Ollama and works with OpenCode's tool loop in practice.

Fast code-chat option:

```text
qwen2.5-coder:7b-opencode
```

Qwen is quick and code-specific, but testing showed it printed a fake JSON tool call inside a Markdown code block instead of making a real OpenCode tool call. That means it can explain or draft code quickly, but it should not be the default if you expect OpenCode to edit files autonomously.

Candidate ranking for this card and OpenCode:

1. `gemma4:e4b-opencode`: best tested local default for real file edits.
2. `qwen2.5-coder:7b-opencode`: fastest useful coding chat/code-drafting model, but not reliable for OpenCode tool calls.
3. `gemma4:12b-opencode`: file-writing works, but it is too slow for comfortable agent use on this 8GB GPU.
4. `lfm2.5:8b-opencode`: promising on paper, but local test did not produce a real `Write` tool call and generated invalid Go syntax.
5. `qwen3.5:4b` or `qwen3.5:9b`: possible future tests; `9b` may fit but leaves less VRAM headroom.

Avoid locally on this card:

- `qwen3-coder:30b`: 19GB.
- `north-mini-code-1.0`: 19GB.
- `devstral:24b`: 14GB.
- `deepseek-coder-v2:16b`: 8.9GB, too tight once context is included.
- `qwen2.5-coder:14b`: 9.0GB, too tight.
- `codellama`: older; prefer Qwen Coder now.

## Why the extra setup was needed

The plain Ollama model worked directly with `ollama run`, but initially behaved badly in OpenCode.

Problems found:

- `gemma4:e4b` was not installed; installed models were `gemma4:e4b` and `gemma4:12b`.
- Ollama was using the GPU correctly, so CPU fallback was not the issue.
- The model was slow partly because Gemma 4 emits thinking/reasoning by default.
- OpenCode sent a large agent prompt, around `4095` input tokens.
- The default Ollama runtime context was only `4096`, leaving room for exactly one output token.
- The symptom was OpenCode replying with only `I` and finishing with `finish: length`.
- OpenCode needs model metadata advertising tool support, otherwise the model may only answer in chat instead of using file tools.

## Verify Ollama and GPU

Check that Ollama is installed and the desired models exist:

```bash
ollama list
```

Check the active model capabilities:

```bash
ollama show qwen2.5-coder:7b-opencode
ollama show gemma4:e4b
ollama show gemma4:12b
```

For the active Qwen Coder model, expected capabilities include:

```text
completion
tools
```

Gemma 4 variants additionally report multimodal and thinking capabilities.

Check GPU usage:

```bash
nvidia-smi
ollama ps
```

When a model is loaded correctly, `ollama ps` should show something like:

```text
qwen2.5-coder:7b-opencode    100% GPU    32768
```

## Create OpenCode-friendly Ollama model variants

Do not point OpenCode directly at stock models if their runtime context is too small. Create variants with a known context window.

The important setting is `PARAMETER num_ctx`. Without it, OpenCode can fill the default context with its system prompt and tool definitions, leaving no room for the model's answer.

### Qwen 2.5 Coder 7B variant

Pull the base model:

```bash
ollama pull qwen2.5-coder:7b
```

Create a Modelfile:

```bash
cat > /tmp/Modelfile.qwen25-coder-7b-opencode <<'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 32768
EOF
```

Create the model variant:

```bash
ollama create qwen2.5-coder:7b-opencode -f /tmp/Modelfile.qwen25-coder-7b-opencode
```

Verify it:

```bash
ollama show qwen2.5-coder:7b-opencode
```

Expected parameter:

```text
num_ctx 32768
```

### e4b variant

Create a Modelfile:

```bash
cat > /tmp/Modelfile.gemma4-e4b-opencode <<'EOF'
FROM gemma4:e4b
PARAMETER num_ctx 32768
EOF
```

Create the model variant:

```bash
ollama create gemma4:e4b-opencode -f /tmp/Modelfile.gemma4-e4b-opencode
```

Verify it:

```bash
ollama show gemma4:e4b-opencode
```

Expected parameter:

```text
num_ctx 32768
```

### 12b variant

Create a Modelfile:

```bash
cat > /tmp/Modelfile.gemma4-12b-opencode <<'EOF'
FROM gemma4:12b
PARAMETER num_ctx 16384
EOF
```

Create the model variant:

```bash
ollama create gemma4:12b-opencode -f /tmp/Modelfile.gemma4-12b-opencode
```

Verify it:

```bash
ollama show gemma4:12b-opencode
```

Expected parameter:

```text
num_ctx 16384
```

The 12b model is slower and closer to the RTX 3070 8GB VRAM limit, so `16384` is safer than `32768`. If it spills to CPU or becomes too slow, use `gemma4:e4b-opencode` as the main model instead.

## OpenCode configuration

Global OpenCode config lives here:

```text
~/.config/opencode/opencode.jsonc
```

Current config:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "ollama/gemma4:e4b-opencode",
  "small_model": "ollama/qwen2.5-coder:7b-opencode",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "qwen2.5-coder:7b-opencode": {
          "name": "Qwen 2.5 Coder 7B opencode (local)",
          "tool_call": true,
          "limit": {
            "context": 32768,
            "output": 8192
          }
        },
        "gemma4:e4b-opencode": {
          "name": "Gemma 4 e4b opencode (local)",
          "tool_call": true,
          "limit": {
            "context": 131072,
            "output": 8192
          }
        },
        "gemma4:12b-opencode": {
          "name": "Gemma 4 12b opencode (local)",
          "tool_call": true,
          "limit": {
            "context": 262144,
            "output": 8192
          }
        }
      }
    }
  }
}
```

Important fields:

- `model` is the primary model used for coding work.
- `small_model` is used for small jobs like session titles. Qwen Coder 7B is quick enough for this and does not need to perform file edits.
- `npm: "@ai-sdk/openai-compatible"` makes OpenCode talk to Ollama through Ollama's OpenAI-compatible API.
- `baseURL: "http://localhost:11434/v1"` is Ollama's OpenAI-compatible endpoint.
- `tool_call: true` advertises tool support to OpenCode so the model can write files and run tools.
- `limit.output: 8192` gives OpenCode a sane output budget.

Do not assume `tool_call: true` guarantees real tool behavior. Qwen 2.5 Coder 7B and LFM 2.5 8B both advertise tools, but local tests showed they answered with text instead of making real OpenCode tool calls. Gemma 4 e4b did make real tool calls.

After changing this config, restart OpenCode. Config is loaded only on startup.

## Thinking and why there is no clean no-thinking switch here

Gemma 4 supports thinking. Direct Ollama CLI showed a large speed difference:

```bash
time ollama run gemma4:e4b "Write one short sentence."
time ollama run gemma4:e4b --think=false "Write one short sentence."
```

On this system, disabling thinking was much faster for short direct CLI prompts.

OpenCode does have native per-model `options`:

```jsonc
"models": {
  "some-model": {
    "options": {
      "reasoningEffort": "low"
    }
  }
}
```

However, testing showed that `options: { "think": false }` does not disable Gemma 4 thinking through Ollama's OpenAI-compatible `/v1/chat/completions` endpoint. The OpenCode session export still contained a `reasoning` part.

The earlier `ollama-nothink.ts` plugin was also not a real fix for this. It can mutate OpenCode chat params, but the underlying Ollama OpenAI-compatible endpoint still does not honor `think: false` the same way `ollama run --think=false` does.

So the cleaned-up setup does not use a no-thinking plugin. The reliable fixes are the larger `num_ctx` model variants and correct OpenCode model metadata.

## Why not bake no-thinking into the Ollama model variant?

For the context fix, yes, creating an Ollama model variant is the right solution. That is why `gemma4:e4b-opencode` and `gemma4:12b-opencode` exist.

For thinking, no, not with the documented Ollama Modelfile options. Ollama's Modelfile supports runtime parameters like `num_ctx`, `num_predict`, `temperature`, `top_k`, and `top_p`, but it does not document `think` as a valid `PARAMETER`.

`think` is an API/CLI request option:

```bash
ollama run gemma4:e4b --think=false "prompt"
```

Because OpenCode sends requests through Ollama's OpenAI-compatible endpoint, and that endpoint did not honor `think: false` in testing, there is currently no clean built-in switch in this setup.

If a future Ollama version adds `PARAMETER think false` support in Modelfiles, or Ollama's OpenAI-compatible endpoint starts honoring `think: false`, then it would be cleaner to use that and avoid plugins.

## Testing OpenCode

Test a chat-only prompt:

```bash
opencode run "hello world in golang" --print-logs --log-level INFO
```

Expected: it prints Go code in chat.

Test file writing:

```bash
rm -f /tmp/opencode/main.go
opencode run "create a main.go file with hello world in Go" --print-logs --log-level INFO
```

Expected: OpenCode uses the `Write` tool and creates `main.go`.

Check the file:

```bash
cat /tmp/opencode/main.go
```

Test a slightly larger task:

```bash
rm -rf /tmp/opencode/greet
mkdir -p /tmp/opencode/greet
opencode run "Create a small Go CLI project in ./greet. It should have go.mod, main.go, and README.md. The CLI should accept an optional name argument and print Hello, <name>!, defaulting to World. Keep it simple." --print-logs --log-level INFO
```

Expected: OpenCode creates multiple files and may run shell commands.

## Prompting note

If you ask:

```text
hello world in golang
```

The model will usually answer in chat.

If you want files changed, ask explicitly:

```text
create a main.go file with hello world in Go
```

or:

```text
modify the existing main.go to print Hello, World!
```

## Troubleshooting

### OpenCode only returns one token like `I`

Cause: the model context is too small. OpenCode's prompt filled the context and left no room for output.

Check a session export:

```bash
opencode export <session-id>
```

Bad symptom:

```json
"input": 4095,
"output": 1,
"finish": "length"
```

Fix: use the `*-opencode` Ollama variant with larger `num_ctx`.

### The model writes code in chat but does not create files

Use an explicit editing prompt and make sure `tool_call: true` is set in OpenCode model metadata.

Example:

```text
create a main.go file with hello world in Go
```

### The model is slow

Expected causes:

- Larger models like `gemma4:12b-opencode` are much slower than Qwen Coder 7B on an 8GB RTX 3070.
- Thinking-capable models can add extra reasoning tokens.
- OpenCode sends large prompts with tools and agent instructions.

Mitigations:

- Use `gemma4:e4b-opencode` as the default local file-editing model.
- Use `qwen2.5-coder:7b-opencode` when you want fast code suggestions in chat and do not need autonomous file edits.
- Keep `num_ctx` as low as is practical while still leaving room for OpenCode prompts.
- Use `gemma4:e4b-opencode` only as a known working fallback.

### Check whether the model is on GPU

```bash
ollama ps
nvidia-smi
```

Good sign:

```text
PROCESSOR    100% GPU
```

If a model spills to CPU, reduce `num_ctx` or switch the main model back to `qwen2.5-coder:7b-opencode`.

## Useful commands

List models:

```bash
ollama list
```

Show model details:

```bash
ollama show qwen2.5-coder:7b-opencode
ollama show gemma4:e4b-opencode
ollama show gemma4:12b-opencode
```

Show the Modelfile for a variant:

```bash
ollama show qwen2.5-coder:7b-opencode --modelfile
ollama show gemma4:e4b-opencode --modelfile
ollama show gemma4:12b-opencode --modelfile
```

Check loaded models and context:

```bash
ollama ps
```

Validate OpenCode config JSONC if it currently has no comments:

```bash
jq empty ~/.config/opencode/opencode.jsonc
```

Run OpenCode with logs:

```bash
opencode run "create a main.go file with hello world in Go" --print-logs --log-level INFO
```

Restart OpenCode after changing config, plugins, or model selection.
