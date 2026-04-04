FROM cyberdojo/docker-base:8bdc8d4@sha256:5f648cc4380bbf30aa1bf0e3fe1bc6660993ecb12081fd1d250178bf9dff6af2
LABEL maintainer=jon@jaggersoft.com

ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

ARG APP_DIR=/runner
ENV APP_DIR=${APP_DIR}

WORKDIR ${APP_DIR}/source
COPY . .
USER nobody
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
