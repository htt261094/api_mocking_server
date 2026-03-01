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
${PROXY_RESPONSE}        ${None}

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

Verify Proxy Response Is Successful
    ${json}=    Set Variable    ${PROXY_RESPONSE.json()}
    Should Be Equal    ${json['status']}    SUCCESS
    Should Be Equal    ${json['code']}      00

Extract State IDs From Proxy Response
    ${json}=    Set Variable    ${PROXY_RESPONSE.json()}
    Set Test Variable    ${CURRENT_ORDER_CODE}    ${json['order_code']}
    Set Test Variable    ${CURRENT_TRANS_ID}      ${json['transaction_id']}
    Log To Console    \n---> Proxy intercepted! Created async Order: ${CURRENT_ORDER_CODE} | Transaction ID: ${CURRENT_TRANS_ID}

Capture Initial Wallet Balance
    [Documentation]    Saves the real DB balance implicitly to state before beginning the test logic.
    ${bal}=    Get Wallet Balance    ${1}
    Set Test Variable    ${INITIAL_BALANCE}    ${bal}
    Log To Console    ---> Initial Balance Captured: ${INITIAL_BALANCE}

Verify Order Status Is
    [Arguments]    ${expected_status}
    ${final_status}=    Get Order Status    ${CURRENT_ORDER_CODE}
    Should Be Equal    ${final_status}    ${expected_status}
    Log To Console    ---> Order Status Verified as: ${final_status}

Verify Wallet Balance Matches Status
    [Arguments]    ${expected_status}
    ${final_balance}=    Get Wallet Balance    ${1}
    IF    '${expected_status}' == 'SUCCESS'
        ${expected_balance}=    Evaluate    decimal.Decimal(str(${INITIAL_BALANCE})) + decimal.Decimal(str(${AMOUNT}))    modules=decimal
        Should Be Equal As Strings    ${final_balance}    ${expected_balance}
    ELSE
        Should Be Equal As Strings    ${final_balance}    ${INITIAL_BALANCE}
    END
    Log To Console    ---> Balance Verified for Status ${expected_status}: ${final_balance}

Create A New Test Order
    Create Order    ${CURRENT_ORDER_CODE}    ${AMOUNT}
    Log To Console    \n---> Created Order: ${CURRENT_ORDER_CODE}

Activate The Test Order With Deduction
    Activate Order With Deduction    ${CURRENT_ORDER_CODE}    NAPAS    ${CURRENT_TRANS_ID}
    Log To Console    ---> Activated with Deduction for Transaction: ${CURRENT_TRANS_ID}

Activate The Test Order Without Deduction
    Activate Order    ${CURRENT_ORDER_CODE}    NAPAS    ${CURRENT_TRANS_ID}
    Log To Console    ---> Activated without Deduction for Transaction: ${CURRENT_TRANS_ID}

Verify Successful Deduction From Wallet
    [Documentation]    Verifies that the wallet now holds INITIAL - AMOUNT.
    ${deducted_balance}=    Get Wallet Balance    ${1}
    ${expected_deducted}=    Evaluate    decimal.Decimal(str(${INITIAL_BALANCE})) - decimal.Decimal(str(${AMOUNT}))    modules=decimal
    Should Be Equal As Strings    ${deducted_balance}    ${expected_deducted}
    Log To Console    ---> Deduction Verified. Current Balance is: ${deducted_balance}

Process Mock Bank Response And Handle Refund
    [Documentation]    Wraps the backend refund mechanism logic natively to simulate bank response processing.
    [Arguments]    ${code}
    Log To Console    ---> Processing Mock Bank Response (Code ${code}) for ${CURRENT_TRANS_ID}
    Process Transaction With Refund    ${CURRENT_TRANS_ID}    ${code}

Process Mock Bank Response Standard Flow
    [Documentation]    Processes bank response without pre-deduction mechanism.
    [Arguments]    ${code}
    Log To Console    ---> Processing Mock Bank Response (Standard) (Code ${code}) for ${CURRENT_TRANS_ID}
    Process Transaction With Db Mock    ${CURRENT_TRANS_ID}    ${code}

Verify DB Flow For Response Code
    [Arguments]    ${code}    ${expected_status}
    Setup Unique Test IDs
    
    # 1. Create and Activate without deduction
    Create A New Test Order
    Activate The Test Order Without Deduction
    
    # 2. Process Response
    Capture Initial Wallet Balance
    Process Mock Bank Response Standard Flow    ${code}
    
    # 3. Verify Final State
    Verify Order Status Is    ${expected_status}
    Verify Wallet Balance Matches Status    ${expected_status}
