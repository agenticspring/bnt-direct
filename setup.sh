#!/usr/bin/env bash
# bnt-direct — mining BNT simple, direct ke pool lama, tanpa relay.
#
# Pakai (sebagai root):
#   curl -L https://cdn.jsdelivr.net/gh/agenticspring/bnt-direct@main/setup.sh -o setup.sh
#   chmod +x setup.sh
#   ./setup.sh
#
# Script ini langsung jalanin miner di background (nohup).
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

echo "== 3. Jalankan miner (direct, pool lama) =="
echo "Pool: ${POOL_URL}"
echo "Address: ${ADDRESS}"
nohup ./seine --pool-url "${POOL_URL}" --address "${ADDRESS}" > miner.log 2>&1 &
disown
sleep 15
tail -n 50 miner.log
echo ""
echo "SELESAI. Cek log: cd /root/bnt-direct && tail -n 50 miner.log"
echo "Harus ada: login accepted, share accepted, dan baris STATS yang nambah."
echo "Berhenti: pkill -f ./seine"
