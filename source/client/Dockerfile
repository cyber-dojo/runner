FROM ghcr.io/cyber-dojo/sinatra-base:5ab6a10@sha256:c096154011cc1cef9cc69e8be948fb4329543f9670d4fb4fd3851a8aa016630d
LABEL maintainer=jon@jaggersoft.com

ARG APP_DIR=/runner
ENV APP_DIR=${APP_DIR}

WORKDIR ${APP_DIR}/source
COPY . .
USER nobody
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
