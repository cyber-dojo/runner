FROM cyberdojo/docker-base:623a63d@sha256:94fa06fcd6d728b03943344b4cd0c237efa864c3d91cb29a4b5544e5181d0999
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

RUN apk add --upgrade git=2.47.3-r0      # https://security.snyk.io/vuln/SNYK-ALPINE320-GIT-10669667
RUN apk add --upgrade sqlite=3.48.0-r3   # https://security.snyk.io/vuln/SNYK-ALPINE321-SQLITE-11191065

RUN gem install --no-document 'concurrent-ruby'

WORKDIR /runner
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
