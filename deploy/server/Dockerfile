FROM lscr.io/linuxserver/baseimage-kasmvnc:debianbookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      wget ca-certificates \
      libnss3 libgbm1 libasound2 libgtk-3-0 libxss1 libxshmfence1 \
      fonts-liberation xdg-utils && \
    wget -O /tmp/browseros.deb https://cdn.browseros.com/download/BrowserOS.deb && \
    apt-get install -y /tmp/browseros.deb && \
    rm /tmp/browseros.deb && \
    rm -rf /var/lib/apt/lists/*

RUN echo "=== Installed browseros files ===" && \
    dpkg -L browseros 2>/dev/null | grep -E '/(bin|opt)/' | head -20 || true

COPY autostart /defaults/autostart
RUN chmod +x /defaults/autostart

EXPOSE 3000 9100 9000
