FROM cyberdojo/docker-base:93aaaee@sha256:676847afbea1f6463dc7bef6f5ea0cb080c01dd4157f5d33e76565fde22cb365
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
