FROM ollama/ollama:rocm

# Preload specific models
ARG MODELS
ENV MODELS=${MODELS}

# needed to set in the environment
ARG OLLAMA_KEEP_ALIVE
ENV OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-24h}

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/ollama-entrypoint.sh
RUN chmod +x /usr/local/bin/ollama-entrypoint.sh

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
        ready=0; \
        for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do \
            if ollama list >/dev/null 2>&1; then \
                ready=1; \
                break; \
            fi; \
            sleep 1; \
        done; \
        if [ "$ready" -ne 1 ]; then \
            echo "ERROR: ollama did not become ready during build-time pre-pull" >&2; \
            echo "--- /tmp/ollama-serve.log ---" >&2; \
            cat /tmp/ollama-serve.log >&2 || true; \
            kill "$pid" || true; \
            wait "$pid" || true; \
            exit 1; \
        fi; \
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
ENTRYPOINT ["/usr/local/bin/ollama-entrypoint.sh"]