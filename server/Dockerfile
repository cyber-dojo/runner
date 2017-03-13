FROM cyberdojo/docker
MAINTAINER Jon Jagger <jon@jaggersoft.com>

# Default Alpine tar does not support --owner/--group options
RUN apk --update add tar

WORKDIR /app

RUN echo "gem 'prometheus-client'" >> /app/Gemfile
RUN apk --update add --virtual build-dependencies build-base \
  && bundle install && gem clean \
  && apk del build-dependencies \
  && rm -vrf /var/cache/apk/*

COPY . /app

ARG PORT
EXPOSE ${PORT}

ENV PORT=${PORT}
CMD [ "./up.sh" ]

