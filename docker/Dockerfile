# Build-time variables. Declared here, before the first FROM, so they're in
# global scope; each stage below re-declares (bare, no value) whichever ones
# it needs, since ARG values don't otherwise carry across a
# `FROM <previous-stage> AS ...` transition.
ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=20
ARG PYTHON_VERSION=3.9
ARG RELEASE_CODENAME=jammy
ARG WORKDIR=/webodm

FROM ubuntu:22.04 AS common
LABEL maintainer="Piero Toffanin <pt@masseranolabs.com>"

ARG DEBIAN_FRONTEND
ARG NODE_MAJOR
ARG PYTHON_VERSION
ARG RELEASE_CODENAME
ARG WORKDIR

# Run-time variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=$WORKDIR
ENV PROJ_LIB=/usr/share/proj

#### Common setup ####

# Create and change into working directory
WORKDIR $WORKDIR

# Set timezone to UTC
RUN echo "UTC" > /etc/timezone

FROM common AS build

ARG NODE_MAJOR
ARG PYTHON_VERSION
ARG RELEASE_CODENAME
ARG WORKDIR

# Install Python deps -- install & remove cleanup build-only deps in the process
COPY requirements.txt ./

# Installs curl/gnupg/build tools, adds the deadsnakes (Python 3.9),
# NodeSource, and nginx.org apt repos, installs the rest of the build-time
# packages, then builds entwine from source. Chained into a single RUN
# (rather than BuildKit heredocs/cache mounts, which buildah's Dockerfile
# parser doesn't reliably support across versions) for Docker/Podman parity.
RUN apt-get -qq update && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg cmake g++ libpdal-dev && \
    curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf23c5a6cf475977595c89f51ba6932366a755776' | gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg && \
    echo "deb http://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $RELEASE_CODENAME main" > /etc/apt/sources.list.d/deadsnakes.list && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nodesource.gpg && \
    echo "deb https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nginx.gpg && \
    echo "deb https://nginx.org/packages/ubuntu $RELEASE_CODENAME nginx" > /etc/apt/sources.list.d/nginx.list && \
    printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx && \
    apt-get update && \
    apt-get -qq install -y nodejs && \
    apt-get install -y --no-install-recommends \
        python$PYTHON_VERSION python$PYTHON_VERSION-venv python$PYTHON_VERSION-distutils python$PYTHON_VERSION-dev libpq-dev build-essential git libproj-dev gdal-bin pdal \
        libgdal-dev nginx certbot gettext-base cron postgresql-client gettext tzdata && \
    python$PYTHON_VERSION -m venv $WORKDIR/venv && \
    mkdir /staging && cd /staging && \
    git clone -b 290 https://github.com/WebODM/entwine && cd entwine && \
    mkdir build && cd build && cmake .. -DWITH_TESTS=OFF -DWITH_ZSTD=OFF -DCMAKE_INSTALL_PREFIX=/staging/entwine/build/install && make -j6 && make install && \
    cd /webodm

# Modify PATH to prioritize venv, effectively activating venv
ENV PATH="$WORKDIR/venv/bin:$PATH"

# Install Python dependencies, including correct Python GDAL bindings
RUN pip install -U pip==26.0.1 setuptools==67.0.0 wheel==0.46.3 cython==3.2.4 && \
    pip install numpy==1.26.2 && \
    pip install -r requirements.txt "boto3==1.14.14" gdal[numpy]=="$(gdal-config --version).*" --no-build-isolation

# Install project Node dependencies
COPY package.json ./
RUN npm install --quiet && \
    npm install --quiet -g webpack@5.89.0 && \
    npm install --quiet -g webpack-cli@5.1.4

# Copy remaining files
COPY . ./

# Defining this here allows for caching of previous layers.
ARG TEST_BUILD

# Final build steps (in one roll to prevent too many layers)
RUN chmod 0644 ./nginx/crontab && \
    ln -s ./nginx/crontab /var/spool/cron/crontabs/root && \
    chmod +x ./nginx/letsencrypt-autogen.sh && \
    ./nodeodm/setup.sh && \
    ./nodeodm/cleanup.sh && \
    webpack --mode production && \
    python manage.py collectstatic --noinput && \
    python manage.py rebuildplugins && \
    python manage.py translate build --safe && \
    python /webodm/app/scripts/install_ffmpeg.py && \
    rm -rf /tmp/* /var/tmp/* && \
    rm /webodm/webodm/secret_key.py

FROM common AS app

ARG NODE_MAJOR
ARG PYTHON_VERSION
ARG RELEASE_CODENAME
ARG WORKDIR

# Modify PATH to prioritize venv, effectively activating venv
ENV PATH="$WORKDIR/venv/bin:$PATH"

# Run-time dependencies (incl. legacy Python support, NodeSource and
# nginx.org apt repos), webpack, then cleanup of build-only apt state.
RUN apt-get -qq update && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg && \
    curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf23c5a6cf475977595c89f51ba6932366a755776' | gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg && \
    echo "deb http://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $RELEASE_CODENAME main" > /etc/apt/sources.list.d/deadsnakes.list && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nodesource.gpg && \
    echo "deb https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nginx.gpg && \
    echo "deb https://nginx.org/packages/ubuntu $RELEASE_CODENAME nginx" > /etc/apt/sources.list.d/nginx.list && \
    printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx && \
    apt-get update && \
    apt-get -qq install -y nodejs && \
    apt-get install -y --no-install-recommends \
        python$PYTHON_VERSION python$PYTHON_VERSION-distutils gdal-bin pdal \
        nginx certbot logrotate gettext-base cron postgresql-client gettext tzdata git exiftool && \
    npm install --quiet -g webpack@5.89.0 && \
    npm install --quiet -g webpack-cli@5.1.4 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/*

COPY --from=build /staging/entwine/build/install/bin/entwine /usr/bin/entwine
COPY --from=build /staging/entwine/build/install/lib/libentwine* /usr/lib/
COPY --from=build /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build $WORKDIR ./

VOLUME /webodm/app/media
