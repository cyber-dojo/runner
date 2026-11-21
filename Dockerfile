FROM ghcr.io/cyber-dojo/sinatra-base:4d448af@sha256:d2d3fd0451afc5954ea4433e41f6f17ad6ad856bf607c9cd23dd4cf9c32b6ce8 AS base
# The FROM statement above is typically set via an automated pull-request from the sinatra-base repo
LABEL maintainer=jon@jaggersoft.com

# The workflow caches the bare image (this base stage) by a hash of this
# stage's instructions (comments and blank lines aside), so this unpinned
# gem is as new as the last change to those instructions. To pick up a newer
# one, eg a security fix, bump GEM_REFRESH.
ARG GEM_REFRESH=1
RUN gem install --no-document 'concurrent-ruby'

ARG APP_DIR=/runner
ENV APP_DIR=${APP_DIR}

# The stage above, base, is the bare image: Ruby, its gems and the OS
# packages, with no source code. The stage below adds the source code, making
# the deployed image. Built with --target base it is the bare image the server
# tests run in (bin/run_tests_bare.sh); built with
# --build-context base=<that bare image>, the deployed image is built FROM
# the very bare image the tests ran in (.github/workflows/main.yml).
FROM base

ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

WORKDIR ${APP_DIR}/source
COPY source/server/ .
# The runner opens /var/run/docker.sock, which is owned by the host's docker
# group, so it cannot drop to an unprivileged user without matching that group.
# See docs/docker-socket-privilege.md
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
