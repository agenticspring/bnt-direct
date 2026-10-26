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

Script ini download Seine, atur HugePages 1024, lalu jalanin miner di background (`nohup`).

## Verifikasi jalan

```bash
cd /root/bnt-direct
tail -n 50 miner.log
```

Harus ada `login accepted`, terus share `accepted` dan baris `STATS` yang nambah.

## Berhenti

```bash
pkill -f ./seine
```

## Catatan

Repo ini sengaja tanpa relay. Beda dengan `bnt-relay` yang lewat relay `139.59.115.14:443` — di sini tidak ada relay sama sekali, miner langsung ke `bntpool.com:3333`.
