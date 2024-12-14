FROM cyberdojo/docker-base:42bda08
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

WORKDIR /runner
COPY source/server/ .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
