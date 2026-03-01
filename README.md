# API Mocking & Testing Project

This project provides a complete framework for API testing using **Robot Framework** and a **FastAPI** mock server. It is designed to simulate complex financial flows, including database-driven responses and wallet management, without needing a real bank backend.

## 🚀 Quick Start

1.  **Requirement**: Python 3.10
2.  **Setup**:
    ```bash
    source venv/bin/activate
    pip install -r requirements.txt
    python mock/init_db.py  # Initialize the SQLite DB
    ```
3.  **Run All Tests**:
    ```bash
    python run.py
    ```

---

## 🏗 Project Architecture

### 1. Mock Server (`mock/server.py`)
A FastAPI server that acts as a "Middleman". It captures incoming bank payment calls and saves them to the local database instead of forwarding them to a real partner.
- **Endpoints**:
    - `POST /v1/bank/payment`: Simulates bank API, persists data to DB.
    - `GET /mock-status/{code}`: Returns various HTTP statuses for error handling tests.

### 2. Database Layer (`mock/mock.db`)
A local SQLite database used to store state and drive mock logic.
- **Tables**: `orders`, `transactions`, `wallets`, `bank_responses`.
- **Logic**: The `mock/db_manipulator.py` script handles all direct database logic (State Injection).

### 3. Test Suites (`tests/`)
- `01_api_suite.robot`: Standard API functional tests.
- `02_payment_lifecycle.robot`: End-to-end payment lifecycle, verifying wallet refund logic, and DB-driven mock responses.

---

## 🛠 Key Features

### State Injection
We bypass external delays (like waiting for a bank callback) by directly updating the database.
- **Scenario**: Create Order -> Wait -> Inject `SUCCESS` into DB -> Verify Wallet.
- **Read**: `tests/02_payment_lifecycle.robot` to see the implementation.

### DB-Driven Mocking
Instead of hardcoding "Success" or "Fail", the mock server reads the desired outcome from the `bank_responses` table.
- **Read**: `mock/db_manipulator.py` -> `get_bank_response_from_db`.

### Wallet Refund Logic
Ensures user funds are protected. If a bank call is captured and then marked as failed, the system automatically refunds the pre-deducted amount to the user's wallet.
- **Read**: `tests/02_payment_lifecycle.robot`.

---

## 📖 Recommended Reading Order
If you are new to the project, read files in this order:
1.  **`mock/init_db.py`**: Understand the data structure.
2.  **`resources/db_keywords.resource`**: See how we bridge Robot Framework with Python logic.
3.  **`tests/02_payment_lifecycle.robot`**: Understand the core "State Injection" testing philosophy.
4.  **`mock/server.py`**: See how the "Middleman" captures real API calls.

---

## 💻 IDE Tips (VS Code)
- Install the **RobotCode** extension.
- Ensure the Python Interpreter is set to `./venv/bin/python`.
- Use the **Testing** tab in VS Code to run individual test cases via the Play icons.
