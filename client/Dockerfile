FROM  alpine:latest
LABEL maintainer=jon@jaggersoft.com

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 1. install ruby
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

RUN apk --update --no-cache add \
    openssl ca-certificates \
    ruby ruby-io-console ruby-dev ruby-irb ruby-bundler ruby-bigdecimal \
    bash tzdata

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 2. install tini (for pid 1 zombie reaping)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# https://github.com/krallin/tini
# https://blog.phusion.nl/2015/01/20/
#    docker-and-the-pid-1-zombie-reaping-problem/

RUN apk add --update --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ tini

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 3. install sinatra
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

RUN echo 'gem: --no-document' > ~/.gemrc
COPY Gemfile /app/
WORKDIR /app

RUN apk --update add --virtual build-dependencies build-base \
  && bundle install && gem clean \
  && apk del build-dependencies \
  && rm -vrf /var/cache/apk/*

RUN export RACK_ENV='production'

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 4. setup client
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

COPY . /app
ARG PORT
EXPOSE ${PORT}
ENV PORT=${PORT}

ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "./up.sh" ]


