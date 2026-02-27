*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Variables ***
${BASE_URL}    http://127.0.0.1:8000

*** Keywords ***
Start Mock API Session
    Create Session    mock_api    ${BASE_URL}

POST To Bank Endpoint
    [Arguments]    ${data}
    ${response}=    POST On Session    mock_api    /v1/bank/payment    json=${data}
    RETURN    ${response}

GET Mock Status Response
    [Arguments]    ${status_code}
    ${response}=    GET On Session    mock_api    /mock-status/${status_code}    expected_status=${status_code}
    RETURN    ${response}

GET Bank Response
    [Arguments]    ${resp_code}    ${expected_status}
    ${response}=    GET On Session    mock_api    /v1/bank/response/${resp_code}    expected_status=${expected_status}
    RETURN    ${response}

Verify Status Endpoint
    [Arguments]    ${status_code}
    ${response}=    GET Mock Status Response    ${status_code}
    Status Should Be    ${status_code}    ${response}
