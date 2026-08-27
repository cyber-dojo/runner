FROM ghcr.io/cyber-dojo/sinatra-base:5ab6a10@sha256:c096154011cc1cef9cc69e8be948fb4329543f9670d4fb4fd3851a8aa016630d AS base
# The FROM statement above is typically set via an automated pull-request from the sinatra-base repo
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

ARG APP_DIR=/runner 
ENV APP_DIR=${APP_DIR}

WORKDIR ${APP_DIR}/source
COPY source/server/ .
# The runner opens /var/run/docker.sock, which is owned by the host's docker
# group, so it cannot drop to an unprivileged user without matching that group.
# See docs/docker-socket-privilege.md
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
