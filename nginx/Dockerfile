FROM nginx:latest

ARG BASIC_AUTH_USER=admin

ARG BASIC_AUTH_PASS=admin

RUN apt-get update && apt-get install -y apache2-utils

RUN htpasswd -cb /etc/nginx/.htpasswd $BASIC_AUTH_USER $BASIC_AUTH_PASS

COPY default.conf /etc/nginx/conf.d/default.conf
