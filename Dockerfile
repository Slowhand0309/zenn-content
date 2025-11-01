FROM node:22.17.0-alpine

RUN apk update && \
    apk --no-cache add git vim