FROM cyberdojo/docker-base:7976545
LABEL maintainer=jon@jaggersoft.com

RUN apk add --no-cache tini
RUN gem install --no-document 'concurrent-ruby'

COPY . /app

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_PORT
ENV PORT=${CYBER_DOJO_RUNNER_PORT}
EXPOSE ${PORT}

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/app/up.sh" ]
