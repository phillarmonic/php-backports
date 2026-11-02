# Build environment for the php-backports series.
#
# The base is the official PHP 8.1 CLI image on Debian bullseye:
#   - PHP 8.1 satisfies build/gen_stub.php's host PHP requirement.
#   - Debian bullseye carries OpenSSL 1.1.1, which PHP 7.4 and 8.0 still expect.
#   - bison 3.7 and re2c 2.0 satisfy every series from 5.6 to 8.1.
#
# Override the base for a different era:
#   docker build --build-arg BASE_IMAGE=php:8.3-cli-bookworm ...
ARG BASE_IMAGE=php:8.1-cli-bullseye
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# Debian bullseye reached end of life on 31 August 2026. Its security index
# still advertises package versions that have been deleted from the live pool,
# so apt fails with 404s on libssl1.1, tzdata, locales, and the rest. The
# archive mirror keeps the complete pool, so point a bullseye base at it. Any
# other base keeps its own sources.
#
# The Release files on the archive are years old, so Valid-Until has to be
# waived. That is a build image pinned to a frozen distribution, not a
# long-lived server.
RUN if . /etc/os-release && [ "${VERSION_CODENAME}" = "bullseye" ]; then \
        rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*; \
        printf '%s\n' \
            'deb [check-valid-until=no] http://archive.debian.org/debian bullseye main' \
            'deb [check-valid-until=no] http://archive.debian.org/debian bullseye-updates main' \
            'deb [check-valid-until=no] http://archive.debian.org/debian-security bullseye-security main' \
            > /etc/apt/sources.list; \
    fi

# The compiler, the parser generators PHP's build needs, and the development
# headers for the extensions the catalog touches: session, pgsql, phar, openssl,
# soap, ldap, filter, fpm, mysqlnd, sqlite, libxml, and the image formats.
#
# bullseye names the OpenLDAP package libldap2-dev, bookworm renamed it, so try
# both. Valgrind is optional: only the memory-safety work needs it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        bison \
        build-essential \
        ca-certificates \
        curl \
        default-libmysqlclient-dev \
        git \
        libargon2-dev \
        libbz2-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libffi-dev \
        libgmp-dev \
        libicu-dev \
        libjpeg-dev \
        libonig-dev \
        libpcre2-dev \
        libpng-dev \
        libpq-dev \
        libreadline-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libtidy-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        libzstd-dev \
        locales \
        make \
        pkg-config \
        procps \
        re2c \
        tzdata \
        unzip \
        xz-utils \
        zlib1g-dev \
    && { apt-get install -y --no-install-recommends libldap2-dev \
         || apt-get install -y --no-install-recommends libldap-dev; } \
    && if apt-cache show valgrind >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends valgrind; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# PHP 5.6 through 7.3 define YYERROR_VERBOSE in the parser prologue and expect
# bison to emit the yystrlen and yystpcpy helpers for it. Bison 3.6 reworked
# that mechanism, so 3.7 no longer generates them and the link fails with
# "undefined reference to yystrlen". Bison 3.3.2 is the last generator those
# branches were built against: keep it beside the default 3.7 and let the
# runner choose by branch. Nothing in the checked-out tree is patched.
RUN mkdir -p /opt/bison33 \
    && curl -fsSL -o /tmp/bison.deb \
        "http://archive.debian.org/debian/pool/main/b/bison/bison_3.3.2.dfsg-1_$(dpkg --print-architecture).deb" \
    && dpkg-deb -x /tmp/bison.deb /opt/bison33 \
    && rm -f /tmp/bison.deb \
    && /opt/bison33/usr/bin/bison --version | head -n 1

WORKDIR /src
RUN mkdir -p /build

CMD ["bash"]
