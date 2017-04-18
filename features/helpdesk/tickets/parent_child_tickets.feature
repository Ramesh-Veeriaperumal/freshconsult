@admin @adv_ticketing
Feature: Parent child tickets

  Background: Enable parent child tickets.
    Given "parent_child_tickets" feature is enabled for the accounts

  @db_clean @ticket_dynamo_clean
  Scenario: Creating a child ticket manually to a normal ticket
    Given a ticket with subject "Employee onboarding"
    When we create child ticket with the subject "ID card issue" for a ticket "Employee onboarding"
    Then child ticket "ID card issue" should get created
    And the ticket "Employee onboarding" should associated as a parent ticket
    And we should get redirected to the ticket "Employee onboarding"
    And the ticket "ID card issue" should be linked to the parent "Employee onboarding"
    And the parent should have "1" child ticket "ID card issue"

  Scenario: Creating a child ticket manually to an existing parent ticket.
    Given a parent with subject "Employee IT Tax"
    When we create child ticket with the subjt "Form 16" for a ticket "Employee IT Tax"
    Then child ticket should get created
    And we should get redirected to the ticket "Employee IT Tax"
    And the ticket "Form 16" should be linked to the parent "Employee IT Tax"
    And the parent should have "2" child tickets

  # Scenario: Creating multiple child tickets to a ticket using template
  #   Given a ticket with subject "Product Mgr onboarding"
  #   When we create a multiple child tickets to a ticket "Product Mgr onboarding"
  #   Then child tickets "4" should get created
  #   And the ticket "Product Mgr onboarding" should associated as a parent ticket
  #   And we should get redirected to the ticket "Product Mgr onboarding"

  # Scenario: Creating parent and multiple child tickets using template
  #   Given a ticket with subject "Product Mgr onboarding" using template
  #   When we create a multiple child tickets to a parent ticket "Product Mgr onboarding"
  #   Then a parent ticket "Product Mgr onboarding" is created
  #   And all child tickets "5" should get created

  Scenario: Creating child ticket to the closed parent ticket
    Given a parent ticket with subject "Developer onboard" and the status resolved
    When we create child ticket with the subject "Goodies" for a prt ticket "Developer onboard"
    Then child ticket "Goodies" should get created with unresolved status
    And the parent ticket "Developer onboard" should get reopened

  Scenario: Reopening child ticket to the closed parent ticket
    Given parent ticket with subject "Developer onboard" and child ticket with the subject "Credentials are not working"
    When we reopen child ticket with the subject "Credentials are not working"
    Then child tkt "Credentials are not working" should get reopened
    And the parent tkt "Developer onboard" should get reopened

  Scenario: Creating child ticket with resolved status to the closed parent ticket
    Given a parent tkt with subject "QA engineer onboard"
    When we create child ticket with the subject "Recevied Goodies" and status resolved for a ticket "QA engineer onboard"
    Then child ticket should get created "Recevied Goodies"
    And the parent ticket "QA engineer onboard" should not get reopened
    And we should get redirected to the ticket "QA engineer onboard"

  Scenario: Closing the parent ticket which has unresolved child tickets
    Given a parent ticket with subject "Employee onboarding" and a child ticket "Bank Account" with unresolved status
    When we trying closing a parent ticket "Employee onboarding" which has unresolved child ticket "Bank Account"
    Then the parent ticket should not get closed

  Scenario: A parent ticket should have only 10 child tickets
    Given a parent tkt "Product Mgr" with 10 child tickets
    Then try creating one more child ticket "support acc access" for the parent ticket
    And the child ticket "support acc access" shouldn't be created

  Scenario Outline: Deleting/Spamming a Parent ticket.
    Given a parent tkt "<ParentSubject>" with these child tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Parent Tkt "<ParentSubject>"
    Then the Parent Ticket "<ParentSubject>" should be moved to <Destination>
    And the child tickets should be unlinked from the parent and become normal tkts
    Examples:
     | ParentSubject           | Subject1      | Subject2  | Action | Destination  |
     | Onboard a new dgnr uniq | Bank Accounts | Rule book | Delete | Trash Folder |
     |  IT Tax                 | Form 16       | Form 18c  | Spam   | SpamFolder   |

  Scenario Outline: Deleting/Spamming a Parent ticket and undo it.
    Given a parent tkt "<ParentSubject>" with these child tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Parent Tkt "<ParentSubject>"
    And I Undo the action for Parent tkt "<ParentSubject>"
    Then the Parent tkt "<ParentSubject>" should have "0" child tickets
    And the child tickets should be unlinked from the parent and become normal tkts
    Examples:
     | ParentSubject           | Subject1      | Subject2  | Action | Destination  |
     | Onboard a new designer-1| Bank Accounts | Rule book | Delete | Trash Folder |
     |  IT Tax - 1             | Form 16       | Form 18c  | Spam   | SpamFolder   |

 Scenario Outline: Deleting/Spamming a Child ticket.
    Given a parent tkt "<ParentSubject>" with these child tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Child Ticket "<Subject2>"
    Then the Child Ticket "<Subject2>" should be moved to <Destination>
    And the Child ticket "<Subject2>" should become a normal ticket
    And the child tickets for the Parent "<ParentSubject>" should be decremented by "1"
    Examples:
     | ParentSubject           | Subject1      | Subject2  | Action | Destination  |
     | Onboard a new designer-2| Bank Accounts | Rule book | Delete | Trash Folder |
     |  IT Tax - 2             | Form 16       | Form 18c  | Spam   | SpamFolder   |


  Scenario Outline: Deleting/Spamming a Child ticket and Undo it.
    Given a parent tkt "<ParentSubject>" with these child tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Child Ticket "<Subject1>"
    And I Undo the action for tkt "<Subject1>"
    Then the Child ticket "<Subject1>" should become a normal ticket
    And the child tickets for the Parent "<ParentSubject>" should be decremented by "1"
    Examples:
     | ParentSubject           | Subject1      | Subject2  | Action | Destination  |
     | Onboard a new designer-3| Bank Accounts | Rule book | Delete | Trash Folder |
     |  IT Tax - 3             | Form 16       | Form 18c  | Spam   | SpamFolder   |