from fastapi import FastAPI, Response, HTTPException
from pydantic import BaseModel
import random
from mock import db_manipulator

app = FastAPI()

class User(BaseModel):
    id: int
    username: str
    email: str

users = {
    1: {"id": 1, "username": "thanhht", "email": "thanhht@example.com"}
}

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
def mock_bank_payment(data: dict):
    # Middleman logic: Persistent incoming call into mock.db
    order_code = f"ORD_{random.randint(100000, 999999)}"
    amount = data.get("amount", 0)
    trans_id = f"BANK_{random.randint(10000000, 99999999)}"
    
    # Save to DB
    db_manipulator.create_order_and_transaction(
        order_code=order_code,
        amount=amount,
        partner_code="MIDDLEMAN",
        partner_trans_id=trans_id
    )
    
    print(f"DEBUG: [MIDDLEMAN] Captured call from Real Product. Created Order {order_code}")
    
    return {
        "status": "RECEIVED",
        "transaction_id": trans_id,
        "message": "Request accepted by Middleman and saved to Mock DB"
    }

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
