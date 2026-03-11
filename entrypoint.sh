#!/usr/bin/env bash
set -euo pipefail

# Optional space-separated list of models to ensure are available.
if [[ -n "${MODELS:-}" ]]; then
  # Split MODELS into an array
  read -r -a models <<< "${MODELS}"

  # Start a temporary ollama server to perform warm-up operations
  ollama serve >/tmp/ollama-entrypoint.log 2>&1 & pid=$!

  ready=0
  for i in {1..20}; do
    if ollama list >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done

  if [[ "$ready" -ne 1 ]]; then
    echo "ERROR: ollama did not become ready during entrypoint pre-pull" >&2
    echo "--- /tmp/ollama-entrypoint.log ---" >&2
    cat /tmp/ollama-entrypoint.log >&2 || true
    kill "$pid" || true
    wait "$pid" || true
    exit 1
  fi

  model_exists() {
    local name="$1"
    if ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$name"; then
      return 0
    fi
    return 1
  }

  for m in "${models[@]}"; do
    if model_exists "$m"; then
      continue
    fi
    if [[ "$m" != *:* ]] && model_exists "${m}:latest"; then
      continue
    fi
    ollama pull "$m"
  done

  kill "$pid" || true
  wait "$pid" || true
fi

exec ollama serve

