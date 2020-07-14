module Silkroad
  module Constants
    module Ticket
      EXPORT_NAME = 'freshdesk_tickets'.freeze
      FORMAT_MAPPING = { csv: 'csv', xls: 'xlsx' }.freeze
      AGENT_RESPONDED_AT_NULL_CONDITION = {
        column_name: 'agent_responded_at',
        operator: Silkroad::Constants::Base::OPERATORS[:equal],
        operand: [nil]
      }.freeze
      SOURCE_NOT_OUTBOUND_EMAIL_CONDITION = {
        column_name: 'source',
        operator: Silkroad::Constants::Base::OPERATORS[:not_equal],
        operand: [TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]]
      }.freeze
      SURVEY_FEATURE_MAPPING = { true => 'new_survey', false => 'old_survey' }.freeze
      AGENT_CONDITIONS = ['responder_id', 'internal_agent_id', 'any_agent_id'].freeze
      GROUP_CONDITIONS = ['group_id, internal_group_id', 'any_group_id'].freeze
      DUE_BY_CONDITIONS = ['due_by', 'frDueBy', 'nr_due_by'].freeze
      AGENT_COLUMNS = ['responder_id', 'internal_agent_id'].freeze
      GROUP_COLUMNS = ['group_id', 'internal_group_id'].freeze
      NESTED_OPERATORS = ['nested_or', 'nested_and'].freeze
      FSM_FIELDS = ['cf_fsm_appointment_start_time', 'cf_fsm_appointment_end_time'].freeze
      # Defining for all fields inorder to prevent loading custom fields whenever possible
      TICKET_FIELDS_COLUMN_NAME_MAPPING = {
        display_id: 'display_id',
        subject: 'subject',
        description: 'description',
        status_name: 'status',
        priority_name: 'priority',
        source_name: 'source',
        ticket_type: 'ticket_type',
        responder_name: 'responder_id',
        group_name: 'group_id',
        created_at: 'created_at',
        due_by: 'due_by',
        resolved_at: 'resolved_at',
        closed_at: 'closed_at',
        updated_at: 'updated_at',
        first_response_time: 'first_response_time',
        time_tracked_hours: 'time_tracked_hours', # To be added
        first_res_time_bhrs: 'first_resp_time_by_bhrs',
        resolution_time_bhrs: 'resolution_time_by_bhrs',
        outbound_count: 'outbound_count',
        inbound_count: 'inbound_count',
        resolution_status: 'resolution_status',
        first_response_status: 'first_response_status',
        every_response_status: 'every_response_status',
        ticket_tags: 'tags',
        skill_name: 'sl_skill_id',
        association_type_name: 'association_type',
        internal_agent_name: 'internal_agent_id',
        internal_group_name: 'internal_group_id',
        product_name: 'helpdesk_schema_less_tickets.product_id'
      }.freeze
      CONTACT_FIELDS_COLUMN_NAME_MAPPING = {
        contact_id: 'requester_id',
        name: 'contact_name',
        email: 'contact_email',
        phone: 'contact_phone',
        mobile: 'contact_mobile',
        fb_profile_id: 'contact_fb_profile_id',
        twitter_id: 'contact_twitter_id',
        time_zone: 'contact_time_zone',
        language: 'contact_language',
        job_title: 'contact_job_title',
        unique_external_id: 'contact_unique_external_id'
      }.freeze
      COMPANY_FIELDS_COLUMN_NAME_MAPPING = {
        name: 'company_name',
        domains: 'company_domains',
        health_score: 'company_field_data.string_cc01',
        account_tier: 'company_field_data.string_cc02',
        industry: 'company_field_data.string_cc03',
        renewal_date: 'company_field_data.datetime_cc01'
      }.freeze
      NONE_VALUE = -1
      OPERATOR_MAPPING = {
        is_in: Silkroad::Constants::Base::OPERATORS[:in],
        is: Silkroad::Constants::Base::OPERATORS[:equal],
        is_greater_than: Silkroad::Constants::Base::OPERATORS[:greater_than]
      }.freeze
      OPERAND_MAPPING = {
        '-1' => nil,
        -1 => nil,
        false => 0,
        true => 1
      }.freeze
      CONTACT_FIELD_DATA = 'contact_field_data'.freeze
      COMPANY_FIELD_DATA = 'company_field_data'.freeze
      FLEXIFIELDS = 'flexifields'.freeze
      START_DATE = Time.at(0).utc.freeze
      SILKROAD_EXPORT_STATUS = {
        recieved: 1,
        started: 2,
        completed: 3,
        failed: 4
      }.freeze
      UNRESOLVED_STATUS_OPERAND = [0, '0'].freeze
      UNASSIGNED_OPERAND = [0, '0'].freeze
      TICKET_COLUMNS = {
        fr_due_by: 'frDueBy',
        source: 'source',
        status: 'status',
        group_id: 'group_id',
        responder_id: 'responder_id',
        internal_group_id: 'internal_group_id',
        internal_agent_id: 'internal_agent_id',
        any_agent_id: 'any_agent_id',
        any_group_id: 'any_group_id',
        created_at: 'created_at',
        resolved_at: 'resolved_at',
        closed_at: 'closed_at'
      }.freeze
      AGENT_PERMISSIONS = {
        all_tickets: 'all_tickets',
        group_tickets: 'group_tickets',
        assigned_tickets: 'assigned_tickets'
      }.freeze
      CREATED_AT_TYPES_BY_TOKEN = {
        today: 'today',
        yesterday: 'yesterday',
        week: 'week',
        last_week: 'last_week',
        month: 'month',
        last_month: 'last_month',
        two_months: 'two_months',
        six_months: 'six_months'
      }.freeze
      DATE_RANGE_SPECIFIER = ' - '.freeze
      TEXT_MAPPING = {
        sla_status: {
          in_sla: { key: 'IN_SLA', text: 'export_data.in_sla' },
          violated_sla: { key: 'VIOLATED_SLA', text: 'export_data.out_of_sla' }
        }
      }.freeze
    end
  end
end
