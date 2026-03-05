*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource
Force Tags    payment    happy_path


*** Test Cases ***
Scenario: Successful Payment With Standard Flow
    [Documentation]    Standard flow: Create order → Activate (no deduction) → Bank responds 00 → Order SUCCESS, wallet credited.
    [Tags]    smoke    standard
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    00

    Verify Order Status Is    SUCCESS
    Verify Wallet Was Credited With Amount

Scenario: Successful Payment With Pre-Deduction Flow
    [Documentation]    Pre-deduction flow: Create → Deduct wallet → Bank responds 00 → Order SUCCESS, no additional wallet change.
    [Tags]    pre-deduction
    [Setup]    Setup Pre-Deduction Payment Flow

    Verify Successful Deduction From Wallet

    Process Mock Bank Response And Handle Refund    00

    Verify Order Status Is    SUCCESS

Scenario: Successful Proxy Payment With Real Bank Forwarding
    [Documentation]    Proxy interception: payment with real_bank_url forwards to external AND returns mock response immediately.
    [Tags]    proxy
    [Setup]    Start Mock API Session

    Capture Initial Wallet Balance
    Simulate Proxy Bank Request    ${AMOUNT}    00    https://httpbin.org/post

    Verify Proxy Response Is Successful
    Extract State IDs From Proxy Response

    Verify Order Status Is    SUCCESS

Scenario: Verify Order State Transitions On Success
    [Documentation]    Traces order through all states: INIT → PROCESSING → SUCCESS.
    [Tags]    state
    [Setup]    Setup Unique Test IDs

    Create A New Test Order
    Verify Order Status Is Init

    Activate The Test Order Without Deduction
    Verify Order Status Is Processing

    Capture Initial Wallet Balance
    Process Mock Bank Response Standard Flow    00
    Verify Order Status Is    SUCCESS

Scenario: Verify Wallet Balance Increases On Standard Success
    [Documentation]    Confirms wallet balance = initial + order amount after a standard flow success.
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    00

    Verify Wallet Was Credited With Amount

Scenario: Verify Transaction Status Matches Order Status On Success
    [Documentation]    Both the order and the overall flow should reflect SUCCESS after bank code 00.
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    00

    Verify Order Status Is    SUCCESS
    Verify Wallet Balance Matches Status    SUCCESS
