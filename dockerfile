FROM ollama/ollama:0.17.7

# Preload specific models
ARG MODELS
ENV MODELS=${MODELS}

# needed to set in the environment
ARG OLLAMA_KEEP_ALIVE
ENV OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-24h}

# Pre-pull models at build time for Docker layer caching
ARG TARGETARCH
RUN if [ -z "${MODELS:-}" ]; then \
        echo "MODELS is empty; skipping build-time pre-pull."; \
    else \
        case "${TARGETARCH:-}" in \
            amd64) PORT=11434 ;; \
            arm64) PORT=11435 ;; \
            *) PORT=11436 ;; \
        esac; \
        export OLLAMA_HOST="http://127.0.0.1:${PORT}"; \
        ollama serve >/tmp/ollama-serve.log 2>&1 & pid="$!"; \
        for i in 1 2 3 4 5 6 7 8 9 10; do \
            ollama list >/dev/null 2>&1 && break; \
            sleep 1; \
        done; \
        for m in $MODELS; do \
            echo "Pulling model $m..."; \
            ollama pull "$m" || exit 1; \
        done; \
        kill "$pid"; \
        wait "$pid" || true; \
    fi

# Expose Ollama default port
EXPOSE 11434

# On container start, quickly ensure models exist (no re-download unless missing)
ENTRYPOINT ["/bin/bash", "-lc", "set -euo pipefail; if [[ -n \"${MODELS:-}\" ]]; then read -r -a models <<< \"${MODELS}\"; ollama serve >/tmp/ollama-entrypoint.log 2>&1 & pid=$!; for i in {1..20}; do ollama list >/dev/null 2>&1 && break; sleep 1; done; for m in \"${models[@]}\"; do ollama list | grep -qw \"$m\" || ollama pull \"$m\"; done; kill \"$pid\"; wait \"$pid\" || true; fi; exec ollama serve"]