FROM cyberdojo/docker-base:0ce6666@sha256:3e2248e992f75cbdfcc302f157497364f81849d57d55d21590763dcb2f627911
LABEL maintainer=jon@jaggersoft.com

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

WORKDIR /runner
COPY . .
USER nobody
HEALTHCHECK --interval=1s --timeout=1s --retries=5 --start-period=5s CMD /runner/config/healthcheck.sh
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD [ "/runner/config/up.sh" ]
