FROM cyberdojo/docker-base:54aa7e3@sha256:526fca5c369c92b4fb36d0c2f723798becbe0077a76a0f69532652c95a51447f AS base
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

# Remove git, which is inherited from the upstream docker:dind base image.
# The runner never uses git at runtime; the only git calls in this repo are
# host-side build scripts (bin/echo_env_vars.sh runs "git rev-parse HEAD" on the
# host, not inside the image). git is the sole package that pulls in libcurl, so
# deleting it also removes libcurl and clears the recurring Alpine libcurl CVEs
# from the runner's Snyk scan. docker-base keeps git for commander, which does
# use "git clone" at runtime.
RUN apk del git

ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

ARG APP_DIR=/runner 
ENV APP_DIR=${APP_DIR}

WORKDIR ${APP_DIR}/source
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
