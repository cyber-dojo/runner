FROM ghcr.io/cyber-dojo/sinatra-base:e06ed4c@sha256:3030430a767406f8ded8c2cf5d24d111d72366b9bf253ea1d6e859a80a0946da AS base
# The FROM statement above is typically set via an automated pull-request from the sinatra-base repo
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

# crun runs a test-run's container from an OCI config, which is the path
# docs/dropping-the-docker-daemon.md proposes in place of the docker daemon.
RUN apk add --no-cache crun

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
