# frozen_string_literal: true

module ArchiveTicketsTestHelper
  def central_payload_archive_ticket_pattern(ticket)
    ret_hash = {
      id: ticket.id,
      display_id: ticket.display_id,
      ticket_id: ticket.ticket_id,
      account_id: ticket.account_id,
      responder_id: ticket.responder_id,
      group_id: ticket.group_id,
      status: { id: ticket.status, name: ticket.status_name },
      priority: { id: ticket.priority, name: TicketConstants::PRIORITY_NAMES_BY_KEY[ticket.priority] },
      ticket_type: ticket.ticket_type,
      source: { id: ticket.source, name: Account.current.ticket_source_revamp_enabled? ? ticket.source_name : Account.current.helpdesk_sources.default_ticket_source_names_by_key[ticket.source] },
      requester_id: ticket.requester_id,
      due_by: ticket.parse_to_date_time(ticket.due_by).try(:utc).try(:iso8601),
      closed_at: ticket.parse_to_date_time(ticket.closed_at).try(:utc).try(:iso8601),
      resolved_at: ticket.parse_to_date_time(ticket.resolved_at).try(:utc).try(:iso8601),
      created_at: ticket.parse_to_date_time(ticket.created_at).try(:utc).try(:iso8601),
      updated_at: ticket.parse_to_date_time(ticket.updated_at).try(:utc).try(:iso8601),
      archive_created_at: ticket.parse_to_date_time(ticket.archive_created_at).try(:utc).try(:iso8601),
      archive_updated_at: ticket.parse_to_date_time(ticket.archive_updated_at).try(:utc).try(:iso8601),
      first_response_time: ticket.parse_to_date_time(ticket.first_response_time).try(:utc).try(:iso8601),
      first_assigned_at: ticket.parse_to_date_time(ticket.first_assigned_at).try(:utc).try(:iso8601),
      assigned_at: ticket.parse_to_date_time(ticket.assigned_at).try(:utc).try(:iso8601),
      custom_fields: ticket.central_custom_fields_hash,
      company_id: ticket.company_id,
      sla_policy_id: ticket.sla_policy_id,
      is_escalated: ticket.isescalated,
      fr_escalated: ticket.fr_escalated,
      resolution_escalation_level: ticket.escalation_level,
      response_reminded: ticket.sla_response_reminded,
      resolution_reminded: ticket.sla_resolution_reminded,
      time_to_resolution_in_bhrs: ticket.resolution_time_by_bhrs,
      time_to_resolution_in_chrs: ticket.resolution_time_by_chrs,
      inbound_count: ticket.inbound_count,
      first_response_by_bhrs: ticket.first_resp_time_by_bhrs,
      first_assign_by_bhrs: ticket.reports_hash['first_assign_by_bhrs'],
      first_response_id: ticket.reports_hash['first_response_id'],
      agent_reassigned_count: ticket.reports_hash['agent_reassigned_count'],
      group_reassigned_count: ticket.reports_hash['group_reassigned_count'],
      reopened_count: ticket.reports_hash['reopened_count'],
      private_note_count: ticket.reports_hash['private_note_count'],
      public_note_count: ticket.reports_hash['public_note_count'],
      agent_reply_count: ticket.reports_hash['agent_reply_count'],
      customer_reply_count: ticket.reports_hash['customer_reply_count'],
      agent_assigned_flag: ticket.reports_hash['agent_assigned_flag'],
      agent_reassigned_flag: ticket.reports_hash['agent_reassigned_flag'],
      group_assigned_flag: ticket.reports_hash['group_assigned_flag'],
      group_reassigned_flag: ticket.reports_hash['group_reassigned_flag'],
      internal_agent_assigned_flag: ticket.reports_hash['internal_agent_assigned_flag'],
      internal_agent_reassigned_flag: ticket.reports_hash['internal_agent_reassigned_flag'],
      internal_group_assigned_flag: ticket.reports_hash['internal_group_assigned_flag'],
      internal_group_reassigned_flag: ticket.reports_hash['internal_group_reassigned_flag'],
      internal_agent_first_assign_in_bhrs: ticket.reports_hash['internal_agent_first_assign_in_bhrs'],
      last_resolved_at: ticket.reports_hash['last_resolved_at'],
      parent_id: ticket.parent_id,
      outbound_email: ticket.outbound_email?,
      subject: ticket.subject,
      description_text: ticket.description,
      description_html: ticket.description_html,
      watchers: ticket.watchers,
      urgent: ticket.urgent,
      spam: ticket.spam,
      trained: ticket.trained,
      fr_due_by: ticket.parse_to_date_time(ticket.frDueBy).try(:utc).try(:iso8601),
      to_emails: ticket.to_emails,
      cc_emails: ticket.cc_email[:cc_emails],
      fwd_emails: ticket.cc_email[:fwd_emails],
      bcc_emails: ticket.cc_email[:bcc_emails],
      reply_cc: ticket.cc_email[:reply_cc],
      tkt_cc: ticket.cc_email[:tkt_cc],
      email_config_id: ticket.email_config_id,
      deleted: ticket.deleted,
      group_users: ticket.group_users,
      tags: Array,
      import_id: ticket.import_id,
      attachment_ids: ticket.attachments.map(&:id),
      first_response_agent_id: ticket.reports_hash['first_response_agent_id'],
      first_response_group_id: ticket.reports_hash['first_response_group_id'],
      first_assign_agent_id: ticket.reports_hash['first_assign_agent_id'],
      first_assign_group_id: ticket.reports_hash['first_assign_group_id'],
      product_id: ticket.product_id,
      archive: ticket.archive,
      internal_agent_id: ticket.internal_agent_id,
      internal_group_id: ticket.internal_group_id,
      on_state_time: ticket.on_state_time,
      associates: ticket.association_hash,
      associates_rdb: ticket.associates_rdb,
      source_additional_info: ticket.source_additional_info_hash,
      status_stop_sla_timer: ticket.status_stop_sla_timer,
      status_deleted: ticket.status_deleted
    }
    ret_hash[:skill_id] = ticket.sl_skill_id if Account.current.skill_based_round_robin_enabled?

    if Account.current.next_response_sla_enabled?
      ret_hash[:nr_due_by] = ticket.parse_to_date_time(ticket.nr_due_by).try(:utc).try(:iso8601)
      ret_hash[:nr_escalated] = ticket.nr_escalated
      ret_hash[:next_response_reminded] = ticket.nr_reminded
    end

    ret_hash
  end

  def central_publish_assoc_archive_ticket_pattern(ticket)
    assoc_ticket_pattern = {
      requester: Hash,
      responder: (ticket.responder ? Hash : nil),
      group: (ticket.group ? Hash : nil),
      attachments: Array,
      product: (ticket.product ? Hash : nil)
    }
    assoc_ticket_pattern[:skill] = Hash if Account.current.skill_based_round_robin_enabled?
    return assoc_ticket_pattern.merge(internal_agent: (ticket.internal_agent ? Hash : nil), internal_group: (ticket.internal_group ? Hash : nil)) if Account.current.shared_ownership_enabled?

    assoc_ticket_pattern
  end
end
