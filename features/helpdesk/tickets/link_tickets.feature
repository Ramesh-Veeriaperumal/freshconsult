@admin @link_tickets
Feature: Linked tickets

  Background: Enable Link tickets.
    Given "link_tickets" feature is enabled for the account

  @db_clean @ticket_dynamo_clean
  Scenario: Linking a ticket to a new Tracker ticket.
    Given a Ticket with subject "Cant use Freshdesk"
    When I link the ticket "Cant use Freshdesk" by creating a new Tracker with the subject "Server Down"
    Then the Tracker "Server Down" should get created
    And I should get redirected to the ticket "Cant use Freshdesk"
    And the ticket "Cant use Freshdesk" should be linked to the tracker
    And the tracker should have "1" related ticket "Cant use Freshdesk"

  Scenario: Linking a ticket to an existing tracker.
    Given a Ticket with subject "Create Company Error"
    And a tracker ticket "Downtime Error #49"
    And the Tracker has these broadcast notes:
      | Debugging the Issue  |
      | Found the root cause |
      | Fixed the Issue      |
    When I link the ticket "Create Company Error" to Tracker "Downtime Error #49"
    Then the ticket "Create Company Error" should be linked to the tracker
    And the ".broadcast_message_box" in the ticket "Create Company Error" should display "Fixed the Issue"
    And the Tracker should have the ticket "Create Company Error" as its related

  Scenario: Linking multiple tickets to a new Tracker ticket.
    Given these tickets:
      | 404 Error          |
      | Server Not Found   |
      | Issue in accessing |
    When I link these tickets by creating a new Tracker with the subject "Scheduled Maintenence"
    Then I should get redirected to "/helpdesk/tickets"
    And the Tracker should get created with "3" related tickets
    And all the tickets should be linked to the Tracker "Scheduled Maintenence"

  Scenario: Linking multiple tickets to an existing Tracker ticket.
    Given these tickets:
      | Ticket Not found |
      | Chat with John   |
      | Login Page       |
    And a tracker ticket "Ticket States issue"
    When I link the tickets to Tracker "Ticket States issue"
    And the related tickets count of the Tracker "Ticket States issue" should get incremented by "3"
    And all the tickets should be linked to the Tracker "Ticket States issue"

  Scenario: Unlink a Related ticket from its Tracker.
    Given a Related ticket with subject "Call with Rachel" linked to a Tracker "Company fields Bug"
    And the Tracker has these broadcast notes:
      | Debugging the Issue  |
      | Found the root cause |
      | Fixed the Issue      |
    When I unlink the Related ticket "Call with Rachel" from its Tracker
    Then the related tickets for the Tracker "Company fields Bug" should be decremented by "1"
    And the Related ticket "Call with Rachel" should become a normal ticket
    And the unlinked ticket should not have the message "Fixed the Issue"

  Scenario Outline: Deleting/Spamming a Tracker ticket.
    Given a Tracker ticket "<TrackerSubject>" with the these related tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Ticket "<TrackerSubject>"
    Then the Ticket "<TrackerSubject>" should be moved to <Destination>
    And the related tickets should be unlinked from the tracker and become normal tickets
    Examples:
     | TrackerSubject | Subject1            | Subject2        | Action | Destination  |
     |  Login issue   | Agent logout        | Login fails     | Delete | Trash Folder |
     |  Favicon Issue | Problem with favicon| Chat with Jill  | Spam   | SpamFolder   |

  Scenario Outline: Deleting/Spamming a Tracker ticket and undo it.
    Given a Tracker ticket "<TrackerSubject>" with the these related tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Ticket "<TrackerSubject>"
    And I Undo the action for "<TrackerSubject>"
    Then the Tracker "<TrackerSubject>" should have "0" related tickets
    And the related tickets should be unlinked from the tracker and become normal tickets
    Examples:
     | TrackerSubject    | Subject1          | Subject2          | Action |
     |  Supervisor Issue | Ticket not closed | Priority not Set  | Delete |
     |  SMTP issue       | Mail not sent     | Agentnot notified | Spam   |

 Scenario Outline: Deleting/Spamming a Related ticket.
    Given a Tracker ticket "<TrackerSubject>" with the these related tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Ticket "<Subject2>"
    Then the Ticket "<Subject2>" should be moved to <Destination>
    And the Related ticket "<Subject2>" should become a normal ticket
    And the related tickets for the Tracker "<TrackerSubject>" should be decremented by "1"
    Examples:
     | TrackerSubject      | Subject1           | Subject2            | Action | Destination  |
     | Sla issue           | Resolved on time   | Mail escalated      | Delete | Trash Folder |
     | Ticket Update Issue | Cant close tickets | Chat with Ekaterina | Spam   | SpamFolder   |


  Scenario Outline: Deleting/Spamming a Related ticket and Undo it.
    Given a Tracker ticket "<TrackerSubject>" with the these related tickets:
      | <Subject1> |
      | <Subject2> |
    When I <Action> the Ticket "<Subject1>"
    And I Undo the action for "<Subject1>"
    Then the Related ticket "<Subject1>" should become a normal ticket
    And the related tickets for the Tracker "<TrackerSubject>" should be decremented by "1"
    Examples:
     | TrackerSubject        | Subject1       | Subject2                         | Action |
     | Payment Gateway Issue | Payment failed | Money Debited Transaction failed | Delete |
     | Reports issue         | Broken Reports | Bug in reports                   | Spam   |

  Scenario: Adding a Broadcast Message.
    Given a tracker ticket "Attachments issue"
    And a Related Ticket "Problem with ticket attachments" assigned to agent "test_agent<test_agent@yopmail.com>"
    When I add a broadcast note "Fixed the Issue" to the Tracker
    Then the broadcast note should get added to the Tracker
    And the ".broadcast_message_box" in the ticket "Problem with ticket attachments" should display "Fixed the Issue"
    And the "test_agent@yopmail.com" should receive an email with the broadcast message
