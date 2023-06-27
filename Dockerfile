FROM cyberdojo/docker-base:c11ff5f
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

WORKDIR /runner
COPY . .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/code/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/code/config/up.sh" ]
