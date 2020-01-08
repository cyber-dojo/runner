FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_PORT
ENV PORT=${CYBER_DOJO_RUNNER_PORT}
EXPOSE ${PORT}

CMD [ "/app/up.sh" ]
