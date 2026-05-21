# Project Office — Nextcloud + ONLYOFFICE Docs

লোকাল ফাইল স্টোরেজ + কোলাবোরেটিভ ডকুমেন্ট এডিটিং স্ট্যাক, Podman দিয়ে চালানো। তিনটা container — MariaDB (Nextcloud-এর জন্য), ONLYOFFICE Document Server (editor engine), Nextcloud (file UI + connector)।

---

## ১. Stack Overview

### Containers

| Container | Image | পোর্ট (host:container) | কাজ |
|---|---|---|---|
| `nextcloud-db` | `mariadb:10.11` | শুধু internal `3306` | Nextcloud-এর database |
| `onlyoffice` | `onlyoffice/documentserver:latest` | `8080:80` | Document editor engine |
| `nextcloud` | `nextcloud:latest` | `8081:80` | File manager + UI |

তিনটাই `office-net` নামক একটা bridge network-এ আছে, তাই container name দিয়েই একে অপরকে call করতে পারে (`http://nextcloud/`, `http://onlyoffice/`, `nextcloud-db:3306`)।

### Persistent Volumes

| Volume | কী থাকে |
|---|---|
| `project-office_nextcloud_db` | MariaDB এর ডেটা ফাইল |
| `project-office_nextcloud_data` | Nextcloud user files, config.php, apps |
| `project-office_onlyoffice_data` | ONLYOFFICE working data |
| `project-office_onlyoffice_log` | ONLYOFFICE logs |
| `project-office_onlyoffice_lib` | ONLYOFFICE library cache |
| `project-office_onlyoffice_db` | ONLYOFFICE internal PostgreSQL |

Container delete করলেও এই volume গুলো থাকে। ডেটা মুছতে হলে `podman volume rm <name>` ম্যানুয়ালি করতে হবে।

### Data Flow

ব্রাউজার থেকে `127.0.0.1:8081` (Nextcloud) দিয়ে ঢুকলে:

```
Browser ──┐
          ├── 127.0.0.1:8081 ──► nextcloud container ──► nextcloud-db (MariaDB)
          │                              │
          │                              └── http://onlyoffice/ (internal call to fetch editor JS)
          │
          └── 127.0.0.1:8080 ──► onlyoffice container
                                         │
                                         └── http://nextcloud/... (callback to download/save document)
```

ONLYOFFICE editor browser-এ লোড হলেও আসল ফাইল download/save container-to-container internal network দিয়ে হয়।

---

## ২. Run / Stop / Restart

প্রজেক্ট ফোল্ডার: `/home/abwahab/Project_Running/project-office/`

### একদম প্রথমবার বা পুরো reset করতে হলে

```fish
cd /home/abwahab/Project_Running/project-office

# পুরো stack নামাও (containers বন্ধ + network মুছে যাবে, কিন্তু volume থাকবে)
podman compose -f podman-compose.yml down

# data রিসেট করতে চাইলে (সব file/db গায়েব হবে — সাবধান!)
podman volume rm project-office_nextcloud_db project-office_nextcloud_data

# stack চালু করো
podman compose -f podman-compose.yml up -d
```

প্রথমবার Nextcloud-এর install শেষ হতে ৩০–৬০ সেকেন্ড লাগে। লগ দেখতে:

```fish
podman logs -f nextcloud
```

`Nextcloud was successfully installed` মেসেজ এলে ready।

### প্রতিদিনের ব্যবহার

```fish
# চালু করতে
podman compose -f /home/abwahab/Project_Running/project-office/podman-compose.yml up -d

# বন্ধ করতে (data থাকবে, পরে আবার তোলা যাবে)
podman compose -f /home/abwahab/Project_Running/project-office/podman-compose.yml down

# শুধু থামাতে (network/container থাকবে, পরের start তাড়াতাড়ি হবে)
podman compose -f /home/abwahab/Project_Running/project-office/podman-compose.yml stop

# থামানো stack আবার চালু করতে
podman compose -f /home/abwahab/Project_Running/project-office/podman-compose.yml start

# status দেখতে
podman compose -f /home/abwahab/Project_Running/project-office/podman-compose.yml ps

# কোনো একটা container-এর লগ দেখতে
podman logs -f nextcloud
podman logs -f onlyoffice
podman logs -f nextcloud-db
```

### Container restart পরে যা যা reset হতে পারে

ONLYOFFICE container রিক্রিয়েট হলে (image pull বা down/up) **নিচের ম্যানুয়াল চেঞ্জগুলো হারিয়ে যাবে**, কারণ এগুলো container filesystem-এ — volume-এ না:

- `ds.conf`-এ port 8080 listening
- `ds-example.conf`-এ autostart=true

পুনরায় চালু করতে — [section ৭](#৭-onlyoffice-test-example-ম্যানুয়াল-config) দেখুন।

---

## ৩. URLs এবং Login

| URL | কী |
|---|---|
| `http://127.0.0.1:8081/` | **Nextcloud** (main interface) |
| `http://127.0.0.1:8081/apps/files/` | Files page (direct) |
| `http://127.0.0.1:8081/status.php` | health JSON |
| `http://127.0.0.1:8080/` | ONLYOFFICE welcome page (শুধু confirm যে চলছে) |
| `http://127.0.0.1:8080/healthcheck` | `true` returns |
| `http://127.0.0.1:8080/example/` | **Test example** (dev demo — production-এ disable) |

### Default Credentials

| Service | User | Password | কোথায় সেট |
|---|---|---|---|
| Nextcloud admin | `admin` | `root_admin` | `podman-compose.yml` → `NEXTCLOUD_ADMIN_PASSWORD` |
| MariaDB root | `root` | `root` | `MYSQL_ROOT_PASSWORD` |
| MariaDB nextcloud user | `nextcloud` | `root_nc` | `MYSQL_PASSWORD` |
| JWT secret (ONLYOFFICE ↔ Nextcloud) | n/a | `e204b94a9b5d89b52ef8848f9efdc019e23aaeb2d40902611d2d3190e69592f9` | `JWT_SECRET` env |

⚠️ **এগুলো সব placeholder/weak — শুধু local dev-এর জন্য। Production-এ অবশ্যই পাল্টাতে হবে।** [Section ৮](#৮-production-checklist) দেখুন।

---

## ৪. Nextcloud → ONLYOFFICE Integration (যা already সেট করা)

Nextcloud-এ ONLYOFFICE connector app install করা আছে। `occ` দিয়ে নিচের কনফিগ সেট আছে (Admin Settings → ONLYOFFICE-এও দেখা যাবে):

| Config key | Value |
|---|---|
| `DocumentServerUrl` (browser থেকে editor load) | `http://127.0.0.1:8080/` |
| `DocumentServerInternalUrl` (Nextcloud → ONLYOFFICE) | `http://onlyoffice/` |
| `StorageUrl` (ONLYOFFICE → Nextcloud) | `http://nextcloud/` |
| `jwt_secret` | উপরের JWT |
| `jwt_header` | `Authorization` |

### Trusted Domains

ONLYOFFICE container Nextcloud-কে যে hostname দিয়ে call করে (`nextcloud`), সেটা trusted_domains-এ যোগ করা আছে। Listing:

```
localhost
127.0.0.1:8081
nextcloud
```

নতুন domain যোগ করতে (যেমন প্রোডাকশন domain):

```fish
podman exec -u www-data nextcloud php occ config:system:set trusted_domains 3 --value=cloud.example.com
```

---

## ৫. ব্যবহারের পথ

### A. Nextcloud দিয়ে (recommended)

1. ব্রাউজারে `http://127.0.0.1:8081/`
2. Login: `admin` / `root_admin`
3. **Files** → **+ New** → **New document / spreadsheet / presentation**
4. ফাইলে ক্লিক করলে ONLYOFFICE editor খুলবে, সেভ স্বয়ংক্রিয়।

### B. ONLYOFFICE Test Example দিয়ে (dev only, insecure)

1. ব্রাউজারে `http://127.0.0.1:8080/example/`
2. বাম পাশে **Create new** → Document/Spreadsheet/etc.
3. ফাইল edit হবে, কিন্তু **কোনো login নেই, কোনো sharing নেই**, ফাইল container volume-এ আলাদা storage-এ।

⚠️ **A আর B-এর ফাইল পরস্পরের সাথে শেয়ার বা sync হয় না।** দুটো সম্পূর্ণ আলাদা storage।

---

## ৬. কী কী Manual Fix করা হয়েছিল (history / reproducibility)

প্রথমবার চালু করার পর যে সমস্যাগুলো আসছিল আর কীভাবে ফিক্স হয়েছিল:

### Issue 1: Nextcloud empty page / DB access denied

**লক্ষণ:** Browser-এ "127.0.0.1:8081 sent back an empty page", log-এ `Access denied for user 'nextcloud'@'...'`।

**কারণ:** আগের কোনো run-এ ভিন্ন `MYSQL_PASSWORD` দিয়ে `nextcloud_db` volume initialize হয়েছিল। MariaDB volume persistent — env বদলালেও existing user-এর password আপডেট হয় না।

**ফিক্স:** stack down → `project-office_nextcloud_db` ও `project-office_nextcloud_data` volume মুছে → আবার up।

### Issue 2: JWT secret ছিল placeholder

**লক্ষণ:** কাজ চলত, কিন্তু secret `YOUR_JWT_SECRET` (literal) ছিল — অনিরাপদ।

**ফিক্স:** `openssl rand -hex 32` দিয়ে generate → `podman-compose.yml`-এ `JWT_SECRET` ফিল্ডে বসানো → stack recreate।

### Issue 3: ONLYOFFICE → Nextcloud HTTP 400

**লক্ষণ:** `podman exec onlyoffice curl http://nextcloud/status.php` → HTTP 400।

**কারণ:** Nextcloud-এর trusted_domains-এ শুধু `127.0.0.1:8081` ছিল, hostname `nextcloud` ছিল না।

**ফিক্স:** `occ config:system:set trusted_domains 2 --value=nextcloud` + compose-এর `NEXTCLOUD_TRUSTED_DOMAINS`-এ যোগ।

### Issue 4: ONLYOFFICE connector app install নেই

**লক্ষণ:** Nextcloud-এ Settings → ONLYOFFICE নেই, "+ New"-এ docx/xlsx option নেই।

**ফিক্স:**

```fish
podman exec -u www-data nextcloud php occ app:install onlyoffice
podman exec -u www-data nextcloud php occ app:enable onlyoffice
```

তারপর URL/secret configure।

### Issue 5: Test example "Download failed"

**লক্ষণ:** `127.0.0.1:8080/example/` থেকে file খুললে "Download failed" পপ-আপ। লগ: `ECONNREFUSED 127.0.0.1:8080`।

**কারণ:** Container-এর ভেতরে nginx শুধু port 80-এ listen করত। Test example browser-কে download URL দিচ্ছিল `http://127.0.0.1:8080/example/download?...` — docservice (একই container-এ) সেটা ফেচ করতে গিয়ে port 8080-এ কিছু পেত না।

**ফিক্স:** `ds.conf`-এ `listen 0.0.0.0:8080;` ও `listen [::]:8080;` যোগ → nginx reload → `ds:example` autostart=true + service start।

---

## ৭. ONLYOFFICE Test Example ম্যানুয়াল Config

Container recreate হলে নিচের সবকিছু আবার ম্যানুয়ালি apply করতে হবে (image-এর মূল অবস্থায় ফিরে যাবে):

```fish
# ১. nginx ভেতরে port 8080-এ listen করাও
podman exec onlyoffice sed -i \
  's|listen 0.0.0.0:80;|listen 0.0.0.0:80;\n  listen 0.0.0.0:8080;|; s|listen \[::\]:80 default_server;|listen [::]:80 default_server;\n  listen [::]:8080;|' \
  /etc/onlyoffice/documentserver/nginx/ds.conf

# ২. nginx reload
podman exec onlyoffice nginx -s reload

# ৩. ds:example autostart on
podman exec onlyoffice sed -i 's,autostart=false,autostart=true,' /etc/supervisor/conf.d/ds-example.conf

# ৪. ds:example এখনই চালু করো
podman exec onlyoffice supervisorctl start ds:example
```

স্থায়ী সমাধান চাইলে — একটা startup script `entrypoint-hook` হিসেবে compose-এ mount করতে হবে (আপাতত করা হয়নি, কারণ এই test example dev-only)।

---

## ৮. Production Checklist

এই setup **local development-এর জন্য** তৈরি। প্রোডাকশনে নিতে হলে minimum নিচের ১৫ আইটেম address করতে হবে।

### ক. গোপনীয়তা ও পাসওয়ার্ড

- [ ] `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `NEXTCLOUD_ADMIN_PASSWORD` — সব strong, unique। কমপক্ষে ২০ অক্ষর, password manager-এ রাখো।
- [ ] `JWT_SECRET` rotate করো নতুন `openssl rand -hex 32` দিয়ে, এবং Nextcloud connector-এও আপডেট করো।
- [ ] কোনো secret সরাসরি `podman-compose.yml`-এ commit করো না। Podman secrets বা `.env` ফাইল (যেটা `.gitignore`-এ থাকবে) ব্যবহার করো:

  ```yaml
  environment:
    - MYSQL_PASSWORD_FILE=/run/secrets/mysql_password
  secrets:
    - mysql_password
  ```

### খ. HTTPS / TLS (অবশ্যই)

- [ ] একটা reverse proxy বসাও — Caddy, Traefik, বা Nginx — যেটা Let's Encrypt দিয়ে auto-cert দেবে।
- [ ] Nextcloud-এ:
  - `NEXTCLOUD_TRUSTED_DOMAINS` সেট করো production domain-এ (যেমন `cloud.example.com`)
  - `OVERWRITEHOST=cloud.example.com`, `OVERWRITEPROTOCOL=https`, `TRUSTED_PROXIES=<reverse proxy IP>` env var যোগ করো
- [ ] ONLYOFFICE-এ `USE_UNAUTHORIZED_STORAGE=false`, `ONLYOFFICE_HTTPS_HSTS_ENABLED=true` সেট করো; HTTPS-এর জন্য cert mount করো বা reverse proxy SSL terminate করুক।
- [ ] Nextcloud connector-এর URL HTTPS-এ আপডেট:

  ```fish
  podman exec -u www-data nextcloud php occ config:app:set onlyoffice DocumentServerUrl --value="https://office.example.com/"
  ```

  Internal URLs (DocumentServerInternalUrl, StorageUrl) container-name-ই থাকবে (`http://onlyoffice/`, `http://nextcloud/`)।

### গ. Domain & DNS

- [ ] পাবলিক DNS (যেমন `cloud.example.com`, `office.example.com`) দুটো subdomain বা একই domain-এর reverse-proxy path।
- [ ] Nextcloud `trusted_domains`-এ public domain যোগ:

  ```fish
  podman exec -u www-data nextcloud php occ config:system:set trusted_domains 3 --value=cloud.example.com
  ```

### ঘ. Firewall

- [ ] শুধু `443` (HTTPS) আর `80` (Let's Encrypt challenge) public, বাকি সব block।
- [ ] `8080`, `8081` host port সরাসরি public-এ expose করো না — শুধু reverse proxy access করুক।
- [ ] `nextcloud-db` কখনো host port-এ bind করো না।

### ঙ. Security Hardening

- [ ] Test example disable: `autostart=false` ও `supervisorctl stop ds:example` — production-এ এটা **চলবে না**।
- [ ] ONLYOFFICE `welcome/` ও `example/` path nginx-এ block করো প্রোডাকশন proxy-তে।
- [ ] Nextcloud-এ **2FA** enable করো admin-এর জন্য (Settings → Security → Two-Factor)।
- [ ] `occ` দিয়ে security headers verify:

  ```fish
  podman exec -u www-data nextcloud php occ security:certificates
  ```

- [ ] Brute-force throttling default-এ on আছে, verify করো `php occ config:system:get auth.bruteforce.protection.enabled`।

### চ. Backup

- [ ] **Daily**:
  - MariaDB dump:
    ```fish
    podman exec nextcloud-db mariadb-dump -uroot -p'<password>' --all-databases > /backup/nc-db-$(date +%F).sql
    ```
  - Nextcloud data volume:
    ```fish
    podman run --rm -v project-office_nextcloud_data:/data -v /backup:/backup alpine \
      tar czf /backup/nc-data-$(date +%F).tar.gz -C /data .
    ```
- [ ] Restore টেস্ট করো নিয়মিত — অপরীক্ষিত backup = no backup।
- [ ] Cron বা systemd timer দিয়ে automate করো।
- [ ] Off-site copy রাখো (B2, S3, rsync to another server)।

### ছ. Maintenance Mode সময় backup-এর আগে

```fish
podman exec -u www-data nextcloud php occ maintenance:mode --on
# backup করো...
podman exec -u www-data nextcloud php occ maintenance:mode --off
```

### জ. Update Strategy

- [ ] `image: nextcloud:latest` এবং `documentserver:latest` — production-এ **specific version tag** ব্যবহার করো (যেমন `nextcloud:30.0.4`, `onlyoffice/documentserver:8.2.2`)।
- [ ] Update-এর আগে backup নাও, তারপর:

  ```fish
  podman compose pull
  podman compose up -d
  podman exec -u www-data nextcloud php occ upgrade
  ```

- [ ] Major version upgrade-এ Nextcloud-এর official upgrade notes পড়ো।

### ঝ. Performance

- [ ] Nextcloud-এর Redis cache যোগ করো (একটা `redis:7` container) — file locking ও memory cache হবে।
- [ ] Cron জব setup করো:

  ```fish
  # প্রতি ৫ মিনিটে
  */5 * * * * podman exec -u www-data nextcloud php -f /var/www/html/cron.php
  ```

- [ ] PHP opcache, memory limits টিউন।

### ঞ. Monitoring & Logging

- [ ] Container logs ship করো central logger-এ (Loki, ELK, etc.)।
- [ ] `nextcloud/data/nextcloud.log` rotate ও alert।
- [ ] Health check endpoints monitor করো (`/status.php`, `/healthcheck`)।
- [ ] Disk usage alert — volume পূর্ণ হলে file corruption।

### ট. Resource Limits

`podman-compose.yml`-এ যোগ করো:

```yaml
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '2.0'
```

### ঠ. ONLYOFFICE License (যদি Enterprise লাগে)

- [ ] Community Edition: ২০ concurrent connection limit।
- [ ] বেশি লাগলে Enterprise license কিনতে হবে — ONLYOFFICE sales contact।

### ড. SystemD Service / Auto-start at boot

হোস্ট restart হলে স্ট্যাক যাতে নিজে উঠে যায়:

```fish
# একটা systemd user service বানাও
mkdir -p ~/.config/systemd/user
podman generate systemd --new --name nextcloud --files --restart-policy=always
# (একইভাবে onlyoffice, nextcloud-db এর জন্য)
systemctl --user enable container-nextcloud
loginctl enable-linger $USER  # user logout হলেও service চলবে
```

বা compose-level: `restart: always` ইতিমধ্যে set আছে — শুধু podman service ahead-of-time ready থাকলে boot-এ উঠবে।

### ঢ. Anti-virus (Optional কিন্তু recommended)

- [ ] `ClamAV` container যোগ করো, Nextcloud-এ Files Antivirus app enable করো।

### ণ. Documentation handoff

- [ ] এই README আপডেট রাখো — যা কনফিগ পাল্টাবে সব এখানে লেখো।
- [ ] Disaster recovery plan — backup restore steps লিখে রাখো।

---

## ৯. Useful Commands Reference

```fish
# Stack status
podman compose -f podman-compose.yml ps

# একটা container shell-এ ঢোকো
podman exec -it nextcloud bash
podman exec -it onlyoffice bash

# Nextcloud occ command (অ্যাডমিন CLI)
podman exec -u www-data nextcloud php occ <command>

# কয়েকটা useful occ
podman exec -u www-data nextcloud php occ app:list
podman exec -u www-data nextcloud php occ user:list
podman exec -u www-data nextcloud php occ config:list system
podman exec -u www-data nextcloud php occ maintenance:mode --on
podman exec -u www-data nextcloud php occ files:scan --all

# Volume inspect
podman volume inspect project-office_nextcloud_data

# একটা volume-এর সাইজ
podman system df -v | grep project-office

# Image update
podman compose -f podman-compose.yml pull
podman compose -f podman-compose.yml up -d

# পুরো nuke (সব ডেটা মুছে যাবে — সাবধান!)
podman compose -f podman-compose.yml down -v
```

---

## ১০. Troubleshooting Quick Reference

| লক্ষণ | প্রথম check |
|---|---|
| `127.0.0.1:8081` empty page | `podman logs nextcloud` — DB connection error দেখো |
| ONLYOFFICE editor "Connection failed" | Nextcloud admin settings → ONLYOFFICE-এ URL ও secret verify |
| "Download failed" / "could not be saved" | `podman logs onlyoffice` — কোন URL ফেচ করতে গিয়ে fail করেছে দেখো |
| Slow file upload | Nextcloud-এ Redis enable, PHP memory_limit বাড়াও |
| `Access denied for user` | Compose-এ `MYSQL_PASSWORD` আর actual DB-র user password mismatch — volume নুক করো |
| Container restart-এ test example কাজ করছে না | [Section ৭](#৭-onlyoffice-test-example-ম্যানুয়াল-config)-এর command রি-রান |

---

**Last updated:** 2026-05-21
