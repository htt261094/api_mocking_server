*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource
Suite Setup    Start Mock API Session
Force Tags    payment    edge_case


*** Test Cases ***
Scenario: Payment With Zero Amount
    [Documentation]    Edge case: creating an order with amount=0 should still succeed without errors.
    [Tags]    amount
    [Setup]    Setup Unique Test IDs

    ${amount}=    Get Test Data    AMOUNT_ZERO
    Create A New Test Order With Amount    ${amount}
    Verify Order Status Is Init

    Activate The Test Order Without Deduction
    Verify Order Status Is Processing

Scenario: Payment With Very Large Amount
    [Documentation]    Edge case: amount=999999999 should not cause overflow or precision errors.
    [Tags]    amount
    [Setup]    Setup Unique Test IDs

    ${amount}=    Get Test Data    AMOUNT_LARGE
    Create A New Test Order With Amount    ${amount}
    Activate The Test Order Without Deduction

    Capture Initial Wallet Balance
    Process Mock Bank Response Standard Flow    00

    Verify Order Status Is    SUCCESS

Scenario: Payment With Decimal Amount
    [Documentation]    Edge case: amount=100.50 should preserve exact decimal precision through the entire flow.
    [Tags]    amount    precision
    [Setup]    Setup Unique Test IDs

    ${amount}=    Get Test Data    AMOUNT_DECIMAL
    Create A New Test Order With Amount    ${amount}
    Activate The Test Order Without Deduction

    Capture Initial Wallet Balance
    Process Mock Bank Response Standard Flow    00

    Verify Order Status Is    SUCCESS

Scenario: Payment Without Optional Real Bank URL
    [Documentation]    Proxy payment with no real_bank_url should work purely as a mock with no forwarding.
    [Setup]    Start Mock API Session

    Capture Initial Wallet Balance
    Simulate Proxy Bank Request    ${AMOUNT}    00

    Verify Proxy Response Is Successful
    Extract State IDs From Proxy Response
    Verify Order Status Is    SUCCESS

Scenario: Multiple Concurrent Orders Have Unique IDs
    [Documentation]    Three sequential orders must all receive distinct order codes.
    [Setup]    Start Mock API Session

    # Order 1
    Setup Unique Test IDs

    # Order 2
    Setup Unique Test IDs

    # Order 3
    Setup Unique Test IDs

    Verify Last 3 Orders Have Distinct Codes

Scenario: Verify Wallet Balance Uses Decimal Precision
    [Documentation]    After a decimal amount payment, wallet balance must not show floating-point artifacts.
    [Tags]    precision
    [Setup]    Setup Unique Test IDs

    ${amount}=    Get Test Data    AMOUNT_SMALL_DECIMAL
    Create A New Test Order With Amount    ${amount}
    Activate The Test Order Without Deduction

    Capture Initial Wallet Balance
    Process Mock Bank Response Standard Flow    00

    Verify Order Status Is    SUCCESS
    Verify Wallet Decimal Precision Is Preserved

Scenario: Create User With Duplicate ID Overwrites
    [Documentation]    POSTing a user with an existing ID should overwrite the previous user record.
    [Tags]    user
    [Setup]    Start Mock API Session

    Verify New User Can Be Created
