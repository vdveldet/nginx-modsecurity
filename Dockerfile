FROM ubuntu:bionic

ARG VERSION
ARG NGINX_VERSION
ARG NGINX_FULL_VERSION
ARG MODSECURITY
ARG MODSECURITY_RELEASE

ENV VERSION $VERSION
ENV NGINX_VERSION $NGINX_VERSION
ENV NGINX_FULL_VERSION $NGINX_FULL_VERSION
ENV MODSECURITY $MODSECURITY
ENV MODSECURITY_RELEASE $MODSECURITY_RELEASE

MAINTAINER vdvelde.t@gmail.com
LABEL Description="nginx 1.17.3 server + mod_security 3" \
      version="${VERSION}"

# Add default timezone
ENV LYBERTEAM_TIME_ZONE Europe/Brussels
RUN echo $LYBERTEAM_TIME_ZONE > /etc/timezone

# Modify user to group
RUN usermod -aG www-data www-data


# Install additional packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  tzdata \
  curl \
  libyajl2 \
  openssl \
  sendmail && \
  DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common && \
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive tzdata && \
  DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx-mainline

# Download nginx Compiled version
RUN apt-get install -y nginx=${NGINX_FULL_VERSION}

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
  ln -sf /dev/stderr /var/log/nginx/error.log && \
  ln -sf /dev/stdout /var/log/modsec_audit.log

# Copy in compiled packages
COPY deb/* /tmp/

# Copy Nginx-modsecurity module to the modules directory
RUN mv /tmp/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

# Install the package
RUN dpkg -i /tmp/modsecurity_${MODSECURITY}-${MODSECURITY_RELEASE}_amd64.deb &&  apt-get install -f && apt -y autoremove



# Configure mod ModSecurity
RUN mkdir -p /etc/nginx/modsec/
RUN  cd /etc/nginx/modsec && \
  curl -O https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended && \
  mv modsecurity.conf-recommended modsecurity.conf && \
  sed -i -e 's/worker_processes auto;/worker_processes 1;/g' /etc/nginx/nginx.conf && \
  sed -i -e 's/SecRuleEngine DetectionOnly/SecRuleEngine On/g' /etc/nginx/modsec/modsecurity.conf && \
  sed -i -e 's/SecAuditEngine RelevantOnly/SecAuditEngine off/g' /etc/nginx/modsec/modsecurity.conf


# PATCH Mod security installation
RUN cd /etc/nginx/modsec/ && \
  curl -O https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping

COPY nginx/nginx/10-mod-modsecurity.conf /etc/nginx/modules-enabled/
COPY nginx/modsec/main.conf /etc/nginx/modsec/

COPY nginx/nginx/default.conf /etc/nginx/conf.d/
COPY nginx/nginx/nginx.conf /etc/nginx/nginx.conf

RUN echo "daemon off;" >> /etc/nginx/nginx.conf

CMD /usr/sbin/nginx
