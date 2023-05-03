ARG BASE_IMAGE
ARG VERSION=3.7.4

FROM ${BASE_IMAGE}

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
       apt-get install --no-install-recommends -y \
            apt-cacher-ng=${VERSION}* ca-certificates wget \
    && sed 's/# ForeGround: 0/ForeGround: 1/' \
            -i /etc/apt-cacher-ng/acng.conf \
    && sed 's/# PassThroughPattern:.*this would allow.*/PassThroughPattern: .* #/' \
            -i /etc/apt-cacher-ng/acng.conf \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

HEALTHCHECK --interval=10s --timeout=2s --retries=3 \
    CMD wget -q -t1 -O /dev/null  http://localhost:3142/acng-report.html || exit 1

EXPOSE 3142/tcp
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["/usr/sbin/apt-cacher-ng"]
