FROM cyberdojo/docker-base:c58be3b@sha256:8dec1f5e6f664033795907d155fd8ad6acafac902d6f11da2e6633ca633f0849
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

RUN apk add --upgrade git=2.47.3-r0           # https://security.snyk.io/vuln/SNYK-ALPINE320-GIT-10669667
RUN apk add --upgrade sqlite=3.48.0-r4        # https://security.snyk.io/vuln/SNYK-ALPINE321-SQLITE-11191066
RUN apk add --upgrade sqlite-libs=3.48.0-r4   # https://security.snyk.io/vuln/SNYK-ALPINE321-SQLITE-11191066
RUN apk upgrade libcrypto3 libssl3            # https://security.snyk.io/vuln/SNYK-ALPINE322-OPENSSL-13174133

RUN gem install --no-document 'concurrent-ruby'

WORKDIR /runner/source
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/source/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/source/config/up.sh" ]
