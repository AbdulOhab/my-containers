# Database Access 

## Option 1: phpMyAdmin (Port 5051)
- Go to: `http://localhost:5051`
- **Server:** `mariadb`
- **Username:** `root`
- **Password:** `root123`

## Option 2: Adminer (Port 5052)
- Go to: `http://localhost:5052`
- **System:** `MySQL`
- **Server:** `mariadb`
- **Username:** `root`
- **Password:** `root123`
- **Database:** `mydatabase`

## Alternative Users
You can also login with:
- **Username:** `admin`
- **Password:** `admin123`
- **Database:** `mydatabase`

Login credentials:
- Username: `root` (Password: `root123`)  
- Username: `admin` (Password: `admin123`)

---

## Error: `bash: mysql: command not found`
- কারণ **mariadb official image** কিছু light-weight version ব্যবহার করে, যেখানে **mysql CLI client নেই**, শুধু server চলে।

---

## CLI Client Installation

**Debian/Ubuntu based image:**
```bash
apt update
apt install mariadb-client -y
````

**Alpine based image:**

```bash
apk add mariadb-client
```

তারপর চালাতে পারবে:

```bash
mysql -u root -proot alapon_blog
```

---

## Database Import Steps

### 1. ফাইল কপি করুন

```bash
podman cp /home/abdulwahab/CodeRunningDev/report-app/database/potropollob.sql database-mariadb:/tmp/potropollob.sql
```

### 2. Container-এ ঢুকুন

```bash
podman exec -it database-mariadb bash
```

### 3. MySQL/MariaDB এ লগইন করুন

```bash
# Root user দিয়ে
mysql -u root -proot123 alapon_blog

# অথবা
mariadb -u root -proot alapon_blog
```

### 4. ডাটাবেসে SQL ফাইল লোড করুন

```sql
SOURCE /tmp/potropollob.sql;
```

### 5. MySQL Commands উদাহরণ

```bash
# Root user দিয়ে login
mysql -u root -preport_app_2025

# অথবা regular user দিয়ে
mysql -u report_user -preport_pass_2025

# Available databases দেখুন
SHOW DATABASES;

# Tables দেখুন
SHOW TABLES;

# MySQL থেকে বের হোন
EXIT;
```

---

## Notes

* Container-এ CLI missing হলে host থেকে connect করার পদ্ধতি ব্যবহার করা যায়:

```bash
mysql -h 127.0.0.1 -P 3310 -u root -proot alapon_blog
```

* Container-এ CLI থাকলে `mariadb` command ব্যবহার করতে হবে, spelling ঠিক রাখতে হবে।

```

এই Markdown ফাইলটি **সরাসরি documentation বা README হিসেবে ব্যবহার করা যাবে**, এবং step-by-step host ও container উভয় context-এ database access দেখানো আছে।  

চাও আমি এটাকে আরও **host + container diagram** সহ visualize করে Markdown-ready বানিয়ে দিই যাতে নতুন ব্যবহারকারীর জন্য আরও সহজ হয়?
```
