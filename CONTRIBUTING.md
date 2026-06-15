# Contributing to Peruse-AI

This repository is a fork of [Prodoorknob/peruse-ai](https://github.com/Prodoorknob/peruse-ai)
(originally by rvedire). Changes are developed here and proposed back to upstream via pull
request, so please keep contributions focused and upstream-friendly.

## Project layout

| Path | What |
|---|---|
| `src/peruse_ai/` | Python package — agent, CLI, config, perception, VLM, outputs |
| `src/peruse_ai/cli.py` | `peruse` CLI entry point (Click) |
| `tests/` | pytest suite |
| `opencode-skill/` | OpenCode UI-audit skill (`peruse-ui-check`) + installer |
| `assets/` | README media and a sample report |

See `AGENTS.md` for a fuller architecture and module map.

## Development setup

Requires Python 3.10+.

```bash
git clone https://github.com/bashrusakh/peruse-ai.git
cd peruse-ai
pip install -e ".[dev]"
playwright install chromium
```

## Workflow

`master` is the default branch. Work on a short-lived branch and open a pull request;
avoid pushing directly to `master`.

```bash
git checkout master
git pull --ff-only

git checkout -b fix/short-description    # or feature/, chore/, docs/
# ... edit, test, commit ...
git push -u origin fix/short-description
```

| Prefix | When |
|---|---|
| `feature/` | new functionality |
| `fix/` | bug fix |
| `chore/` | tooling, deps, refactor without behavior change |
| `docs/` | documentation only |

## Checks before opening a PR

Run what is relevant to your change:

```bash
ruff check src tests        # lint
mypy src                    # type check
pytest -v                   # tests (asyncio_mode=auto)
```

Lint/type config lives in `pyproject.toml` (ruff: line length 100, rules `E,F,I,N,W,UP`).
For changes that touch browser or agent behavior, also do a quick manual `peruse run`
smoke test against a known page.

## Commit and PR messages

Use one template for both commits and PR titles:

```text
<scope>: <imperative summary>
```

Rules: English only, lowercase scope, short imperative summary, no trailing period, one
logical change per commit.

| Scope | Area |
|---|---|
| `agent` | `agent.py` — perceive/plan/act loop |
| `cli` | `cli.py` — commands and options |
| `config` | `config.py` — settings |
| `perception` | `perception.py` — DOM + screenshot capture |
| `vlm` | `vlm.py` — backends, prompts, connectivity |
| `browser` | `browser.py` — Playwright wrapper |
| `outputs` | `outputs.py` — report generation |
| `focus-group` | `focus_group.py` — multi-persona runs |
| `skill` | `opencode-skill/` |
| `docs` | README, CHANGELOG, AGENTS.md, this file |
| `tests` | test-only changes |
| `fix(<area>)` | focused bug fix when that reads better |

Examples:

```text
cli: add --api-key flag for authenticated VLM backends
config: document kwargs-over-env priority
fix(outputs): correct screenshot path in saved reports
docs: rewrite README for the fork
```

A PR body should usually cover: summary, why, validation, and risk or possible
regressions. Co-author trailers are welcome when AI agents contributed.

## Proposing changes upstream

To send a change to the upstream project:

```bash
git remote add upstream https://github.com/Prodoorknob/peruse-ai.git
git fetch upstream
git rebase upstream/master          # keep your branch current
# then open a PR from your fork's branch against Prodoorknob/peruse-ai
```

Keep upstream PRs self-contained — avoid bundling unrelated changes, and update
`CHANGELOG.md` when the change is user-visible.

## License

MIT — see the root `LICENSE` file.
