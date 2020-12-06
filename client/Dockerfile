FROM cyberdojo/docker-base:d0da6ee
LABEL maintainer=jon@jaggersoft.com

WORKDIR /runner
COPY . .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_CLIENT_PORT
ENV PORT=${CYBER_DOJO_RUNNER_CLIENT_PORT}

EXPOSE ${PORT}
USER nobody
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
