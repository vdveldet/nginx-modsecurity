FROM vdveldet/base-os

MAINTAINER vdvelde.t@gmail.com
LABEL Description="nginx ${NGINX_VERSION} server + mod_security ${MODSECURITY}" \
      version="${VERSION}"

# Add Repo
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common && \
  DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx-mainline

RUN apt-get install -y nginx && rm /etc/nginx/sites-enabled/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
  ln -sf /dev/stderr /var/log/nginx/error.log && \
  ln -sf /dev/stdout /var/log/modsec_audit.log

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
