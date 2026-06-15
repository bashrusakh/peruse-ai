# Peruse-AI — AI Agent Reference

Quick orientation for AI coding agents working in this repository. For human-facing docs
see `README.md`; for contribution mechanics see `CONTRIBUTING.md`.

## Core purpose

Peruse-AI is a local-first, universal web agent. Given a URL and a high-level task, it
autonomously explores a web app with a real browser and a local Vision-Language Model
(VLM), then produces structured Markdown reports (data insights, UX/UI review, bug report).
It runs fully locally against Ollama, LM Studio, any OpenAI-compatible endpoint, or the
Jina VLM cloud backend.

This repository is a fork of [Prodoorknob/peruse-ai](https://github.com/Prodoorknob/peruse-ai);
changes are proposed upstream via pull request.

## Architecture overview

The pipeline is a perceive → decide → act loop:

1. **Entry** — `cli.py` (Click commands) or the Python API (`PeruseAgent`).
2. **Init** — load `PeruseConfig`, create the VLM (`vlm.create_vlm`), launch the browser.
3. **Perceive** — `perception.py` captures a screenshot, extracts DOM elements, and
   monitors console/network errors.
4. **Decide** — the VLM receives the screenshot + DOM and returns a JSON action.
5. **Act** — `browser.py` executes the action via Playwright.
6. **Report** — `outputs.py` post-processes the `AgentResult` into Markdown + screenshots.

Keep the boundaries clear: browser I/O belongs in `browser.py`; page-state capture in
`perception.py`; VLM construction and prompts in `vlm.py`; the agent loop and result types
in `agent.py`; report generation in `outputs.py`; configuration in `config.py`.

## Repository layout

| Path | What |
|---|---|
| `src/peruse_ai/agent.py` | `PeruseAgent`, `AgentResult`, `AgentStep` — the perceive/plan/act loop |
| `src/peruse_ai/cli.py` | `peruse` CLI: `run`, `scan`, `focus-group`, `check-vlm` |
| `src/peruse_ai/config.py` | `PeruseConfig` (pydantic-settings), `VLMBackend` |
| `src/peruse_ai/perception.py` | screenshot + DOM extraction + error monitoring |
| `src/peruse_ai/browser.py` | Playwright browser wrapper |
| `src/peruse_ai/vlm.py` | VLM creation, prompts, connectivity check |
| `src/peruse_ai/outputs.py` | report generators + `save_outputs` |
| `src/peruse_ai/focus_group.py` | `FocusGroup` — concurrent multi-persona runs |
| `src/peruse_ai/__init__.py` | public API surface + `__version__` |
| `tests/` | pytest suite (`test_config`, `test_outputs`, `test_perception`) |
| `opencode-skill/` | OpenCode `peruse-ui-check` skill + `install.sh` |
| `assets/` | README media + a sample report |

## Tech stack

- Language: Python 3.10+ (`pyproject.toml` is the source of truth)
- Browser automation: Playwright (Chromium) via `browser-use`
- VLM clients: `langchain-ollama`, `langchain-openai`
- Config: `pydantic` + `pydantic-settings`
- CLI / terminal UX: `click`, `rich`
- Images: `Pillow`

## Documentation map

- General project behavior: `README.md`
- Contribution and commit conventions: `CONTRIBUTING.md`
- Release history and user-visible changes: `CHANGELOG.md`
- OpenCode skill behavior: `opencode-skill/SKILL.md`

## Build and validation commands

```bash
pip install -e ".[dev]"          # install with dev tools
playwright install chromium      # one-time browser download

ruff check src tests             # lint
mypy src                         # type check
pytest -v                        # tests (asyncio_mode=auto)
```

For docs-only changes, tests are usually not required; state that they were not run because
the change is documentation-only.

## Runtime entry points

- CLI: `peruse_ai.cli:main` — commands `run`, `scan`, `check-vlm`, `focus-group`
- Agent: `PeruseAgent.run()` in `agent.py`
- VLM: `create_vlm()` and `check_vlm_connection()` in `vlm.py`
- Reports: `save_outputs()` in `outputs.py`

## Configuration rules (important)

`PeruseConfig` resolves settings in priority order: **constructor kwargs > `PERUSE_*`
environment variables > `.env` file > defaults**. This has a sharp edge that has already
caused a real bug:

- CLI options with a non-`None` default (`--model`, `--backend`) are *always* placed into
  the config kwargs, so they override env vars. Options that should fall back to env must
  use a `None` default and be applied conditionally:

  ```python
  if base_url:
      config_kwargs["vlm_base_url"] = base_url
  if api_key:
      config_kwargs["vlm_api_key"] = api_key
  ```

- When adding a CLI option, thread it through three places that must stay in sync: the
  command function signature, the `asyncio.run(_handler(...))` call, and the internal
  `_*_handler` / `_*_agent` signature. Click maps each option to a parameter by name.

## Output contract

- `outputs.py` writes Markdown reports (`ux_review_*.md`, `data_insights_*.md`,
  `bug_report_*.md`) plus deduplicated PNG screenshots at `screenshots/step_NNN.png`.
- It does **not** emit JSON. Do not document or depend on JSON output unless you add it.

## VLM backends

`VLMBackend`: `ollama`, `lmstudio`, `openai_compat`, `jina`. The `openai_compat` and cloud
endpoints may require auth — supply it via `vlm_api_key` (`--api-key` /
`PERUSE_VLM_API_KEY`).

## Agent constraints

- Prefer the smallest correct change; keep diffs tight and avoid drive-by refactors.
- Do not run mutating git/GitHub commands unless explicitly asked. Read-only
  status/diff/log is fine when preparing a requested commit or PR.
- Keep the public API in `__init__.py` stable unless the task changes it.
- Preserve a dirty working tree; never revert unrelated edits.
- Do not commit secrets, API keys, `peruse_output/`, or generated reports.
- Inspect nearby code before introducing new patterns; match existing style (ruff, line
  length 100).

## Line endings (skill copies)

The skill exists as two content-identical copies that must stay in sync: the repo copy in
`opencode-skill/` uses **CRLF**, while a deployed working copy may use **LF**. When editing
one, mirror the change to the other and preserve each file's existing line-ending
convention. Most of this repo (`*.py`, `README.md`, `pyproject.toml`) is CRLF.

## Testing expectations

- `config.py` changes: run `pytest tests/test_config.py` at minimum.
- `outputs.py` changes: run `pytest tests/test_outputs.py` at minimum.
- `perception.py` changes: run `pytest tests/test_perception.py` at minimum.
- Cross-cutting changes: run the full `pytest`.
- Add a regression test when fixing a reproducible bug.

## Commit conventions

Follow `CONTRIBUTING.md`: `<scope>: <imperative summary>`, with scopes such as `agent`,
`cli`, `config`, `perception`, `vlm`, `browser`, `outputs`, `focus-group`, `skill`,
`docs`, `tests`. One logical change per commit.
