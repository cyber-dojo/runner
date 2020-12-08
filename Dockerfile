FROM cyberdojo/docker-base:65ce57e
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

WORKDIR /runner
COPY . .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_PORT
ENV PORT=${CYBER_DOJO_RUNNER_PORT}

EXPOSE ${PORT}
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/code/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/code/config/up.sh" ]
