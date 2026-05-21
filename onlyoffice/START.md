# Start Guide — সব বন্ধ থাকলে কীভাবে চালু করবেন

পুরো stack বন্ধ আছে (containers stopped/removed, কিন্তু volumes আছে)। এই গাইড অনুসরণ করে চালু করুন।

বিস্তারিত architecture/config জানতে → [README.md](README.md)।

---

## ধাপ ১ — Podman service চালু আছে কিনা দেখুন

```fish
podman info > /dev/null && echo "podman OK"
```

`podman OK` দেখালে পরের ধাপ। না দেখালে — `systemctl --user start podman.socket` বা শুধু একবার `podman ps` রান করুন (rootless podman daemon auto-start)।

---

## ধাপ ২ — প্রজেক্ট ফোল্ডারে যান

```fish
cd /home/abwahab/Project_Running/project-office
```

ফাইল আছে কিনা verify:

```fish
ls
```

দেখার কথা: `podman-compose.yml`, `README.md`, `START.md`, ইত্যাদি।

---

## ধাপ ৩ — বর্তমান অবস্থা দেখুন (চালু কিছু আছে কি?)

```fish
podman compose -f podman-compose.yml ps
```

কিছু না দেখালে — সব বন্ধ, পরের ধাপ। কিছু দেখালে — সেগুলো already up; ধাপ ৪ skip করে ধাপ ৫-এ যান।

---

## ধাপ ৪ — Stack চালু করুন

```fish
podman compose -f podman-compose.yml up -d
```

`-d` মানে detached (background-এ)। ৩টা container তৈরি/চালু হবে: `nextcloud-db`, `onlyoffice`, `nextcloud`।

প্রথমবার চালু হতে ১০–৩০ সেকেন্ড, কিন্তু Nextcloud-এর ভেতরে initialization আরও ৩০–৬০ সেকেন্ড নিতে পারে।

---

## ধাপ ৫ — Nextcloud ready হওয়ার জন্য অপেক্ষা করুন

```fish
podman logs -f nextcloud
```

স্ক্রিনে যেকোনো একটা দেখলে ready:

- `Nextcloud was successfully installed` (প্রথমবার)
- `resuming normal operations` (পরবর্তী start)

দেখার পর `Ctrl+C` দিয়ে log থেকে বের হন।

দ্রুত one-liner check (log না দেখে):

```fish
curl -s http://127.0.0.1:8081/status.php
```

`{"installed":true,"maintenance":false,...}` এলে ready।

---

## ধাপ ৬ — তিনটা service-এর health verify

```fish
echo "=== Nextcloud ==="
curl -s http://127.0.0.1:8081/status.php; echo

echo "=== ONLYOFFICE ==="
curl -s http://127.0.0.1:8080/healthcheck; echo

echo "=== Containers ==="
podman compose -f podman-compose.yml ps
```

আশা করা output:

- Nextcloud: `{"installed":true,...}`
- ONLYOFFICE: `true`
- Containers: তিনটাই `Up`

কোনোটা fail করলে → [Troubleshooting](#troubleshooting) section।

---

## ধাপ ৭ — ONLYOFFICE Test Example চাইলে চালু করুন (Optional)

শুধু যদি `http://127.0.0.1:8080/example/` ব্যবহার করতে চান। **Container recreate হলে এই config হারিয়ে যায়, তাই প্রতিবার up-এর পর রি-অ্যাপ্লাই করতে হবে।**

```fish
# ১. ভেতরে nginx port 8080-এ listen করাও
podman exec onlyoffice sed -i \
  's|listen 0.0.0.0:80;|listen 0.0.0.0:80;\n  listen 0.0.0.0:8080;|; s|listen \[::\]:80 default_server;|listen [::]:80 default_server;\n  listen [::]:8080;|' \
  /etc/onlyoffice/documentserver/nginx/ds.conf

# ২. nginx reload
podman exec onlyoffice nginx -s reload

# ৩. ds:example autostart on
podman exec onlyoffice sed -i 's,autostart=false,autostart=true,' /etc/supervisor/conf.d/ds-example.conf

# ৪. ds:example এখনই চালু করো
podman exec onlyoffice supervisorctl start ds:example

# ৫. ভেরিফাই
podman exec onlyoffice curl -sS -o /dev/null -w "http://127.0.0.1:8080/example/ → HTTP %{http_code}\n" http://127.0.0.1:8080/example/
```

শেষ লাইনে `HTTP 200` দেখালে test example ready।

**যদি শুধু Nextcloud ব্যবহার করেন, এই ধাপ স্কিপ করুন।**

---

## ধাপ ৮ — ব্রাউজারে খুলুন

| URL | কী |
|---|---|
| http://127.0.0.1:8081/ | Nextcloud login — `admin` / `root_admin` |
| http://127.0.0.1:8080/example/ | (শুধু ধাপ ৭ করলে) ONLYOFFICE demo |

Nextcloud login করার পর: **Files → + New → New document** করে দেখুন editor সঠিকভাবে খোলে।

---

## ধাপ ৯ — কাজ শেষ হলে বন্ধ করতে

দুটো option:

```fish
# Option A — শুধু থামাও (পরে দ্রুত আবার চালু করা যাবে)
podman compose -f podman-compose.yml stop

# Option B — পুরো নামাও (network ও container মুছে যাবে, কিন্তু volume/data থাকবে)
podman compose -f podman-compose.yml down
```

- **Option A**-এর পর: আবার শুরু করতে `podman compose -f podman-compose.yml start`
- **Option B**-এর পর: আবার শুরু করতে এই গাইডের ধাপ ৪ থেকে শুরু

পরের বার host reboot করলে container গায়েব — Option B-এর মতো শুরু করতে হবে।

---

## Troubleshooting

### `127.0.0.1:8081` empty page বা error

```fish
podman logs --tail 50 nextcloud
```

`Access denied for user` দেখালে — DB password mismatch। সাধারণত compose-এর env vs volume-এর পুরোনো initialization আলাদা। সমাধান:

```fish
podman compose -f podman-compose.yml down
podman volume rm project-office_nextcloud_db project-office_nextcloud_data
podman compose -f podman-compose.yml up -d
```

⚠️ এতে Nextcloud-এর সব data মুছে যাবে। শুধু dev setup-এ করুন।

### `127.0.0.1:8080` থেকে কোনো response নেই

```fish
podman logs --tail 30 onlyoffice
podman compose -f podman-compose.yml ps
```

`onlyoffice` container `Up` কিনা দেখুন। `Exited` দেখালে — আবার `up -d` করুন।

### ONLYOFFICE editor "Download failed"

দুই কারণে হয়:

1. **আপনি Nextcloud-এ আছেন:** Settings → Administration → ONLYOFFICE-এ URL ও secret verify করুন। ([README.md → section ৪](README.md))
2. **আপনি test example-এ আছেন (`:8080/example/`):** ধাপ ৭-এর সব command রান হয়েছে কিনা verify করুন।

### Container তৈরি হচ্ছে কিন্তু পরে exit করছে

```fish
podman logs nextcloud-db
podman logs nextcloud
podman logs onlyoffice
```

লগে যে error দেখাচ্ছে সেটা দিয়ে diagnose করুন। সবচেয়ে কমন: volume permission, port conflict (8080/8081 অন্য কিছু দখল করে আছে)।

Port conflict চেক:

```fish
ss -ltn | grep -E ':8080|:8081|:3306'
```

---

## TL;DR (এক লাইনে)

বেশিরভাগ সময় শুধু এটা যথেষ্ট:

```fish
cd /home/abwahab/Project_Running/project-office && podman compose -f podman-compose.yml up -d && sleep 30 && curl -s http://127.0.0.1:8081/status.php
```

শেষে `{"installed":true,...}` দেখালে → ব্রাউজারে http://127.0.0.1:8081/ → done।


# where store data

/home/abwahab/.local/share/containers/storage/volumes/project-office_nextcloud_data/_data/
    └── data/admin/files/   ← এখানে আপনার সব .docx, .xlsx

# Volume path
podman volume inspect project-office_onlyoffice_data --format '{{.Mountpoint}}'

# কী file আছে
ls /home/abwahab/.local/share/containers/storage/volumes/project-office_onlyoffice_data/_data/

# সাইজ
du -sh /home/abwahab/.local/share/containers/storage/volumes/project-office_*/
