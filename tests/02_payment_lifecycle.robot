*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource

*** Variables ***
${AMOUNT}        200000
${PARTNER_CODE}    NAPAS

*** Test Cases ***
Scenario: Bypassing Bank Delay via State Injection
    [Documentation]    Normal flow: Create -> Wait (Simulated) -> Manual DB Status Injection -> Verify Success.
    [Setup]    Setup Unique Test IDs
    
    # 1. Create Order and Transaction (Status starts at PENDING)
    Create Order And Transaction    ${CURRENT_ORDER_CODE}    ${AMOUNT}    ${PARTNER_CODE}    ${CURRENT_TRANS_ID}
    Log To Console    \n---> Created Order: ${CURRENT_ORDER_CODE} | Transaction ID: ${CURRENT_TRANS_ID} | Amount: ${AMOUNT}
    
    # 2. Verify Processing status
    ${status}=    Get Order Status    ${CURRENT_ORDER_CODE}
    Should Be Equal    ${status}    PROCESSING
    ${initial_balance}=    Get Wallet Balance    ${1}
    Log To Console    ---> Status is Processing. Initial Balance: ${initial_balance}

    # 3. Simulate system waiting (delay)
    Log To Console    System is waiting for Bank callback (Simulating 2s delay)...
    Sleep    2s

    # 4. State Injection: Force SUCCESS status in DB
    Log To Console    ---> Injecting SUCCESS status into DB for ${CURRENT_TRANS_ID}
    Force Update Transaction Status    ${CURRENT_TRANS_ID}    SUCCESS

    # 5. Verify final state logic
    Verify Database Order And Balance    ${CURRENT_ORDER_CODE}    SUCCESS    ${initial_balance}    ${AMOUNT}
    ${final_balance}=    Get Wallet Balance    ${1}
    Log To Console    ---> Final Balance verified as: ${final_balance}

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
