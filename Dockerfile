FROM alpine

WORKDIR /app

COPY release/bin/linux_amd64/ /usr/local/bin/
COPY public /app/public
COPY templates /app/templates

ENV PORT=3000

EXPOSE 3000

CMD http-echo-server
