FROM cyberdojo/docker-base:d0da6ee
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
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/app/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/app/config/up.sh" ]
