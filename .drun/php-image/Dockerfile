# Runtime image for a php-backports build.
#
# The build context is the install prefix that .drun/scripts/build-php-image.sh
# produced on the same architecture, so this file adds only the shared
# libraries the binary links against plus the labels. Nothing is compiled here.
#
# The base matches the build image. That is what keeps the C library and the
# OpenSSL ABI identical to the environment the test suite ran in. Bullseye is
# past end of life, so apt points at the archive mirror, exactly as the build
# image does.
ARG BASE_IMAGE=debian:bullseye-slim
FROM ${BASE_IMAGE}

ARG PHP_SERIES=unknown
ARG PHP_VERSION=unknown
ARG SOURCE_REVISION=unknown

ENV DEBIAN_FRONTEND=noninteractive

RUN if . /etc/os-release && [ "${VERSION_CODENAME}" = "bullseye" ]; then \
        rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*; \
        printf '%s\n' \
            'deb [check-valid-until=no] http://archive.debian.org/debian bullseye main' \
            'deb [check-valid-until=no] http://archive.debian.org/debian bullseye-updates main' \
            'deb [check-valid-until=no] http://archive.debian.org/debian-security bullseye-security main' \
            > /etc/apt/sources.list; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libargon2-1 \
        libbz2-1.0 \
        libcurl4 \
        libedit2 \
        libgmp10 \
        libicu67 \
        libjpeg62-turbo \
        libldap-2.4-2 \
        libonig5 \
        libpng16-16 \
        libpq5 \
        libreadline8 \
        libsasl2-2 \
        libsodium23 \
        libsqlite3-0 \
        libssl1.1 \
        libtidy5deb1 \
        libwebp6 \
        libxml2 \
        libxslt1.1 \
        libzip4 \
        libzstd1 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY usr/local/ /usr/local/

ENV PATH=/usr/local/bin:$PATH

# Fail the build if the binary cannot start, if a module fails to load, or if
# the tree is not the version the tag claims. The -v output also records what
# the identity patch currently reports.
RUN set -eux; \
    php -v 2>&1 | tee /tmp/php-v.txt; \
    ! grep -qi 'unable to load' /tmp/php-v.txt; \
    php -m; \
    test "$(php -r 'echo PHP_VERSION;')" = "${PHP_VERSION}"

LABEL org.opencontainers.image.title="php-backports" \
      org.opencontainers.image.description="Phillarmonic security backport of PHP ${PHP_SERIES}. Not an official PHP release." \
      org.opencontainers.image.source="https://github.com/phillarmonic/php-backports" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.version="${PHP_VERSION}" \
      org.opencontainers.image.licenses="BSD-3-Clause"

# The CLI is the only SAPI built. Keep it interactive by default, the same
# shape the official php-cli image has.
CMD ["php", "-a"]
