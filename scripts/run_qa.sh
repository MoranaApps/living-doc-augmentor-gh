#!/usr/bin/env bash

# CI-equivalent local quality-gate wrapper.
# Usage:
#   ./scripts/run_qa.sh            # sequential (safe default)
#   ./scripts/run_qa.sh --parallel # parallel (faster)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

if [[ "${1:-}" == "--parallel" ]]; then
    echo "=== Running quality gates (parallel) ==="
    make qa-parallel
else
    echo "=== Running quality gates (sequential) ==="
    make qa
fi
