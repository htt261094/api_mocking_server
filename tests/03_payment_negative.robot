*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource
Suite Setup    Start Mock API Session
Force Tags    payment    negative


*** Test Cases ***
Scenario: Bank Insufficient Balance Failure
    [Documentation]    Bank response code 01 → order FAILED, HTTP 400.
    [Tags]    fail-01
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    01

    Verify Order Status Is    FAILED
    Verify Wallet Balance Is Unchanged

Scenario: Bank System Error Failure
    [Documentation]    Bank response code 05 → order FAILED, HTTP 500.
    [Tags]    fail-05
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    05

    Verify Order Status Is    FAILED
    Verify Wallet Balance Is Unchanged

Scenario: Bank Transaction Timeout Failure
    [Documentation]    Bank response code 99 → order FAILED, HTTP 504.
    [Tags]    fail-99
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    99

    Verify Order Status Is    FAILED
    Verify Wallet Balance Is Unchanged

Scenario: Wallet Refund On Bank Failure After Pre-Deduction
    [Documentation]    Pre-deduction flow: wallet deducted first → bank fails → wallet auto-refunded to original.
    [Tags]    refund
    [Setup]    Setup Pre-Deduction Payment Flow

    Verify Successful Deduction From Wallet

    Process Mock Bank Response And Handle Refund    01

    Verify Order Status Is    FAILED
    Verify Wallet Was Refunded After Failure

Scenario: No Wallet Change On Standard Flow Bank Failure
    [Documentation]    Standard flow (no pre-deduction): bank fails → wallet stays exactly the same.
    [Setup]    Setup Standard Payment Flow

    Process Mock Bank Response Standard Flow    05

    Verify Order Status Is    FAILED
    Verify Wallet Balance Is Unchanged

Scenario: Unknown Bank Response Code Returns Not Found
    [Documentation]    Requesting a non-existent bank response code returns HTTP 404.
    [Setup]    Start Mock API Session

    Verify Unknown Bank Response Code Returns Not Found

Scenario: Retrieve Non-Existent User
    [Documentation]    GET /users/999 returns an error response, not a crash.
    [Setup]    Start Mock API Session

    Verify Non-Existent User Returns Error

Data Driven: All Failure Codes Produce Failed Status
    [Documentation]    Template: verify all known failure bank codes result in order FAILED.
    [Template]    Verify Full Standard Flow For Code
    # Code    Expected Status
    01        FAILED
    05        FAILED
    99        FAILED
