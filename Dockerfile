FROM cyberdojo/docker-base:8bdc8d4@sha256:5f648cc4380bbf30aa1bf0e3fe1bc6660993ecb12081fd1d250178bf9dff6af2
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

RUN gem install --no-document 'concurrent-ruby'

WORKDIR /runner/source
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/source/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/source/config/up.sh" ]
