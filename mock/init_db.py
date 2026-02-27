import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "mock.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # 1. Table orders (Manage original orders/transactions)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_code TEXT,
            amount DECIMAL,
            status TEXT CHECK(status IN ('INIT', 'PROCESSING', 'SUCCESS', 'FAILED')),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # 2. Table transactions (Transaction history with 3rd party)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER,
            partner_code TEXT,
            partner_trans_id TEXT,
            trans_status TEXT CHECK(trans_status IN ('PENDING', 'SUCCESS', 'FAILED')),
            callback_logs TEXT,
            FOREIGN KEY (order_id) REFERENCES orders(id)
        )
    """)

    # 3. Table wallets (Wallet balance - For final result verification)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS wallets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            balance DECIMAL
        )
    """)

    # 4. Table bank_responses (Mock responses stored in DB)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS bank_responses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            resp_code TEXT UNIQUE,
            resp_message TEXT,
            target_status TEXT,
            http_status INTEGER
        )
    """)

    # Seed data
    cur.execute("INSERT OR IGNORE INTO wallets (user_id, balance) VALUES (1, 1000000)")
    
    # Seed bank responses
    responses = [
        ('00', 'Success', 'SUCCESS', 200),
        ('01', 'Insufficient balance', 'FAILED', 400),
        ('05', 'System error', 'FAILED', 500),
        ('99', 'Transaction timeout', 'FAILED', 504)
    ]
    cur.executemany("INSERT OR IGNORE INTO bank_responses (resp_code, resp_message, target_status, http_status) VALUES (?, ?, ?, ?)", responses)
    
    conn.commit()
    conn.close()
    print(f"Database initialized at {DB_PATH}")

if __name__ == "__main__":
    init_db()
