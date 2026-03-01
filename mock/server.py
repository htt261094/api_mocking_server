from fastapi import FastAPI, Response, HTTPException, BackgroundTasks
from pydantic import BaseModel
import random
import time
import requests
from mock import db_manipulator

app = FastAPI()

class User(BaseModel):
    id: int
    username: str
    email: str

users = {
    1: {"id": 1, "username": "thanhht", "email": "thanhht@example.com"}
}

def send_bank_callback(callback_url: str, trans_id: str, final_status: str, delay: int = 2):
    print(f"DEBUG: [BACKGROUND] Waiting {delay} seconds before processing for {trans_id}...")
    time.sleep(delay)
    
    # Update DB automatically
    db_manipulator.force_update_transaction_status(trans_id, final_status)
    print(f"DEBUG: [BACKGROUND] Updated {trans_id} status to {final_status} in Mock DB.")
    
    # Fire webhook if URL is provided
    if callback_url:
        try:
            payload = {
                "transaction_id": trans_id,
                "status": final_status,
                "message": "Async callback from mock bank"
            }
            resp = requests.post(callback_url, json=payload, timeout=5)
            print(f"DEBUG: [BACKGROUND] Sent callback to {callback_url}. Response: {resp.status_code}")
        except Exception as e:
            print(f"DEBUG: [BACKGROUND] Failed to send callback to {callback_url}: {e}")

def forward_to_real_bank(real_bank_url: str, payload: dict):
    """Fire-and-forget proxy: send the original request to the real bank."""
    print(f"DEBUG: [PROXY] Forwarding request to REAL bank at {real_bank_url} in background...")
    try:
        # We forward the exact payload minus our mock control flags
        clean_payload = {k: v for k, v in payload.items() if k not in ["real_bank_url", "test_response_code", "callback_url", "simulate_delay"]}
        resp = requests.post(real_bank_url, json=clean_payload, timeout=10)
        print(f"DEBUG: [PROXY] Real bank responded with HTTP {resp.status_code}")
    except Exception as e:
        print(f"DEBUG: [PROXY] Failed to forward to real bank: {e}")

@app.get("/")
def read_root():
    return {"message": "Welcome to the Mock API"}

@app.get("/users/{user_id}", response_model=User)
def read_user(user_id: int):
    if user_id in users:
        return users[user_id]
    return {"error": "User not found"}

@app.post("/users/", response_model=User)
def create_user(user: User):
    users[user.id] = user.dict()
    return user

@app.post("/v1/bank/payment")
def mock_bank_payment(data: dict, background_tasks: BackgroundTasks):
    # Proxy Interception Logic
    order_code = f"ORD_{random.randint(100000, 999999)}"
    
    # Cast safely via string intermediary to prevent Python float pollution
    import decimal
    amount = decimal.Decimal(str(data.get("amount", "0")))
    
    trans_id = f"BANK_{random.randint(10000000, 99999999)}"
    
    # Control flags
    real_bank_url = data.get("real_bank_url", "")
    test_response_code = str(data.get("test_response_code", "00"))
    
    # 1. Forward to Real Bank in background (if provided)
    if real_bank_url:
        background_tasks.add_task(forward_to_real_bank, real_bank_url, data)
    
    # 2. Save interception to Mock DB (for history)
    db_manipulator.create_order_and_transaction(
        order_code=order_code,
        amount=amount,
        partner_code="MIDDLEMAN",
        partner_trans_id=trans_id
    )
    
    print(f"DEBUG: [MIDDLEMAN-PROXY] Captured call. Created mock Order {order_code}")
    
    # 3. Synchronously fetch DB Mock Response instantly
    mock_resp = db_manipulator.get_bank_response_from_db(test_response_code)
    db_manipulator.force_update_transaction_status(trans_id, mock_resp['status'])
    
    return Response(
        status_code=mock_resp["http_status"],
        content=f'{{"transaction_id": "{trans_id}", "order_code": "{order_code}", "code": "{mock_resp["code"]}", "message": "{mock_resp["message"]}", "status": "{mock_resp["status"]}"}}',
        media_type="application/json"
    )

@app.get("/v1/bank/response/{resp_code}")
def get_bank_response(resp_code: str):
    mock_resp = db_manipulator.get_bank_response_from_db(resp_code)
    if not mock_resp:
        raise HTTPException(status_code=404, detail=f"Response code {resp_code} not found")
    
    return Response(
        status_code=mock_resp["http_status"],
        content=f'{{"code": "{mock_resp["code"]}", "message": "{mock_resp["message"]}", "status": "{mock_resp["status"]}"}}',
        media_type="application/json"
    )

@app.get("/mock-status/{status_code}")
def mock_status(status_code: int):
    return Response(status_code=status_code, content=f"Returning status {status_code}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
