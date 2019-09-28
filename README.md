# nginx-modsecurity

Build status (https://travis-ci.org/vdveldet/nginx-modsecurity.svg?branch=master)

NGINX server combined with security of ModSecurity available in a docker.

The docker is focused security, since compiling ModSecurity uses a lot of dependencies, you do not want in your front end docker...
Compilation is done in a separate compile docker.

The compiled modules are copied into the work container, containing only the basic functions and patches for the OS.
NGINX is used from the ppa:ondrej/nginx-mainline repository and not compiled for this project. NGINX has therefore a lot of features that can be used just as the normal version.

Current version :
  * Nginx Server 1.17.3
  * modsecurity 3.0.3
