FROM cyberdojo/docker-base:06c425c
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

RUN apk add git=2.47.2-r0  # https://security.snyk.io/vuln/SNYK-ALPINE321-GIT-8625653

WORKDIR /runner
COPY source/server/ .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
