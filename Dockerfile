FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com

COPY . /app

ARG SHA
ENV SHA=${SHA}

EXPOSE 4597
CMD [ "./up.sh" ]
