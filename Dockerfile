FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

WORKDIR /app
COPY Gemfile .
RUN echo "gem: --no-rdoc --no-ri" > ~/.gemrc \
  && bundle install
COPY . .

ARG SHA
ENV SHA=${SHA}

EXPOSE 4597
CMD [ "./up.sh" ]
