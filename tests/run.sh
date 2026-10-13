#!/usr/bin/env bash
# Run syntax checks and isolated regressions without touching the live desktop.
set -euo pipefail
cd "$(dirname "$0")/.."
while IFS= read -r -d '' script; do bash -n "$script"; done < <(find scripts .config tests -type f -name '*.sh' -print0)
for test in tests/*.sh; do [[ $test == tests/run.sh ]] || bash "$test"; done
