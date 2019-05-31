# ---- Build container
#
FROM golang:1.11 AS build

WORKDIR /go/src/app
COPY . .
RUN go install -v ./...

# ---- Runtime container
#
FROM alpine

WORKDIR /app

COPY --from=build /go/bin/app /app/http-echo-server

COPY public /app/public
COPY templates /app/templates

ENV PORT=3000

EXPOSE 3000

CMD http-echo-server
