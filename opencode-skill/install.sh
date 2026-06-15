#!/usr/bin/env bash
set -euo pipefail

# ── paths ─────────────────────────────────────────────────────────────────────
SKILL_DIR="${HOME}/.config/opencode/skills/peruse-ui-check"
ENV_FILE="${HOME}/.peruse-ui.env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="${SCRIPT_DIR}/SKILL.md"

# ── colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}!${NC} $*"; }
die()     { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

echo ""
echo -e "${CYAN}peruse-ui-check skill installer${NC}"
echo "────────────────────────────────"
echo ""

# ── check SKILL.md exists ─────────────────────────────────────────────────────
[ -f "$SKILL_SRC" ] || die "SKILL.md not found at $SKILL_SRC"

# ── collect LLM config ────────────────────────────────────────────────────────
# Load existing values as defaults if ~/.peruse-ui.env already exists
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE" 2>/dev/null || true
fi

echo -e "Configure VLM endpoint — saved to ${CYAN}${ENV_FILE}${NC}"
echo -e "(used as fallback when OpenCode config has no matching provider)"
echo ""

read -rp "  VLM base URL  [${PERUSE_VLM_BASE_URL:-}]: " input_url
[ -n "$input_url" ] && PERUSE_VLM_BASE_URL="$input_url"
[ -n "${PERUSE_VLM_BASE_URL:-}" ] || die "VLM base URL is required."

read -rp "  Model name    [${PERUSE_VLM_MODEL:-}]: " input_model
[ -n "$input_model" ] && PERUSE_VLM_MODEL="$input_model"
[ -n "${PERUSE_VLM_MODEL:-}" ] || die "Model name is required."

echo ""

# ── write ~/.peruse-ui.env ────────────────────────────────────────────────────
# Note: peruse-ai reads PERUSE_VLM_* natively — no custom prefix needed
cat > "$ENV_FILE" <<EOF
# peruse-ui fallback config
# Used only when OpenCode provider config is not available.
# peruse-ai reads these env vars natively (PERUSE_VLM_* prefix).

PERUSE_VLM_BACKEND=openai_compat
PERUSE_VLM_BASE_URL=${PERUSE_VLM_BASE_URL}
PERUSE_VLM_MODEL=${PERUSE_VLM_MODEL}

# Optional
# PERUSE_OUTPUT_DIR=./peruse_output
# PERUSE_MAX_STEPS=30
# PERUSE_HEADLESS=true
EOF
success "Config written → ${ENV_FILE}"

# ── install skill ─────────────────────────────────────────────────────────────
mkdir -p "$SKILL_DIR"
cp "$SKILL_SRC" "$SKILL_DIR/SKILL.md"
success "Skill installed → ${SKILL_DIR}/SKILL.md"

# ── install dependencies ──────────────────────────────────────────────────────
echo ""
info "Checking dependencies..."

if ! pip show peruse-ai &>/dev/null; then
    info "Installing peruse-ai..."
    pip install peruse-ai --break-system-packages -q && success "peruse-ai installed"
else
    success "peruse-ai already installed ($(pip show peruse-ai | grep Version | cut -d' ' -f2))"
fi

# Verify CLI entry point is accessible
if ! command -v peruse &>/dev/null; then
    warn "'peruse' CLI not in PATH — you may need to add $(python3 -m site --user-base)/bin to PATH"
    echo "    Add to ~/.bashrc or ~/.zshrc:"
    echo "    export PATH=\"\$PATH:$(python3 -m site --user-base)/bin\""
else
    success "'peruse' CLI accessible ($(peruse --version 2>/dev/null || echo 'version unknown'))"
fi

info "Installing playwright chromium..."
if playwright install chromium &>/dev/null 2>&1; then
    success "playwright chromium ready"
elif python -m playwright install chromium &>/dev/null 2>&1; then
    success "playwright chromium ready (via python -m)"
else
    warn "playwright chromium install failed — run manually: playwright install chromium"
fi

# ── quick connectivity check ──────────────────────────────────────────────────
echo ""
info "Testing VLM connectivity..."
if peruse check-vlm \
    --backend openai_compat \
    --base-url "$PERUSE_VLM_BASE_URL" \
    --model "$PERUSE_VLM_MODEL" 2>/dev/null; then
    success "VLM endpoint reachable"
else
    warn "VLM connectivity check failed — endpoint may be offline or model name incorrect"
    warn "You can test manually: peruse check-vlm --backend openai_compat --base-url $PERUSE_VLM_BASE_URL --model $PERUSE_VLM_MODEL"
fi

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}All done.${NC} In OpenCode, say: ${CYAN}\"run ui check\"${NC}"
echo ""
