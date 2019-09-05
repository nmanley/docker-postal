FROM ubuntu:16.04

WORKDIR /

RUN apt-get update && apt-get install -y --no-install-recommend \
        software-properties-common

RUN apt-add-repository ppa:brightbox/ruby-ng -y
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

RUN export DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        cron \
        curl \
        ruby2.3 \
        ruby2.3-dev \
        build-essential \
        libmysqlclient-dev \
        wget \
        git \
        nano \
        zip \
        unzip \
        nodejs \
        nginx \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
        && rm -rf /var/lib/apt/lists/* \
        && rm /etc/cron.daily/*

RUN gem install bundler procodile --no-rdoc --no-ri
RUN useradd -r -m -d /opt/postal -s /bin/bash postal
RUN setcap 'cap_net_bind_server=+ep' /usr/bin/ruby2.3

# Persist Docker Volume
VOLUME /opt/postal

# Postal Vars
ENV POSTAL_DOMAIN mail.example.com
ENV POSTAL_NAME postal-mta

# Connection to database container.
ENV DB_HOSTNAME database:3306
ENV DB_USERNAME postal
ENV DB_PASSWORD postal
ENV DB_DATABASE postal
ENV DB_PREFIX   pos_

# RabbitMQ ENV
ENV RABBITMQ_USERNAME postal
ENV RABBITMQ_PASSWORD p0stalpassw0rd
ENV RABBITMQ_HOST     rabbitmq
ENV RABBITMQ_PORT     5672

RUN curl -o postal.zip -SL https://github.com/nmanley/postal/archive/master.zip \
        && sudo -i -u postal mkdir -p /opt/postal/app \
        && unzip postal.zip -d /opt/postal/app \
        && rm postal.zip \
        && chown -R postal:postal /opt/postal/app

RUN ln -s /opt/postal/app/bin/postal /usr/bin/postal
RUN postal bundle /opt/postal/vendor/bundle \
        && postal initialize-config \
        && postal initialize \
        && postal start

RUN cp /opt/postal/app/resource/nginx.cfg /etc/nginx/sites-available/default \
        && mkdir /etc/nginx/ssl/ \
        && openssl req -x509 -newkey rsa:4096 -keyout /etc/nginx/ssl/postal.key -out /etc/nginx/ssl/postal.cert -days 365 -nodes -subj "/C=GB/ST=${POSTAL_NAME}/L=${POSTAL_NAME}/O=${POSTAL_NAME}/CN=${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}" \
        && nginx reload

COPY nginx.conf "/etc/nginx/sites-available/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}"
RUN sed -i "s/{http_v4_ip}/${HTTP_V4_IP}/" "/etc/nginx/sites-available/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}" \
        && sed -i "s/{http_v4_port}/${HTTP_V4_PORT}" "/etc/nginx/sites-available/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}" \
        && sed -i "s/{postal_subdomain}/${POSTAL_SUBDOMAIN}" "/etc/nginx/sites-available/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}" \
        && sed -i "s/{postal_domain}/${POSTAL_DOMAIN}" "/etc/nginx/sites-available/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}"
RUN ln -s "/etc/nginx/sites-available/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}" "/etc/nginx/sites-enabled/${POSTAL_SUBDOMAIN}.${POSTAL_DOMAIN}"

COPY docker-entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx -g 'daemon off;'"]

