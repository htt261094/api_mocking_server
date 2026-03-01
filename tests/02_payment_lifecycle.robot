*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource

*** Variables ***
${AMOUNT}        200000
${PARTNER_CODE}    NAPAS

*** Test Cases ***
Scenario: Proxy Real Bank Requests and Mock Local Responses
    [Documentation]    Interception flow: Mock server accepts request intended for real bank, forwards it in background, and immediately returns mocked DB response.
    [Setup]    Start Mock API Session
    
    # 1. POST request to Mock Server (simulate Middleman calling the proxy instead of Real Bank)
    ${initial_balance}=    Get Wallet Balance    ${1}
    # We pass a dummy real_bank_url to ALWAYS trigger the background forwarding
    ${data}=    Create Dictionary    amount=${AMOUNT}    test_response_code=00    real_bank_url=https://httpbin.org/post
    ${response}=    POST To Bank Endpoint    ${data}
    Status Should Be    200    ${response}
    
    # 2. Extract generated IDs
    ${json}=    Set Variable    ${response.json()}
    ${CURRENT_ORDER_CODE}=    Set Variable    ${json['order_code']}
    ${CURRENT_TRANS_ID}=    Set Variable    ${json['transaction_id']}
    Should Be Equal    ${json['status']}    SUCCESS
    Should Be Equal    ${json['code']}      00
    
    Log To Console    \n---> Proxy intercepted! Created async Order: ${CURRENT_ORDER_CODE} | Transaction ID: ${CURRENT_TRANS_ID}
    Log To Console    ---> Mock Server instantly returned DB response: ${json['message']}
    
    # 3. Verify final state logic (The DB was injected INSTANTLY by the proxy mock!)
    Verify Database Order And Balance    ${CURRENT_ORDER_CODE}    SUCCESS    ${initial_balance}    ${AMOUNT}
    ${final_balance}=    Get Wallet Balance    ${1}
    Log To Console    ---> Zero waiting needed. Final Balance verified as: ${final_balance}

Scenario: Automated Wallet Refund On Bank Failure
    [Documentation]    Special flow: Create -> Activate (Deduct first) -> Bank Fail -> Verify Auto-Refund.
    [Setup]    Setup Unique Test IDs
    
    ${initial_balance}=    Get Wallet Balance    ${1}

    # 1. Create and Activate with immediate deduction
    Create Order    ${CURRENT_ORDER_CODE}    ${AMOUNT}
    Log To Console    \n---> Created Order: ${CURRENT_ORDER_CODE} | Initial Balance: ${initial_balance}
    Activate Order With Deduction    ${CURRENT_ORDER_CODE}    NAPAS    ${CURRENT_TRANS_ID}
    Log To Console    ---> Activated with Deduction for Transaction: ${CURRENT_TRANS_ID}
    
    # 2. Verify deduction occurred
    ${deducted_balance}=    Get Wallet Balance    ${1}
    ${expected_deducted}=    Evaluate    ${initial_balance} - ${AMOUNT}
    Should Be Equal As Numbers    ${deducted_balance}    ${expected_deducted}
    Log To Console    ---> Deduction Verified. Current Balance is: ${deducted_balance}

    # 3. Simulate Bank Failure (Code 01)
    Log To Console    ---> Simulating Bank Failure (Code 01) for ${CURRENT_TRANS_ID}
    Process Transaction With Refund    ${CURRENT_TRANS_ID}    01

    # 4. Verify Order is FAILED and Balance is REFUNDED
    Verify Database Order And Balance    ${CURRENT_ORDER_CODE}    FAILED    ${initial_balance}    ${AMOUNT}
    ${final_balance}=    Get Wallet Balance    ${1}
    Log To Console    ---> Auto-Refund Verified! Final balance returned to: ${final_balance}

Data Driven: Verify Outcomes by Bank Response Code
    [Documentation]    Table-driven verification for different bank result codes.
    [Template]    Verify DB Flow For Response Code
    # Code    Expected Status
    00        SUCCESS
    01        FAILED
    05        FAILED
    99        FAILED
