#!/usr/bin/env bash
# setup-crm.sh
# Phase 5: installs the Cascade Ridge internal CRM on vm-crm01 (Ubuntu 24.04).
# All customer and shipment data is FAKE, created for a cybersecurity lab.
# The database password is never stored on disk: it is read from Key Vault
# at setup time and at app start, using the VM's managed identity.
# Run with: sudo bash setup-crm.sh
set -euo pipefail

VAULT="kv-cascaderidge01"
SECRET="crm-db-password"
HOSTNAME_FQDN="crm.corp.cascaderidgelogistics.com"

echo "== 1. Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q postgresql nginx python3-flask python3-psycopg2 gunicorn ufw

echo "== 2. Reading the database password from Key Vault (managed identity)"
get_secret() {
  python3 - "$VAULT" "$SECRET" <<'PY'
import json, sys, urllib.request
vault, name = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net",
    headers={"Metadata": "true"})
token = json.load(urllib.request.urlopen(req, timeout=10))["access_token"]
req = urllib.request.Request(
    f"https://{vault}.vault.azure.net/secrets/{name}?api-version=7.4",
    headers={"Authorization": f"Bearer {token}"})
print(json.load(urllib.request.urlopen(req, timeout=10))["value"], end="")
PY
}
DBPW="$(get_secret)"
if [ "${#DBPW}" -lt 20 ]; then echo "Could not read the secret from Key Vault"; exit 1; fi
echo "   got a ${#DBPW} character password (not shown)"

echo "== 3. Creating the database and app role"
sudo -u postgres psql -v ON_ERROR_STOP=1 -q <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'crmapp') THEN
    CREATE ROLE crmapp LOGIN;
  END IF;
END \$\$;
ALTER ROLE crmapp WITH PASSWORD '${DBPW}';
SQL
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='crm'" | grep -q 1 \
  || sudo -u postgres createdb -O crmapp crm

echo "== 4. Creating tables and loading fake data"
DBPW="$DBPW" python3 <<'PY'
import os, random, datetime, psycopg2
conn = psycopg2.connect(host="127.0.0.1", dbname="crm", user="crmapp", password=os.environ["DBPW"])
cur = conn.cursor()
cur.execute("""
CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY, account TEXT UNIQUE, name TEXT, city TEXT,
  contact_email TEXT, annual_spend INTEGER, owner TEXT);
CREATE TABLE IF NOT EXISTS shipments (
  id SERIAL PRIMARY KEY, shipment_no TEXT UNIQUE, customer_id INTEGER REFERENCES customers(id),
  origin TEXT, destination TEXT, pickup DATE, truck TEXT, status TEXT);
""")
cur.execute("SELECT COUNT(*) FROM customers")
if cur.fetchone()[0] == 0:
    rnd = random.Random(2026)
    customers = ["Harbor Lane Grocers", "Copperline Hardware", "Mossrock Brewing",
                 "Alder Point Medical Supply", "Glacier View Furniture", "Summit Ridge Outfitters",
                 "Driftwood Home Goods", "Fernbrook Nursery", "Stonegate Auto Parts", "Westwind Pet Supply"]
    cities = ["Olympia", "Tacoma", "Seattle", "Portland", "Spokane", "Yakima", "Bellingham", "Vancouver"]
    ids = []
    for i, c in enumerate(customers):
        slug = "".join(ch for ch in c.lower() if ch.isalpha())
        cur.execute("INSERT INTO customers (account,name,city,contact_email,annual_spend,owner) "
                    "VALUES (%s,%s,%s,%s,%s,%s) RETURNING id",
                    (f"ACCT-{100+i}", c, rnd.choice(cities), f"shipping@{slug}.example",
                     rnd.randint(12000, 240000), "Tom Becker"))
        ids.append(cur.fetchone()[0])
    start = datetime.date(2026, 11, 1)
    for i in range(1, 41):
        cur.execute("INSERT INTO shipments (shipment_no,customer_id,origin,destination,pickup,truck,status) "
                    "VALUES (%s,%s,%s,%s,%s,%s,%s)",
                    (f"SHP-{24000+i:05d}", rnd.choice(ids), "Olympia", rnd.choice(cities),
                     start + datetime.timedelta(days=rnd.randint(0, 29)),
                     f"TRK-{rnd.randint(1,12):02d}", rnd.choice(["Scheduled", "In Transit", "Delivered"])))
    print("   loaded 10 customers and 40 shipments")
else:
    print("   data already present, skipping")
conn.commit()
PY
unset DBPW

echo "== 5. Installing the web app"
id crm >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin crm
mkdir -p /opt/crm/templates
cp app.py /opt/crm/app.py
cp templates/*.html /opt/crm/templates/
chown -R root:crm /opt/crm && chmod -R 750 /opt/crm

cat > /etc/systemd/system/crm.service <<UNIT
[Unit]
Description=Cascade Ridge CRM (fictional lab app)
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
User=crm
Group=crm
WorkingDirectory=/opt/crm
Environment=KV_NAME=${VAULT}
Environment=KV_SECRET=${SECRET}
ExecStart=/usr/bin/gunicorn --workers 2 --bind 127.0.0.1:8000 app:app
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now crm.service

echo "== 6. HTTPS with nginx (self-signed certificate for now)"
if [ ! -f /etc/ssl/private/crm.key ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout /etc/ssl/private/crm.key -out /etc/ssl/certs/crm.crt \
    -subj "/CN=${HOSTNAME_FQDN}" -addext "subjectAltName=DNS:${HOSTNAME_FQDN},IP:10.2.2.4" 2>/dev/null
  chmod 600 /etc/ssl/private/crm.key
fi
cat > /etc/nginx/sites-available/crm <<NGX
server {
    listen 443 ssl;
    server_name ${HOSTNAME_FQDN} 10.2.2.4;
    ssl_certificate     /etc/ssl/certs/crm.crt;
    ssl_certificate_key /etc/ssl/private/crm.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    server_tokens off;
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy no-referrer always;
    add_header Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'none'; frame-ancestors 'none'" always;
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
    }
}
NGX
ln -sf /etc/nginx/sites-available/crm /etc/nginx/sites-enabled/crm
rm -f /etc/nginx/sites-enabled/default
nginx -t -q && systemctl reload nginx

echo "== 7. Host firewall (defense in depth behind the NSG)"
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow from 10.100.0.2 to any port 22 proto tcp >/dev/null
ufw allow from 10.1.0.0/16 to any port 443 proto tcp >/dev/null
ufw --force enable >/dev/null
ufw status numbered

echo "== 8. Checking"
sleep 2
curl -sk -o /dev/null -w "   https://localhost -> HTTP %{http_code}\n" https://localhost/ || true
systemctl is-active --quiet crm && echo "   crm service is running"
echo "Done. Cascade Ridge CRM is installed."
