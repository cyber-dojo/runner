FROM ghcr.io/cyber-dojo/sinatra-base:949edc1@sha256:fd5205d77df654e812682c185b04f8c94f22ae192d2a09efb68f1358a36d73a2 AS base
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
