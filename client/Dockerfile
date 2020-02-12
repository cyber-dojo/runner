FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG CYBER_DOJO_RUNNER_DEMO_PORT
ENV PORT=${CYBER_DOJO_RUNNER_DEMO_PORT}
EXPOSE ${PORT}

CMD [ "./up.sh" ]
