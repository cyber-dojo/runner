FROM cyberdojo/docker-base:77d4203@sha256:56aa599981168c97518c19ec9236e2e3eb271f04adf7ae6aa479703ad76f9d01
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

#RUN apk add --upgrade expat=2.7.5-r0          # https://security.snyk.io/vuln/SNYK-ALPINE321-EXPAT-15199474
#RUN apk add --upgrade c-ares=1.34.6-r0        # https://security.snyk.io/vuln/SNYK-ALPINE322-CARES-14409293
#RUN apk upgrade libcrypto3 libssl3            # https://security.snyk.io/vuln/SNYK-ALPINE322-OPENSSL-13174133

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
