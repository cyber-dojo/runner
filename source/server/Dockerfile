FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

RUN gem install --no-document 'concurrent-ruby'

COPY . /app

# Patch prometheus-client to avoid warnings
# warning: instance variable @all_labels_preset not initialized

RUN mv /app/metric.rb /usr/lib/ruby/gems/2.6.0/gems/prometheus-client-2.0.0/lib/prometheus/client/metric.rb

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

ARG CYBER_DOJO_RUNNER_PORT
ENV PORT=${CYBER_DOJO_RUNNER_PORT}
EXPOSE ${PORT}

CMD [ "/app/up.sh" ]
