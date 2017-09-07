@admin
Feature: Sla calculations

#Remove the background after new sla logic is enabled for all accounts
  Background: Enable New Sla logic
    Given "new_sla_logic" feature is launched for the account

  @db_clean

  @sla_policy
  Scenario: Creating a ticket
    When I create a ticket with priority "low", type "Incident" and status "open" at "9:00"
    # @sla_policy is applied.
    Then the ticket's due by should be "14:00"
    And the ticket's first response due by should be "13:00"

  Scenario: Updating a ticket's status from on state to off state
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    When I update the ticket's status to "pending" at "14:00"
    Then the ticket's time spent in on state should be "5" "hours"

  Scenario: Updating a ticket's status from off to on state
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    When I update the ticket's status to "open" at "11:00"
    Then the ticket's due by should be recalculated to "15:00"
    And the ticket's first response due by should be recalculated to "14:00"

  Scenario: Updating a ticket's status from on to on state
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    And the ticket's status was updated to "open" at "11:00"
    When I update the ticket's status to "Waiting on Third Party" at "12:00"
    Then the ticket's time spent in on state should not be recalculated
    And the ticket's due by should not be recalculated
    And the ticket's first response due by should not be recalculated

  Scenario: Updating a ticket's status from off to off state
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    When I update the ticket's status to "Waiting on Customer" at "12:00"
    Then the ticket's time spent in on state should not be recalculated
    And the ticket's due by should not be recalculated
    And the ticket's first response due by should not be recalculated

  Scenario: Updating a ticket's priority
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    And the ticket's status was updated to "open" at "11:00"
    When I update the ticket's priority to "high" at "12:00"
    Then the ticket's time spent in on state should be "2" "hours"
    And the ticket's due by should be recalculated to "13:00"
    And the ticket's first response due by should be recalculated to "12:00"

  @sla_policy1
  Scenario: Updating a ticket's type
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    And the ticket's status was updated to "open" at "11:00"
    When I update the ticket's type to "Problem" at "12:00"
    # @sla_policy1 is applied.
    Then the ticket's time spent in on state should be "2" "hours"
    And the ticket's due by should be recalculated to "16:00"
    And the ticket's first response due by should be recalculated to "15:00"

  @sla_policy2
  Scenario: Updating a ticket's source
    Given a ticket created at "9:00", priority "low", type "Question" and status "open"
    # Default policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    And the ticket's status was updated to "open" at "11:00"
    When I update the ticket's source to "forum" at "12:00"
    # @sla_policy2 is applied.
    Then the ticket's time spent in on state should be "2" "hours"
    And the ticket's due by should be recalculated to "14:00"
    And the ticket's first response due by should be recalculated to "13:00"

  @sla_policy3
  Scenario: Updating a ticket's company
    Given a ticket created at "9:00", priority "low", type "Question" and status "open"
    # Default policy is applied.
    And the ticket's status was updated to "pending" at "10:00"
    And the ticket's status was updated to "open" at "11:00"
    When I update the ticket's company to "Company 1" at "12:00"
    # @sla_policy3 is applied.
    Then the ticket's time spent in on state should be "2" "hours"
    And the ticket's due by should be recalculated to "13:00"
    And the ticket's first response due by should be recalculated to "12:00"

  @sla_policy4
  Scenario: Updating a ticket's group
    Given a ticket created at "9:00", priority "low", type "Question" and status "open"
    # Default policy is applied.
    And the ticket's status was updated to "pending" at "9:15"
    And the ticket's status was updated to "open" at "9:30"
    When I update the ticket's group to "QA" at "9:45"
    # @sla_policy4 is applied.
    Then the ticket's time spent in on state should be "30" "minutes"
    And the ticket's due by should be recalculated to "11:15"
    And the ticket's first response due by should be recalculated to "10:15"

  Scenario: Updating a ticket's internal group
    Given a ticket created at "9:00", priority "low", type "Question" and status "open"
    And "shared_ownership" feature is present for the account
    # Default policy is applied.
    And the ticket's status was updated to "pending" at "9:15"
    And the ticket's status was updated to "Waiting on Third Party" at "9:30"
    When I update the ticket's internal group to "Test group" at "9:45"
    Then the ticket's time spent in on state should not be recalculated
    And the ticket's due by should not be recalculated
    And the ticket's first response due by should not be recalculated

  @sla_policy5
  Scenario: Updating a ticket's group to a group with different business hours
    Given a ticket created at "9:00", priority "low", type "Question", status "open" and group "QA"
    # @sla_policy4 is applied.
    And the ticket's status was updated to "pending" at "9:15"
    And the ticket's status was updated to "open" at "9:30"
    When I update the ticket's group to "Sales" at "9:45"
    # @sla_policy5 is applied.
    Then the ticket's time spent in on state should be "30" "minutes"
    And the ticket's due by should be recalculated to "15:25"
    And the ticket's first response due by should be recalculated to "15:20"

  @sla_policy6
  Scenario: Updating a ticket's group to a group with different time zone
    Given a ticket created at "9:00", priority "low", type "Question", status "open" and group "QA"
    # @sla_policy4 is applied.
    And the ticket's status was updated to "pending" at "9:15"
    And the ticket's status was updated to "open" at "9:30"
    When I update the ticket's group to "Product Management" at "9:45"
    # @sla_policy6 is applied.
    Then the ticket's time spent in on state should be "30" "minutes"
    And the ticket's due by should be recalculated to "12:00"
    And the ticket's first response due by should be recalculated to "11:55"

  Scenario: Updating a ticket after first response has been made
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "12:00"
    And the ticket's first response was made at "12:30"
    When I update the ticket's status to "open" at "13:00"
    Then the ticket's time spent in on state should be "3" "hours"
    And the ticket's due by should be recalculated to "15:00"
    And the ticket's first response due by should not be recalculated

  Scenario: Updating a ticket's priority for which the resolution & response time is less than the time spent in on state 
    Given a ticket created at "9:00", priority "low", type "Incident" and status "open"
    # @sla_policy is applied.
    And the ticket's status was updated to "pending" at "11:00"
    And the ticket's status was updated to "open" at "12:00"
    When I update the ticket's priority to "urgent" at "14:00"
    Then the ticket's time spent in on state should be "4" "hours"
    # The due by and first response due by will be calculated from created at without considering any on/off states.
    And the ticket's due by should be recalculated to "11:00"
    And the ticket's first response due by should be recalculated to "10:00"

  @sla_policy7
  Scenario: Updating a ticket for which sla policy configured in calendar hours is applied
    Given a ticket created at "9:00", priority "low", type "Feature Request" and status "open"
    # @sla_policy7 is applied
    And the ticket's status was updated to "pending" at "12:00"
    And I update the ticket's status to "open" at "13:00"
    Then the ticket's time spent in on state should be "3" "hours"
    And the ticket's due by should be recalculated to "22:00"
    And the ticket's first response due by should be recalculated to "20:00"
#edge cases
  @db_clean
  @sla_policy8
  Scenario: Updating a ticket and due falls on a non working day before adjusting business minutes
    Given a ticket created on "Thursday" at "22:45", priority "low", type "Incident", status "open" and group "Sales"
  # @sla_policy8 is applied
    And I update the ticket's priority to "medium" on "Friday" at "16:30"
    And the ticket's due by should be recalculated to "Friday" at "23:46"
  @db_clean
  @sla_policy9
  Scenario: Updating a ticket and due falls on a working day after business hours before adjusting business minutes
    Given a ticket created on "Thursday" at "22:15", priority "low", type "Incident", status "open" and group "Sales"
  # @sla_policy9 is applied
    And I update the ticket's priority to "medium" on "Friday" at "16:30"
    And the ticket's due by should be recalculated to "Friday" at "23:16"
  @db_clean
  @sla_policy10
  Scenario: Updating a ticket and due falls before business hours
    Given a ticket created on "Thursday" at "22:15", priority "low", type "Incident", status "open" and group "Sales"
# @sla_policy10 is applied
    And I update the ticket's priority to "medium" on "Friday" at "16:30"
    And the ticket's due by should be recalculated to "Friday" at "23:16"
  @db_clean
  @sla_policy11
  Scenario: Adding one sec to multiples of 24 hours in seconds,sla should be in business hours
    Given a ticket created on "Monday" at "9:15", priority "low", type "Incident", status "open" and group "Sales"
# @sla_policy11 is applied
    Then the ticket's due by should be on "Friday" at "9:15"

  Scenario: no one sec to multiples of 24 hours in seconds,sla should be in business days
    Given a ticket created on "Monday" at "9:15", priority "Medium", type "Incident", status "open" and group "Sales"
# @sla_policy11 is applied
    Then the ticket's due by should be on "Tuesday" at "9:15"