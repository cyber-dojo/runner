FROM cyberdojo/docker-base:5412310@sha256:c27bd6bb19a6142a43a345ab175289c28eadfbfde15898b828e31b81d7b247a4
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

ARG APP_DIR=/runner 
ENV APP_DIR=${APP_DIR}

# https://security.snyk.io/vuln/SNYK-ALPINE322-OPENSSL-15993406
#RUN apk add --upgrade openssl=3.5.6-r0     
# https://security.snyk.io/vuln/SNYK-ALPINE323-UTILLINUX-15993298
#RUN apk add --upgrade util-linux=2.41.4-r0
# https://security.snyk.io/vuln/SNYK-ALPINE323-MUSL-16032072
#RUN apk add --upgrade musl=1.2.5-r23
#RUN apk add --upgrade musl-utils=1.2.5-r23

WORKDIR ${APP_DIR}/source
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
