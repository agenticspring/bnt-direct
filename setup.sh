#!/usr/bin/env bash
# bnt-direct — mining BNT simple, direct ke pool lama, tanpa relay.
#
# Pakai (sebagai root):
#   curl -L https://cdn.jsdelivr.net/gh/agenticspring/bnt-direct@main/setup.sh -o setup.sh
#   chmod +x setup.sh
#   ./setup.sh
#
# Script ini memasang miner dengan auto-restart, tetap paste-only:
# lapis 1 systemd (bnt-direct) kalau tersedia; lapis 2 cron
# (@reboot + cek tiap 5 menit) kalau tidak ada systemd tapi ada cron;
# lapis 3 background biasa (nohup) hanya kalau systemd dan cron
# sama-sama tidak tersedia, dan di lapis itu auto-restart tidak berlaku.
# Pool: bntpool.com:3333 (pool lama), direct, tanpa relay, tanpa allowlist.
# Wallet sudah tertanam langsung di bawah (wallet produksi Dez).
# Kalau script ini dipakai orang lain, ganti ADDRESS dulu sebelum jalan.
set -euo pipefail

POOL_URL="stratum+tcp://bntpool.com:3333"
ADDRESS="PLMGsifmTC9Zn5pHqcMkbayvzSG3SBX6vAwJts3KQCwfGRsznpv2qdyCFyRpnh46TwcQu8mLEu1CVdHdQzsx7Ty637GQc"
SEINE_VERSION="v0.2.21"
SEINE_URL="https://github.com/zpalmtree/seine/releases/download/${SEINE_VERSION}/seine-linux-x86_64.tar.gz"

[ "$(id -u)" = "0" ] || { echo "ERROR: jalankan sebagai root" >&2; exit 1; }

mkdir -p /root/bnt-direct
cd /root/bnt-direct

echo "== 1. Seine ${SEINE_VERSION} =="
if [ -x ./seine ] && ./seine --version 2>/dev/null | grep -q "v0.2.21"; then
  echo "Binary ./seine v0.2.21 sudah ada, download dilewati."
else
  curl -L --connect-timeout 15 --max-time 180 "$SEINE_URL" -o seine.tar.gz
  [ -s seine.tar.gz ] || { echo "ERROR: download seine gagal / kosong" >&2; exit 1; }
  tar -xzf seine.tar.gz
  chmod +x ./seine
  ./seine --version
fi

echo "== 2. HugePages 1024 =="
mkdir -p /etc/sysctl.d
printf '# Seine HugeTLB pages\nvm.nr_hugepages = 1024\n' > /etc/sysctl.d/99-seine-hugepages.conf
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
sysctl -w vm.nr_hugepages=1024
sleep 2
FREE="$(awk '/^HugePages_Free:/ {print $2}' /proc/meminfo)"
echo "HugePages_Free=${FREE}"
if [ "${FREE:-0}" -lt 1024 ]; then
  echo "HugePages masih <1024, coba compact sekali lagi..."
  echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
  sysctl -w vm.nr_hugepages=1024
  sleep 2
  FREE="$(awk '/^HugePages_Free:/ {print $2}' /proc/meminfo)"
  echo "HugePages_Free=${FREE}"
fi
[ "${FREE:-0}" -ge 1024 ] || { echo "ERROR: HugePages_Free=${FREE}, Seine butuh minimal 1024" >&2; exit 1; }

echo "== 3. Pasang + jalankan miner sebagai service systemd =="
echo "Pool: ${POOL_URL}"
echo "Address: ${ADDRESS}"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  # Migrasi dari versi lama (nohup): hentikan proses lama dulu supaya
  # tidak ada dua miner jalan bersamaan, lalu service yang mengambil alih.
  pkill -f '/root/bnt-direct/seine' 2>/dev/null || true
  sleep 2
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ -f "${SCRIPT_DIR}/bnt-direct.service" ]; then
    cp "${SCRIPT_DIR}/bnt-direct.service" /etc/systemd/system/bnt-direct.service
  elif [ -f ./bnt-direct.service ]; then
    cp ./bnt-direct.service /etc/systemd/system/bnt-direct.service
  else
    cat > /etc/systemd/system/bnt-direct.service <<EOF
[Unit]
Description=BNT miner direct ke pool lama (Seine)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/bnt-direct
ExecStartPre=/bin/sh -c 'echo 1 > /proc/sys/vm/compact_memory || true'
ExecStartPre=/sbin/sysctl -w vm.nr_hugepages=1024
ExecStart=/root/bnt-direct/seine --pool-url ${POOL_URL} --address ${ADDRESS}
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
  fi
  systemctl daemon-reload
  systemctl enable --now bnt-direct
  sleep 15
  systemctl is-active bnt-direct
  journalctl -u bnt-direct -n 50 --no-pager || true
  echo ""
  echo "SELESAI. Miner jalan sebagai service bnt-direct (auto-restart + auto-start setelah reboot)."
  echo "Cek log: journalctl -u bnt-direct -n 50 --no-pager"
  echo "Harus ada: login accepted, share accepted, dan baris STATS yang nambah."
  echo "Berhenti: systemctl stop bnt-direct"
elif command -v crontab >/dev/null 2>&1; then
  echo "systemd tidak tersedia di mesin ini, pasang auto-restart via cron (@reboot + cek tiap 5 menit)."
  echo "Tetap paste-only: tidak ada langkah manual tambahan."
  cat > /root/bnt-direct/start-miner.sh <<EOF
#!/usr/bin/env bash
cd /root/bnt-direct
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
sysctl -w vm.nr_hugepages=1024 2>/dev/null || true
if pgrep -f '/root/bnt-direct/seine' >/dev/null 2>&1; then exit 0; fi
nohup ./seine --pool-url ${POOL_URL} --address ${ADDRESS} > miner.log 2>&1 &
disown
EOF
  chmod +x /root/bnt-direct/start-miner.sh
  (crontab -l 2>/dev/null | grep -v '/root/bnt-direct/start-miner.sh'; printf '@reboot sleep 20 /root/bnt-direct/start-miner.sh\n*/5 * * * * /root/bnt-direct/start-miner.sh\n') | crontab -
  crontab -l 2>/dev/null | grep 'start-miner.sh' || true
  if ! pgrep -x cron >/dev/null 2>&1 && ! pgrep -x crond >/dev/null 2>&1; then
    if command -v service >/dev/null 2>&1; then service cron start 2>/dev/null || service crond start 2>/dev/null || true; fi
    echo "PERINGATAN: daemon cron belum terlihat jalan; @reboot hanya jalan kalau cron daemon aktif saat boot."
  fi
  /root/bnt-direct/start-miner.sh
  sleep 15
  tail -n 50 miner.log
  echo ""
  echo "SELESAI (cron). Miner auto-start via @reboot dan dicek/dinyalakan lagi tiap 5 menit selama cron daemon jalan saat boot."
  echo "Cek log: cd /root/bnt-direct && tail -n 50 miner.log"
  echo "Harus ada: login accepted, share accepted, dan baris STATS yang nambah."
  echo "Berhenti: pkill -f ./seine; lalu hapus baris start-miner.sh dari crontab (crontab -e)"
else
  echo "PERINGATAN: systemd dan cron sama-sama tidak tersedia di mesin ini, fallback ke background biasa (nohup)."
  echo "Auto-restart setelah reboot TIDAK berlaku di mesin ini."
  nohup ./seine --pool-url "${POOL_URL}" --address "${ADDRESS}" > miner.log 2>&1 &
  disown
  sleep 15
  tail -n 50 miner.log
  echo ""
  echo "SELESAI (nohup, tanpa auto-restart). Cek log: cd /root/bnt-direct && tail -n 50 miner.log"
  echo "Harus ada: login accepted, share accepted, dan baris STATS yang nambah."
  echo "Berhenti: pkill -f ./seine"
fi
