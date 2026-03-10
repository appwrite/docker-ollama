FROM ollama/ollama:0.12.7

# Preload specific models
ARG MODELS
ENV MODELS=${MODELS}

# needed to set in the environment
ARG OLLAMA_KEEP_ALIVE
ENV OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-24h}

# Pre-pull models at build time for Docker layer caching
RUN ollama serve & \
    sleep 5 && \
    for m in $MODELS; do \
        echo "Pulling model $m..."; \
        ollama pull "$m" || exit 1; \
    done && \
    pkill ollama

# Expose Ollama default port
EXPOSE 11434

# On container start, quickly ensure models exist (no re-download unless missing)
ENTRYPOINT ["/bin/bash", "-c", "read -r -a models <<< \"$MODELS\"; for m in \"${models[@]}\"; do ollama list | grep -qw \"$m\" || ollama pull \"$m\" || exit 1; done && exec ollama serve"]