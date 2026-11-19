# app.py: Cascade Ridge internal CRM (fictional company, cybersecurity lab).
# Read-only views of fake customers and shipments.
# The database password comes from Key Vault through the VM's managed identity
# and is kept only in memory.
import json
import os
import urllib.request

import psycopg2
import psycopg2.extras
from flask import Flask, abort, render_template

app = Flask(__name__)
_password = None


def db_password():
    global _password
    if _password is None:
        req = urllib.request.Request(
            "http://169.254.169.254/metadata/identity/oauth2/token"
            "?api-version=2018-02-01&resource=https://vault.azure.net",
            headers={"Metadata": "true"})
        token = json.load(urllib.request.urlopen(req, timeout=10))["access_token"]
        vault = os.environ["KV_NAME"]
        secret = os.environ["KV_SECRET"]
        req = urllib.request.Request(
            f"https://{vault}.vault.azure.net/secrets/{secret}?api-version=7.4",
            headers={"Authorization": f"Bearer {token}"})
        _password = json.load(urllib.request.urlopen(req, timeout=10))["value"]
    return _password


def query(sql, params=()):
    conn = psycopg2.connect(host="127.0.0.1", dbname="crm", user="crmapp", password=db_password())
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)  # always parameterized, never string-built
            return cur.fetchall()
    finally:
        conn.close()


@app.route("/")
def dashboard():
    stats = query("""
        SELECT (SELECT COUNT(*) FROM customers) AS customers,
               (SELECT COUNT(*) FROM shipments) AS shipments,
               (SELECT COUNT(*) FROM shipments WHERE status = 'In Transit') AS in_transit,
               (SELECT COALESCE(SUM(annual_spend),0) FROM customers) AS revenue""")[0]
    upcoming = query("""
        SELECT s.shipment_no, c.name AS customer, s.destination, s.pickup, s.status
        FROM shipments s JOIN customers c ON c.id = s.customer_id
        WHERE s.status <> 'Delivered' ORDER BY s.pickup LIMIT 8""")
    return render_template("dashboard.html", stats=stats, upcoming=upcoming)


@app.route("/customers")
def customers():
    rows = query("SELECT * FROM customers ORDER BY name")
    return render_template("customers.html", rows=rows)


@app.route("/customers/<int:cid>")
def customer(cid):
    rows = query("SELECT * FROM customers WHERE id = %s", (cid,))
    if not rows:
        abort(404)
    ships = query("SELECT * FROM shipments WHERE customer_id = %s ORDER BY pickup", (cid,))
    return render_template("customer.html", c=rows[0], ships=ships)


@app.route("/shipments")
def shipments():
    rows = query("""
        SELECT s.*, c.name AS customer FROM shipments s
        JOIN customers c ON c.id = s.customer_id ORDER BY s.pickup""")
    return render_template("shipments.html", rows=rows)


@app.route("/health")
def health():
    query("SELECT 1")
    return {"status": "ok"}
