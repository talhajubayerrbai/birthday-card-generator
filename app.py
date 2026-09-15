import os
import uuid
import sqlite3
from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, abort

app = Flask(__name__)

DB_PATH = os.environ.get("DB_PATH", "cards.db")

# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS cards (
                id       TEXT PRIMARY KEY,
                recipient TEXT NOT NULL,
                sender    TEXT NOT NULL,
                style     TEXT NOT NULL,
                message   TEXT NOT NULL,
                created   TEXT NOT NULL
            )
        """)
        conn.commit()


init_db()

# ---------------------------------------------------------------------------
# Card styles
# ---------------------------------------------------------------------------

STYLES = [
    {"key": "sunshine",  "label": "☀️  Sunshine",   "bg": "#FFF9C4", "accent": "#F9A825", "text": "#4E342E"},
    {"key": "ocean",     "label": "🌊  Ocean",       "bg": "#E3F2FD", "accent": "#1565C0", "text": "#0D2137"},
    {"key": "rose",      "label": "🌹  Rose",        "bg": "#FCE4EC", "accent": "#C62828", "text": "#3E0000"},
    {"key": "forest",   "label": "🌿  Forest",      "bg": "#E8F5E9", "accent": "#2E7D32", "text": "#1B2E1C"},
    {"key": "midnight", "label": "🌙  Midnight",    "bg": "#1A1A2E", "accent": "#E94560", "text": "#E0E0E0"},
    {"key": "candy",    "label": "🍭  Candy",       "bg": "#F3E5F5", "accent": "#7B1FA2", "text": "#2E003E"},
]

STYLE_MAP = {s["key"]: s for s in STYLES}

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/", methods=["GET"])
def index():
    return render_template("index.html", styles=STYLES)


@app.route("/create", methods=["POST"])
def create():
    recipient = request.form.get("recipient", "").strip()
    sender    = request.form.get("sender",    "").strip()
    style_key = request.form.get("style",     "sunshine")
    message   = request.form.get("message",   "").strip()

    if not recipient or not sender:
        return redirect(url_for("index"))

    if style_key not in STYLE_MAP:
        style_key = "sunshine"

    if not message:
        message = f"Happy Birthday, {recipient}! 🎂 Wishing you an amazing day filled with joy!"

    card_id = str(uuid.uuid4())[:8]
    created = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    with get_db() as conn:
        conn.execute(
            "INSERT INTO cards (id, recipient, sender, style, message, created) VALUES (?,?,?,?,?,?)",
            (card_id, recipient, sender, style_key, message, created)
        )
        conn.commit()

    return redirect(url_for("view_card", card_id=card_id))


@app.route("/card/<card_id>")
def view_card(card_id):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM cards WHERE id = ?", (card_id,)).fetchone()
    if row is None:
        abort(404)
    style = STYLE_MAP.get(row["style"], STYLES[0])
    return render_template("card.html", card=row, style=style)


@app.route("/health")
def health():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
