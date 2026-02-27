*** Settings ***
Resource    ../resources/api_keywords.resource
Suite Setup    Start Mock API Session

*** Test Cases ***
Verify Root Endpoint
    [Documentation]    Test the root endpoint of the mock API.
    ${response}=    GET On Session    mock_api    /
    Status Should Be    200    ${response}
    Should Contain    ${response.text}    Welcome

Verify User Retrieval
    [Documentation]    Test getting a user by ID.
    ${response}=    GET On Session    mock_api    /users/1
    Status Should Be    200    ${response}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${json['id']}    1

Verify User Creation
    [Documentation]    Test creating a new user.
    ${data}=    Create Dictionary    id=2    username=testuser    email=test@example.com
    ${response}=    POST On Session    mock_api    /users/    json=${data}
    Status Should Be    200    ${response}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${json['id']}    2

Verify Error Status Codes
    [Documentation]    Template-based verification for different error status codes.
    [Template]    Verify Status Endpoint
    400
    404
    500

Verify Bank Response HTTP Status
    [Documentation]    Verify that known bank response codes return the correct HTTP status.
    [Template]    GET Bank Response
    # Code    Expected HTTP Status
    00        200
    01        400
    05        500
    99        504
