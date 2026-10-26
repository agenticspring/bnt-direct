# bnt-direct

Mining BNT simple, direct ke pool lama, tanpa relay.

- Pool: `bntpool.com:3333` (pool lama), direct — tanpa relay, tanpa allowlist
- Wallet: sudah tertanam langsung di `setup.sh` (wallet produksi Dez)
- Miner: Seine `v0.2.21`, 1 worker, HugePages 1024

Wallet di script ini:

```
PLMGsifmTC9Zn5pHqcMkbayvzSG3SBX6vAwJts3KQCwfGRsznpv2qdyCFyRpnh46TwcQu8mLEu1CVdHdQzsx7Ty637GQc
```

Kalau script ini dipakai orang lain, ganti `ADDRESS` di `setup.sh` dulu sebelum jalan.

## Pakai (sebagai root)

```bash
curl -L https://cdn.jsdelivr.net/gh/agenticspring/bnt-direct@main/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

Script ini download Seine, atur HugePages 1024 (runtime + persisten), lalu memasang miner sebagai service systemd `bnt-direct`: auto-restart kalau proses mati, dan auto-start lagi setelah reboot. Kalau mesin tidak pakai systemd, script fallback ke background biasa (`nohup`) dan auto-restart tidak berlaku di mesin itu.

Mesin lama yang dulu dipasang versi `nohup`: cukup jalankan ulang `setup.sh` yang baru — skrip menghentikan proses `nohup` lama dulu, lalu service yang mengambil alih, jadi tidak ada dua miner jalan bersamaan.

## Verifikasi jalan

```bash
systemctl is-active bnt-direct
journalctl -u bnt-direct -n 50 --no-pager
```

Harus ada `login accepted`, terus share `accepted` dan baris `STATS` yang nambah. Cek juga service-nya ter-enable (auto-start setelah reboot):

```bash
systemctl is-enabled bnt-direct
```

## Berhenti

```bash
systemctl stop bnt-direct
```

Untuk mematikan auto-start setelah reboot juga:

```bash
systemctl disable bnt-direct
```

## Catatan

Repo ini sengaja tanpa relay. Beda dengan `bnt-relay` yang lewat relay `139.59.115.14:443` — di sini tidak ada relay sama sekali, miner langsung ke `bntpool.com:3333`.
