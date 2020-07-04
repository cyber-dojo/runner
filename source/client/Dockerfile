FROM cyberdojo/rack-base:2e387b6
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG CYBER_DOJO_RUNNER_DEMO_PORT
ENV PORT=${CYBER_DOJO_RUNNER_DEMO_PORT}
EXPOSE ${PORT}

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/app/up.sh" ]
