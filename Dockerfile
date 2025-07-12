FROM cyberdojo/docker-base:644342a@sha256:c7ab22f97b992690fe7e5ae92516176d727bc1232148ba1ac730e4d554f4a5ae
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
