*** Settings ***
Library    ../mock/db_manipulator.py
Library    Collections
Library    String

*** Variables ***
${CURRENT_ORDER_CODE}    ${None}
${CURRENT_TRANS_ID}      ${None}

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

Verify Database Order And Balance
    [Arguments]    ${order_code}    ${expected_status}    ${initial_balance}    ${amount}
    ${final_status}=    Get Order Status    ${order_code}
    Should Be Equal    ${final_status}    ${expected_status}
    
    ${final_balance}=    Get Wallet Balance    ${1}
    IF    '${expected_status}' == 'SUCCESS'
        ${expected_balance}=    Evaluate    ${initial_balance} + ${amount}
        Should Be Equal As Numbers    ${final_balance}    ${expected_balance}
    ELSE
        Should Be Equal As Numbers    ${final_balance}    ${initial_balance}
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
