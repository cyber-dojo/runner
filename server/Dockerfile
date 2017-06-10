FROM cyberdojo/docker
MAINTAINER Jon Jagger <jon@jaggersoft.com>

# Default Alpine tar does not support --owner/--group options
RUN apk --update add tar

WORKDIR /app

COPY . /app

ARG PORT
EXPOSE ${PORT}

ENV PORT=${PORT}
CMD [ "./up.sh" ]

