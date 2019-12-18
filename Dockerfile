FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

WORKDIR /app
COPY . .

ARG COMMIT_SHA
ENV SHA=${COMMIT_SHA}

EXPOSE 4597
CMD [ "./up.sh" ]
