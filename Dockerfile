FROM vdveldet/base-os

MAINTAINER vdvelde.t@gmail.com
LABEL Description="nginx 1.14.0 server + mod_security 3" \
      version="${VERSION}"

# Add Repo
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common && \
  DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx-mainline

#      root@71f45fa07a2b:/etc/nginx/modules-enabled# ls
#      50-mod-http-auth-pam.conf  50-mod-http-echo.conf   50-mod-http-geoip2.conf        50-mod-http-subs-filter.conf    50-mod-http-xslt-filter.conf  50-mod-ssl-ct.conf
#      50-mod-http-dav-ext.conf   50-mod-http-geoip.conf  50-mod-http-image-filter.conf  50-mod-http-upstream-fair.conf  50-mod-mail.conf              50-mod-stream.conf
#      root@1770120c9156:/# ls -l /etc/nginx/modules-enabled/
#total 0
#lrwxrwxrwx. 1 root root 57 Aug 16 14:45 50-mod-http-auth-pam.conf -> /usr/share/nginx/modules-available/mod-http-auth-pam.conf
#lrwxrwxrwx. 1 root root 56 Aug 16 14:45 50-mod-http-dav-ext.conf -> /usr/share/nginx/modules-available/mod-http-dav-ext.conf
#lrwxrwxrwx. 1 root root 53 Aug 16 14:45 50-mod-http-echo.conf -> /usr/share/nginx/modules-available/mod-http-echo.conf
#lrwxrwxrwx. 1 root root 54 Aug 16 14:45 50-mod-http-geoip.conf -> /usr/share/nginx/modules-available/mod-http-geoip.conf
#lrwxrwxrwx. 1 root root 55 Aug 16 14:45 50-mod-http-geoip2.conf -> /usr/share/nginx/modules-available/mod-http-geoip2.conf
#lrwxrwxrwx. 1 root root 61 Aug 16 14:45 50-mod-http-image-filter.conf -> /usr/share/nginx/modules-available/mod-http-image-filter.conf
#lrwxrwxrwx. 1 root root 60 Aug 16 14:45 50-mod-http-subs-filter.conf -> /usr/share/nginx/modules-available/mod-http-subs-filter.conf
#lrwxrwxrwx. 1 root root 62 Aug 16 14:45 50-mod-http-upstream-fair.conf -> /usr/share/nginx/modules-available/mod-http-upstream-fair.conf
#lrwxrwxrwx. 1 root root 60 Aug 16 14:45 50-mod-http-xslt-filter.conf -> /usr/share/nginx/modules-available/mod-http-xslt-filter.conf
#lrwxrwxrwx. 1 root root 48 Aug 16 14:45 50-mod-mail.conf -> /usr/share/nginx/modules-available/mod-mail.conf
#lrwxrwxrwx. 1 root root 50 Aug 16 14:45 50-mod-ssl-ct.conf -> /usr/share/nginx/modules-available/mod-ssl-ct.conf
#lrwxrwxrwx. 1 root root 50 Aug 16 14:45 50-mod-stream.conf -> /usr/share/nginx/modules-available/mod-stream.conf
# root@1770120c9156:/# cat  /usr/share/nginx/modules-available/mod-ssl-ct.conf
#load_module modules/ngx_ssl_ct_module.so;
#load_module modules/ngx_http_ssl_ct_module.so;
#root@1770120c9156:/#



RUN apt-get install -y nginx && rm /etc/nginx/sites-enabled/*
RUN apt-get install -y apt-utils autoconf automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev libyajl2 openssl libssl-dev libperl-dev libxslt-dev

RUN git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
RUN cd ModSecurity && \
  git submodule init && \
  git submodule update && \
  ./build.sh && \
  ./configure && \
  make && \
  make install && \
  cd ..

# Compile Connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

# Compile the module
RUN NGINX_VERSION=$(nginx -v 2>&1| awk -F "/" {'print $2'} | awk {'print $1'}) && \
  wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar zxvf nginx-${NGINX_VERSION}.tar.gz && \
  cd nginx-${NGINX_VERSION} && \
  ./configure --with-cc-opt='-g -O2 -fdebug-prefix-map=/build/nginx-RFWPEB/nginx-1.17.0=. -fstack-protector-strong -Wformat \
  -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -fPIC' \
  --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf \
  --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid \
  --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  --with-debug --with-pcre-jit \
  --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module \
  --with-http_auth_request_module --with-http_v2_module --with-http_dav_module --with-http_slice_module \
  --with-threads --with-http_addition_module --with-http_geoip_module=dynamic --with-http_gunzip_module \
  --with-http_gzip_static_module --with-http_sub_module --with-stream=dynamic --with-stream_ssl_module \
  --with-stream_ssl_preread_module --with-mail=dynamic --with-mail_ssl_module \
  --add-dynamic-module=../ModSecurity-nginx && \
  make modules && \
  mkdir -p  /usr/share/nginx/modules && \
  cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/ && \
  cd ..

# Remove Compile dir
RUN cd .. && rm -rf ModSecurity && rm -rf ModSecurity-nginx

RUN NGINX_VERSION=$(nginx -v 2>&1| awk -F "/" {'print $2'}  | awk {'print $1'} ) && \
  rm -rf nginx-${NGINX_VERSION} && \
  rm -f nginx-${NGINX_VERSION}.gz

#Shrinking the image with packages not needed.
RUN apt-get remove -y  autoconf-archive gnu-standards autoconf-doc gettext binutils-doc cpp-doc \
  gcc-7-locales dbus-user-session libpam-systemd pinentry-gnome3 tor \
  debian-keyring g++-multilib g++-7-multilib gcc-7-doc libstdc++6-7-dbg \
  gcc-multilib flex bison gdb gcc-doc gcc-7-multilib libgcc1-dbg libgomp1-dbg \
  libitm1-dbg libatomic1-dbg libasan4-dbg liblsan0-dbg libtsan0-dbg \
  libubsan0-dbg libcilkrts5-dbg libmpx2-dbg libquadmath0-dbg parcimonie \
  xloadimage scdaemon glibc-doc libcurl4-doc libidn11-dev libkrb5-dev \
  libldap2-dev librtmp-dev libssh2-1-dev libssl-dev bzr libglib2.0-doc \
  libgraphite2-utils icu-doc libtool-doc libstdc++-7-doc gfortran \
  fortran95-compiler gcj-jdk man-browser pinentry-doc python3-doc python3-tk \
  python3-venv python3.6-venv python3.6-doc binfmt-support readline-doc \
  apt-utils autoconf automake autotools-dev binutils binutils-common \
  binutils-x86-64-linux-gnu build-essential cpp cpp-7 dirmngr dpkg-dev \
  fakeroot file g++ g++-7 gcc gcc-7 gcc-7-base geoip-bin gir1.2-glib-2.0 \
  gir1.2-harfbuzz-0.0 gnupg gnupg-l10n gnupg-utils gpg gpg-agent \
  gpg-wks-client gpg-wks-server gpgconf gpgsm icu-devtools \
  libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl \
  libapt-inst2.0 libasan4 libassuan0 libatomic1 libbinutils libc-dev-bin \
  libc6-dev libcc1-0 libcilkrts5 libcurl4-openssl-dev libdpkg-perl libfakeroot \
  libfile-fcntllock-perl libgcc-7-dev libgeoip-dev libgirepository-1.0-1 \
  libglib2.0-0 libglib2.0-bin libglib2.0-data libglib2.0-dev \
  libglib2.0-dev-bin libgomp1 libgraphite2-3 libgraphite2-dev libharfbuzz-dev \
  libharfbuzz-gobject0 libharfbuzz-icu0 libharfbuzz0b libicu-dev \
  libicu-le-hb-dev libicu-le-hb0 libiculx60 libisl19 libitm1 libksba8 \
  liblmdb-dev liblmdb0 liblocale-gettext-perl liblsan0 libltdl-dev libltdl7 \
  libmagic-mgc libmagic1 libmpc3 libmpdec2 libmpfr6 libmpx2 libnpth0 \
  libpcre++-dev libpcre++0v5 libpcre16-3 libpcre3-dev libpcre32-3 \
  libpcrecpp0v5 libpython3-stdlib libpython3.6-minimal libpython3.6-stdlib \
  libquadmath0 libreadline7 libstdc++-7-dev libtool libtsan0 libubsan0 \
  libxml2-dev libyajl-dev linux-libc-dev lmdb-doc manpages \
  manpages-dev mime-support pinentry-curses pkgconf python3 python3-distutils \
  python3-lib2to3 python3-minimal python3.6 python3.6-minimal readline-common \
  shared-mime-info xdg-user-dirs xz-utils zlib1g-dev apt-utils autoconf  \
  automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev \
  libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev gcc make mc

RUN apt -y autoremove

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

CMD service nginx start
