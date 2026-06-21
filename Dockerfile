# syntax=docker/dockerfile:1
###############################################################################
#  BASE IMAGE  —  debian bookworm-slim + tools dasar                          #
#  ----------------------------------------------------------------------     #
#  Ini "fondasi" container. Ringan tapi kompatibel (glibc, sekeluarga Ubuntu).#
#  Layer aplikasi (cloudflared / frps / web-terminal) ditambah DI ATAS ini.   #
###############################################################################
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="base" \
      org.opencontainers.image.description="Base image: debian slim + tools dasar untuk hub tunnel / web terminal" \
      maintainer="abelLabs"

# Cegah prompt interaktif saat apt + set timezone & locale
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Jakarta \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# 1) update daftar paket  2) upgrade paket ke versi terbaru
# 3) pasang tools dasar    4) bersihkan cache biar image tetap kecil
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      openssh-client \
      supervisor \
      tzdata \
      bash \
      nano \
      less \
      procps \
      iproute2 \
      neofetch \
      figlet \
      lolcat \
      ncurses-bin \
      openssh-server \
      tmux \
      tini \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

###############################################################################
#  LAYER APLIKASI  —  cloudflared (tunnel) + sshwifty (web terminal)          #
###############################################################################

# cloudflared 2026.6.1 — pintu masuk dari Cloudflare ke container (mode token)
RUN curl -fsSL -o /usr/local/bin/cloudflared \
      https://github.com/cloudflare/cloudflared/releases/download/2026.6.1/cloudflared-linux-amd64 \
 && chmod +x /usr/local/bin/cloudflared

# sshwifty 0.4.7 — web terminal (SSH client di browser)
RUN curl -fsSL -o /tmp/sshwifty.tar.gz \
      https://github.com/nirui/sshwifty/releases/download/0.4.7-beta-release-prebuild/sshwifty_0.4.7-beta-release_linux_amd64.tar.gz \
 && tar -xzf /tmp/sshwifty.tar.gz -C /tmp \
 && mv /tmp/sshwifty_linux_amd64 /usr/local/bin/sshwifty \
 && chmod +x /usr/local/bin/sshwifty \
 && rm -rf /tmp/sshwifty.tar.gz /tmp/DEPENDENCIES.md /tmp/GPG.asc /tmp/LICENSE.md /tmp/Note /tmp/README.md /tmp/SUM.sha512 /tmp/preset.example.json /tmp/src /tmp/sshwifty.conf.example.json

# frps 0.69.1 — server hub reverse-tunnel: tempat 3 mesin Ubuntu "nelpon masuk"
RUN curl -fsSL -o /tmp/frp.tar.gz \
      https://github.com/fatedier/frp/releases/download/v0.69.1/frp_0.69.1_linux_amd64.tar.gz \
 && tar -xzf /tmp/frp.tar.gz -C /tmp \
 && mv /tmp/frp_0.69.1_linux_amd64/frps /usr/local/bin/frps \
 && chmod +x /usr/local/bin/frps \
 && rm -rf /tmp/frp.tar.gz /tmp/frp_0.69.1_linux_amd64

# User non-root (praktik aman). Layer aplikasi boleh pakai user ini nanti.
RUN useradd --create-home --shell /bin/bash app

# Banner sambutan ala panel datacenter — tampil tiap masuk shell interaktif.
COPY welcome.sh /usr/local/bin/welcome
RUN chmod +x /usr/local/bin/welcome \
 && cat >> /etc/bash.bashrc <<'BASHRC'

# === abelLabs hub: shell interaktif ===
case $- in *i*)
  # 1) History langsung kesimpen tiap perintah (anti-ilang walau koneksi putus)
  export HISTSIZE=10000 HISTFILESIZE=20000
  export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
  # 2) Auto-attach tmux: session TETAP NYALA walau browser ditutup/mati
  if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ] && [ -t 1 ]; then
    exec tmux new-session -A -s main
  fi
  # 3) Banner panel datacenter (sekali per sesi, tampil DI DALAM tmux)
  [ -z "$ABEL_WELCOMED" ] && { /usr/local/bin/welcome; export ABEL_WELCOMED=1; }
  ;;
esac
BASHRC

# Konfigurasi supervisor (sshd + sshwifty; cloudflared ditambah dinamis oleh start.sh)
COPY supervisord.conf /etc/supervisor/conf.d/hub.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Port: 8182 = web sshwifty, 7000 = frps (mesin nelpon masuk)
EXPOSE 8182 7000

# tini = init kecil: rapikan sinyal (Ctrl-C) & zombie process di dalam container
ENTRYPOINT ["/usr/bin/tini", "--"]

# start.sh: siapin password/sshd/config lalu jalanin supervisor (semua proses)
CMD ["/usr/local/bin/start.sh"]
