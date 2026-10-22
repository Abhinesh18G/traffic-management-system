
FROM nginx:1.28-alpine

ARG CREATE_HEALTH_PAGE=true

COPY index.html /usr/share/nginx/html/index.html

RUN if [ "$CREATE_HEALTH_PAGE" = "true" ]; then \
      echo "OK" > /usr/share/nginx/html/health.html; \
    else \
      rm -f /usr/share/nginx/html/health.html; \
    fi

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
