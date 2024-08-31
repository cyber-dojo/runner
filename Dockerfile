ARG BASE_IMAGE=cyberdojo/docker-base:c852959
FROM ${BASE_IMAGE}
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

RUN apk add curl # https://security.snyk.io/vuln/SNYK-ALPINE320-CURL-7838598

WORKDIR /runner
COPY . .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

# ARGs are reset after FROM See https://github.com/moby/moby/issues/34129
ARG BASE_IMAGE
ENV BASE_IMAGE=${BASE_IMAGE}

USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/code/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/code/config/up.sh" ]
