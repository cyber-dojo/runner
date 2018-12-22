FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

WORKDIR /app
COPY . .

ARG SHA
ENV SHA=${SHA}

EXPOSE 4597
CMD [ "./up.sh" ]
