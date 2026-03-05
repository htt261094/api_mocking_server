*** Settings ***
Resource    ../resources/api_keywords.resource
Force Tags    api
Suite Setup    Start Mock API Session

*** Test Cases ***
Scenario: Verify Root Endpoint
    [Documentation]    Test the root endpoint of the mock API.
    [Tags]    smoke    status
    Verify Root Returns Welcome Message

Scenario: Verify User Retrieval
    [Documentation]    Test getting a user by ID.
    [Tags]    user
    Verify User Retrieval By ID

Scenario: Verify User Creation
    [Documentation]    Test creating a new user.
    [Tags]    user    smoke
    Verify New User Can Be Created

Data Driven: Verify Error Status Codes
    [Documentation]    Template-based verification for different error status codes.
    [Tags]    status
    [Template]    Verify Status Endpoint
    400
    404
    500

Data Driven: Verify Bank Response HTTP Status
    [Documentation]    Verify that known bank response codes return the correct HTTP status.
    [Template]    Verify Bank Response Code Returns Expected Status
    # Code    Expected HTTP Status
    00        200
    01        400
    05        500
    99        504

