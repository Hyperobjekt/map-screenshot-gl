FROM node:10.24.1-slim

ENV NODE_ENV="production"
# Debian Stretch is EOL, so its package repositories now live in the
# Debian archive rather than the normal mirrors.
RUN sed -i \
    -e 's|deb.debian.org/debian|archive.debian.org/debian|g' \
    -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' \
    /etc/apt/sources.list \
&& sed -i '/stretch-updates/d' /etc/apt/sources.list \
&& printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive \
&& apt-get -qq update \
&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
    apt-transport-https \
    curl \
    unzip \
    build-essential \
    python \
    libcairo2-dev \
    libgles2-mesa-dev \
    libgbm-dev \
    libllvm3.9 \
    libprotobuf-dev \
    libxxf86vm-dev \
    xvfb \
&& apt-get clean

RUN mkdir -p /usr/src/app
COPY /src /usr/src/app
RUN cd /usr/src/app && npm install --production
ENTRYPOINT ["/usr/src/app/run.sh"]
