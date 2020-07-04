FROM cyberdojo/docker-base:d0da6ee
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

COPY . /app

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_PORT
ENV PORT=${CYBER_DOJO_RUNNER_PORT}
EXPOSE ${PORT}

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/app/up.sh" ]
