FROM cyberdojo/docker-base:909ba1d@sha256:20ac5af0c95cd148ad9acba9ca8da9c9145d6df478f40cccac52042aa071427f
LABEL maintainer=jon@jaggersoft.com

ARG APP_DIR=/runner
ENV APP_DIR=${APP_DIR}

WORKDIR ${APP_DIR}/source
COPY . .
USER nobody
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD ./config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "./config/up.sh" ]
