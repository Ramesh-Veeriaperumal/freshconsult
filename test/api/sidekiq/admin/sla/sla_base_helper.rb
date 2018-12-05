['tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['sla_policies_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module SlaBaseHelper
  include TicketsTestHelper
  include SlaPoliciesTestHelper

  def create_test_ticket_sla_reminder(agent, group)
    ticket = create_ticket(params = { requester_id: agent.user_id, created_at: (Time.zone.now - 2.hours), priority: 4, subject: "Test ticket"}, group)
    ticket.update_attributes(due_by: Time.zone.now - 1.hour, frDueBy: Time.zone.now - 1.hour)
    sla_policy = create_sla_policy_with_escalations(conditions = {group_id: [group.id]}, escalations = {time: 1800, agent_ids: [agent.id]})
    ticket.schema_less_ticket.update_attributes(long_tc01: sla_policy.id)
    [ticket, sla_policy]
  end

  def check_for_correct_response_sla_reminder(ticket, agent)
    # For response_reminder
    response_sla_reminder_notif = @account.email_notifications.response_sla_reminder.first
    mail_message_response = SlaNotifier.group_escalation(ticket, [agent.user_id], EmailNotification::RESPONSE_SLA_REMINDER)
    response_subject_actual = Liquid::Template.parse(response_sla_reminder_notif.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    response_body_actual = Liquid::Template.parse(response_sla_reminder_notif.agent_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    assert_equal response_subject_actual, mail_message_response.subject
    assert_equal Helpdesk::HTMLSanitizer.plain(response_body_actual)+"\n", mail_message_response.part.first.body.decoded
    assert_equal ticket.sla_response_reminded, true    
  end

  def check_for_correct_resolution_sla_reminder(ticket, agent)
    # For resolution_reminder
    resolution_sla_reminder_notif = @account.email_notifications.resolution_sla_reminder.first
    mail_message_resolution = SlaNotifier.group_escalation(ticket, [agent.user_id], EmailNotification::RESOLUTION_SLA_REMINDER)
    resolution_subject_actual = Liquid::Template.parse(resolution_sla_reminder_notif.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    resolution_body_actual = Liquid::Template.parse(resolution_sla_reminder_notif.agent_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    assert_equal resolution_subject_actual, mail_message_resolution.subject
    assert_equal Helpdesk::HTMLSanitizer.plain(resolution_body_actual)+"\n", mail_message_resolution.part.first.body.decoded
    assert_equal ticket.sla_resolution_reminded, true
  end

  def create_test_ticket_sla_escalation(agent, group)
    ticket = create_ticket(params = { requester_id: agent.user_id, created_at: (Time.zone.now - 2.hours), priority: 4, subject: "Test ticket"}, group)
    ticket.update_attributes(due_by: Time.zone.now - 1.hour, frDueBy: Time.zone.now - 1.hour)
    sla_policy = create_sla_policy_with_details(conditions = {group_id: [group.id]}, escalations = {time: 1800, agent_ids: [agent.id]}, ticket.priority)
    ticket.schema_less_ticket.update_attributes(long_tc01: sla_policy.id)
    [ticket, sla_policy]
  end

  def check_for_correct_response_sla_escalation(ticket, agent)
    # For response_escalation
    first_response_sla_violation_entry = @account.email_notifications.find_by_notification_type(EmailNotification::FIRST_RESPONSE_SLA_VIOLATION)
    mail_message_response = SlaNotifier.group_escalation(ticket, [agent.user_id], EmailNotification::FIRST_RESPONSE_SLA_VIOLATION)
    response_subject_actual = Liquid::Template.parse(first_response_sla_violation_entry.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    response_body_actual = Liquid::Template.parse(first_response_sla_violation_entry.agent_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    assert_equal response_subject_actual, mail_message_response.subject
    assert_equal Helpdesk::HTMLSanitizer.plain(response_body_actual)+"\n", mail_message_response.part.first.body.decoded
    assert_equal ticket.fr_escalated, true
  end

  def check_for_correct_resolution_sla_escalation(ticket, agent)
    # For resolution_escalation
    resolution_sla_violation_entry = @account.email_notifications.find_by_notification_type(EmailNotification::RESOLUTION_TIME_SLA_VIOLATION)
    mail_message_resolution = SlaNotifier.group_escalation(ticket, [agent.user_id], EmailNotification::RESOLUTION_TIME_SLA_VIOLATION)
    resolution_subject_actual = Liquid::Template.parse(resolution_sla_violation_entry.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    resolution_body_actual = Liquid::Template.parse(resolution_sla_violation_entry.agent_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    assert_equal resolution_subject_actual, mail_message_resolution.subject
    assert_equal Helpdesk::HTMLSanitizer.plain(resolution_body_actual)+"\n", mail_message_resolution.part.first.body.decoded
    assert_equal ticket.escalation_level, Helpdesk::SlaPolicy::ESCALATION_LEVELS_MAX
    assert_equal ticket.isescalated, true
  end

  def check_for_correct_group_sla_escalation(ticket, agent)
    # For group_escalation
    group_escalation_entry = @account.email_notifications.find_by_notification_type(EmailNotification::TICKET_UNATTENDED_IN_GROUP)
    mail_message_group_escalation = SlaNotifier.agent_escalation(ticket, agent.user, EmailNotification::TICKET_UNATTENDED_IN_GROUP)
    group_esc_subject_actual = Liquid::Template.parse(group_escalation_entry.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    group_esc_body_actual = Liquid::Template.parse(group_escalation_entry.agent_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    assert_equal group_esc_subject_actual, mail_message_group_escalation.subject
    assert_equal Helpdesk::HTMLSanitizer.plain(group_esc_body_actual)+"\n", mail_message_group_escalation.part.first.body.decoded
    assert_equal ticket.ticket_states.group_escalated, true
  end

end