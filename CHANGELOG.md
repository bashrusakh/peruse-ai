# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This repository is a fork of [Prodoorknob/peruse-ai](https://github.com/Prodoorknob/peruse-ai)
(originally by rvedire). Version `0.1.0` is inherited from upstream; `0.2.0` and later are
changes developed in this fork and proposed back upstream.

## [0.2.0] - 2026-06-15

### Added

- **`--api-key` CLI flag** on `run`, `scan`, `check-vlm`, and `focus-group`. Supplies the
  VLM API key for backends that require auth (e.g. `openai_compat` cloud endpoints),
  mirroring `--base-url`. The flag takes priority over the `PERUSE_VLM_API_KEY` environment
  variable, which remains a fallback. (`src/peruse_ai/cli.py`)
- **OpenCode UI-audit skill** under `opencode-skill/` (`peruse-ui-check`): drives
  `peruse run` against a local dev server, reads the generated reports, builds a fix plan,
  applies edits, and iterates — with an optional multi-model comparison mode and an
  `install.sh` installer. (`opencode-skill/SKILL.md`, `opencode-skill/install.sh`)

### Changed

- **README** reworked for this fork: consistent repository links, an upstream credit,
  `--api-key` documented across the CLI reference and configuration tables, install
  instructions for both PyPI and a source checkout, and a section on the OpenCode skill.
- **`CONTRIBUTING.md`** and **`AGENTS.md`** rewritten for peruse-ai — both previously
  contained boilerplate copied from an unrelated project.

### Fixed

- **Skill: the selected model/backend was ignored.** `SKILL.md` set the backend and model
  through `PERUSE_VLM_*` env vars while invoking `peruse run` without flags; the CLI's
  built-in defaults (`ollama` / `qwen3-vl:6b`) then shadowed them via constructor kwargs.
  The skill now passes explicit `--backend` / `--model` / `--base-url` / `--api-key`.
- **Skill: cloud providers failed on auth.** The API key parsed during model discovery was
  never forwarded to `peruse run`; it is now passed via `--api-key`.
- **Skill: inconsistent variable names** (`$LLM_BASE_URL` / `$LLM_MODEL` vs.
  `MODEL_ID` / `BASE_URL` / `API_KEY`) unified, and the `~/.peruse-ui.env` fallback now
  bridges the env-file names to the variables the run step uses.
- **Skill docs vs. behavior:** removed the non-existent `*.json` output from the expected
  files and corrected the screenshot path to `screenshots/step_*.png` (matches
  `outputs.py`).
- **`install.sh`:** added an optional API-key prompt (saved to the env file and passed to
  `check-vlm`), a `pip --break-system-packages` fallback for older pip, and removed a
  redundant `2>&1` redirect.

## [0.1.0] - Upstream baseline

Initial release inherited from upstream
[Prodoorknob/peruse-ai](https://github.com/Prodoorknob/peruse-ai):

- Autonomous, local-first web exploration with Playwright + a local Vision-Language Model
  (Ollama, LM Studio, OpenAI-compatible, or Jina VLM backends).
- Dual-channel perception (DOM extraction + screenshots) with loop detection and nudge
  recovery.
- Custom personas and concurrent focus groups.
- Multi-output report pipeline: Data Insights, UX/UI Review, and Bug Report.
- `peruse` CLI (`run`, `scan`, `focus-group`, `check-vlm`) and a Python API.

[0.2.0]: https://github.com/bashrusakh/peruse-ai/releases/tag/v0.2.0
[0.1.0]: https://github.com/Prodoorknob/peruse-ai
