#!/usr/bin/env bash
# Install git hooks for ClaudeAgentSDK development.
# Usage: bash scripts/initial-setup.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Installing pre-push hook..."
cp "$REPO_ROOT/scripts/pre-push" "$REPO_ROOT/.git/hooks/pre-push"
chmod +x "$REPO_ROOT/.git/hooks/pre-push"

echo "Done. Pre-push hook installed."
