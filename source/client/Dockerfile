FROM cyberdojo/docker-base:d0da6ee
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG CYBER_DOJO_RUNNER_DEMO_PORT
ENV PORT=${CYBER_DOJO_RUNNER_DEMO_PORT}
EXPOSE ${PORT}

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/app/up.sh" ]
