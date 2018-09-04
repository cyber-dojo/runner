FROM  cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

# - - - - - - - - - - - - - - - -
# setup server
# - - - - - - - - - - - - - - - -

ARG RUNNER_STATELESS_HOME=/app
COPY . ${RUNNER_STATELESS_HOME}

# - - - - - - - - - - - - - - - - -
# git commit sha image is built from
# - - - - - - - - - - - - - - - - -

ARG SHA
RUN echo ${SHA} > ${RUNNER_STATELESS_HOME}/sha.txt

EXPOSE 4597
CMD [ "./up.sh" ]
