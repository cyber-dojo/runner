FROM cyberdojo/docker-base:0ce6666@sha256:3e2248e992f75cbdfcc302f157497364f81849d57d55d21590763dcb2f627911
# The FROM statement above is typically set via an automated pull-request from the docker-base repo
LABEL maintainer=jon@jaggersoft.com

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

RUN gem install --no-document 'concurrent-ruby'
WORKDIR /runner
COPY source/server/ .
USER root
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
