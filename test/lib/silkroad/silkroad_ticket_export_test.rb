require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'agent_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
['contact_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['tag_test_helper.rb'].each { |file| require Rails.root.join('test', 'models', 'helpers', file) }

class SikroadTicketExportTest < ActionView::TestCase
  include AgentHelper
  include TicketFieldsTestHelper
  include ContactFieldsTestHelper
  include CompanyFieldsTestHelper
  include TagTestHelper
  include Silkroad::Constants::Base
  include Silkroad::Constants::Ticket

  def setup
    super
    @account = Account.first.make_current
    @account.launch(:silkroad_export)
    @agent = add_agent_to_account(@account, name: 'silkroad_export_test_user', active: 1, role: 4)
    User.stubs(:current).returns(@agent.user)
  end

  def test_build_request_body_with_valid_params
    export_params = get_valid_export_params
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(export_params)
    actual_ticket_fields = JSON.parse(transformed_export_params).deep_symbolize_keys
    required_ticket_fields = get_valid_transformed_params
    assert_equal required_ticket_fields, actual_ticket_fields
  end

  def test_date_range_with_different_timezones
    TimeZone.stubs(:find_time_zone).returns('Casablanca')
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(get_valid_export_params)
    transformed_export_params = JSON.parse(transformed_export_params).deep_symbolize_keys
    actual_date_range = transformed_export_params[:date_range]
    expected_list = [{ from: '2020-01-01T00:00:00+00:00', to: '2020-01-01T23:59:59+00:00', column_name: 'created_at' },
                    { from: '2020-01-01T01:00:00+01:00', to: '2020-01-02T00:59:59+01:00', column_name: 'created_at' }]
    assert_equal true, (expected_list.include? actual_date_range)

    TimeZone.stubs(:find_time_zone).returns('New Delhi')
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(get_valid_export_params)
    transformed_export_params = JSON.parse(transformed_export_params).deep_symbolize_keys
    actual_date_range = transformed_export_params[:date_range]
    expected_date_range = { from: '2020-01-01T05:30:00+05:30', to: '2020-01-02T05:29:59+05:30', column_name: 'created_at' }
    assert_equal expected_date_range, actual_date_range
  ensure
    TimeZone.unstub(:find_time_zone)
  end

  ## FILTER CONDITIONS

  def test_filter_conditions_with_status_as_unresolved
    export_params = { data_hash: [{ condition: 'status', operator: 'is_in', value: ['0'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: 'status', operator: 'in', operand: [2, 3, 6, 7] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_filter_condition_with_flexifields
    custom_field = create_custom_field_dropdown('flexifield_dropdown')
    export_params = { data_hash: [{ condition: custom_field.name + '.' + custom_field.column_name, operator: 'is_in',
                                    value: 'SecondChoice,FirstChoice', ff_name: custom_field.name }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: custom_field.name + '.' + custom_field.column_name, operator: 'in', operand: ['SecondChoice', 'FirstChoice'] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_resolved_at_ticket_states_filter_with_status
    export_params = { ticket_state_filter: 'resolved_at',
                      data_hash: [{ condition: 'status', operator: 'is_in', value: ['2', '3', '4'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: 'status', operator: 'in', operand: [4] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_resolved_at_ticket_states_filter_without_status
    export_params = { ticket_state_filter: 'resolved_at',
                      data_hash: [{ condition: 'spam', operator: 'is', value: false }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: 'spam', operator: 'eq', operand: [0] }, { column_name: 'status', operator: 'in', operand: [4, 5] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_closed_at_ticket_states_filter_with_status
    export_params = { ticket_state_filter: 'closed_at',
                      data_hash: [{ condition: 'status', operator: 'is_in', value: ['0'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: 'status', operator: 'in', operand: [nil] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_filter_condition_for_any_group_id
    export_params = { data_hash: [{ condition: 'any_group_id', operator: 'is_in', value: ['2', '4'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ operator: 'nested_or', nested_conditions: [{ column_name: 'group_id', operator: 'in', operand: [2, 4] },
                                                                              { column_name: 'internal_group_id', operator: 'in', operand: [2, 4] }] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_filter_condition_for_any_agent_id
    export_params = { data_hash: [{ condition: 'any_agent_id', operator: 'is_in', value: ['2', '4'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ operator: 'nested_or', nested_conditions: [{ column_name: 'responder_id', operator: 'in', operand: [2, 4] },
                                                                              { column_name: 'internal_agent_id', operator: 'in', operand: [2, 4] }] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_filter_conditions_with_group_tickets_permission
    User.current.agent.stubs(:ticket_permission_token).returns(:group_tickets)
    User.current.agent_groups.stubs(:pluck).returns([1, 2, 3])
    @account.stubs(:shared_ownership_enabled?).returns(true)
    export_params = { data_hash: [{ condition: 'status', operator: 'is_in', value: ['2', '4'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: 'status', operator: 'in', operand: [2, 4] },
                                 { operator: 'nested_or', nested_conditions: [{ column_name: 'group_id', operator: 'in', operand: [1, 2, 3] },
                                                                              { column_name: 'responder_id', operator: 'in', operand: [User.current.id] },
                                                                              { column_name: 'internal_group_id', operator: 'in', operand: [1, 2, 3] },
                                                                              { column_name: 'internal_agent_id', operator: 'in', operand: [User.current.id] }] }]
    assert_equal required_filter_condition, actual_filter_condition
  ensure
    User.current.agent.unstub(:ticket_permission_token)
    User.current.agent_groups.unstub(:pluck)
    @account.unstub(:shared_ownership_enabled?)
  end

  def test_filter_conditions_with_assigned_tickets_permission
    User.current.agent.stubs(:ticket_permission_token).returns(:assigned_tickets)
    @account.stubs(:shared_ownership_enabled?).returns(true)
    export_params = { data_hash: [{ condition: 'group_id', operator: 'is_in', value: ['2', '4'], ff_name: 'default' }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ operator: 'nested_or', nested_conditions: [{ column_name: 'responder_id', operator: 'in', operand: [User.current.id] },
                                                                              { column_name: 'internal_agent_id', operator: 'in', operand: [User.current.id] }] }]
    assert_equal required_filter_condition, actual_filter_condition
  ensure
    User.current.agent.unstub(:ticket_permission_token)
    @account.unstub(:shared_ownership_enabled?)
  end

  def test_filter_conditions_with_tags
    test_tag = create_tag(@account, name: 'tag1')
    export_params = { data_hash: [{ condition: 'helpdesk_tags.name', operator: 'is_in', value: [test_tag.name] }] }
    actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
    required_filter_condition = [{ column_name: TICKET_FIELDS_COLUMN_NAME_MAPPING[:ticket_tags], operator: 'in', operand: [test_tag.id] }]
    assert_equal required_filter_condition, actual_filter_condition
  end

  def test_created_at_filters_with_greater_than_operator
    Timecop.freeze(silkroad_export_current_time) do
      created_at_keys = ['today', 'week', 'last_week', 'month', 'last_month', 'two_months', 'six_months', '15']
      created_at_values = [[Time.zone.now.beginning_of_day.iso8601], [Time.zone.now.beginning_of_week.iso8601],
                           [Time.zone.now.beginning_of_day.ago(7.days).iso8601], [Time.zone.now.beginning_of_month.iso8601],
                           [Time.zone.now.beginning_of_day.ago(1.month).iso8601], [Time.zone.now.beginning_of_day.ago(2.months).iso8601],
                           [Time.zone.now.beginning_of_day.ago(6.months).iso8601], [Time.zone.now.ago(15.minutes).iso8601]]
      created_at_keys.zip(created_at_values).each do |key, value|
        export_params = { data_hash: [{ condition: 'created_at', operator: 'is_greater_than', value: key }] }
        actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
        required_filter_condition = [{ column_name: 'created_at', operator: 'gt', operand: value }]
        assert_equal required_filter_condition, actual_filter_condition
      end
    end
  end

  def test_created_at_filters_with_between_operator
    Timecop.freeze(silkroad_export_current_time) do
      created_at_keys = ['yesterday', '01 Jan 2020 - 05 Jan 2020']
      created_at_values = [[Time.zone.now.yesterday.beginning_of_day.iso8601, Time.zone.now.beginning_of_day.iso8601],
                           [Time.zone.parse('01 Jan 2020').beginning_of_day.iso8601, Time.zone.parse('05 Jan 2020').end_of_day.iso8601]]
      created_at_keys.zip(created_at_values).each do |key, value|
        export_params = { data_hash: [{ condition: 'created_at', operator: 'between', value: key }] }
        actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
        required_filter_condition = [{ column_name: 'created_at', operator: 'between', operand: value }]
        assert_equal required_filter_condition, actual_filter_condition
      end
    end
  end

  def test_due_by_filters_with_between_operator
    Timecop.freeze(silkroad_export_current_time) do
      due_by_ids = (2..8).to_a.map(&:to_s)
      due_by_values = [[Time.zone.now.beginning_of_day.iso8601, Time.zone.now.end_of_day.iso8601], [Time.zone.now.tomorrow.beginning_of_day.iso8601, Time.zone.now.tomorrow.end_of_day.iso8601],
                       [Time.zone.now.iso8601, 8.hours.from_now.iso8601], [Time.zone.now.iso8601, 4.hours.from_now.iso8601], [Time.zone.now.iso8601, 2.hours.from_now.iso8601],
                       [Time.zone.now.iso8601, 1.hour.from_now.iso8601], [Time.zone.now.iso8601, 30.minutes.from_now.iso8601]]
      due_by_filter_conditions = [{ column_name: 'status', operator: 'in', operand: Helpdesk::TicketStatus.donot_stop_sla_statuses(@account) }]
      due_by_ids.zip(due_by_values).each do |id, value|
        export_params = { data_hash: [{ condition: 'due_by', operator: 'due_by_op', value: id, ff_name: 'default' }] }
        actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
        required_filter_condition = [{ column_name: 'due_by', operator: 'between', operand: value }]
        assert_equal required_filter_condition + due_by_filter_conditions, actual_filter_condition
      end
    end
  end

  def test_due_by_filters_with_le_operator
    Timecop.freeze(silkroad_export_current_time) do
      export_params = { data_hash: [{ condition: 'due_by', operator: 'due_by_op', value: 1, ff_name: 'default' }] }
      actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
      required_filter_condition = [{ column_name: 'due_by', operator: 'le', operand: [Time.zone.now.iso8601] }]
      due_by_filter_conditions = [{ column_name: 'status', operator: 'in', operand: Helpdesk::TicketStatus.donot_stop_sla_statuses(@account) }]
      assert_equal required_filter_condition + due_by_filter_conditions, actual_filter_condition
    end
  end

  def test_filter_conditions_with_multiple_due_by_params
    Timecop.freeze(silkroad_export_current_time) do
      export_params = { data_hash: [{ condition: 'due_by', operator: 'due_by_op', value: '8,3', ff_name: 'default' }] }
      actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
      required_filter_condition = [{ operator: 'nested_or', nested_conditions: [{ column_name: 'due_by', operator: 'between', operand: [Time.zone.now.iso8601, 30.minutes.from_now.iso8601] },
                                                                                { column_name: 'due_by', operator: 'between', operand: [Time.zone.now.tomorrow.beginning_of_day.iso8601, Time.zone.now.tomorrow.end_of_day.iso8601] }] }]
      due_by_filter_conditions = [{ column_name: 'status', operator: 'in', operand: Helpdesk::TicketStatus.donot_stop_sla_statuses(@account) }]
      assert_equal required_filter_condition + due_by_filter_conditions, actual_filter_condition
    end
  end

  def test_filter_conditions_with_resolution_overdue_and_status
    Timecop.freeze(silkroad_export_current_time) do
      export_params = { data_hash: [{ condition: 'due_by', operator: 'due_by_op', value: '1,3', ff_name: 'default' },
                                    { condition: 'status', operator: 'is_in', value: ['2', '3'] }] }
      actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
      required_status_operand = [2, 3] & Helpdesk::TicketStatus.donot_stop_sla_statuses(@account)
      required_filter_condition = [{ operator: 'nested_or', nested_conditions: [{ column_name: 'due_by', operator: 'le', operand: [Time.zone.now.iso8601] },
                                                                                { column_name: 'due_by', operator: 'between', operand: [Time.zone.now.tomorrow.beginning_of_day.iso8601, Time.zone.now.tomorrow.end_of_day.iso8601] }] },
                                   { column_name: 'status', operator: 'in', operand: required_status_operand }]
      assert_equal required_filter_condition, actual_filter_condition
    end
  end

  def test_filter_conditions_with_multiple_fr_due_by_params
    Timecop.freeze(silkroad_export_current_time) do
      export_params = { data_hash: [{ condition: 'frDueBy', operator: 'due_by_op', value: '8,3', ff_name: 'default' }] }
      actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
      required_filter_condition = [{ operator: 'nested_or', nested_conditions: [{ column_name: 'frDueBy', operator: 'between', operand: [Time.zone.now.iso8601, 30.minutes.from_now.iso8601] },
                                                                                { column_name: 'frDueBy', operator: 'between', operand: [Time.zone.now.tomorrow.beginning_of_day.iso8601, Time.zone.now.tomorrow.end_of_day.iso8601] }] }]
      fr_due_by_filter_conditions = [AGENT_RESPONDED_AT_NULL_CONDITION, SOURCE_NOT_OUTBOUND_EMAIL_CONDITION,
                                     { column_name: 'status', operator: 'in', operand: Helpdesk::TicketStatus.donot_stop_sla_statuses(@account) }]
      assert_equal required_filter_condition + fr_due_by_filter_conditions, actual_filter_condition
    end
  end

  def test_filter_conditions_with_fr_due_by_params_and_source
    Timecop.freeze(silkroad_export_current_time) do
      export_params = { data_hash: [{ condition: 'frDueBy', operator: 'due_by_op', value: '3', ff_name: 'default' },
                                    { condition: 'source', operator: 'is_in', value: '1' }] }
      actual_filter_condition = Silkroad::Export::Ticket.new.build_filter_conditions(export_params)
      required_filter_condition = [{ column_name: 'frDueBy', operator: 'between', operand: [Time.zone.now.tomorrow.beginning_of_day.iso8601, Time.zone.now.tomorrow.end_of_day.iso8601] }]
      fr_due_by_filter_conditions = [{ column_name: 'source', operator: 'in', operand: ['1', 10] }, AGENT_RESPONDED_AT_NULL_CONDITION,
                                     { column_name: 'status', operator: 'in', operand: Helpdesk::TicketStatus.donot_stop_sla_statuses(@account) }]
      assert_equal required_filter_condition + fr_due_by_filter_conditions, actual_filter_condition
    end
  end

  ## TICKET FIELDS

  def test_transform_ticket_fields_with_default_contacts_and_company_fields
    export_params = get_valid_export_params
    export_params[:contact_fields] = { fb_profile_id: 'Facebook ID' }
    export_params[:company_fields] = { name: 'Company Name' }
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(export_params)
    actual_ticket_fields = JSON.parse(transformed_export_params).deep_symbolize_keys[:export_fields]
    required_ticket_fields = [{ column_name: 'status', display_name: 'status' }, { column_name: 'responder_id', display_name: 'Agent' },
                              { column_name: 'contact_fb_profile_id', display_name: 'Facebook ID' }, { column_name: 'company_name', display_name: 'Company Name' }]
    assert_equal required_ticket_fields, actual_ticket_fields
  end

  def test_transform_custom_ticket_field
    custom_field = create_custom_field_dropdown('flexifield_dropdown')
    export_params = get_valid_export_params
    export_params[:ticket_fields] = { custom_field.name => custom_field.label }
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(export_params)
    actual_ticket_fields = JSON.parse(transformed_export_params).deep_symbolize_keys[:export_fields]
    required_ticket_fields = [{ column_name: "#{FLEXIFIELDS}.#{custom_field.column_name}", display_name: custom_field.label }]
    assert_equal required_ticket_fields, actual_ticket_fields
  end

  def test_transform_custom_contact_field
    field_type = 'dropdown'
    choices = [{ value: 'FirstChoice', position: 1 }, { value: 'SecondChoice', position: 2 }]
    cf_param = cf_params(type: field_type, field_type: "custom_#{field_type}", label: 'Custom Contact Field', custom_field_choices_attributes: choices)
    custom_field = create_custom_contact_field(cf_param)
    @account.reload # To make sure the custom field is cached

    export_params = get_valid_export_params
    export_params[:contact_fields] = { custom_field.name => custom_field.label }
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(export_params)
    actual_ticket_fields = JSON.parse(transformed_export_params).deep_symbolize_keys[:export_fields]
    required_ticket_fields = [{ column_name: 'status', display_name: 'status' }, { column_name: 'responder_id', display_name: 'Agent' },
                              { column_name: "#{CONTACT_FIELD_DATA}.#{custom_field.column_name}", display_name: custom_field.label }]
    assert_equal required_ticket_fields, actual_ticket_fields
  end

  def test_transform_custom_comapany_field
    field_type = 'dropdown'
    choices = [{ value: 'FirstChoice', position: 1 }, { value: 'SecondChoice', position: 2 }]
    cf_param = company_params(type: field_type, field_type: "custom_#{field_type}", label: 'Custom Company Field', custom_field_choices_attributes: choices)
    custom_field = create_custom_company_field(cf_param)
    @account.reload # To make sure the custom field is cached

    export_params = get_valid_export_params
    export_params[:company_fields] = { custom_field.name => custom_field.label }
    transformed_export_params = Silkroad::Export::Ticket.new.build_request_body(export_params)
    actual_ticket_fields = JSON.parse(transformed_export_params).deep_symbolize_keys[:export_fields]
    required_ticket_fields = [{ column_name: 'status', display_name: 'status' }, { column_name: 'responder_id', display_name: 'Agent' },
                              { column_name: "#{COMPANY_FIELD_DATA}.#{custom_field.column_name}", display_name: custom_field.label }]
    assert_equal required_ticket_fields, actual_ticket_fields
  end

  def test_build_request_body
    request_body = Silkroad::Export::Ticket.new.build_request_body(sample_export_params)
    assert_equal expected_body, request_body
  end

  def test_build_request_body_with_translation
    User.current.language = 'fr'
    User.current.save!
    @account.launch(:silkroad_multilingual)
    request_body = Silkroad::Export::Ticket.new.build_request_body(sample_export_params)
    assert_equal expected_body_fr, request_body
  ensure
    User.current.language = 'en'
    User.current.save!
    I18n.locale = 'en'
    @account.rollback(:silkroad_multilingual)
  end

  private

    def expected_body_fr
      {
        'product_account_id': 1,
        'datastore': {
          'product': 'freshdesk',
          'datastore_name': ActiveRecord::Base.current_shard_selection.shard.to_s
        },
        'date_range': {
          'from': Time.zone.parse('2020-01-13 18:30:00+00:00').iso8601,
          'to': Time.zone.parse('2020-02-13 23:59:59+00:00').iso8601,
          'column_name': 'created_at'
        },
        'filter_conditions': [
          {
            'column_name': 'status',
            'operator': 'in',
            'operand': [2]
          }
        ],
        'export_fields': [
          {
            'column_name': 'display_id',
            'display_name': 'Ticket ID'
          },
          {
            'column_name': 'subject',
            'display_name': 'Subject'
          },
          {
            'column_name': 'status',
            'display_name': 'Status'
          }
        ],
        'name': 'freshdesk_tickets',
        'format': 'csv',
        'callback_url': 'https://localhost.freshpo.com/api/channel/admin/data_export/update',
        'additional_info':
        {
          'timezone': 'Asia/Kolkata',
          'features': {
            'survey': SURVEY_FEATURE_MAPPING[@account.new_survey_enabled?.to_s.to_sym]
          },
          'text': {
            'resolution_status': {
              'IN_SLA': '(conformément au SLA)',
              'VIOLATED_SLA': 'SLA non respecté'
            },
            'first_response_status': {
              'IN_SLA': '(conformément au SLA)',
              'VIOLATED_SLA': 'SLA non respecté'
            },
            'every_response_status': {
              'IN_SLA': '(conformément au SLA)',
              'VIOLATED_SLA': 'SLA non respecté'
            },
            'priority': {
              '1': 'Faible',
              '2': 'Moyenne',
              '3': 'Élevée',
              '4': 'Urgent'
            },
            'source': {
              '1': 'E-mail',
              '2': 'Portail',
              '3': 'Téléphone',
              '4': 'Forum',
              '5': 'Twitter',
              '6': 'Facebook',
              '7': 'Chat',
              '8': 'MobiHelp',
              '9': 'Widget commentaire',
              '10': 'E-mail sortant',
              '11': 'E-commerce',
              '12': 'Bot'
            },
            'association_type': {
              '1': 'Parent',
              '2': 'Enfant',
              '3': 'Tracker',
              '4': 'Ticket associé'
            },
            'status': {
              '2': 'Ouvert',
              '3': 'En attente',
              '4': 'Résolu',
              '5': 'Clôturé',
              '6': 'Waiting on Customer',
              '7': 'Waiting on Third Party'
            }
          }
        }
      }.to_json
    end

    def expected_body
      {
        'product_account_id': 1,
        'datastore': {
          'product': 'freshdesk',
          'datastore_name': ActiveRecord::Base.current_shard_selection.shard.to_s
        },
        'date_range': {
          'from': Time.zone.parse('2020-01-13 18:30:00+00:00').iso8601,
          'to': Time.zone.parse('2020-02-13 23:59:59+00:00').iso8601,
          'column_name': 'created_at'
        },
        'filter_conditions': [
          {
            'column_name': 'status',
            'operator': 'in',
            'operand': [2]
          }
        ],
        'export_fields': [
          {
            'column_name': 'display_id',
            'display_name': 'Ticket ID'
          },
          {
            'column_name': 'subject',
            'display_name': 'Subject'
          },
          {
            'column_name': 'status',
            'display_name': 'Status'
          }
        ],
        'name': 'freshdesk_tickets',
        'format': 'csv',
        'callback_url': 'https://localhost.freshpo.com/api/channel/admin/data_export/update',
        'additional_info':
        {
          'timezone': 'Asia/Kolkata',
          'features': {
            'survey': SURVEY_FEATURE_MAPPING[@account.new_survey_enabled?.to_s.to_sym]
          },
          'text': {
            'resolution_status': {
              'IN_SLA': 'Within SLA',
              'VIOLATED_SLA': 'SLA Violated'
            },
            'first_response_status': {
              'IN_SLA': 'Within SLA',
              'VIOLATED_SLA': 'SLA Violated'
            },
            'every_response_status': {
              'IN_SLA': 'Within SLA',
              'VIOLATED_SLA': 'SLA Violated'
            },
            'priority': {
              '1': 'Low',
              '2': 'Medium',
              '3': 'High',
              '4': 'Urgent'
            },
            'source': {
              '1': 'Email',
              '2': 'Portal',
              '3': 'Phone',
              '4': 'Forum',
              '5': 'Twitter',
              '6': 'Facebook',
              '7': 'Chat',
              '8': 'MobiHelp',
              '9': 'Feedback Widget',
              '10': 'Outbound Email',
              '11': 'Ecommerce',
              '12': 'Bot'
            },
            'association_type': {
              '1': 'Parent',
              '2': 'Child',
              '3': 'Tracker',
              '4': 'Related ticket'
            },
            'status': {
              '2': 'Open',
              '3': 'Pending',
              '4': 'Resolved',
              '5': 'Closed',
              '6': 'Waiting on Customer',
              '7': 'Waiting on Third Party'
            }
          }
        }
      }.to_json
    end

    def sample_export_params
      {
        format: 'csv',
        date_filter: '30',
        ticket_state_filter: 'created_at',
        query_hash: [{
          condition: 'status',
          operator: 'is_in',
          type: 'default',
          value: [2]
        }],
        start_date: '2020-01-13 18:30:00',
        end_date: '2020-02-13 23:59:59',
        ticket_fields: {
          display_id: 'Ticket ID',
          subject: 'Subject',
          status_name: 'Status'
        },
        filter_name: 'all_tickets',
        export_fields: {
          display_id: 'Ticket ID',
          subject: 'Subject',
          status_name: 'Status'
        },
        current_user_id: 1,
        portal_url: 'localhost.freshdesk-dev.com',
        data_hash: [{
          condition: 'status',
          operator: 'is_in',
          value: '2',
          ff_name: 'default'
        }]
      }
    end

    def get_valid_export_params
      {
        format: 'csv',
        ticket_state_filter: 'created_at',
        start_date: '2020-01-01 00:00:00',
        end_date: '2020-01-01 23:59:59',
        ticket_fields: { status_name: 'status', responder_name: 'Agent' },
        data_hash: [{ condition: 'status', operator: 'is_in', value: ['2'], ff_name: 'default' }]
      }.stringify_keys
    end

    def get_valid_transformed_params
      Time.use_zone(TimeZone.find_time_zone) do
        {
          product_account_id: Account.current.id,
          datastore: { product: 'freshdesk', datastore_name: ActiveRecord::Base.current_shard_selection.shard.to_s },
          date_range: {
            from: Time.zone.parse('2020-01-01 00:00:00+00:00').iso8601,
            to: Time.zone.parse('2020-01-01 23:59:59+00:00').iso8601,
            column_name: 'created_at'
          },
          filter_conditions: [{ column_name: 'status', operator: 'in', operand: [2] }],
          export_fields: [{ column_name: 'status', display_name: 'status' }, { column_name: 'responder_id', display_name: 'Agent' }],
          name: 'freshdesk_tickets',
          format: 'csv',
          callback_url: "https://#{Account.current.full_domain}/api/channel/admin/data_export/update",
          additional_info: {
            'timezone': 'Asia/Kolkata',
            'features': {
              'survey': SURVEY_FEATURE_MAPPING[@account.new_survey_enabled?.to_s.to_sym]
            },
            'text': {
              'resolution_status': {
                'IN_SLA': 'Within SLA',
                'VIOLATED_SLA': 'SLA Violated'
              },
              'first_response_status': {
                'IN_SLA': 'Within SLA',
                'VIOLATED_SLA': 'SLA Violated'
              },
              'every_response_status': {
                'IN_SLA': 'Within SLA',
                'VIOLATED_SLA': 'SLA Violated'
              },
              'priority': {
                '1': 'Low',
                '2': 'Medium',
                '3': 'High',
                '4': 'Urgent'
              },
              'source': {
                '1': 'Email',
                '2': 'Portal',
                '3': 'Phone',
                '4': 'Forum',
                '5': 'Twitter',
                '6': 'Facebook',
                '7': 'Chat',
                '8': 'MobiHelp',
                '9': 'Feedback Widget',
                '10': 'Outbound Email',
                '11': 'Ecommerce',
                '12': 'Bot'
              },
              'association_type': {
                '1': 'Parent',
                '2': 'Child',
                '3': 'Tracker',
                '4': 'Related ticket'
              },
              'status': {
                '2': 'Open',
                '3': 'Pending',
                '4': 'Resolved',
                '5': 'Closed',
                '6': 'Waiting on Customer',
                '7': 'Waiting on Third Party'
              }
            }
          }
        }
      end
    end

    def silkroad_export_current_time
      @silkroad_export_current_time ||= Time.use_zone(TimeZone.find_time_zone) do
        Time.zone.now.beginning_of_day + 12.hours
      end
    end
end
