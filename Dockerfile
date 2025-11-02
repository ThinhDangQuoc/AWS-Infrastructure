# create non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

USER appuser

# add healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
