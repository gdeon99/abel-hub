# abel-hub — kelola banyak mesin Ubuntu NAT dari 1 web/HP

Container "hub" buat ngatur beberapa mesin Ubuntu yang **gak punya IP public** (di balik NAT),
diakses dari mana aja (browser/HP) lewat **web terminal**. Di-host di **Railway**, pintunya
pakai **Cloudflare Tunnel**. Mesin "nelpon keluar" ke hub (pakai `frp`), jadi NAT bukan masalah.

```
  HP/Browser ──HTTPS──► Cloudflare ──► [ HUB di Railway ]
                                        cloudflared + sshwifty(web) + frps + sshd
                                              ▲ reverse tunnel (frpc)
                                   ┌──────────┼──────────┐
                                Mesin1     Mesin2     Mesin3   ← Ubuntu NAT
```

---

## 🚀 Colok mesin — CUKUP 1 BARIS

Jalanin di **tiap mesin** yang mau dikelola (auto-cari port sendiri: mesin pertama jadi
"Mesin 1", kedua "Mesin 2", dst):

```bash
curl -fsSL https://raw.githubusercontent.com/gdeon99/abel-hub/main/connect.sh | bash -s -- <FRP_TOKEN>
```

Ganti `<FRP_TOKEN>` dengan token frp kamu. Login default **`root` / `root`** (diset otomatis),
lalu buka web → klik "Mesin N" → masuk. Mau password lain? `... | ABEL_ROOT_PASS=xxx bash -s -- <FRP_TOKEN>`.

Script-nya **pintar**:
- 🔎 auto-deteksi port kosong di hub (7001/7002/7003/...)
- 🔁 idempotent (di-run ulang aman, gak dobel)
- 🛡️ retry download, klasifikasi error, reload sshd tanpa mutusin sesi
- ♻️ self-healing (frpc mati → nyala lagi; reboot → nyala lagi)
- 🖥️ auto-`tmux` (session gak mati walau koneksi putus)

> Server/port default sudah ditanam. Override kalau perlu:
> `... | bash -s -- <FRP_TOKEN> <host-tcp-proxy> <port>`

---

## Isi container (hub)

| Komponen | Gunanya |
|------|---------|
| `cloudflared` 2026.6.1 | pintu masuk dari Cloudflare ke container (mode token) |
| `sshwifty` 0.4.7 | web terminal (SSH client di browser), port 8182 |
| `frps` 0.69.1 | hub reverse-tunnel; mesin konek lewat sini (port 7000) |
| `openssh-server` | sshd lokal — target login |
| `supervisor` + `tini` | jalanin semua proses sekaligus, rapi |
| `tmux` | session persistent (auto-attach) |
| neofetch, figlet, lolcat | banner panel datacenter saat masuk shell |

## Environment variables (di Railway)

| Variable | Gunanya | Default |
|----------|---------|---------|
| `CF_TUNNEL_TOKEN` | token Cloudflare Tunnel (kosongkan = tes lokal, cloudflared skip) | (kosong) |
| `SSHWIFTY_SHAREDKEY` | password buka halaman web terminal | `changeme` |
| `SSH_PASSWORD` | password login user `app` di hub | `changeme` |
| `FRP_TOKEN` | token rahasia frps (**wajib kuat!**) | `changeme` |
| `MACHINE_USER` | user default login mesin di preset | `ubuntu` |

## Build & tes lokal

```bash
docker build -t base:latest .
docker run --rm -p 8182:8182 -e SSHWIFTY_SHAREDKEY=rahasia -e SSH_PASSWORD=rahasia base:latest
# buka http://localhost:8182 → SharedKey → klik "Hub" → login app/rahasia
```

## Deploy ke Railway (tanpa GitHub repo)

```bash
railway login
railway init
railway up
# set Variables: CF_TUNNEL_TOKEN, SSHWIFTY_SHAREDKEY, SSH_PASSWORD, FRP_TOKEN
railway tcp-proxy create --port 7000     # endpoint buat mesin nyetor diri
```
Di Cloudflare Zero Trust → Tunnels: arahkan `panel.domain-kamu.com` → `http://localhost:8182`.

## File

| File | Isi |
|------|-----|
| `Dockerfile` | image hub (debian-slim + semua tools) |
| `start.sh` | entrypoint: siapin sshd/config + jalanin supervisor |
| `supervisord.conf` | definisi proses (sshd, frps, sshwifty) |
| `welcome.sh` | banner panel datacenter |
| `connect.sh` | **colok mesin 1-baris** (auto-port, anti-error) |
| `setup-mesin.sh` | versi script colok mesin (argumen manual) |
| `.env.example` | contoh environment variables |

---

Dibikin bareng Claude. Token/password **jangan** di-commit ke repo (semua lewat env/argumen).
