*** Settings ***
Library    ../mock/db_manipulator.py
Library    Collections
Library    String

*** Variables ***
${CURRENT_ORDER_CODE}    ${None}
${CURRENT_TRANS_ID}      ${None}
${AMOUNT}                200000
${PARTNER_CODE}          NAPAS
${INITIAL_BALANCE}       ${None}

*** Keywords ***
Generate Unique Order ID
    WHILE    ${True}
        ${random}=    Generate Random String    6    [NUMBERS]
        ${order_id}=    Set Variable    ORD_${random}
        ${status}=    Get Order Status    ${order_id}
        IF    $status is None    BREAK
    END
    RETURN    ${order_id}

Generate Unique Partner Trans ID
    ${random}=    Generate Random String    8    [UPPER][NUMBERS]
    RETURN    BANK_${random}

Setup Unique Test IDs
    ${order_code}=    Generate Unique Order ID
    ${trans_id}=      Generate Unique Partner Trans ID
    Set Test Variable    ${CURRENT_ORDER_CODE}    ${order_code}
    Set Test Variable    ${CURRENT_TRANS_ID}      ${trans_id}

Verify Proxy Response And Initialize State
    [Documentation]    Analyzes the mocked proxy JSON response and sets suite variables for the rest of the test seamlessly.
    [Arguments]    ${response}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal    ${json['status']}    SUCCESS
    Should Be Equal    ${json['code']}      00
    Set Test Variable    ${CURRENT_ORDER_CODE}    ${json['order_code']}
    Set Test Variable    ${CURRENT_TRANS_ID}      ${json['transaction_id']}
    Log To Console    \n---> Proxy intercepted! Created async Order: ${CURRENT_ORDER_CODE} | Transaction ID: ${CURRENT_TRANS_ID}
    Log To Console    ---> Mock Server instantly returned DB response: ${json['message']}

Capture Initial Wallet Balance
    [Documentation]    Saves the real DB balance implicitly to state before beginning the test logic.
    ${bal}=    Get Wallet Balance    ${1}
    Set Test Variable    ${INITIAL_BALANCE}    ${bal}
    Log To Console    ---> Initial Balance Captured: ${INITIAL_BALANCE}

Verify Final Wallet Balance For Current Order
    [Documentation]    Verifies that the database successfully processed a mock payment and upgraded the balance correctly according to the current order status.
    [Arguments]    ${expected_status}
    Verify Database Order And Balance    ${CURRENT_ORDER_CODE}    ${expected_status}    ${INITIAL_BALANCE}    ${AMOUNT}
    ${final_balance}=    Get Wallet Balance    ${1}
    Log To Console    ---> Zero waiting needed. Final Balance verified as: ${final_balance}

 Create And Activate Order With Immediate Deduction
    [Documentation]    Workflow wrapper to create and activate pre-deduction.
    Create Order    ${CURRENT_ORDER_CODE}    ${AMOUNT}
    Log To Console    \n---> Created Order: ${CURRENT_ORDER_CODE}
    Activate Order With Deduction    ${CURRENT_ORDER_CODE}    NAPAS    ${CURRENT_TRANS_ID}
    Log To Console    ---> Activated with Deduction for Transaction: ${CURRENT_TRANS_ID}

Verify Successful Deduction From Wallet
    [Documentation]    Verifies that the wallet now holds INITIAL - AMOUNT.
    ${deducted_balance}=    Get Wallet Balance    ${1}
    ${expected_deducted}=    Evaluate    decimal.Decimal(str(${INITIAL_BALANCE})) - decimal.Decimal(str(${AMOUNT}))    modules=decimal
    Should Be Equal As Strings    ${deducted_balance}    ${expected_deducted}
    Log To Console    ---> Deduction Verified. Current Balance is: ${deducted_balance}

Simulate Bank Failure And Refund
    [Documentation]    Wraps the backend refund mechanism logic natively.
    [Arguments]    ${fail_code}
    Log To Console    ---> Simulating Bank Failure (Code ${fail_code}) for ${CURRENT_TRANS_ID}
    Process Transaction With Refund    ${CURRENT_TRANS_ID}    ${fail_code}

Verify Database Order And Balance
    [Arguments]    ${order_code}    ${expected_status}    ${initial_balance}    ${amount}
    ${final_status}=    Get Order Status    ${order_code}
    Should Be Equal    ${final_status}    ${expected_status}
    
    ${final_balance}=    Get Wallet Balance    ${1}
    IF    '${expected_status}' == 'SUCCESS'
        ${expected_balance}=    Evaluate    decimal.Decimal(str(${initial_balance})) + decimal.Decimal(str(${amount}))    modules=decimal
        Should Be Equal As Strings    ${final_balance}    ${expected_balance}
    ELSE
        Should Be Equal As Strings    ${final_balance}    ${initial_balance}
    END
    Log To Console    Verified Order Status: ${final_status}, Balance: ${final_balance}

Verify DB Flow For Response Code
    [Arguments]    ${code}    ${expected_status}
    Setup Unique Test IDs
    
    # Standard Flow Breakdown
    Create Order    ${CURRENT_ORDER_CODE}    ${500000}
    Activate Order    ${CURRENT_ORDER_CODE}    NAPAS    ${CURRENT_TRANS_ID}
    
    # Fetch Response and Process
    ${initial_balance}=    Get Wallet Balance    ${1}
    Process Transaction With Db Mock    ${CURRENT_TRANS_ID}    ${code}
    
    # Verify Final State
    Verify Database Order And Balance    ${CURRENT_ORDER_CODE}    ${expected_status}    ${initial_balance}    ${500000}
