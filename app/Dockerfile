FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

EXPOSE 4597
CMD [ "/app/up.sh" ]
