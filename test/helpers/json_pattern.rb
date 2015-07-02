module JsonPattern
  def forum_category_response_pattern(name = 'test', desc = 'test desc')
    {
      id: Fixnum,
      name: name,
      description: desc,
      position: Fixnum,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def forum_category_pattern(fc)
    {
      id: Fixnum,
      name: fc.name,
      description: fc.description,
      position: fc.position,
      created_at: fc.created_at,
      updated_at: fc.updated_at
    }
  end

  def bad_request_error_pattern(field, value, params_hash = {})
    {
      field: "#{field}",
      message: I18n.t("api.error_messages.#{value}", params_hash.merge(default: value)),
      code: BaseError::API_ERROR_CODES_BY_VALUE[value] || BaseError::DEFAULT_CUSTOM_CODE
    }
  end

  def too_many_request_error_pattern
    {
      message: String
    }
  end

  def invalid_json_error_pattern
    {
      code: 'invalid_json',
      message: String
    }
  end

  def un_supported_media_type_error_pattern
    {
      code: 'invalid_content_type',
      message: String
    }
  end

  def not_acceptable_error_pattern
    {
      code: 'invalid_accept_header',
      message: String
    }
  end

  def request_error_pattern(code, params_hash = {})
    {
      code: code,
      message: I18n.t("api.error_messages.#{code}", params_hash.merge(default: code))
    }
  end

  def base_error_pattern(code, params_hash = {})
    {
      message: I18n.t("api.error_messages.#{code}", params_hash.merge(default: code))
    }
  end

  def forum_pattern(forum)
    {
      id: Fixnum,
      name: forum.name,
      description: forum.description,
      position: forum.position,
      description_html: forum.description_html,
      forum_category_id: forum.forum_category_id,
      forum_type: forum.forum_type,
      forum_visibility: forum.forum_visibility,
      topics_count: forum.topics_count,
      posts_count: forum.posts_count
    }
  end

  def forum_response_pattern(f = nil, hash = {})
    {
      id: Fixnum,
      name: hash[:name] || f.name,
      description: hash[:description] || f.description,
      position: hash[:position] || f.position,
      description_html: hash[:description_html] || f.description_html,
      forum_category_id: hash[:forum_category_id] || f.forum_category_id,
      forum_type: hash[:forum_type] || f.forum_type,
      forum_visibility: hash[:forum_visibility] || f.forum_visibility,
      topics_count: hash[:topics_count] || f.topics_count,
      posts_count: hash[:posts_count] || f.posts_count
    }
  end

  def topic_pattern(expected_output = {}, topic)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      title: expected_output[:title] || topic.title,
      forum_id: expected_output[:forum_id] || topic.forum_id,
      user_id: expected_output[:user_id] || topic.user_id,
      locked: expected_output[:locked] || topic.locked,
      sticky: expected_output[:sticky] || topic.sticky,
      published: expected_output[:published] || topic.published,
      stamp_type: expected_output[:stamp_type] || topic.stamp_type,
      replied_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      replied_by: expected_output[:replied_by] || topic.replied_by,
      posts_count: expected_output[:posts_count] || topic.posts_count,
      hits: expected_output[:hits] || topic.hits,
      user_votes: expected_output[:user_votes] || topic.user_votes,
      merged_topic_id: expected_output[:merged_topic_id] || topic.merged_topic_id,
      created_at: expected_output[:ignore_created_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:created_at],
      updated_at: expected_output[:ignore_updated_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:updated_at]
    }
  end

  def post_pattern(expected_output = {}, post)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      body: expected_output[:body] || post.body,
      body_html: expected_output[:body_html] || post.body_html,
      topic_id: expected_output[:topic_id] || post.topic_id,
      forum_id: expected_output[:forum_id] || post.forum_id,
      user_id: expected_output[:user_id] || post.user_id,
      answer: expected_output[:output] || post.answer,
      published: post.published,
      spam: post.spam,
      trash: post.trash,
      created_at: expected_output[:ignore_created_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:created_at],
      updated_at: expected_output[:ignore_updated_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:updated_at]
    }
  end

  def deleted_ticket_pattern(expected_output = {}, ticket)
    ticket_pattern(expected_output, ticket).merge(deleted: (expected_output[:deleted] || ticket.deleted))
  end

  def index_ticket_pattern(ticket)
    ticket_pattern(ticket).except(:attachments, :notes, :tags)
  end

  def index_deleted_ticket_pattern(ticket)
    index_ticket_pattern(ticket).merge(deleted: ticket.deleted)
  end

  def ticket_pattern(expected_output = {}, ignore_extra_keys = true, ticket)
    expected_custom_field = (expected_output[:custom_fields] && ignore_extra_keys) ? expected_output[:custom_fields].ignore_extra_keys! : expected_output[:custom_fields]
    ticket_custom_field = (ticket.custom_field && ignore_extra_keys) ? ticket.custom_field.ignore_extra_keys! : ticket.custom_field

    {
      cc_emails: expected_output[:cc_emails] || ticket.cc_email[:cc_emails],
      fwd_emails: expected_output[:fwd_emails] || ticket.cc_email[:fwd_emails],
      reply_cc_emails:  expected_output[:reply_cc_emails] || ticket.cc_email[:reply_cc],
      description:  expected_output[:description] || ticket.description,
      description_html: expected_output[:description_html] || ticket.description_html,
      ticket_id: expected_output[:display_id] || ticket.display_id,
      fr_escalated:  expected_output[:fr_escalated] || ticket.fr_escalated,
      is_escalated:  expected_output[:is_escalated] || ticket.isescalated,
      spam:  expected_output[:spam] || ticket.spam,
      urgent:  expected_output[:urgent] || ticket.urgent,
      requester_status_name:  expected_output[:requester_status_name] || ticket.requester_status_name,
      email_config_id:  expected_output[:email_config_id] || ticket.email_config_id,
      group_id:  expected_output[:group_id] || ticket.group_id,
      priority:  expected_output[:priority] || ticket.priority,
      requester_id:  expected_output[:requester_id] || ticket.requester_id,
      responder_id:  expected_output[:responder_id] || ticket.responder_id,
      source: expected_output[:source] || ticket.source,
      status: expected_output[:status] || ticket.status,
      subject:  expected_output[:subject] || ticket.subject,
      type:  expected_output[:ticket_type] || ticket.ticket_type,
      to_email:  expected_output[:to_email] || ticket.to_email,
      to_emails: expected_output[:to_emails] || ticket.to_emails,
      product_id:  expected_output[:product_id] || ticket.product_id,
      attachments: Array,
      notes: Array,
      tags:  expected_output[:tags] || ticket.tag_names,
      custom_fields:  expected_custom_field || ticket_custom_field,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      due_by: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      fr_due_by: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def note_pattern(expected_output = {}, note)
    {
      body: expected_output[:body] || note.body,
      body_html: expected_output[:body_html] || note.body_html,
      id: Fixnum,
      incoming: expected_output[:incoming] || note.incoming,
      private: expected_output[:private] || note.private,
      user_id: expected_output[:user_id] || note.user_id,
      support_email: note.support_email,
      ticket_id: expected_output[:ticket_id] || note.notable_id,
      notified_to: expected_output[:notify_emails] || note.to_emails,
      attachments: Array,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def time_sheet_pattern(expected_output = {}, time_sheet)
    {
      note: expected_output[:note] || time_sheet.note,
      ticket_id: expected_output[:ticket_id] || time_sheet.workable.display_id,
      id: Fixnum,
      user_id: expected_output[:user_id] || time_sheet.user_id,
      billable: expected_output[:billable] || time_sheet.billable,
      timer_running: expected_output[:timer_running] || time_sheet.timer_running,
      time_spent: expected_output[:time_spent] || time_sheet.time_spent,
      executed_at: expected_output[:executed_at] || time_sheet.executed_at,
      start_time: expected_output[:start_time] || time_sheet.start_time,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def reply_note_pattern(expected_output = {}, note)
    {
      body: expected_output[:body] || note.body,
      body_html: expected_output[:body_html] || note.body_html,
      id: Fixnum,
      user_id: expected_output[:user_id] || note.user_id,
      from_email: note.from_email,
      cc_emails: expected_output[:cc_emails] || note.cc_emails,
      bcc_emails: expected_output[:bcc_emails] || note.bcc_emails,
      ticket_id: expected_output[:ticket_id] || note.notable_id,
      replied_to: note.to_emails,
      attachments: Array,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def ticket_field_pattern(tf, hash = {})
    {
      id: tf.id,
      default: tf.default,
      description: tf.description,
      type: tf.field_type,
      customers_can_edit: tf.editable_in_portal,
      label: tf.label,
      label_for_customers: tf.label_in_portal,
      name: tf.name,
      position: tf.position,
      required_for_agents: tf.required,
      required_for_closure: tf.required_for_closure,
      required_for_customers: tf.required_in_portal,
      displayed_to_customers: tf.visible_in_portal,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      choices: hash[:choices] || Array
    }
  end

  def requester_ticket_field_pattern(tf)
    ticket_field_pattern(tf).merge(
      portal_cc: tf.field_options['portalcc'],
      portal_cc_to: tf.field_options['portalcc_to']
    )
  end

  def ticket_field_nested_pattern(tf, hash = {})
    ticket_field_pattern(tf).merge(
      nested_ticket_fields: Array
    )
  end

  def nested_ticket_fields_pattern(ntf)
    {
      description: ntf.description,
      id: ntf.id,
      label: ntf.label,
      label_in_portal: ntf.label_in_portal,
      level: ntf.level,
      name: ntf.name,
      ticket_field_id: ntf.ticket_field_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def group_pattern(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:auto_ticket_assign] = (expected_output[:auto_ticket_assign] || group.ticket_assign_type)
    return group_json
  end

  def group_pattern_without_assingn_type(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    return group_json
  end

  def group_json(expected_output, group)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || group.name,
      description: expected_output[:description] || group.description,
      business_calendar_id: expected_output[:business_calendar_id] || group.business_calendar_id,
      escalate_to: expected_output[:escalate_to] || group.escalate_to,
      agents: group.agent_groups.map(&:user_id),
      unassigned_for: expected_output[:unassigned_for] || (GroupConstants::UNASSIGNED_FOR_MAP.key(group.assign_time)),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
end

include JsonPattern
