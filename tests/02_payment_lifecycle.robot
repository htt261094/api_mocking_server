*** Settings ***
Resource    ../resources/api_keywords.resource
Resource    ../resources/db_keywords.resource


*** Test Cases ***
Scenario: Proxy Real Bank Requests and Mock Local Responses
    [Documentation]    Interception flow: Mock server accepts request intended for real bank, forwards it in background, and immediately returns mocked DB response.
    [Setup]    Start Mock API Session
    
    # 1. Capture State and proxy request to Mock Server
    Capture Initial Wallet Balance
    ${response}=    Simulate Proxy Bank Request    ${AMOUNT}    00    https://httpbin.org/post
    
    # 2. Extract generated IDs and Verify Mock Response
    Verify Proxy Response And Initialize State    ${response}
    
    # 3. Verify final state logic (The DB was injected INSTANTLY by the proxy mock!)
    Verify Final Wallet Balance For Current Order    SUCCESS

Scenario: Automated Wallet Refund On Bank Failure
    [Documentation]    Special flow: Create -> Activate (Deduct first) -> Bank Fail -> Verify Auto-Refund.
    [Setup]    Setup Unique Test IDs
    
    # 0. Capture initial state
    Capture Initial Wallet Balance

    # 1. Create and Activate with immediate deduction
    Create And Activate Order With Immediate Deduction
    
    # 2. Verify deduction occurred correctly
    Verify Successful Deduction From Wallet

    # 3. Simulate Bank Failure (Code 01)
    Simulate Bank Failure And Refund    01

    # 4. Verify Order is FAILED and Balance is REFUNDED
    Verify Final Wallet Balance For Current Order    FAILED

Data Driven: Verify Outcomes by Bank Response Code
    [Documentation]    Table-driven verification for different bank result codes.
    [Template]    Verify DB Flow For Response Code
    # Code    Expected Status
    00        SUCCESS
    01        FAILED
    05        FAILED
    99        FAILED
