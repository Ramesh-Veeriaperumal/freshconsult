require_relative '../../test_helper.rb'
['shared_ownership_test_helper.rb', 'company_fields_test_helper.rb', 'contact_fields_test_helper.rb'].each do |file|
  require Rails.root.join("test/core/helpers/#{file}")
end
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

class Admin::AutomationsControllerTest < ActionController::TestCase
  include AutomationTestHelper
  include AutomationDelegatorTestHelper
  include TicketFieldsTestHelper
  include CompanyFieldsTestHelper
  include ContactFieldsTestHelper
  include SharedOwnershipTestHelper
  include Admin::Automation::AutomationSummary

  def wrap_cname(params)
    { automation: params }
  end

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run

    Account.current.enable_setting(:shared_ownership)
    Account.current.ticket_fields.custom_fields.each(&:destroy)
    get_all_custom_fields
    create_products(Account.current)
    create_tags_data(Account.current) if Account.current.tags.count == 0
    get_a_dropdown_custom_field
    get_a_nested_custom_field
    ceate_contact_segments
    get_custom_contact_fields
    get_custom_company_fields
    @account = Account.current || Account.first.make_current
    initialize_internal_agent_with_default_internal_group
    Account.current.disable_setting(:shared_ownership)
    @@before_all_run = true
  end

  def teardown
    va_rules = Account.current.account_va_rules.find_by_id(@va_rule_id)
    va_rules.destroy if va_rules.present?
    @va_rule_id = nil
    User.any_instance.unstub(:privilege?)
    unstub_service_task_automation_lp_and_privilege
    super
  end

  def enable_service_task_automation_lp_and_privileges
    User.any_instance.stubs(:privilege?).with(:manage_service_task_automation_rules).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
  end

  def unstub_service_task_automation_lp_and_privilege
    User.any_instance.unstub(:privilege?)
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  # Start Invalid rule & Feature not enabled test cases
  def test_invalid_rule_type
    get :index, controller_params(rule_type: 123)
    assert_response 404
    match_json('code' => 'rule_type_not_allowed',
               'message' => 'Rule type not allowed: 123')
  end

  # START Dispatcher test cases
  def test_get_dispatcher_rules
    get :index, controller_params(rule_type: VAConfig::RULES[:dispatcher])
    assert_response 200
    rules = Account.current.all_va_rules
    match_json(rules_pattern(rules))
  end

  def test_delete_dispatcher_rule
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    delete :destroy,
    controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: rule_id)
    assert_response 204
  end

  def test_delete_invalid_dispatcher_rule_id
    delete :destroy, controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: 0)
    assert_response 404
  end

  def test_dispatcher_create_with_ticket_conditions_subject
    dispatcher_create_test(:subject)
  end

  def test_dispatcher_create_with_ticket_conditions_description
    dispatcher_create_test(:description)
  end

  def test_dispatcher_create_with_ticket_conditions_cf_paragraph
    dispatcher_create_test(:cf_paragraph)
  end

  def test_dispatcher_create_with_ticket_conditions_cf_text
    dispatcher_create_test(:cf_text)
  end

  def test_dispatcher_create_with_ticket_conditions_subject_or_description
    dispatcher_create_test(:subject_or_description)
  end

  def test_dispatcher_create_with_ticket_conditions_from_email
    dispatcher_create_test(:from_email)
  end

  def test_dispatcher_create_with_ticket_conditions_to_email
    dispatcher_create_test(:to_email)
  end

  def test_dispatcher_create_with_ticket_conditions_ticket_cc
    dispatcher_create_test(:ticket_cc)
  end

  def test_dispatcher_create_with_ticket_conditions_ticket_type
    dispatcher_create_test(:ticket_type)
  end

  def test_dispatcher_create_with_ticket_conditions_product_id
    dispatcher_create_test(:product_id)
  end

  def test_dispatcher_create_with_ticket_conditions_group_id
    dispatcher_create_test(:group_id)
  end

  def test_dispatcher_create_with_ticket_conditions_responder_id
    dispatcher_create_test(:responder_id)
  end

  def test_dispatcher_create_with_ticket_conditions_cf_checkbox
    dispatcher_create_test(:cf_checkbox)
  end

  def test_dispatcher_create_with_ticket_conditions_cf_number
    dispatcher_create_test(:cf_number)
  end

  def test_dispatcher_create_with_ticket_conditions_status
    dispatcher_create_test(:status)
  end

  def test_dispatcher_create_with_ticket_conditions_priority
    dispatcher_create_test(:priority)
  end

  def test_dispatcher_create_with_ticket_conditions_source
    dispatcher_create_test(:source)
  end

  def test_dispatcher_create_with_ticket_conditions_cf_decimal
    dispatcher_create_test(:cf_decimal)
  end

  def test_dispatcher_create_with_ticket_conditions_cf_date
    dispatcher_create_test(:cf_date)
  end

  def test_dispatcher_create_with_ticket_actions_priority
    dispatcher_create_test(:cf_date, :priority)
  end

  def test_dispatcher_create_with_ticket_actions_ticket_type
    dispatcher_create_test(:cf_date, :ticket_type)
  end

  def test_dispatcher_create_with_ticket_actions_status
    dispatcher_create_test(:cf_date, :status)
  end

  def test_dispatcher_create_with_ticket_actions_responder_id
    dispatcher_create_test(:cf_date, :responder_id)
  end

  def test_dispatcher_create_with_ticket_actions_group_id
    dispatcher_create_test(:cf_date, :group_id)
  end

  def test_dispatcher_create_with_ticket_actions_internal_agent_id
    dispatcher_create_test(:cf_date, :internal_agent_id)
  end

  def test_dispatcher_create_with_ticket_actions_product_id
    dispatcher_create_test(:cf_date, :product_id)
  end

  def test_dispatcher_create_with_ticket_actions_internal_group_id
    dispatcher_create_test(:cf_date, :internal_group_id)
  end

  def test_dispatcher_create_with_ticket_actions_add_a_cc
    dispatcher_create_test(:cf_date, :add_a_cc)
  end

  def test_dispatcher_create_with_ticket_actions_add_tag
    dispatcher_create_test(:cf_date, :add_tag)
  end

  def test_dispatcher_create_with_contact_email
    dispatcher_create_test(:email, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_name
    dispatcher_create_test(:name, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_job_title
    dispatcher_create_test(:job_title, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_segments
    dispatcher_create_test(:segments, :add_tag, :contact)
  end

  def test_dispatcher_create_with_twitter_followers_count
    dispatcher_create_test(:twitter_followers_count, :add_tag, :contact)
  end

  def test_dispatcher_create_with_twitter_profile_status
    dispatcher_create_test(:twitter_profile_status, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_time_zone
    dispatcher_create_test(:time_zone, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_language
    dispatcher_create_test(:language, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_test_custom_text
    dispatcher_create_test(:test_custom_text, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_test_custom_paragraph
    dispatcher_create_test(:test_custom_paragraph, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_test_custom_checkbox
    dispatcher_create_test(:test_custom_checkbox, :add_tag, :contact)
  end

  def test_dispatcher_create_with_contact_test_custom_number
    dispatcher_create_test(:test_custom_number, :add_tag, :contact)
  end

  def test_dispatcher_create_with_company_name
    dispatcher_create_test(:name, :add_tag, :company)
  end

  def test_dispatcher_create_with_company_domains
    dispatcher_create_test(:domains, :add_tag, :company)
  end

  def test_dispatcher_create_with_company_renewal_date
    dispatcher_create_test(:renewal_date, :add_tag, :company)
  end

  def test_dispatcher_create_with_company_test_custom_text
    dispatcher_create_test(:test_custom_text, :add_tag, :company)
  end

  def test_dispatcher_create_with_company_test_custom_paragraph
    dispatcher_create_test(:test_custom_paragraph, :add_tag, :company)
  end

  def test_dispatcher_create_with_company_test_custom_checkbox
    dispatcher_create_test(:test_custom_checkbox, :add_tag, :company)
  end

  def test_dispatcher_create_with_company_test_custom_number
    dispatcher_create_test(:test_custom_number, :add_tag, :company)
  end

  def test_show_for_dispatcher
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }.merge(va_rule_request), va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    get :show, controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: va_rule_id)
    assert_response(200)
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end
  # END Dispatcher test cases

  # START observer test cases
  def test_get_observer_rules
    get :index, controller_params(rule_type: VAConfig::RULES[:observer])
    assert_response 200
    rules = Account.current.all_observer_rules
    match_json(rules_pattern(rules))
  end

  def test_create_observer_rule_with_ticket_events_priority
    observer_create_test(:priority)
  end

  def test_create_observer_rule_with_ticket_events_ticket_type
    observer_create_test(:ticket_type)
  end

  def test_create_observer_rule_with_ticket_events_status
    observer_create_test(:status)
  end

  def test_create_observer_rule_with_ticket_responder_id
    observer_create_test(:responder_id)
  end

  def test_create_observer_rule_with_ticket_group_id
    observer_create_test(:group_id)
  end

  def test_create_observer_rule_with_ticket_note_type
    observer_create_test(:note_type)
  end

  def test_create_dispatcher_rule
    dispatcher_create_test(:source)
  end

  def test_show_for_observer
    rule_type = VAConfig::RULES[:observer]
    Account.current.account_va_rules.destroy_all
    va_rule_request = valid_request_observer(:ticket_type)
    post :create, construct_params({ rule_type: rule_type }.merge(va_rule_request), va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    get :show, controller_params(rule_type: rule_type).merge(id: va_rule_id)
    assert_response(200)
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end
  # END observer test cases

  # START position reorder test cases
  def test_reorder_from_low_to_higher_index
    rule_type = VAConfig::RULES[:dispatcher]
    4.times do
      va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
      post :create, construct_params({ rule_type: rule_type }.merge(va_rule_request), va_rule_request)
    end
    position_mapping = get_va_rules_position
    positions = position_mapping.keys
    first_value = [positions[0], position_mapping[positions[0]]]
    last_value = [positions[1], position_mapping[positions[1]]]
    put :update, construct_params({ rule_type: rule_type, id: first_value[1] }, { 'position': last_value[0].to_i })
    assert_response(200)
    position_mapping[first_value[0]] = last_value[1]
    position_mapping[last_value[0]] = first_value[1]
    actual_position_mapping = get_va_rules_position
    match_custom_json(actual_position_mapping, position_mapping)
  end

  def get_va_rules_position
    Account.current.all_va_rules.where('id is not null').inject({}) do |hash, x|
      hash.merge!(x.position.to_s => x.id.to_s)
    end
  end
  # END position reorder test cases

  # START freddy test cases
  def test_create_observer_rule_with_thank_you_note_feature_disabled
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(false)
    va_rule_request = observer_rule_json_with_thank_you_note
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 403
    parsed_response = JSON.parse(response.body)
    match_json({
      'description': 'Validation failed',
      'errors': [
        {
          'field': 'freddy_suggestion[:condition]',
          'message': 'The detect_thank_you_note feature(s) is/are not supported in your plan. Please upgrade your account to use it.',
          'code': 'access_denied'
        }
      ]
    })
  end

  def test_create_observer_rule_with_thank_you_note_feature_enabled
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(true)
    va_rule_request = observer_rule_json_with_thank_you_note
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rule = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rule.destroy if va_rule.present?
  end

  def test_create_observer_rule_with_thank_you_note_wrong_performer
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(true)
    va_rule_request = observer_rule_json_with_thank_you_note
    va_rule_request['performer']['type'] = 1
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    parsed_response = JSON.parse(response.body)
    match_json({
      'description': 'Validation failed',
      'errors': [
        {
          'field': 'conditions[:condition_set_1][:ticket][:freddy_suggestion][2]',
          'message': "Thank you note in condition can only be used for 'add private note/reply sent' events performed by customer",
          'code': 'invalid_value'
        }
      ]
    })
  end

  def test_create_observer_rule_with_thank_you_note_wrong_event
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(true)
    va_rule_request = observer_rule_json_with_thank_you_note
    va_rule_request['events'] = [
      {
        'field_name': 'priority',
        'from': '--',
        'to': '--'
      }
    ]
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    parsed_response = JSON.parse(response.body)
    match_json({
      'description': 'Validation failed',
      'errors': [
        {
          'field': 'conditions[:condition_set_1][:ticket][:freddy_suggestion][2]',
          'message': "Thank you note in condition can only be used for 'add private note/reply sent' events performed by customer",
          'code': 'invalid_value'
        }
      ]
      })
  end
  # END freddy test cases

  def test_create_supervisor_rule
    Account.current.add_feature :supervisor_custom_status
    va_rule_request = sample_supervisor_json_without_conditions
    custom_status = create_custom_status
    condition_data = [{ 'name': 'hours_since_waiting_on_custom_status', 'custom_status_id': custom_status.status_id, 'operator': 'greater_than', 'value': 6 }]
    va_rule_request['conditions'] = conditions_hash(condition_data, 'any')
    post :create, construct_params({ rule_type: VAConfig::RULES[:supervisor] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    assert_equal rule.name, parsed_response['name']
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
    custom_status.destroy if custom_status.present?
    Account.current.reload
    Account.current.revoke_feature(:supervisor_custom_status) if Account.current.supervisor_custom_status_enabled?
  end

  def test_create_supervisor_condition_without_custom_status_id
    Account.current.add_feature :supervisor_custom_status
    va_rule_request = sample_supervisor_json_without_conditions
    condition_data = [{ 'name': 'hours_since_waiting_on_custom_status', 'operator': 'greater_than', 'value': 6 }]
    va_rule_request['conditions'] = conditions_hash(condition_data, 'any')
    post :create, construct_params({ rule_type: VAConfig::RULES[:supervisor] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    match_json ({ 'description': 'Validation failed',
                  'errors': [
                    { 'field': 'conditions[:condition_set_1][:ticket][:hours_since_waiting_on_custom_status]',
                      'message': "Expecting these field 'custom_status_id' present for request parameter 'conditions[:condition_set_1][:ticket][:hours_since_waiting_on_custom_status]'",
                      'code': 'invalid_value'
                    }
                  ] })
  ensure
    Account.current.reload
    Account.current.revoke_feature(:supervisor_custom_status) if Account.current.supervisor_custom_status_enabled?
  end

  def test_create_supervisor_condition_invalid_custom_status_id
    Account.current.add_feature :supervisor_custom_status
    va_rule_request = sample_supervisor_json_without_conditions
    condition_data = [{ 'name': 'hours_since_waiting_on_custom_status', 'custom_status_id': -1, 'operator': 'greater_than', 'value': 6 }]
    va_rule_request['conditions'] = conditions_hash(condition_data, 'any')
    post :create, construct_params({ rule_type: VAConfig::RULES[:supervisor] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    match_json ({ 'description': 'Validation failed', 'errors': [{ 'field': 'custom_status_id', 'message': "Invalid value: '-1' for 'custom_status_id'", 'code': 'invalid_value' }] })
  ensure
    Account.current.reload
    Account.current.revoke_feature(:supervisor_custom_status) if Account.current.supervisor_custom_status_enabled?
  end

  def test_create_observer_rule_for_response_due
    Account.current.account_va_rules.destroy_all
    va_rule_request = observer_rule_json_with_response_due_event
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    @status = nil
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_create_observer_rule_for_resolution_due
    Account.current.account_va_rules.destroy_all
    va_rule_request = observer_rule_json_with_resolution_due_event
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    @status = nil
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_create_observer_rule_for_next_response_due
    Account.current.account_va_rules.destroy_all
    va_rule_request = observer_rule_json_with_next_response_due_event
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    @status = nil
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_create_observer_rule_for_invalid_response_due
    Account.current.account_va_rules.destroy_all
    va_rule_request = observer_rule_json_with_invalid_response_due_event
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    match_json({ 'description': 'Validation failed', 'errors': [{ 'field': 'events[:response]', 'message': 'Unexpected/invalid field in request', 'code': 'invalid_field' }, { 'field': 'conditions[:conditions_set_1][:response]', 'message': 'Unexpected/invalid field in request', 'code': 'invalid_field' }] })
  ensure
    Account.current.reload
  end

  def test_create_observer_rule_for_invalid_resolution_due
    Account.current.account_va_rules.destroy_all
    va_rule_request = observer_rule_json_with_invalid_resolution_due_event
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    match_json({ 'description': 'Validation failed', 'errors': [{ 'field': 'events[:resolution]', 'message': 'Unexpected/invalid field in request', 'code': 'invalid_field' }, { 'field': 'conditions[:conditions_set_1][:resolution]', 'message': 'Unexpected/invalid field in request', 'code': 'invalid_field' }] })
  ensure
    Account.current.reload
  end

  def test_create_observer_rule_for_invalid_next_response_due
    Account.current.account_va_rules.destroy_all
    va_rule_request = observer_rule_json_with_invalid_next_response_due_event
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    match_json({ 'description': 'Validation failed', 'errors': [{ 'field': 'events[:next_response]', 'message': 'Unexpected/invalid field in request', 'code': 'invalid_field' }, { 'field': 'conditions[:conditions_set_1][:next_response]', 'message': 'Unexpected/invalid field in request', 'code': 'invalid_field' }] })
  ensure
    Account.current.reload
  end

  def test_observer_rule_with_null_value_in_condition
    observer_rule = Account.current.all_observer_rules.first
    delete_value_from_condition(observer_rule) if observer_rule.present?
    get :index, controller_params(rule_type: VAConfig::RULES[:observer])
    assert_response 200
  ensure
    Account.current.reload
  end

  # Service task automation cases

  def test_create_service_task_dispatcher_rule_when_field_service_management_is_disabled
    enable_service_task_automation_lp_and_privileges
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_create_service_task_observer_rule_without_manage_service_task_automations_privilege
    enable_service_task_automation_lp_and_privileges
    User.any_instance.stubs(:privilege?).with(:manage_service_task_automation_rules).returns(false)
    va_rule_request = valid_request_observer(:priority)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_service_task_dispatcher_rule_path
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(rule_id)
    expected_rule_path = "https://#{Account.current.host}/a/field-service/admin/automations/service-task-creation/#{rule_id}/edit"
    actual_rule_path = rule.rule_path
    assert_equal expected_rule_path, actual_rule_path
  end

  def test_service_task_dispatcher_create_with_ticket_conditions_cf_date
    enable_service_task_automation_lp_and_privileges
    dispatcher_create_test(:cf_date, :priority, :ticket, VAConfig::RULES[:service_task_dispatcher])
  end

  def test_service_task_dispatcher_create_with_ticket_conditions_cf_date_time
    enable_service_task_automation_lp_and_privileges
    dispatcher_create_test(:cf_date_time, :priority, :ticket, VAConfig::RULES[:service_task_dispatcher])
  end

  def test_get_service_task_dispatcher_rules
    enable_service_task_automation_lp_and_privileges
    get :index, controller_params(rule_type: VAConfig::RULES[:service_task_dispatcher])
    assert_response 200
    rules = Account.current.all_service_task_dispatcher_rules
    match_json(rules_pattern(rules))
  end

  def test_update_service_task_dispatcher_rule
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    new_va_rule_request = valid_request_dispatcher_with_ticket_conditions(:ticket_type)
    put :update, construct_params({ rule_type: VAConfig::RULES[:service_task_dispatcher], id: rule_id }, new_va_rule_request)
    parsed_update_response = JSON.parse(response.body)
    rule = Account.current.account_va_rules.find(rule_id)
    assert_response 200
    match_custom_json(parsed_update_response, new_va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def test_delete_service_task_dispatcher_rule
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(:source)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    delete :destroy,
           controller_params(rule_type: VAConfig::RULES[:service_task_dispatcher]).merge(id: rule_id)
    rule = Account.current.account_va_rules.find_by_id(rule_id)
    assert_response 204
    assert_nil rule
  end

  def test_summary_in_service_task_dispatcher_for_add_note_action
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_dispatcher_rule('add_note')
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal ' <div class = SummaryKey>Add note and notify field technician</div> ', summary[:actions][0]
  end

  def test_summary_in_service_task_dispatcher_for_assign_group_action
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_dispatcher_rule('group_id')
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal ' <div class = SummaryKey>Assign to Service Group</div> <div class = SummaryValue>Product Management</div>', summary[:actions][0]
  end

  def test_summary_in_service_task_dispatcher_for_assign_group_in_same_ticket
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_dispatcher_rule('group_id', 'priority', 'same_ticket')
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal 'On the same service task <div class = SummaryKey>Assign to Service Group</div> <div class = SummaryValue>Product Management</div>', summary[:actions][0]
  end

  def test_summary_in_service_task_dispatcher_for_assign_group_in_parent_ticket
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_dispatcher_rule('group_id', 'priority', 'parent_ticket')
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal 'On the parent ticket <div class = SummaryKey>Assign to Group</div> <div class = SummaryValue>Product Management</div>', summary[:actions][0]
  end

  def test_summary_in_service_task_dispatcher_for_group_assign_in_condition
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_dispatcher_rule('priority', 'group_id')
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Service Group</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Product Management</div>', summary[:conditions][:condition_set_1][0]
    assert_equal ' <div class = SummaryKey>Set Priority as</div> <div class = SummaryValue>Low</div>', summary[:actions][0]
  end

  def test_summary_in_service_task_dispatcher_for_agent_assign
    agent = add_agent_to_group(nil, ticket_permission = 1, role_id = @account.roles.supervisor.first.id)
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_dispatcher_rule('responder_id', nil, nil, action: { responder_id: agent.id })
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal " <div class = SummaryKey>Assign to Field Technician</div> <div class = SummaryValue>#{agent.name}</div>", summary[:actions][0]
    agent.try(:destroy)
  end

  def test_summary_in_service_task_dispatcher_for_agent_assign_in_same_ticket
    enable_service_task_automation_lp_and_privileges
    agent = add_agent_to_group(nil, ticket_permission = 1, role_id = @account.roles.supervisor.first.id)
    rule = create_service_task_dispatcher_rule('responder_id', 'priority', 'same_ticket', action: { responder_id: agent.id }, condition: { priority: 1 })
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal "On the same service task <div class = SummaryKey>Assign to Field Technician</div> <div class = SummaryValue>#{agent.name}</div>", summary[:actions][0]
    agent.try(:destroy)
  end

  def test_summary_in_service_task_dispatcher_for_assign_agent_in_parent_ticket
    enable_service_task_automation_lp_and_privileges
    agent = add_agent_to_group(nil, ticket_permission = 1, role_id = @account.roles.supervisor.first.id)
    rule = create_service_task_dispatcher_rule('responder_id', 'priority', 'parent_ticket', action: { responder_id: agent.id }, condition: { priority: 1 })
    summary = generate_summary(rule, true)
    assert_equal 'If <div class = SummaryKey>Priority</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>Low</div>', summary[:conditions][:condition_set_1][0]
    assert_equal "On the parent ticket <div class = SummaryKey>Assign to Agent</div> <div class = SummaryValue>#{agent.name}</div>", summary[:actions][0]
    agent.try(:destroy)
  end

  def test_summary_in_service_task_dispatcher_for_agent_assign_in_condition
    enable_service_task_automation_lp_and_privileges
    agent = add_agent_to_group(nil, ticket_permission = 1, role_id = @account.roles.supervisor.first.id)
    rule = create_service_task_dispatcher_rule('priority', 'responder_id', nil, action: { priority: 1 }, condition: { responder_id: agent.id })
    summary = generate_summary(rule, true)
    assert_equal "If <div class = SummaryKey>Field Technician</div> <div class = SummaryOperator>is</div> <div class = SummaryValue>#{agent.name}</div>", summary[:conditions][:condition_set_1][0]
    assert_equal ' <div class = SummaryKey>Set Priority as</div> <div class = SummaryValue>Low</div>', summary[:actions][0]
    agent.try(:destroy)
  end

  def test_create_service_task_observer_rule_with_ticket_events_ticket_type
    enable_service_task_automation_lp_and_privileges
    observer_create_test(:ticket_type, :subject, :priority, VAConfig::RULES[:service_task_observer])
  end

  def test_service_task_observer_for_agent_assign_condition
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:priority, :responder_id, :status, 3)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(rule_id)
    match_custom_json(parsed_response, va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def test_summary_in_service_task_observer_for_association_type_same_ticket_in_action_with_agent_performer
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_observer_rule('1', 'same_ticket')
    summary = generate_summary(rule, true)
    assert_equal 'When an action performed by <div class = SummaryKey>Field Technician</div>', summary[:performer]
    assert_equal 'On the same service task <div class = SummaryKey>Set Priority as</div> <div class = SummaryValue>Low</div>', summary[:actions][0]
    assert_equal 'When <div class = SummaryKey>Priority</div>', summary[:events][0]
  end

  def test_summary_in_service_task_observer_for_association_type_same_ticket_in_action_with_requester_performer
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_observer_rule('2', 'same_ticket')
    summary = generate_summary(rule, true)
    assert_equal 'When an action performed by <div class = SummaryKey>Requester</div>', summary[:performer]
    assert_equal 'On the same service task <div class = SummaryKey>Set Priority as</div> <div class = SummaryValue>Low</div>', summary[:actions][0]
    assert_equal 'When <div class = SummaryKey>Priority</div>', summary[:events][0]
  end

  def test_summary_in_service_task_observer_for_association_same_ticket_in_action_with_any_performer
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_observer_rule('3', 'same_ticket')
    summary = generate_summary(rule, true)
    assert_equal 'When an action performed by <div class = SummaryKey>Field Technician or Requester</div>', summary[:performer]
    assert_equal 'On the same service task <div class = SummaryKey>Set Priority as</div> <div class = SummaryValue>Low</div>', summary[:actions][0]
    assert_equal 'When <div class = SummaryKey>Priority</div>', summary[:events][0]
  end

  def test_summary_in_service_task_observer_for_association_type_parent_ticket_action
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_observer_rule('3', 'parent_ticket')
    summary = generate_summary(rule, true)
    assert_equal 'When an action performed by <div class = SummaryKey>Field Technician or Requester</div>', summary[:performer]
    assert_equal 'On the parent ticket <div class = SummaryKey>Set Priority as</div> <div class = SummaryValue>Low</div>', summary[:actions][0]
    assert_equal 'When <div class = SummaryKey>Priority</div>', summary[:events][0]
  end

  def test_summary_in_service_task_observer_for_add_note_action
    enable_service_task_automation_lp_and_privileges
    rule = create_service_task_observer_rule('3', 'same_ticket', 'add_note')
    summary = generate_summary(rule, true)
    assert_equal 'When an action performed by <div class = SummaryKey>Field Technician or Requester</div>', summary[:performer]
    assert_equal 'On the same service task <div class = SummaryKey>Add note and notify field technician</div> ', summary[:actions][0]
    assert_equal 'When <div class = SummaryKey>Priority</div>', summary[:events][0]
  end

  def test_service_task_observer_for_agent_assign_action
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:priority, :status, :responder_id, 3)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(rule_id)
    match_custom_json(parsed_response, va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def test_service_task_observer_for_assign_group_condition
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:priority, :group_id, :status, 3)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(rule_id)
    match_custom_json(parsed_response, va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def test_service_task_observer_for_assign_group_action
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:priority, :status, :group_id, 3)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(rule_id)
    match_custom_json(parsed_response, va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def test_service_task_observer_rule_path
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:priority)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(rule_id)
    expected_rule_path = "https://#{Account.current.host}/a/field-service/admin/automations/service-task-updates/#{rule_id}/edit"
    actual_rule_path = rule.rule_path
    assert_equal expected_rule_path, actual_rule_path
  end

  def test_update_service_task_observer_rule
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:priority)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    new_va_rule_request = valid_request_dispatcher_with_ticket_conditions(:ticket_type)
    put :update, construct_params({ rule_type: VAConfig::RULES[:service_task_observer], id: rule_id }, new_va_rule_request)
    parsed_update_response = JSON.parse(response.body)
    rule = Account.current.account_va_rules.find(rule_id)
    assert_response 200
    match_custom_json(parsed_update_response, automation_rule_pattern(rule))
  end

  def test_get_service_task_observer_rules
    enable_service_task_automation_lp_and_privileges
    get :index, controller_params(rule_type: VAConfig::RULES[:service_task_observer])
    assert_response 200
    rules = Account.current.all_service_task_observer_rules
    match_json(rules_pattern(rules))
  end

  def test_delete_service_task_observer_rule
    enable_service_task_automation_lp_and_privileges
    va_rule_request = valid_request_observer(:ticket_type)
    post :create, construct_params({ rule_type: VAConfig::RULES[:service_task_observer] }.merge(va_rule_request), va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    delete :destroy,
           controller_params(rule_type: VAConfig::RULES[:service_task_observer]).merge(id: va_rule_id)
    rule = Account.current.account_va_rules.find_by_id(va_rule_id)
    assert_response 204
    assert_nil rule
  end
end
