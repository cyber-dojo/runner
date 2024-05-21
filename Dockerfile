ARG BASE_IMAGE=cyberdojo/docker-base:4e163c1
FROM ${BASE_IMAGE}
# Updating the base image, eg to reduce the entries in .snyk succeeds but then
# fails the snyk container scan (in .github/workflows/main.yml) with the error
# Invalid OCI archive
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

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
