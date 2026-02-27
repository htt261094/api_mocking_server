import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "mock.db")

def create_order(order_code, amount):
    """
    Step 1: Create a new order with status 'INIT'.
    """
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO orders (order_code, amount, status) VALUES (?, ?, 'INIT')",
        (order_code, amount)
    )
    order_id = cur.lastrowid
    conn.commit()
    cur.close()
    conn.close()
    return order_id

def activate_order(order_code, partner_code, partner_trans_id):
    """
    Step 2: Update order to 'PROCESSING' and create a PENDING transaction.
    """
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    cur.execute("UPDATE orders SET status = 'PROCESSING' WHERE order_code = ?", (order_code,))
    cur.execute("SELECT id FROM orders WHERE order_code = ?", (order_code,))
    row = cur.fetchone()
    if not row:
        conn.close()
        raise ValueError(f"Order {order_code} not found")
    
    order_id = row[0]
    cur.execute(
        "INSERT INTO transactions (order_id, partner_code, partner_trans_id, trans_status) VALUES (?, ?, ?, 'PENDING')",
        (order_id, partner_code, partner_trans_id)
    )
    
    conn.commit()
    cur.close()
    conn.close()

def activate_order_with_deduction(order_code, partner_code, partner_trans_id):
    """
    Special Step 2: Activate order and deduct balance from wallet (PRE-PAYMENT).
    """
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Get order amount
    cur.execute("SELECT id, amount FROM orders WHERE order_code = ?", (order_code,))
    row = cur.fetchone()
    if not row:
        conn.close()
        raise ValueError(f"Order {order_code} not found")
    
    order_id, amount = row
    
    # Update order and create transaction
    cur.execute("UPDATE orders SET status = 'PROCESSING' WHERE id = ?", (order_id,))
    cur.execute(
        "INSERT INTO transactions (order_id, partner_code, partner_trans_id, trans_status) VALUES (?, ?, ?, 'PENDING')",
        (order_id, partner_code, partner_trans_id)
    )
    
    # Deduct from wallet (Assume user_id 1)
    print(f"DEBUG: [WALLET] Deducting {amount} from wallet for order {order_code}...")
    cur.execute("UPDATE wallets SET balance = balance - ? WHERE user_id = 1", (amount,))
    
    conn.commit()
    cur.close()
    conn.close()

def get_bank_response_from_db(resp_code):
    """
    Step 3: Get mock response code and message from DB.
    """
    print(f"DEBUG: [DB_MOCK] Fetching mock response for code '{resp_code}' from bank_responses table...")
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT resp_code, resp_message, target_status, http_status FROM bank_responses WHERE resp_code = ?", (resp_code,))
    row = cur.fetchone()
    conn.close()
    if row:
        print(f"DEBUG: [DB_MOCK] Found response: {row[1]} (Target status: {row[2]}, HTTP: {row[3]})")
        return {"code": row[0], "message": row[1], "status": row[2], "http_status": row[3]}
    print(f"DEBUG: [DB_MOCK] !!! No response found for code '{resp_code}' in DB !!!")
    return None

def process_transaction_with_refund(partner_trans_id, resp_code):
    """
    Advanced Step 4: Process transaction with automatic logic for success or refund on failure.
    """
    mock_resp = get_bank_response_from_db(resp_code)
    if not mock_resp:
        raise ValueError(f"Mock response code {resp_code} not found in DB")
    
    target_status = mock_resp['status'] # SUCCESS or FAILED
    
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Update transaction
    cur.execute(
        "UPDATE transactions SET trans_status = ?, callback_logs = ? WHERE partner_trans_id = ?",
        (target_status, mock_resp['message'], partner_trans_id)
    )
    
    # Get order details
    cur.execute("""
        SELECT o.id, o.amount, o.status FROM orders o 
        JOIN transactions t ON o.id = t.order_id 
        WHERE t.partner_trans_id = ?
    """, (partner_trans_id,))
    row = cur.fetchone()
    
    if row:
        order_id, amount, current_order_status = row
        cur.execute("UPDATE orders SET status = ? WHERE id = ?", (target_status, order_id))
        
        # LOGIC: If FAILED, refund the wallet
        if target_status == 'FAILED':
            print(f"DEBUG: [WALLET] Bank failed with code {resp_code}. Refunding {amount} to wallet...")
            cur.execute("UPDATE wallets SET balance = balance + ? WHERE user_id = 1", (amount,))
        # (Note: If Success, we don't add balance because it was already deducted in activate_order_with_deduction)
    
    conn.commit()
    cur.close()
    conn.close()
    return mock_resp

def process_transaction_with_db_mock(partner_trans_id, resp_code):
    """
    Backward compatibility: Standard flow (add balance on success).
    """
    mock_resp = get_bank_response_from_db(resp_code)
    if not mock_resp:
        raise ValueError(f"Mock response code {resp_code} not found in DB")
    
    target_status = mock_resp['status']
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("UPDATE transactions SET trans_status = ?, callback_logs = ? WHERE partner_trans_id = ?", (target_status, mock_resp['message'], partner_trans_id))
    cur.execute("""
        SELECT o.id, o.amount FROM orders o 
        JOIN transactions t ON o.id = t.order_id 
        WHERE t.partner_trans_id = ?
    """, (partner_trans_id,))
    row = cur.fetchone()
    if row:
        order_id, amount = row
        cur.execute("UPDATE orders SET status = ? WHERE id = ?", (target_status, order_id))
        if target_status == 'SUCCESS':
            cur.execute("UPDATE wallets SET balance = balance + ? WHERE user_id = 1", (amount,))
    conn.commit()
    cur.close()
    conn.close()
    return mock_resp

def get_order_status(order_code):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT status FROM orders WHERE order_code = ?", (order_code,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else None

def get_wallet_balance(user_id):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT balance FROM wallets WHERE user_id = ?", (user_id,))
    row = cur.fetchone()
    conn.close()
    return float(row[0]) if row else 0.0

# Backward compatibility wrappers
def create_order_and_transaction(order_code, amount, partner_code, partner_trans_id):
    order_id = create_order(order_code, amount)
    activate_order(order_code, partner_code, partner_trans_id)
    return order_id

def force_update_transaction_status(transaction_id, status):
    resp_code = '00' if status == 'SUCCESS' else '99'
    process_transaction_with_db_mock(transaction_id, resp_code)
