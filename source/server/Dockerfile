FROM cyberdojo/docker-base:7976545
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

COPY . /app

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_PORT
ENV PORT=${CYBER_DOJO_RUNNER_PORT}
EXPOSE ${PORT}

CMD [ "/app/up.sh" ]
