FROM node:10-alpine

# enable node_modules caching layer
RUN apk add --no-cache tini git
ADD package.json /tmp/package.json
ADD package-lock.json /tmp/package-lock.json
RUN cd /tmp && npm install
RUN mkdir -p /opt/app && cp -a /tmp/node_modules /opt/app

# set work dir
WORKDIR /opt/app
ADD . /opt/app
RUN cd /opt/app

# add tini for PID 1 handling
ENTRYPOINT ["/sbin/tini", "--"]

# NodeJS launch
USER node
ENV NODE_ENV production
CMD ["/bin/sh", "/opt/app/entrypoint.sh"]