FROM cyberdojo/rack-base:2e387b6
LABEL maintainer=jon@jaggersoft.com

WORKDIR /app
COPY . .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_CLIENT_PORT
ENV PORT=${CYBER_DOJO_RUNNER_CLIENT_PORT}

EXPOSE ${PORT}
USER nobody
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/app/config/up.sh" ]
