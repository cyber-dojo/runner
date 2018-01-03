FROM  docker:latest
LABEL maintainer=jon@jaggersoft.com

# - - - - - - - - - - - - - - - -
# install ruby+
# tar is needed to tar-pipe test coverage out of tmpfs.
# - - - - - - - - - - - - - - - -

RUN apk --update --no-cache add \
    bash \
    ruby-bundler \
    ruby-dev \
    tar

# - - - - - - - - - - - - - - - -
# install ruby gems
# - - - - - - - - - - - - - - - -

ARG            CYBER_DOJO_RUNNER_HOME
COPY Gemfile ${CYBER_DOJO_RUNNER_HOME}/
WORKDIR      ${CYBER_DOJO_RUNNER_HOME}

RUN apk --update add --virtual build-dependencies build-base \
  && bundle config --global silence_root_warning 1 \
  && bundle install \
  && gem clean \
  && apk del build-dependencies build-base \
  && rm -vrf /var/cache/apk/*

# - - - - - - - - - - - - - - - -
# setup client
# - - - - - - - - - - - - - - - -

COPY . ${CYBER_DOJO_RUNNER_HOME}

ARG PORT
EXPOSE ${PORT}
ENV PORT=${PORT}

CMD [ "./up.sh" ]
