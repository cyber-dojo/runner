FROM ghcr.io/cyber-dojo/sinatra-base:1a1d65f@sha256:31bfb1e5cbc25d4b37e0dfea2e460d4ecdaf8062bfc5b70b6a28c40211daea61 AS base
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
# See docs/runner-as-docker-group.txt
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
