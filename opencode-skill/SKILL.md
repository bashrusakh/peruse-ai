# peruse-ui-check

Visual UI audit skill: runs `peruse run` against a local dev server, reads the output,
builds a fix plan, applies code edits, and repeats for N iterations.
Supports multi-model comparison mode.

## Trigger phrases

- "check ui", "run ui check", "peruse ui", "visual audit", "ui audit", "ux check"
- "analyze interface", "run peruse", "visual ui check"
- "compare models on ui", "test ui with multiple models"

## Parameters (extract from user message)

| Param        | Default                    | Example                          |
|--------------|----------------------------|----------------------------------|
| `URL`        | `http://localhost:8888`    | `http://localhost:3000`          |
| `TASK`       | see default task below     | custom task description          |
| `ITERATIONS` | `3`                        | `2`, `5`                         |
| `OUTPUT_DIR` | `./peruse_output`          | `./ui_reports`                   |
| `MODELS`     | ask user (see STEP 0)      | `qwen2.5-vl:72b`, or `["a","b"]`|
| `MAX_STEPS`  | `30`                       | `50`                             |

If `MODELS` contains more than one entry — run in **multi-model comparison mode** (see STEP 6-B).

Default TASK if not specified:
```
Analyze the menu and navigation. Evaluate: item hierarchy, grouping, structural logic,
visual issues (spacing, alignment, contrast), UX issues (confusing labels, duplication,
hidden items). Return a report in English.
```

---

## STEP 0 — Model discovery and selection

Run this before anything else. Goal: determine which model(s) `peruse run` will use.

### 0-A. Check if model was specified in the message

If the user explicitly named a model or models — use those, skip to 0-D.

### 0-B. Read OpenCode config to find available VL-capable models

```bash
cat ~/.config/opencode/opencode.json 2>/dev/null || echo "{}"
cat ~/.local/share/opencode/auth.json 2>/dev/null || echo "{}"
```

Parse the `provider` section of `opencode.json`. For each provider entry, collect:
- Provider ID
- `options.baseURL`
- Each model ID listed under `models`

Also check `auth.json` to know which providers have credentials stored.

Build a flat list: `providerID/modelID` for every configured model.

### 0-C. Filter and rank VL-capable models

A model is considered VL-capable if its name (case-insensitive) matches any of:

```
vl, vision, visual, -v\d, 4o, pixtral, llava, internvl,
qwen.*vl, gemini, claude, gpt-4, minicpm-v, phi-3-vision,
cogvlm, blip, fuyu, idefics, paligemma, molmo, florence
```

Text-only signals (deprioritize unless no VL models found):
```
coder, code-only, instruct$, text-only, embedding, rerank
```

Sort VL candidates by parameter count: 72b > 32b > 14b > 7b > 3b.

### 0-D. Present choices to the user

Show a numbered list:

```
Found these VL-capable models in your OpenCode config:

  1. myprovider/qwen2.5-vl:72b    ← recommended (largest)
  2. myprovider/qwen2.5-vl:32b
  3. myprovider/llava:13b
  4. otherprovider/gemini-2.0-flash

Options:
  • Enter a number to use that model
  • Enter multiple numbers separated by commas to compare (e.g. "1,2")
  • Enter "all" to run all VL models
  • Type a model name manually if not listed

Which model(s) should peruse use?
```

Wait for user response. Parse into `SELECTED_MODELS[]` (array, even if single entry).

If no VL models found — show all available models, warn that vision may not work, let user choose.

If OpenCode config is missing — fall back to `~/.peruse-ui.env`:
```bash
[ -f "$HOME/.peruse-ui.env" ] && source "$HOME/.peruse-ui.env"
```

### 0-E. Resolve baseURL and API key per selected model

For each selected model, look up its provider in `opencode.json` → get `options.baseURL`.
For the API key, check `auth.json` under the same provider ID.

Store as: `MODEL_ID`, `BASE_URL`, `API_KEY` per entry.

---

## STEP 1 — Preflight checks

```bash
# 1. peruse-ai package installed? (CLI entry point is "peruse", not "peruse-ai")
pip show peruse-ai 2>/dev/null || pip install peruse-ai --break-system-packages

# 2. playwright chromium available?
playwright install chromium 2>/dev/null || python -m playwright install chromium 2>/dev/null || true

# 3. Verify "peruse" CLI is accessible
peruse --help > /dev/null 2>&1 || { echo "ERROR: peruse CLI not found after install"; exit 1; }

# 4. Dev server responding?
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
echo "Dev server status: $HTTP_STATUS"
```

If dev server returns non-200 or connection refused:
- Look for `package.json` in the project root
- Try: `npm run dev &` or `npm start &`, wait 5 seconds, retry
- If still failing — report and stop

---

## STEP 2 — Run peruse

**Note:** The CLI command is `peruse run`, not `peruse-ai`.
peruse-ai reads config from env vars: `PERUSE_VLM_BACKEND`, `PERUSE_VLM_BASE_URL`, `PERUSE_VLM_MODEL`.

### Single-model mode

```bash
PERUSE_VLM_BACKEND=openai_compat \
PERUSE_VLM_BASE_URL="$LLM_BASE_URL" \
PERUSE_VLM_MODEL="$LLM_MODEL" \
peruse run \
  --url "$URL" \
  --task "$TASK" \
  --reports ux \
  --max-steps "$MAX_STEPS" \
  --output "$OUTPUT_DIR/run_${ITERATION}"
```

### Multi-model mode (multiple models selected)

Run sequentially — one `peruse run` per model:

```bash
for entry in "${SELECTED_MODELS[@]}"; do
  MODEL_ID="..."    # parsed from entry
  BASE_URL="..."    # from opencode.json provider options
  API_KEY="..."     # from auth.json

  SAFE_MODEL_ID="${MODEL_ID//\//_}"   # replace / with _ for dir name

  PERUSE_VLM_BACKEND=openai_compat \
  PERUSE_VLM_BASE_URL="$BASE_URL" \
  PERUSE_VLM_MODEL="$MODEL_ID" \
  peruse run \
    --url "$URL" \
    --task "$TASK" \
    --reports ux \
    --max-steps "$MAX_STEPS" \
    --output "$OUTPUT_DIR/${SAFE_MODEL_ID}/run_${ITERATION}"
done
```

Wait for all runs to complete before proceeding.

---

## STEP 3 — Read and analyze output

For each model run, read all files from the output directory:

```bash
ls -la "$OUTPUT_DIR/[model_dir]/run_${ITERATION}/"
```

Expected files:
- `ux_review_*.md` — UX report (main analysis file)
- `*.json` — structured data
- `screenshots/` or `screenshot_*.png` — visual captures

Read each file. View screenshots visually (you are multimodal).

Build an analysis summary per model run:
1. **Critical issues** — broken layout, invisible text, overlapping elements
2. **UX problems** — confusing labels, illogical grouping, hidden items
3. **Minor issues** — spacing, alignment, contrast

---

## STEP 4 — Build fix plan

### Single-model mode

```
## Fix Plan — Iteration $ITERATION

### Critical (fix now)
- [ ] FILE: src/components/Sidebar.vue — line ~45: icon overlap, add margin-left: 8px
- [ ] FILE: src/views/Dashboard.vue — heading contrast too low (#aaa → #333)

### UX (fix now)
- [ ] FILE: src/router/index.js — rename "Cfg" to "Settings"

### Minor (if time allows)
- [ ] FILE: src/assets/styles/main.css — sidebar padding inconsistent → 12px
```

### Multi-model mode

Merge findings across all models. Mark agreement level:

```
## Fix Plan — Iteration $ITERATION (merged, N models)

### All models agree — fix immediately
- [ ] FILE: src/views/Dashboard.vue — contrast (flagged by: model-a, model-b, model-c)

### Partial agreement (2+ models) — fix now
- [ ] FILE: src/components/Sidebar.vue — overlap (flagged by: model-a, model-b)

### Single-model finding — low priority, review manually
- [ ] src/router/index.js — label clarity (model-a only)
```

Issues flagged by 2+ models go into the fix plan. Single-model-only findings are noted but not auto-fixed.

Show the plan. Proceed automatically unless this is the final iteration or >5 files are affected.

---

## STEP 5 — Apply fixes

Apply Critical → UX → Minor.

For each fix:
1. Read the file first
2. Make targeted edits — do not rewrite whole files
3. Log: `✓ Fixed: src/components/Sidebar.vue — margin-left added`

If a fix is ambiguous — skip it, note in summary, do not guess.

---

## STEP 6-A — Iteration summary

```
## Iteration $ITERATION / $TOTAL_ITERATIONS complete

Model(s): [list]
Applied: N fixes
Skipped: M (reasons)
Changed files: [list]

Next: re-running peruse to verify fixes...
```

If `$ITERATION < $TOTAL_ITERATIONS` → increment, go back to STEP 2.
If `$ITERATION == $TOTAL_ITERATIONS` → go to STEP 6-B or 6-C.

---

## STEP 6-B — Final report: multi-model comparison

```
## UI Audit Complete — Multi-model comparison

### Models tested
| Model                    | Issues found | Unique findings | Agreement rate |
|--------------------------|-------------|-----------------|----------------|
| provider/qwen2.5-vl:72b  |     12      |       3         |     75%        |
| provider/llava:13b        |      8      |       1         |     62%        |

### Consensus issues (all models agreed)
- [list]

### Model-specific findings worth manual review
- qwen2.5-vl:72b found X that others didn't — [description]

### Recommendation
Best model for this codebase: [model with highest agreement + most unique valid findings]

### What was fixed across all iterations
- [list]

### Remaining issues
- [list]
```

---

## STEP 6-C — Final report: single-model

```
## UI Audit Complete — $TOTAL_ITERATIONS iterations

### What was fixed
- [list]

### Remaining issues
- [list]

### Manual verification command
PERUSE_VLM_BACKEND=openai_compat \
PERUSE_VLM_BASE_URL=$LLM_BASE_URL \
PERUSE_VLM_MODEL=$LLM_MODEL \
peruse run --url $URL --task "..." --reports ux --output ./peruse_output/final
```

---

## Error handling

| Situation | Action |
|---|---|
| `peruse` command not found after install | Check `pip install peruse-ai` ran, check `$PATH` |
| peruse crashes mid-run | Read partial output, continue with what's available |
| No `ux_review_*.md` files generated | Show stderr, stop |
| One model fails in multi-model run | Skip that model, continue others, note in final report |
| Dev server dies mid-run | Restart it, retry |
| LLM endpoint unreachable | Report immediately, do not retry silently |
| Fix causes syntax error | Revert, log as skipped |
| No VL models found in config | Warn, let user choose any model |

---

## Example invocations

**Default — agent discovers VL models, asks user:**
> "run ui check"
→ Agent reads OpenCode config, lists VL models, waits for selection.

**Explicit single model:**
> "run ui check with qwen2.5-vl:72b, 2 iterations"
→ Uses named model, skips discovery.

**Multi-model comparison:**
> "compare qwen2.5-vl:72b and llava:13b on the UI, 3 iterations"
→ Runs both models each iteration, merged fix plan, comparison report at end.

**All VL models:**
> "run ui check with all vl models"
→ Discovers and runs all VL-capable models.

---

## Execution order

```
STEP 0 (model selection)
  → STEP 1 (preflight)
    → STEP 2 (peruse run)
      → STEP 3 (analyze output)
        → STEP 4 (fix plan)
          → STEP 5 (apply fixes)
            → STEP 6-A (iteration summary)
              → back to STEP 2 (if more iterations)
              → STEP 6-B or 6-C (final report)
```
