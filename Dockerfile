FROM cyberdojo/docker-base:909ba1d@sha256:20ac5af0c95cd148ad9acba9ca8da9c9145d6df478f40cccac52042aa071427f AS base
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
