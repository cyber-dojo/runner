FROM cyberdojo/rack-base:2e387b6
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_CLIENT_PORT
ENV PORT=${CYBER_DOJO_RUNNER_CLIENT_PORT}
EXPOSE ${PORT}

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/app/up.sh" ]
