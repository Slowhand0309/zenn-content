FROM node:20.10.0-alpine

RUN apk update && \
    apk --no-cache add git vim