FROM cyberdojo/docker-base
LABEL maintainer=jon@jaggersoft.com
COPY . /app
EXPOSE 4597
CMD [ "./up.sh" ]
