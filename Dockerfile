RUN addgroup appgroup && adduser --ingroup appgroup --disabled-password appuser
USER appuser


HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -f http://localhost:8080/health || exit 1
