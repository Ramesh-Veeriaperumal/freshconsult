module VA::Search::Constants
  AUTOMATIONS_SEARCH_FIELDS = {
    action: {
      fields_with_filter_search: %i[priority ticket_type status responder_id group_id internal_agent_id
                                    product_id source internal_group_id add_watcher add_a_cc add_tag],

      fields_without_filter_search: %i[trigger_webhook add_note forward_ticket send_email_to_group
                                       send_email_to_agent send_email_to_requester delete_ticket
                                       mark_as_spam skip_notification add_comment marketplace_app_slack_v2
                                       marketplace_app_office_365],

      transformable_fields: %i[ticket_type add_tag]
    }.freeze,

    ticket_condition: {
      fields_with_filter_search: %i[from_email to_email ticket_cc priority ticket_type status source
                                    product_id created_at responder_id group_id internal_agent_id
                                    internal_group_id updated_at last_interaction tag_ids tag_names ticlet_cc
                                    created_during contact_name company_name hours_since_created pending_since resolved_at
                                    closed_at opened_at first_assigned_at assigned_at requester_responded_at agent_responded_at
                                    frDueBy due_by inbound_count outbound_count],
      fields_without_filter_search: %i[subject description subject_or_description freddy_suggestion],

      transformable_fields: %i[ticket_type tag_names]
    }.freeze,

    company_condition: {
      fields_with_filter_search: %i[name domains health_score account_tier industry renewal_date segments],
      fields_without_filter_search: [],
      transformable_fields: %i[health_score account_tier industry]
    }.freeze,

    contact_condition: {
      fields_with_filter_search: %i[email name job_title time_zone language segments],
      fields_without_filter_search: [],
      transformable_fields: []
    }.freeze,

    event: {
      fields_with_filter_search: %i[priority ticket_type status group_id responder_id note_type ticket_action
                                    time_sheet_action customer_feedback],
      fields_without_filter_search: %i[reply_sent due_by mail_del_failed_others mail_del_failed_requester response_due resolution_due next_response_due],
      transformable_fields: %i[ticket_type]
    }.freeze

  }.freeze

  EVALUATE_ON_MAPPING = {
    requester: :contact,
    company: :company,
    ticket: :ticket
  }.freeze

  FIELD_VALUE_CHANGE_MAPPING = {
    ticlet_cc: :ticket_cc,
    tag_ids: :tag_names,
    created_during: :created_at
  }.freeze

  ANY_NONE_VALUES = ['', '--', '##'].freeze

  ANY_NONE = { NONE: '', ANY: '--', ANY_WITHOUT_NONE: '##' }.freeze

  DEFAULT_ANY_NONE = { '' => 'NONE', '--' => 'ANY', '##' => 'ANY_WITHOUT_NONE' }.freeze

  CONDITIONS_DEFAULT_FIELDS = %i[evaluate_on name operator].freeze

  CONDITIONS_ADDITIONAL_FIELDS = %i[business_hours_id].freeze
end
