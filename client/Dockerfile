FROM  cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

# - - - - - - - - - - - - - - - -
# setup client
# - - - - - - - - - - - - - - - -

ARG RUNNER_STATELESS_HOME=/app
COPY . ${RUNNER_STATELESS_HOME}

EXPOSE 4598
CMD [ "./up.sh" ]
