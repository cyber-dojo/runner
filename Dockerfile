FROM cyberdojo/docker-base:9cb077b@sha256:e603f1fe13b1c842167ebd81ab0e7ab19c4a16c4f42cb47040581051d4dae32d
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

RUN apk add --upgrade expat=2.7.4-r0          # https://security.snyk.io/vuln/SNYK-ALPINE321-EXPAT-15199474
RUN apk add --upgrade c-ares=1.34.6-r0        # https://security.snyk.io/vuln/SNYK-ALPINE322-CARES-14409293
RUN apk add --upgrade busybox=1.37.0-r14      # https://security.snyk.io/vuln/SNYK-ALPINE321-BUSYBOX-14102399
RUN apk add --upgrade git=2.47.3-r0           # https://security.snyk.io/vuln/SNYK-ALPINE320-GIT-10669667
RUN apk add --upgrade sqlite=3.48.0-r4        # https://security.snyk.io/vuln/SNYK-ALPINE321-SQLITE-11191066
RUN apk add --upgrade sqlite-libs=3.48.0-r4   # https://security.snyk.io/vuln/SNYK-ALPINE321-SQLITE-11191066
RUN apk upgrade libcrypto3 libssl3            # https://security.snyk.io/vuln/SNYK-ALPINE322-OPENSSL-13174133

RUN gem install --no-document 'concurrent-ruby'

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
