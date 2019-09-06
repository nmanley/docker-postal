# Minimal Ubuntu
FROM phusion/baseimage:0.9.19

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Adding ruby's repo
RUN apt-add-repository ppa:brightbox/ruby-ng -y
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

# Installing some warez
RUN apt update && apt install -y --no-install-recommends software-properties-common build-essential
RUN apt update && apt install -y --no-install-recommends \
        cron \
        curl \
        git \
        ruby2.3 \
        ruby2.3-dev \
        libmysqlclient-dev \
        unzip \
        nano \
        nodejs \
        nginx

# Installing procodile
RUN gem install bundler procodile --no-rdoc --no-ri

# Adding postal user
RUN useradd -r -m -d /opt/postal -s /bin/bash postal

ENV POSTAL_DOMAIN postal.example.com
ENV POSTAL_PROTO https
ENV FASTSERVER_ENABLED false
ENV FASTSERVER_BIND_ADDRESS 127.0.0.1
ENV USE_IP_POOLS false
ENV APP_FROM_NAME "App PostMaster"
ENV APP_FROM_EMAIL postmaster@${POSTAL_DOMAIN}

# Database vars
ENV DB_HOSTNAME database
ENV DB_PORT 3306
ENV DB_USERNAME postal
ENV DB_PASSWORD postal
ENV DB_DATABASE postal

# Message DB
ENV MSG_DB_HOSTNAME database
ENV MSG_DB_PORT 3306
ENV MSG_DB_USERNAME postal
ENV MSG_DB_PASSWORD postal
ENV MSG_DB_PREFIX postal

# RabbitMQ ENV
ENV RABBITMQ_USERNAME postal
ENV RABBITMQ_PASSWORD p0stalpassw0rd
ENV RABBITMQ_HOST rabbitmq
ENV RABBITMQ_PORT 5672
ENV RABBITMQ_VHOST //rabbitmq

# Workers
ENV APP_WORKERS 1
ENV APP_THREADS 4

# SMTP Server
ENV SMTP_PORT 2525

# SpamD
ENV SPAMD_ENABLED false
ENV SPAMD_HOST 127.0.0.1
ENV SPAMD_PORT 783

# ClamAV
ENV CLAMAV_ENABLED false
ENV CLAMAV_HOST 127.0.0.1
ENV CLAMAV_PORT 2000

RUN mkdir -p /opt/postal/app \
        && git clone https://github.com/nmanley/postal /opt/postal/app \
        && chown -R postal:postal /opt/postal/app

# Writing config to postal.example.yml \
RUN sed -i "s,{POSTAL_DOMAIN},${POSTAL_DOMAIN}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{POSTAL_PROTO},${POSTAL_PROTO}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{FASTSERVER_ENABLED},${FASTSERVER_ENABLED}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{FASTSERVER_BIND_ADDRESS},${FASTSERVER_BIND_ADDRESS}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{USE_IP_POOLS},${USE_IP_POOLS}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{DB_HOSTNAME},${DB_HOSTNAME}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{DB_PORT},${DB_PORT}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{DB_USERNAME},${DB_USERNAME}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{DB_PASSWORD},${DB_PASSWORD}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{DB_DATABASE},${DB_DATABASE}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{MSG_DB_HOST},${MSG_DB_HOST}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{MSG_DB_PORT},${MSG_DB_PORT}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{MSG_DB_USERNAME},${MSG_DB_USERNAME}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{MSG_DB_PASSWORD},${MSG_DB_PASSWORD}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{MSG_DB_PREFIX},${MSG_DB_PREFIX}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{RABBITMQ_HOST},${RABBITMQ_HOST}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{RABBITMQ_USERNAME},${RABBITMQ_USERNAME}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{RABBITMQ_PASSWORD},${RABBITMQ_PASSWORD}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{RABBITMQ_VHOST},${RABBITMQ_VHOST}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{SMTP_HOST},${SMTP_HOST}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{SMTP_PORT},${SMTP_PORT}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{APP_FROM_NAME},${APP_FROM_NAME}," /opt/postal/app/config/postal.example.yml \
        && sed -i "s,{APP_FROM_EMAIL},${APP_FROM_EMAIL}," /opt/postal/app/config/postal.example.yml

RUN cat /opt/postal/app/config/postal.example.yml

RUN ln -s /opt/postal/app/bin/postal /usr/bin/postal
RUN postal bundle /opt/postal/vendor/bundle \
        && postal initialize-config \
        && postal initialize \
        && postal start

RUN cp /opt/postal/app/resource/nginx.cfg /etc/nginx/sites-available/default \
        && mkdir -p /etc/nginx/ssl/ \
        && openssl req -x509 -newkey rsa:4096 -keyout /etc/nginx/ssl/postal.key -out /etc/nginx/ssl/postal.cert -days 365 -nodes -subj "/C=GB/ST=${APP_NAME}/L=${APP_NAME}/O=${APP_NAME}/CN=${POSTAL_SERVER_SUBDOMAIN}.${POSTAL_DOMAIN}" \
        && nginx -s reload
RUN ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

COPY docker-entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx -g 'daemon off;'"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


