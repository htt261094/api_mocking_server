*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource
Force Tags    payment    e2e


*** Test Cases ***
Scenario: Complete Payment Lifecycle Standard Flow
    [Documentation]    Full E2E: Create → Activate → Bank Success → Verify order SUCCESS + wallet credited.
    [Tags]    smoke    lifecycle
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    00

    Verify Order Status Is    SUCCESS
    Verify Wallet Was Credited With Amount

Scenario: Complete Payment Lifecycle Pre-Deduction Flow
    [Documentation]    Full E2E: Create → Deduct → Bank Success → Verify order SUCCESS + wallet correctly settled.
    [Tags]    lifecycle
    [Setup]    Setup Pre-Deduction Payment Flow

    Verify Successful Deduction From Wallet

    Process Mock Bank Response And Handle Refund    00

    Verify Order Status Is    SUCCESS

Scenario: Payment Success Then Query Bank Response
    [Documentation]    Full payment flow, then verify GET /v1/bank/response/00 matches the success template.
    [Setup]    Start Mock API Session

    # 1. Execute full proxy payment
    Capture Initial Wallet Balance
    Simulate Proxy Bank Request    ${AMOUNT}    00    https://httpbin.org/post
    Verify Proxy Response Is Successful
    Extract State IDs From Proxy Response

    # 2. Independently query the bank response template
    Verify Bank Response Code Returns Expected Status    00    200

Scenario: Payment Failure With Auto-Refund End To End
    [Documentation]    Complete refund flow: fund wallet → deduct → bank fails (01) → auto-refund → wallet restored.
    [Tags]    refund
    [Setup]    Setup Pre-Deduction Payment Flow

    # 1. Verify deduction occurred
    Verify Successful Deduction From Wallet

    # 2. Bank fails
    Process Mock Bank Response And Handle Refund    01

    # 3. Verify everything is restored
    Verify Order Status Is    FAILED
    Verify Wallet Was Refunded After Failure

Scenario: Sequential Payments Accumulate Wallet Balance
    [Documentation]    Two successive standard-flow successes: wallet = initial + amount1 + amount2.
    [Tags]    accumulation
    [Setup]    Start Mock API Session

    Capture Initial Wallet Balance

    # Payment 1
    Setup Unique Test IDs
    Create A New Test Order
    Activate The Test Order Without Deduction
    Process Mock Bank Response Standard Flow    00
    Verify Order Status Is    SUCCESS

    # Payment 2
    Setup Unique Test IDs
    Create A New Test Order
    Activate The Test Order Without Deduction
    Process Mock Bank Response Standard Flow    00
    Verify Order Status Is    SUCCESS

    # Verify accumulated balance
    Verify Wallet Accumulated Two Payments

Data Driven: Full E2E Flow For All Bank Response Codes
    [Documentation]    Template: tests the complete standard flow outcome for every known bank response code.
    [Template]    Verify Full Standard Flow For Code
    # Code    Expected Status
    00        SUCCESS
    01        FAILED
    05        FAILED
    99        FAILED
