ARG BASE_IMAGE=always-provided
FROM ${BASE_IMAGE}
LABEL maintainer=jon@jaggersoft.com

RUN apk add --upgrade c-ares=1.34.5-r0   # https://security.snyk.io/vuln/SNYK-ALPINE321-CARES-9680227

# ARGs are reset after FROM See https://github.com/moby/moby/issues/34129
ARG BASE_IMAGE
ENV BASE_IMAGE=${BASE_IMAGE}

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

RUN gem install --no-document 'concurrent-ruby'
WORKDIR /runner
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
