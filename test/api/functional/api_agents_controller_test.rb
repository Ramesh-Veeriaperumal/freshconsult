# require 'faker'
require_relative '../test_helper'
['agents_test_helper.rb', 'attachments_test_helper.rb', 'freshcaller_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
require_relative '../helpers/admin/skills_test_helper'
require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'agent_status_availability.rb')
require 'webmock/minitest'
WebMock.allow_net_connect!
class ApiAgentsControllerTest < ActionController::TestCase
  include Redis::OthersRedis
  include AgentsTestHelper
  include AttachmentsTestHelper
  include Admin::SkillsTestHelper
  include ::Freshcaller::TestHelper
  include ::Freshcaller::Endpoints
  include FreshchatAccountTestHelper
  include Freshchat::AgentUtil
  include AgentStatusAvailabilityTestHelper
  def wrap_cname(params)
    { api_agent: params }
  end

  def setup
    super
    before_all
  end

  def teardown
    Account.current.technicians.where(email: 'john.wick@gmal.com').each(&:destroy)
    Account.current.groups.where(name: %w[liverpool_fc_01 liverpool_fc_02]).each(&:destroy)
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.features.gamification_enable.create
    @@before_all_run = true
  end

  def create_multiple_emails emails, other_params = {}
    email_params = []
    1..2.times do |loop_number|
      email_params.push({ email: emails[loop_number] })
    end
    email_params
  end

  def test_agent_index
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    get :index, controller_params
    assert_response 200
    agents = @account.all_agents.order('users.name')
    pattern = agents.map { |agent| agent_pattern(agent) }
    match_json(pattern.ordered)
  end

  def test_agent_filter_state
    get :index, controller_params(state: 'fulltime')
    assert_response 200
    response = parse_response @response.body
    assert response.size == Agent.where(occasional: false).count
    get :index, controller_params(state: 'occasional')
    assert_response 200
    response = parse_response @response.body
    assert response.size == Agent.where(occasional: true).count
  end

  def test_agent_filter_type
    field_agent_type = AgentType.create_agent_type(@account, 'field_agent')
    3.times do
      add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id })
    end
    Account.stubs(:current).returns(Account.first)
    get :index, controller_params(type: field_agent_type.name.to_s)
    assert_response 200
    response = parse_response @response.body
    assert response.size == Agent.where(agent_type: field_agent_type.agent_type_id).count
  ensure
    Account.current.agents.where(agent_type: field_agent_type.agent_type_id).destroy_all
    field_agent_type.destroy
    Account.unstub(:current)
  end

  def test_agent_filter_email
    email = @account.all_agents.first.user.email
    get :index, controller_params(email: email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_with_invalid_email
    get :index, controller_params(email: '!@#$%')
    assert_response 400
    match_json([bad_request_error_pattern('email', :invalid_format, accepted: 'valid email address')])
  end

  def test_agent_filter_mobile
    @account.all_agents.update_all(mobile: nil)
    @account.all_agents.first.user.update_column(:mobile, '1234567890')
    get :index, controller_params(mobile: '1234567890')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_phone
    @account.all_agents.update_all(phone: nil)
    @account.all_agents.first.user.update_column(:phone, '1234567891')
    get :index, controller_params(phone: '1234567891')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_combined_filter
    @account.all_agents.update_all(phone: nil)
    @account.all_agents.first.user.update_column(:phone, '1234567890')
    @account.all_agents.last.user.update_column(:phone, '1234567890')
    email = @account.all_agents.first.user.email
    get :index, controller_params(email: email, phone: '1234567890')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_index_with_invalid_filter
    get :index, controller_params(name: 'John')
    assert_response 400
    match_json([bad_request_error_pattern('name', :invalid_field)])
  end

  def test_agent_filter_invalid_state
    get :index, controller_params(state: 'active')
    assert_response 400
    match_json([bad_request_error_pattern('state', :not_included, list: 'occasional,fulltime')])
  end

  def test_agent_filter_invalid_type
    get :index, controller_params(type: 1)
    valid_types = @account.agent_types.map(&:name)
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included, list: valid_types.join(','))])
  end

  def test_agent_filter_order_by_default_order_type_asc_desc
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    user_order = @account.all_agents.order('name asc')
    get :index, controller_params(order_type: 'asc')
    check_agents_order(user_order, @response)
    get :index, controller_params(order_type: 'desc')
    check_agents_order(user_order.reverse, @response)
  end

  def test_agent_filter_order_by_name_order_type_asc_desc
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    user_order = @account.all_agents.order('name asc')
    get :index, controller_params(order_by: 'name', order_type: 'asc')
    check_agents_order(user_order, @response)
    get :index, controller_params(order_by: 'name', order_type: 'desc')
    check_agents_order(user_order.reverse, @response)
  end

  def test_agent_filter_order_by_created_at_order_type_asc_desc
    emails = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    created_at_time = generate_time_at_interval(3, 1)
    emails.each_with_index do |email, index|
      options = { role: Role.find_by_name('Agent').id, email: email }
      add_agent(@account, options)
      update_user_created_at(email, created_at_time[index])
    end
    user_order = @account.all_agents.order('created_at asc')
    get :index, controller_params(order_by: 'created_at', order_type: 'asc')
    check_agents_order(user_order.reverse, @response)
    get :index, controller_params(order_by: 'created_at', order_type: 'desc')
    check_agents_order(user_order.reverse, @response)
  end

  def test_agent_filter_order_by_last_active_at_order_type_asc_dsc
    emails = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    created_at_time = generate_time_at_interval(3, 1)
    emails.each_with_index do |email, index|
      options = { role: Role.find_by_name('Agent').id, email: email }
      add_agent(@account, options)
      update_agent_last_activet_at(email, created_at_time[index])
    end
    user_order = @account.all_agents.order('last_active_at asc')
    get :index, controller_params(order_by: 'last_active_at', order_type: 'asc')
    check_agents_order(user_order, @response)
    get :index, controller_params(order_by: 'last_active_at', order_type: 'desc')
    check_agents_order(user_order.reverse, @response)
  end

  def test_show_agent
    sample_agent = @account.all_agents.first
    get :show, construct_params(id: sample_agent.user.id)
    assert_response 200
    match_json(agent_pattern_with_additional_details(sample_agent.user))
  end

  def test_show_agent_with_view_contact_privilege_only
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    sample_agent = @account.all_agents.first
    get :show, construct_params(id: sample_agent.user.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_show_missing_agent
    get :show, construct_params(id: 60_000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_index_with_link_header
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    per_page = @account.all_agents.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/agents?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  # Agent email filter, passing an array to the email attribute

  def test_agent_filter_email_array
    email = sample_agent = @account.all_agents.first.user.email
    get :index, controller_params({ email: [email] }, false)
    assert_response 400
    match_json([bad_request_error_pattern('email', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_agent_valid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name }
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
    assert_response 200
  end

  def test_update_agent_with_invalid_fields
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name, company_id: 1 }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:company_id, :invalid_field)])
    assert_response 400
  end

  def test_update_agent_invalid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { name: nil, phone: 3_534_653, mobile: 6_756_868, email: Faker::Name.name, time_zone: 'Cntral Time (US & Canada)', language: 'huty', occasional: 'yes', signature: 123, ticket_scope: 212,
               role_ids: ['test', 'y'], group_ids: ['test', 'y'], job_title: 234 }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:name, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern(:phone, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:job_title, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:signature, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:occasional, :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(:mobile, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:role_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern(:group_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern(:email, :invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern(:language, :not_included, list: I18n.available_locales.map(&:to_s).join(',')),
                bad_request_error_pattern(:time_zone, :not_included, list: ActiveSupport::TimeZone.all.map(&:name).join(',')),
                bad_request_error_pattern(:ticket_scope, :not_included, list: Agent::PERMISSION_TOKENS_BY_KEY.keys.join(','))])
    assert_response 400
  end

  def test_update_agent_with_blank_mandatory_fields
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { name: '', email: '', time_zone: '', language: '', occasional: nil, ticket_scope: nil,
               role_ids: [] }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:name, :blank),
                bad_request_error_pattern(:occasional, :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern(:role_ids, :blank),
                bad_request_error_pattern(:email, :blank),
                bad_request_error_pattern(:language, :not_included, list: I18n.available_locales.map(&:to_s).join(',')),
                bad_request_error_pattern(:time_zone, :not_included, list: ActiveSupport::TimeZone.all.map(&:name).join(',')),
                bad_request_error_pattern(:ticket_scope, :not_included, list: Agent::PERMISSION_TOKENS_BY_KEY.keys.join(','))
               ])
    assert_response 400
  end

  def test_update_agent_with_inaccessible_fields
    role_ids = Role.limit(2).pluck(:id)
    params = { time_zone: 'Chennai', language: 'en', ticket_scope: 2,
               role_ids: role_ids }
    Account.any_instance.stubs(:multi_timezone_enabled?).returns(false)
    Account.any_instance.stubs(:features?).with(:multi_language).returns(false)
    put :update, construct_params({ id: @agent.id }, params)
    match_json([bad_request_error_pattern(:language, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'language', feature: :multi_language),
                bad_request_error_pattern(:time_zone, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'time_zone', feature: :multi_timezone),
                bad_request_error_pattern(:ticket_scope, :agent_roles_and_scope_error, code: :inaccessible_field),
                bad_request_error_pattern(:role_ids, :agent_roles_and_scope_error, code: :inaccessible_field)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:features?)
    Account.any_instance.unstub(:multi_timezone_enabled?)
  end

  def test_update_agent_with_length_invalid
    role_ids = Role.limit(2).pluck(:id)
    params = { name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300),
               email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", phone: Faker::Lorem.characters(300) }
    put :update, construct_params({ id: @agent.id }, params)
    match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('job_title', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('mobile', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('email', :'Has 328 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('phone', :'Has 300 characters, it can have maximum of 255 characters')])
    assert_response 400
  end

  def test_update_agent_with_array_fields_invalid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { role_ids: '1,2', group_ids: '34,4' }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:role_ids, :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(:group_ids, :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_update_agent_with_manage_user_ability
    current_agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.stubs(:current).returns(current_agent)
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    group_ids = [create_group(@account).id]
    params = {
      name: Faker::Name.name,
      phone: Faker::PhoneNumber.phone_number,
      mobile: Faker::PhoneNumber.phone_number,
      email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)',
      language: 'en',
      occasional: false,
      signature: Faker::Lorem.paragraph,
      ticket_scope: 2,
      group_ids: group_ids,
      job_title: Faker::Name.name
    }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_update_agent_without_manage_user_ability
    current_agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.stubs(:current).returns(current_agent)
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.any_instance.stubs(:privilege?).returns(false)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 403
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_update_field_agent_with_correct_scope_and_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = {email: Faker::Internet.email}
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
  ensure
    agent.destroy
    field_agent_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_field_tech_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = {email: Faker::Internet.email, role_ids: [field_tech_role.id]}
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
  ensure
    agent.destroy
    field_tech_role.destroy
    field_agent_type.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_agent_role_when_field_tech_enabled
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = { role_ids: [Role.find_by_name('Agent').id] } 
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('user.role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'), :code => :invalid_value)])
  ensure
    agent.destroy
    field_tech_role.destroy
    field_agent_type.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_incorrect_scope_and_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    params = { role_ids: [Role.find_by_name('Account Administrator').id], ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('user.role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'), code: :invalid_value), bad_request_error_pattern('ticket_permission', :field_agent_scope, code: :invalid_value)])
  ensure
    agent.destroy if agent.present?
    field_agent_type.destroy if field_agent_type.present?
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_from_group_scope_to_restricted_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets] })
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)["ticket_scope"] == Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
  ensure
    agent.destroy
    field_agent_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end


  def test_update_field_agent_from_group_scope_to_restricted_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets] })
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)["ticket_scope"] == Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
  ensure
    agent.destroy
    field_agent_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_from_restricted_to_group_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)['ticket_scope'] == Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets]
  ensure
    agent.destroy
    field_agent_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_from_group_scope_to_restricted_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets] })
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)["ticket_scope"] == Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
  ensure
    agent.destroy
    field_agent_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_multiple_role
    Account.any_instance.stubs(:agent_types_from_cache).returns(Account.first.agents.first)
    Agent.any_instance.stubs(:find).returns(Account.first.agent_types.first)
    Agent.any_instance.stubs(:length).returns(0)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = { role_ids: [Role.find_by_name('Administrator').id,Role.find_by_name('Field technician').id] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('user.role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'), :code => :invalid_value)])
  ensure
    agent.destroy if agent.present?
    field_agent_type.destroy if field_agent_type.present?
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:agent_types_from_cache)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_support_type_group
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, { role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    group = create_group(@account)
    params = { group_ids: [group.id] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern('group_ids', :should_not_be_support_group)])
    assert_response 400
  ensure
    agent.destroy
    group.destroy
    field_agent_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_support_agent_with_field_type_group
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    group_type = GroupType.create(name: 'field_agent_group', account_id: @account.id, group_type_id: 2)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id)
    group = create_group(@account, group_type: group_type.group_type_id)
    params = { group_ids: [group.id] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)['group_ids'].include?(group.id)
  ensure
    agent.destroy
    group.destroy
    field_agent_type.destroy
    group_type.destroy
    field_tech_role.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_agent_with_array_fields_invalid_model
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { role_ids: [123, 567], group_ids: [466, 566] }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:role_ids, :invalid_list, list: params[:role_ids].join(', ')),
                bad_request_error_pattern(:group_ids, :invalid_list, list: params[:group_ids].join(', '))])
    assert_response 400
  end

  def test_update_agent_with_same_email
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { email: @agent.email }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['agent_id'], @agent.id
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'has already been taken')])
  end

  def test_update_agent_without_any_groups
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    group = create_group_with_agents(@account, agent_list: [agent.id])
    assert AgentGroup.exists?(group_id: group.id)

    params = { group_ids: [] }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    refute AgentGroup.exists?(group_id: group.id)
  end

  def test_update_agent_with_only_role_ids
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    role_ids = Role.limit(2).pluck(:id)
    params = { role_ids: role_ids }
    previous_privelege = agent.privileges
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    refute previous_privelege == updated_agent.privileges
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
    assert_response 200
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
  end

  def test_update_agent_with_string_enumerators_for_level_and_scope
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { ticket_scope: '2' }
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    match_json([bad_request_error_pattern(:ticket_scope, :not_included, code: :datatype_mismatch, list: Agent::PERMISSION_TOKENS_BY_KEY.keys.join(','), prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_update_agent_with_agent_limit_reached_valid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    Subscription.any_instance.stubs(:agent_limit).returns(@account.full_time_support_agents.count)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: true, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name }
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
    assert_response 200
  ensure
    Subscription.any_instance.unstub(:agent_limit)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_update_agent_with_agent_limit_reached_invalid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    agent.agent.update_attributes(occasional: true)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    Subscription.any_instance.stubs(:agent_limit).returns(@account.full_time_support_agents.count - 1)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:occasional, :max_agents_reached, code: :incompatible_value, max_count: (@account.full_time_support_agents.count - 1))])
    assert_response 400
  ensure
    Subscription.any_instance.unstub(:agent_limit)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_update_admin_without_admin_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(@agent)
    @agent.stubs(:privilege?).with(:manage_account).returns(false)
    params = { signature: 'test' }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_update_admin_with_admin_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(@agent)
    @agent.stubs(:privilege?).returns(true)
    params = { signature: 'test' }
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
    assert_response 200
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_update_without_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    params = { signature: 'test' }
    put :update, construct_params({ id: @agent.id }, params)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_destroy
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    delete :destroy, construct_params(id: agent.id)
    assert_response 204
    assert agent.reload.helpdesk_agent == false
    assert_nil Agent.find_by_user_id(agent.id)
  end

  def test_destroy_with_invalid_id
    delete :destroy, construct_params(id: 123)
    assert_response 404
  end

  def test_destroy_without_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    delete :destroy, construct_params(id: agent.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_destroy_admin_without_admin_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(@agent)
    @agent.stubs(:privilege?).with(:manage_account).returns(false)
    delete :destroy, construct_params(id: agent.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_destroy_admin_with_admin_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(@agent)
    @agent.stubs(:privilege?).with(:manage_account).returns(true)
    @agent.stubs(:privilege?).with(:manage_users).returns(true)
    delete :destroy, construct_params(id: agent.id)
    assert_response 204
    assert agent.reload.helpdesk_agent == false
    assert_nil Agent.find_by_user_id(agent.id)
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_destroy_current_user
    delete :destroy, construct_params(id: @agent.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy_agent_with_freshchat
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, freshchat_agent: true)
    freshid_authorization = user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    agent = Account.current.agents.find_by_user_id(user.id)
    freshchat_enabled = agent.additional_settings[:freshchat][:enabled]
    stub_request(:delete, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(status: 404)
    delete :destroy, construct_params(id: user.id)
    assert_response 204
    assert_equal true, freshchat_enabled
  ensure
    User.any_instance.unstub(:freshid_authorization)
    AgentObserver.any_instance.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_destroy_agent_with_manage_user_privilege_only
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    User.stubs(:current).returns(@agent)
    @agent.stubs(:privilege?).with(:manage_account).returns(false)
    @agent.stubs(:privilege?).with(:manage_users).returns(true)
    delete :destroy, construct_params(id: agent.id)
    assert_response 204
    assert agent.reload.helpdesk_agent == false
    assert_nil Agent.find_by_user_id(agent.id)
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_destroy_admin_with_manage_user_privilege_only
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(@agent)
    @agent.stubs(:privilege?).with(:manage_account).returns(false)
    @agent.stubs(:privilege?).with(:manage_users).returns(true)
    delete :destroy, construct_params(id: agent.id)
    assert_response 403
  ensure
    User.unstub(:current)
    User.any_instance.unstub(:privilege?)
  end

  def test_update_fails_with_avatar_id
    AgentValidation.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    put :update, construct_params({ id: @agent.id }, avatar_id: Faker::Number.number(10).to_i)
    match_json([bad_request_error_pattern('avatar_id', :invalid_field)])
    assert_response 400
  ensure
    AgentValidation.any_instance.unstub(:private_api?)
  end

  def test_update_agent_with_unpermitted_fields
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { name: Faker::Name.name }
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:allow_update_agent_enabled?).returns(false)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('base', :cannot_edit_inaccessible_fields)])
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:allow_update_agent_enabled?)
  end

   def test_update_agent_with_unpermitted_fields
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { name: Faker::Name.name }
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:allow_update_agent_enabled?).returns(true)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:allow_update_agent_enabled?)
  end

  def test_update_agent_email_with_freshid_email_not_present_in_freshid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { name: Faker::Name.name, email: Faker::Internet.email }
    User.any_instance.stubs(:update_freshid_user).returns(true)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:allow_update_agent_enabled?).returns(false)
    ApiAgentsController.any_instance.stubs(:freshid_user_details).returns('')
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
  ensure
    Account.current.agents.find_by_user_id(agent.id).destroy
    User.any_instance.unstub(:update_freshid_user)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:allow_update_agent_enabled?)
    ApiAgentsController.any_instance.unstub(:freshid_user_details)
  end

  def test_update_agent_email_with_freshid_email_present_in_freshid
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params = { name: Faker::Name.name, email: Faker::Internet.email }
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:allow_update_agent_enabled?).returns(false)
    ApiAgentsController.any_instance.stubs(:freshid_user_details).returns(User.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
  ensure
    Account.current.agents.find_by_user_id(agent.id).destroy
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:allow_update_agent_enabled?)
    ApiAgentsController.any_instance.unstub(:freshid_user_details)
  end

  def test_filter_agent_list_by_group_id
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    group = create_group_with_agents(@account, agent_list: [agent.id])
    get :index, controller_params(group_id: group.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal agent.id, response[0]['id']
  end

  def test_filter_agent_list_by_invalid_group_id
    get :index, controller_params(group_id: '0')
    assert_response 400
    match_json([bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer')])
  end

  def test_check_role_permission_valid
    account_admin_role_id = Role.find_by_name('Account Administrator').id
    agent = add_test_agent(@account, role: account_admin_role_id)
    params = { role_ids: [account_admin_role_id] }
    specimen_agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    agent.make_current
    put :update, construct_params({ id: specimen_agent.id }, params)
    assert_response 200
  ensure
    agent.destroy
    specimen_agent.destroy
  end

  def test_valid_agents_export
    Account.stubs(:current).returns(Account.first)
    params = { 'response_type' => 'api', 'fields' => ['email', 'name', 'phone'] }
    post :export, construct_params(params)
    assert_response 200
  ensure
    Account.unstub(:current)
  end

  def test_invalid_response_type_for_export
    Account.stubs(:current).returns(Account.first)
    params = { 'response_type' => 'call', 'fields' => ['email', 'name', 'phone'] }
    post :export, construct_params(params)
    response = JSON.parse @response.body
    assert_response 400
    match_json([bad_request_error_pattern('response_type', :"It should be one of these values: 'email,api'", code: :invalid_value)])
  ensure
    Account.unstub(:current)
  end

  def test_export_with_invalid_field_value
    Account.stubs(:current).returns(Account.first)
    params = { 'response_type' => 'email', 'fields' => ['email', 'name', 'phone', 'emp_id'] }
    post :export, construct_params(params)
    response = JSON.parse @response.body
    assert_response 400
    match_json([bad_request_error_pattern('fields', :"Invalid value(s) for field(s): emp_id", code: :invalid_value)])
  ensure
    Account.unstub(:current)
  end

  def test_get_export_s3_url_with_failed_status
    Account.stubs(:current).returns(Account.first)
    ApiAgentsController.any_instance.stubs(:fetch_export_details).returns(status: 'failed')
    ApiAgentsController.any_instance.stubs(:load_data_export).returns({})
    get :export_s3_url, controller_params(id: 'testid')
    response = JSON.parse @response.body
    assert_response 200
    assert_equal response['status'], 'failed'
  ensure
    Account.unstub(:current)
    ApiAgentsController.any_instance.unstub(:fetch_export_details)
    ApiAgentsController.any_instance.unstub(:load_data_export)
  end

  def test_create_agent_with_race_condition_without_redis_key_limit_greater_than_agent_count
    key = agents_count_key
    remove_others_redis_key(key) if redis_key_exists?(key)
    Account.stubs(:current).returns(Account.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name, occasional: false }
    current_agent_count = Account.current.full_time_support_agents.count
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:support_agent_limit_reached?).returns(false)
    subscription = Account.current.subscription
    subscription.agent_limit = current_agent_count + 1
    subscription.state = 'active'
    subscription.save

    post :create, construct_params(params_hash)
    assert_response 201
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    remove_others_redis_key(key) if redis_key_exists?(key)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:support_agent_limit_reached?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_with_race_condition_without_redis_key
    key = agents_count_key
    remove_others_redis_key(key) if redis_key_exists?(key)
    Account.stubs(:current).returns(Account.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name, occasional: false }
    current_agent_count = Account.current.full_time_support_agents.count
    error_message = 'You have reached the maximum number of agents your subscription allows. You need to delete an existing agent or contact your account administrator to purchase additional agents.'
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:support_agent_limit_reached?).returns(false)
    subscription = Account.current.subscription
    subscription.agent_limit = current_agent_count
    subscription.state = 'active'
    subscription.save

    post :create, construct_params(params_hash)
    assert_response 400
    response = parse_response @response.body
    assert_equal response['errors'][0]['message'], error_message
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    remove_others_redis_key(key) if redis_key_exists?(key)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:support_agent_limit_reached?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_with_race_condition_with_redis_key
    key = agents_count_key
    Account.stubs(:current).returns(Account.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name, occasional: false }
    current_agent_count = Account.current.full_time_support_agents.count
    error_message = 'You have reached the maximum number of agents your subscription allows. You need to delete an existing agent or contact your account administrator to purchase additional agents.'
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:support_agent_limit_reached?).returns(false)
    set_others_redis_key(key, current_agent_count)
    subscription = Account.current.subscription
    subscription.agent_limit = current_agent_count
    subscription.state = 'active'
    subscription.save

    post :create, construct_params(params_hash)
    assert_response 400
    response = parse_response @response.body
    assert_equal response['errors'][0]['message'], error_message
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    remove_others_redis_key(key) if redis_key_exists?(key)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:support_agent_limit_reached?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_deleting_and_adding_agent_with_redis_key
    key = agents_count_key
    Account.stubs(:current).returns(Account.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name, occasional: false }
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    current_agent_count = Account.current.full_time_support_agents.count
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:support_agent_limit_reached?).returns(false)
    set_others_redis_key(key, current_agent_count)
    subscription = Account.current.subscription
    subscription.agent_limit = current_agent_count
    subscription.state = 'active'
    subscription.save

    delete :destroy, construct_params(id: agent.id)
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count

    post :create, construct_params(params_hash)
    assert_response 201
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    remove_others_redis_key(key) if redis_key_exists?(key)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:support_agent_limit_reached?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_without_freshid
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    agent_id = response['id']
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.current.agents.find_by_user_id(agent_id).destroy
    Account.unstub(:current)
  end

  def test_create_support_agent_blank_roleids
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    agent_id = response['id']
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.current.agents.find_by_user_id(agent_id).destroy
    Account.unstub(:current)
  end

  def test_create_agent_with_invalid_ticket_scope
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    params_hash = { email: Faker::Internet.email, ticket_scope: 5, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    assert_response 400
    response = parse_response @response.body
    match_json([bad_request_error_pattern(:ticket_scope, :not_included, list: Agent::PERMISSION_TOKENS_BY_KEY.keys.join(','))])
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_with_invalid_fields
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    role_ids = [Account.current.roles.find_by_name('Agent').id]
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name, company_id: 1 }
    post :create, construct_params(params)
    match_json([bad_request_error_pattern(:company_id, :invalid_field)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_invalid_datatypes
    Account.stubs(:current).returns(Account.first)
    params = { name: nil, phone: 3_534_653, mobile: 6_756_868, email: Faker::Name.name, time_zone: 'Cntral Time (US & Canada)', language: 'huty', occasional: 'yes', signature: 123, ticket_scope: 212,
               role_ids: ['test', 'y'], group_ids: ['test', 'y'], job_title: 234 }
    post :create, construct_params(params)
    match_json([bad_request_error_pattern(:name, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern(:phone, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:job_title, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:signature, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:occasional, :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(:mobile, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:role_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern(:group_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern(:email, :invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern(:language, :not_included, list: I18n.available_locales.map(&:to_s).join(',')),
                bad_request_error_pattern(:time_zone, :not_included, list: ActiveSupport::TimeZone.all.map(&:name).join(',')),
                bad_request_error_pattern(:ticket_scope, :not_included, list: Agent::PERMISSION_TOKENS_BY_KEY.keys.join(','))])
    assert_response 400
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_with_role_ids_for_field_agent
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    field_agent_type = AgentType.create_agent_type(@account, 'field_agent')
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], agent_type: 2, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    assert_equal response['errors'][0]['message'], 'Field technicians cannot have Roles: 4'
    assert_response 400
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    field_agent_type.destroy
    Account.unstub(:current)
  end

  def test_create_to_check_freshid_existing_user
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    AgentDelegator.any_instance.stubs(:freshid_user_details).returns(User.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    assert_response 400
    response = parse_response @response.body
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_user_details)
    AgentDelegator.any_instance.unstub(:freshid_user_details)
    Account.unstub(:current)
  end

  def test_create_without_privilege
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.current.stubs(:freshid_user_details).returns(User.first)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    Account.unstub(:current)
    User.any_instance.unstub(:privilege?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_user_details)
  end

  def test_create_agent_with_length_invalid
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    params_hash = { name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300),
                    email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", phone: Faker::Lorem.characters(300) }
    post :create, construct_params(params_hash)
    match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('job_title', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('mobile', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('email', :'Has 328 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('phone', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('ticket_scope', :'Mandatory attribute missing', code: :inaccessible_field)])
    assert_response 400
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_create_field_agent_with_correct_scope_and_role
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, agent_type: field_agent_type.agent_type_id, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    agent_id = response['id']
    assert_response 201
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    field_agent_type.destroy
    field_tech_role.destroy
    Account.current.agents.find_by_user_id(agent_id).destroy
    Account.unstub(:current)
  end

  def test_create_agent_with_incorrect_scope
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    params_hash = { agent_type: field_agent_type.agent_type_id, ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], email: Faker::Internet.email, name: Faker::Name.name }
    Account.stubs(:current).returns(Account.first)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('ticket_scope', :"It should be one of these values: '2,3'", code: :invalid_value)])
  ensure
    field_agent_type.destroy if field_agent_type.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_with_incorrect_role
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    params_hash = { role_ids: [Role.find_by_name('Account Administrator').id], agent_type: field_agent_type.agent_type_id, ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets], email: Faker::Internet.email, name: Faker::Name.name }
    Account.stubs(:current).returns(Account.first)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('role_ids', 'Field technicians cannot have Roles: 1', code: :invalid_value)])
  ensure
    field_agent_type.destroy if field_agent_type.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.unstub(:current)
  end

  def test_create_field_agent_with_field_type_group
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    group_type = GroupType.create(name: 'field_agent_group', account_id: Account.current.id, group_type_id: 2)
    group = create_group(Account.current, group_type: group_type.group_type_id)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, agent_type: field_agent_type.agent_type_id, name: Faker::Name.name, group_ids: [group.id] }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    agent_id = response['id']
    assert_response 201
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    field_agent_type.destroy
    group.destroy
    group_type.destroy
    field_tech_role.destroy
    Account.current.agents.find_by_user_id(agent_id).destroy
    Account.unstub(:current)
  end

  def test_create_agent_with_support_group
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    group = create_group(@account)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name, group_ids: [group.id] }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    agent_id = response['id']
    assert_response 201
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    group.destroy
    Account.unstub(:current)
  end

  def test_create_agent_with_skills
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.current.stubs(:privilege?).with(:manage_skills).returns(true)
    group = create_group(@account)
    skill1 = create_dummy_skill
    skill2 = create_dummy_skill
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name, group_ids: [group.id], skill_ids: [skill1[:id], skill2[:id]] }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    agent_id = response['id']
    assert_response 201
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    group.destroy
    Account.current.unstub(:skill_based_round_robin_enabled?)
    User.current.unstub(:privilege?)
    Account.current.agents.find_by_user_id(agent_id).destroy
    Account.unstub(:current)
    skill1.destroy
    skill2.destroy
  end

  def test_create_agent_sbrr_not_enabled
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(false)
    User.current.stubs(:privilege?).with(:manage_skills).returns(true)
    group = create_group(@account)
    skill1 = create_dummy_skill
    skill2 = create_dummy_skill
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name, group_ids: [group.id], skill_ids: [skill1[:id], skill2[:id]] }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    assert_response 400
    match_json([bad_request_error_pattern('skill_ids', :invalid_field)])
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    group.destroy
    Account.current.unstub(:skill_based_round_robin_enabled?)
    User.current.unstub(:privilege?)
    Account.unstub(:current)
    skill1.destroy
    skill2.destroy
  end

  def test_create_agent_without_skill_privilege
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.current.stubs(:privilege?).with(:manage_skills).returns(false)
    group = create_group(@account)
    skill1 = create_dummy_skill
    skill2 = create_dummy_skill
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, name: Faker::Name.name, group_ids: [group.id], skill_ids: [skill1[:id], skill2[:id]] }
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    assert_response 400
    match_json([bad_request_error_pattern('skill_ids', :inaccessible_field)])
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    group.destroy
    Account.current.unstub(:skill_based_round_robin_enabled?)
    User.current.unstub(:privilege?)
    Account.unstub(:current)
    User.unstub(:current)
    skill1.destroy
    skill2.destroy
  end

  def test_create_agent_with_agent_level_id
    Account.stubs(:current).returns(Account.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name, agent_level_id: 2 }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    assert_equal response['agent_level_id'], 2
  ensure
    Account.unstub(:current)
  end

  def test_create_agent_with_existing_agent
    email = Faker::Internet.email
    agent = add_agent(@account, email: email)
    params_hash = { email: email, ticket_scope: 1, name: Faker::Name.name }
    post :create, construct_params(params_hash)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['agent_id'], agent.id
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'has already been taken')])
  end

  def test_create_agent_with_agent_level_id_gamification_disabled
    Account.any_instance.stubs(:gamification_enabled?).returns(false)
    Account.stubs(:current).returns(Account.first)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Agent').id], name: Faker::Name.name, agent_level_id: 2 }
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:agent_level_id, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'agent_level_id', feature: :gamification)])
  ensure
    Account.any_instance.unstub(:gamification_enabled?)
    Account.unstub(:current)
  end

  def test_create_agent_with_freshchat_enabled
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Account Administrator').id], name: Faker::Name.name, freshchat_agent: true }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    assert_equal response['freshchat_agent'], true
  ensure
    AgentObserver.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_create_agent_in_freshchat_with_feature_disabled
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(false)
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Account Administrator').id], name: Faker::Name.name, freshchat_agent: true }
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:freshchat_agent, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'freshchat_agent', feature: :omni_chat_agent)])
  ensure
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_create_agent_with_freshcaller_enabled
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    stub_create_users
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Account Administrator').id], name: Faker::Name.name, freshcaller_agent: true }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    assert_equal true, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_create_agent_with_freshcaller_disabled
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    params_hash = { email: Faker::Internet.email, ticket_scope: 2, role_ids: [Account.current.roles.find_by_name('Account Administrator').id], name: Faker::Name.name, freshcaller_agent: false }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    assert_equal false, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_update_admin_with_skills
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.current.stubs(:privilege?).with(:manage_skills).returns(true)
    skill1 = create_dummy_skill
    skill2 = create_dummy_skill
    params = { skill_ids: [skill1[:id], skill2[:id]] }
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
    assert_response 200
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    User.current.unstub(:privilege?)
    User.unstub(:current)
    skill1.destroy
    skill2.destroy
    agent.destroy
  end

  def test_update_agent_sbrr_not_enabled
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(false)
    User.current.stubs(:privilege?).with(:manage_skills).returns(true)
    skill1 = create_dummy_skill
    skill2 = create_dummy_skill
    params = { skill_ids: [skill1[:id], skill2[:id]] }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('skill_ids', :invalid_field)])
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    User.current.unstub(:privilege?)
    skill1.destroy
    skill2.destroy
    agent.destroy
  end

  def test_update_focus_mode_preferences
    user = add_test_agent(@account)
    params = { focus_mode: false }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    assert_equal user.agent.focus_mode?, false
  end

  def test_update_multiple_without_id
    payload = { "agents" => [
                {
                  "ticket_assignment" => {
                    "available" => true
                  }
                }
              ]}
    put :update_multiple, construct_params(payload)
    result = parse_response(@response.body)
    assert_response 400
    assert_equal result, { "description" => "Validation failed",
                           "errors" => [
                              { "field"=>"id",
                                "message"=>"It should be a/an Integer",
                                "code"=>"missing_field"
                              }
                            ]
                          }
  end

  def test_update_multiple_without_ticket_assignment
    payload = { "agents" => [
                {
                  "id" => Account.current.account_managers.first.id
                }
              ]}
    put :update_multiple, construct_params(payload)
    result = parse_response(@response.body)
    assert_response 400
    assert_equal result, { "description" => "Validation failed",
                           "errors" => [
                              { "field" => "ticket_assignment",
                                "message" => "can't be blank",
                                "code" => "invalid_value"
                              }
                            ]
                          }
  end

  def test_update_multiple_without_available
    payload = { "agents" => [
                {
                  "id" => Account.current.account_managers.first.id,
                  "ticket_assignment" => {}
                }
              ]}
    put :update_multiple, construct_params(payload)
    result = parse_response(@response.body)
    assert_response 400
    assert_equal result, { "description" => "Validation failed",
                           "errors" => [
                              { "field"=>"ticket_assignment",
                                "message"=>"can't be blank",
                                "code"=>"invalid_value"
                              }
                            ]
                          }
  end

  def test_update_multiple_invalid_key_in_ticket_assignment
    payload = { "agents" => [
                {
                  "id" => Account.current.account_managers.first.id,
                  "ticket_assignment" => { "test" => "test" }
                }
              ]}
    put :update_multiple, construct_params(payload)
    result = parse_response(@response.body)
    assert_response 400
    assert_equal result, { "description" => "Validation failed",
                           "errors" => [
                              { "field"=>"test",
                                "message"=>"Unexpected/invalid field in request",
                                "code"=>"invalid_field"
                              }
                            ]
                          }
  end

  def test_update_multiple_invalid_value_in_available
    payload = { "agents" => [
                {
                  "id" => Account.current.account_managers.first.id,
                  "ticket_assignment" => { "available" => "test" }
                }
              ]}
    put :update_multiple, construct_params(payload)
    result = parse_response(@response.body)
    assert_response 400
    assert_equal result, { "description" => "Validation failed",
                           "errors" => [
                              { "field"=>"ticket_assignment",
                                "nested_field"=>"ticket_assignment.available",
                                "message"=>"It should be a/an Boolean",
                                "code"=>"datatype_mismatch"
                              }
                            ]
                          }
  end

  def test_update_multiple_with_valid_payload
    payload = { "agents" => [
                {
                  "id" => Account.current.account_managers.first.id,
                  "ticket_assignment" => { "available" => true }
                }
              ]}
    put :update_multiple, construct_params(payload)
    result = parse_response(@response.body)
    assert_response 202
    assert_equal result, {"job_id"=>nil, "href"=>"https://localhost.freshpo.com/api/v2/jobs/"}
  end

  def test_update_freshcaller_agent_without_freshcaller
    Account.any_instance.stubs(:freshcaller_enabled?).returns(false)
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    params = { freshcaller_agent: true }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:freshcaller_agent, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'freshcaller_agent', feature: :freshcaller)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_agent_update_to_create_freshchat_agent
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    params = { freshchat_agent: true }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal response['freshchat_agent'], true
  ensure
    AgentObserver.any_instance.unstub(:freshchat_domain?)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_agent_update_to_disable_freshchat_agent_standalone_account
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, freshchat_agent: true)
    agent = Account.current.agents.find_by_user_id(user.id)
    freshchat_enabled = agent.additional_settings[:freshchat][:enabled]
    params = { freshchat_agent: false }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshchat_enabled
    assert_equal response['freshchat_agent'], false
  ensure
    AgentObserver.any_instance.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_agent_update_to_disable_freshchat_agent_omni_account
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    stub_request(:put, %r{^https://test-freshchat.freshpo.com/v2/agents/.*?$}).to_return(body: { 'is_deactivated' => true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, freshchat_agent: true)
    freshid_authorization = user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    agent = Account.current.agents.find_by_user_id(user.id)
    freshchat_enabled = agent.additional_settings[:freshchat][:enabled]
    params = { freshchat_agent: false }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshchat_enabled
    assert_equal response['freshchat_agent'], false
  ensure
    User.any_instance.unstub(:freshid_authorization)
    AgentObserver.any_instance.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_bundle_id)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_agent_update_to_re_enable_freshchat_agent
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    stub_request(:put, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: { 'is_deactivated' => false }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, freshchat_agent: true)
    freshid_authorization = user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    agent = Account.current.agents.find_by_user_id(user.id)
    freshchat_enabled_before_disabling = agent.additional_settings[:freshchat][:enabled]
    agent.additional_settings[:freshchat][:enabled] = false
    agent.save
    agent.reload
    freshchat_enabled_after_disabling = agent.additional_settings[:freshchat][:enabled]
    params = { freshchat_agent: true }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshchat_enabled_before_disabling
    assert_equal false, freshchat_enabled_after_disabling
    assert_equal response['freshchat_agent'], true
  ensure
    User.any_instance.unstub(:freshid_authorization)
    AgentObserver.any_instance.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_agent_update_with_duplicate_update_to_freshchat_agent
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, freshchat_agent: true)
    agent = Account.current.agents.find_by_user_id(user.id)
    freshchat_enabled = agent.additional_settings[:freshchat][:enabled]
    params = { freshchat_agent: true }
    put :update, construct_params({ id: user.id }, params)
    AgentObserver.any_instance.expects(:handle_fchat_agent).times(0)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshchat_enabled
    assert_equal response['freshchat_agent'], true
  ensure
    AgentObserver.any_instance.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_agent_update_with_invalid_freshchat_agent_update
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    AgentObserver.any_instance.stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    create_fc_account
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: {}.to_json, status: 200)
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = Account.current.agents.find_by_user_id(user.id)
    freshchat_enabled = agent.additional_settings.try(:[], :freshchat).try(:[], :enabled)
    params = { freshchat_agent: false }
    put :update, construct_params({ id: user.id }, params)
    agent.reload
    AgentObserver.any_instance.expects(:handle_fchat_agent).times(0)
    assert_response 200
    response = parse_response @response.body
    assert_equal nil, freshchat_enabled
    assert_equal false, response['freshchat_agent']
    assert_equal nil, agent.additional_settings.try(:[], :freshchat).try(:[], :enabled)
  ensure
    AgentObserver.any_instance.unstub(:freshchat_domain)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
  end

  def test_agent_update_to_create_freshcaller_agent
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    stub_create_users
    params = { freshcaller_agent: true }
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_agent_update_to_disable_freshcaller_agent_omni_account
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: true,
      fc_user_id: 1234
    )
    stub_create_users_already_present(1234, true)
    freshcaller_enabled = agent.freshcaller_agent.try(:fc_enabled)
    params = { freshcaller_agent: false }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshcaller_enabled
    assert_equal false, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:omni_bundle_id)
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_agent_update_to_disable_freshcaller_agent_standalone_account
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: true,
      fc_user_id: 1234
    )
    freshcaller_enabled = agent.freshcaller_agent.try(:fc_enabled)
    params = { freshcaller_agent: false }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshcaller_enabled
    assert_equal false, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:omni_bundle_id)
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_agent_update_to_re_enable_freshcaller_agent
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: false,
      fc_user_id: 1234
    )
    stub_create_users_already_present(1234, false)
    freshcaller_enabled = agent.freshcaller_agent.try(:fc_enabled)
    params = { freshcaller_agent: true }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, freshcaller_enabled
    assert_equal true, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_agent_update_with_duplicate_update_to_freshcaller_agent
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: true,
      fc_user_id: 1234
    )
    freshcaller_enabled = agent.freshcaller_agent.try(:fc_enabled)
    params = { freshcaller_agent: true }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, freshcaller_enabled
    assert_equal true, response['freshcaller_agent']
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_destroy_agent_with_omni_freshcaller
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: true,
      fc_user_id: 1234
    )
    freshcaller_enabled = agent.freshcaller_agent.try(:fc_enabled)
    stub_create_users_already_present(1234, true)
    delete :destroy, construct_params(id: user.id)
    assert_response 204
    assert_equal true, freshcaller_enabled
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:omni_bundle_id)
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_destroy_agent_with_standalone_freshcaller
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: false,
      fc_user_id: 1234
    )
    freshcaller_enabled = agent.freshcaller_agent.try(:fc_enabled)
    delete :destroy, construct_params(id: user.id)
    assert_response 204
    assert_equal false, freshcaller_enabled
  ensure
    delete_freshcaller_account
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_update_agent_with_agent_level_id
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, agent_level_id: 3)
    params = { agent_level_id: 4 }
    put :update, construct_params({ id: agent.id }, params)
    updated_agent = User.find(agent.id)
    match_json(agent_pattern_with_additional_details(params, updated_agent))
    match_json(agent_pattern_with_additional_details({}, updated_agent))
    assert_response 200
  end

  def test_update_agent_with_invalid_agent_level_id
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id, agent_level_id: 3)
    params = { agent_level_id: 2 }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern('agent_level_id', :"Agent level cannot be lower than current level", code: :invalid_value)])
    assert_response 400
  end

  def test_update_agent_level_id_with_gamification_disabled
    Account.any_instance.stubs(:gamification_enabled?).returns(false)
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    params = { agent_level_id: 2 }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:agent_level_id, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'agent_level_id', feature: :gamification)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:gamification_enabled?)
  end

  def test_update_multiple_with_50_agents
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    agent_array = []
    agent_role_id = Role.find_by_name('Agent').id
    50.times do
      agent_array << {
        "id" => add_test_agent(@account, role: agent_role_id).id,
        "ticket_assignment" => { "available" => true }
      }
    end
    payload = { "agents" => agent_array }
    dynamo_response = { 'payload' => agent_array , 'action' => 'update_multiple' }
    BulkApiJobs::Agent.any_instance.stubs(:pick_job).returns(dynamo_response)
    Sidekiq::Testing.inline! do
      put :update_multiple, construct_params(payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
    payload['agents'].each do |agent|
      assert_equal Account.current.agents.find_by_user_id(agent['id']).available, true
    end
  ensure
    BulkApiJobs::Agent.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_get_agent_statuses_availability
    toggle_agent_status_feature(true)
    stubbed_request = stub_request(:get, 'http://localhost:8080/api/v1/agents/1/availability').to_return(body: sample_show.to_json, status: 200)
    get :fetch_availability, construct_params(id: '1')
    assert_response 200
  ensure
    remove_request_stub(stubbed_request)
    toggle_agent_status_feature(false)
  end

  def test_patch_agent_statuses_availability
    toggle_agent_status_feature(true)
    stubbed_request = stub_request(:patch, 'http://localhost:8080/api/v1/agents/1/availability').to_return(body: sample_show.to_json, status: 200)
    process(:update_availability, construct_params(id: '1'), nil, nil, 'PATCH')
    assert_response 200
  ensure
    remove_request_stub(stubbed_request)
    toggle_agent_status_feature(false)
  end

  def test_patch_agent_availability_feature_not_present_should_return_forbidden
    toggle_agent_status_feature(false)
    process(:update_availability, construct_params(id: '1'), nil, nil, 'PATCH')
    assert_response 403
  end

  def test_get_agent_availability_feature_not_present_should_return_forbidden
    toggle_agent_status_feature(false)
    get :fetch_availability, construct_params(id: '1')
    assert_response 403
  end

  def test_contribution_group_creation_without_feature
    enable_advanced_ticket_scopes {}
    params = {
      "name": 'John doe', "email": 'john.james0709@gmal.com', "ticket_scope": 2,
      "contribution_group_ids": [3, 4]
    }
    post :create, construct_params(params)
    error_data = [bad_request_error_pattern(:advanced_ticket_scopes,
                                            :require_feature,
                                            code: :access_denied, feature: :advanced_ticket_scopes)]
    assert_response 403
    match_json(description: 'Validation failed', errors: error_data)
  end

  def test_create_contribution_group_for_global_scope
    enable_advanced_ticket_scopes do
      params = {
        "name": 'John doe', "email": 'john.james0709@gmal.com', "ticket_scope": 1,
        "contribution_group_ids": [3, 4]
      }
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:contribution_group_ids,
                                              :contribution_group_is_not_available_for_global_access,
                                              code: :invalid_value)]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_contribution_group_for_restricted_access
    enable_advanced_ticket_scopes do
      params = {
        "name": 'John doe', "email": 'john.james0709@gmal.com', "ticket_scope": 3,
        "contribution_group_ids": [3, 4]
      }
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:contribution_group_ids,
                                              :contribution_group_is_not_available_for_global_access,
                                              code: :invalid_value)]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_contribution_group_being_nil
    enable_advanced_ticket_scopes do
      params = {
        "name": 'John doe', "email": 'john.james0709@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": nil
      }
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:contribution_group_ids,
                                              'Value set is of type Null.It should be a/an Array',
                                              code: :datatype_mismatch)]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_contribution_group_being_blank
    enable_advanced_ticket_scopes do
      params = {
        "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": []
      }
      post :create, construct_params(params)
      assert_response 201
      agent = Account.current.technicians.reload.where(email: 'john.wick@gmal.com').first.agent
      match_json(agent_pattern_with_additional_details(agent.user))
    end
  end

  def test_invalid_contribution_group_id_for_create_agent
    enable_advanced_ticket_scopes do
      last_group_id = Account.current.groups.reload.pluck_all(:id).max + 100
      params = {
        "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": [last_group_id]
      }
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:contribution_group_ids,
                                              :invalid_list,
                                              code: :invalid_value, list: [last_group_id])]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_common_id_for_both_contribition_group_and_group_ids
    enable_advanced_ticket_scopes do
      group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                   create_group(@account, name: 'liverpool_fc_02').id]
      params = {
        "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": [group_ids.first], group_ids: group_ids
      }
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"group_ids/contribution_group_ids",
                                              :uniq_group_and_contribution_error_message,
                                              code: :invalid_value)]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_agent_with_group_id_blank_contribution_not_blank
    enable_advanced_ticket_scopes do
      group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                   create_group(@account, name: 'liverpool_fc_02').id]
      params = {
        "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": group_ids, group_ids: []
      }
      post :create, construct_params(params)
      assert_response 201
      agent = Account.current.technicians.reload.where(email: 'john.wick@gmal.com').first.agent
      match_json(agent_pattern_with_additional_details(agent.user))
      write_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: true).count
      read_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: false).count
      assert write_groups.zero?
      assert_equal 2, read_groups
    end
  end

  def test_create_agent_with_group_id_not_blank_contribution_blank
    enable_advanced_ticket_scopes do
      group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                   create_group(@account, name: 'liverpool_fc_02').id]
      params = {
        "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": [], group_ids: group_ids
      }
      post :create, construct_params(params)
      assert_response 201
      agent = Account.current.technicians.reload.where(email: 'john.wick@gmal.com').first.agent
      match_json(agent_pattern_with_additional_details(agent.user))
      write_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: true).count
      read_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: false).count
      assert_equal 2, write_groups
      assert read_groups.zero?
    end
  end

  def test_create_agent_with_both_group_and_contribution_group_not_blank
    enable_advanced_ticket_scopes do
      group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                   create_group(@account, name: 'liverpool_fc_02').id]
      params = {
        "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
        "contribution_group_ids": [group_ids.first], group_ids: [group_ids.last]
      }
      post :create, construct_params(params)
      assert_response 201
      agent = Account.current.technicians.reload.where(email: 'john.wick@gmal.com').first.agent
      match_json(agent_pattern_with_additional_details(agent.user))
      write_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: true).pluck_all(:group_id)
      read_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: false).pluck_all(:group_id)
      assert_equal [group_ids.last], write_groups
      assert_equal [group_ids.first], read_groups
    end
  end

  def test_create_agent_with_group_ids
    enable_advanced_ticket_scopes {}
    group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                 create_group(@account, name: 'liverpool_fc_02').id]
    params = {
      "name": 'John wick', "email": 'john.wick@gmal.com', "ticket_scope": 2,
      group_ids: [group_ids.last]
    }
    post :create, construct_params(params)
    assert_response 201
    agent = Account.current.technicians.reload.where(email: 'john.wick@gmal.com').first.agent
    match_json(agent_pattern_with_additional_details(agent.user))
    write_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: true).pluck_all(:group_id)
    read_groups = Account.current.agent_groups.where(user_id: agent.user_id, write_access: false).pluck_all(:group_id)
    assert_equal [group_ids.last], write_groups
    assert read_groups.count.zero?
  end

  def test_update_agent_with_both_group_id_and_contribution_group_blank
    dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
    group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                 create_group(@account, name: 'liverpool_fc_02').id]
    dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.first; ag.write_access = false; ag.save! }
    dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.last; ag.write_access = true; ag.save! }
    enable_advanced_ticket_scopes do
      params = {
        group_ids: [], "contribution_group_ids": []
      }
      put :update, construct_params({ id: dummy_user.id }, params)
      write_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: true).count
      read_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: false).count
      assert write_groups.zero?
      assert read_groups.zero?
    end
  end

  def test_update_agent_with_group_and_contribution_interchanged
    dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
    group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                 create_group(@account, name: 'liverpool_fc_02').id]
    dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.first; ag.write_access = false; ag.save! }
    dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.last; ag.write_access = true; ag.save! }
    enable_advanced_ticket_scopes do
      params = {
        group_ids: [group_ids.first], "contribution_group_ids": [group_ids.last]
      }
      put :update, construct_params({ id: dummy_user.id }, params)
      write_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: true).pluck(:group_id)
      read_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: false).pluck(:group_id)
      assert_equal [group_ids.first], write_groups
      assert_equal [group_ids.last], read_groups
    end
  end

  def test_update_agent_with_change_to_all_ticket_permission
    enable_advanced_ticket_scopes do
      dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
      group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                   create_group(@account, name: 'liverpool_fc_02').id]
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.first; ag.write_access = false; ag.save! }
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.last; ag.write_access = true; ag.save! }
      params = { ticket_scope: 1 }
      put :update, construct_params({id: dummy_user.id}, params)
      write_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: true).count
      read_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: false).count
      assert_response 200
      assert_equal 1, write_groups
      assert read_groups.zero?
    end
  end

  def test_update_agent_with_change_to_restricted_permission
    enable_advanced_ticket_scopes do
      dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
      group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                   create_group(@account, name: 'liverpool_fc_02').id]
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.first; ag.write_access = false; ag.save! }
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids.last; ag.write_access = true; ag.save! }
      params = { ticket_scope: 3 }
      put :update, construct_params({id: dummy_user.id}, params)
      write_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: true).count
      read_groups = Account.current.agent_groups.where(user_id: dummy_user.id, write_access: false).count
      assert_response 200
      assert_equal 1, write_groups
      assert read_groups.zero?
    end
  end

  def test_create_agent_with_contribution_group_for_fsm_agent
    enable_advanced_ticket_scopes do
      enable_fsm_feature do
        params = {
          "name": 'John doe', "email": 'john.wick@gmal.com', "ticket_scope": 2,
          "contribution_group_ids": [3, 4], "agent_type": 2
        }
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern(:contribution_group_ids,
                                                :contribution_group_not_allowed_fsm,
                                                code: :invalid_value)]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_update_fsm_agent_with_contribution_group
    group_ids = Account.current.groups.pluck_all(:id)
    enable_advanced_ticket_scopes do
      enable_fsm_feature do
        group_ids = Account.current.groups.pluck_all(:id)
        dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2, agent_type: 2)
        update_params = { "contribution_group_ids": group_ids[0, 2] }
        put :update, construct_params({ id: dummy_user.id }, update_params)
        error_data = [bad_request_error_pattern(:contribution_group_ids,
                                                :contribution_group_not_allowed_fsm,
                                                code: :invalid_value)]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_update_agent_with_write_access_group_as_readone
    enable_advanced_ticket_scopes do
      group_ids = Account.current.groups.pluck_all(:id)
      dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids[0]; ag.write_access = true; ag.save! }
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids[1]; ag.write_access = true; ag.save! }
      update_params = { "contribution_group_ids": group_ids[0, 3] }
      put :update, construct_params({ id: dummy_user.id }, update_params)
      error_data = [bad_request_error_pattern(:contribution_group_ids,
                                              :group_ids_already_used,
                                              code: :invalid_value, list: group_ids[0, 2].sort.join(', '))]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_update_agent_with_read_access_group_as_writeone
    enable_advanced_ticket_scopes do
      group_ids = Account.current.groups.pluck_all(:id)
      dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids[0]; ag.write_access = false; ag.save! }
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids[1]; ag.write_access = false; ag.save! }
      update_params = { "group_ids": group_ids[0, 3] }
      put :update, construct_params({ id: dummy_user.id }, update_params)
      error_data = [bad_request_error_pattern(:group_ids,
                                              :contribution_group_ids_already_used,
                                              code: :invalid_value, list: group_ids[0, 2].sort.join(', '))]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_update_agent_with_duplicate_group_issues
    group_ids = [create_group(@account, name: 'liverpool_fc_01').id,
                 create_group(@account, name: 'liverpool_fc_02').id].sort
    dummy_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: 2)
    dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_ids[1]; ag.write_access = true; ag.save! }
    update_params = { "group_ids": group_ids }
    put :update, construct_params({ id: dummy_user.id }, update_params)
    assert_response 200
    assert_equal 2, Account.current.agent_groups.where(user_id: dummy_user.id).count
  end

  def test_availability_count
    feature_not_exist = Account.current.add_feature(:omni_channel_routing)
    lp_feature_exist = Account.current.launched?(:omni_agent_availability_dashboard)
    Account.current.launch(:omni_agent_availability_dashboard)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    ApiAgentsController.any_instance.stubs(:request_ocr).returns(AVAILABILITY_COUNT_RESPONSE.to_json)
    get :availability_count, controller_params
    assert_response 200
    match_json(availability_count_pattern)
  ensure
    ApiAgentsController.any_instance.unstub(:request_ocr)
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:omni_agent_availability_dashboard) if !lp_feature_exist
    Account.current.revoke_feature(:omni_channel_routing) if feature_not_exist
  end

  def test_availability_count_with_valid_group_filter
    feature_not_exist = Account.current.add_feature(:omni_channel_routing)
    lp_feature_exist = Account.current.launched?(:omni_agent_availability_dashboard)
    Account.current.launch(:omni_agent_availability_dashboard)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    availability_count_response = AVAILABILITY_COUNT_RESPONSE.dup
    availability_count_response[:agents_availability_count].slice!(:freshdesk)
    ApiAgentsController.any_instance.stubs(:request_ocr).returns(availability_count_response.to_json)
    get :availability_count, controller_params(freshdesk_group_ids: '1,2,3')
    assert_response 200
    match_json(availability_count_pattern(availability_count_response))
  ensure
    ApiAgentsController.any_instance.unstub(:request_ocr)
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:omni_agent_availability_dashboard) if !lp_feature_exist
    Account.current.revoke_feature(:omni_channel_routing) if feature_not_exist
  end

  def test_availability_count_with_invalid_group_filter
    feature_not_exist = Account.current.add_feature(:omni_channel_routing)
    lp_feature_exist = Account.current.launched?(:omni_agent_availability_dashboard)
    Account.current.launch(:omni_agent_availability_dashboard)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    get :availability_count, controller_params(group_ids: '1,2,3')
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :invalid_field)])
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:omni_agent_availability_dashboard) if !lp_feature_exist
    Account.current.revoke_feature(:omni_channel_routing) if feature_not_exist
  end

  def test_availability_count_without_ocr_feature
    feature_exist = Account.current.revoke_feature(:omni_channel_routing)
    lp_feature_exist = Account.current.launched?(:omni_agent_availability_dashboard)
    Account.current.launch(:omni_agent_availability_dashboard)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    get :availability_count, controller_params
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'omni_channel_routing'.titleize))
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:omni_agent_availability_dashboard) if !lp_feature_exist
    Account.current.add_feature(:omni_channel_routing) if feature_exist
  end

  def test_availability_count_without_dashboard_feature
    feature_not_exist = Account.current.add_feature(:omni_channel_routing)
    lp_feature_exist = Account.current.launched?(:omni_agent_availability_dashboard)
    Account.current.rollback(:omni_agent_availability_dashboard) if lp_feature_exist
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    get :availability_count, controller_params
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'omni_agent_availability_dashboard'.titleize))
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.launch(:omni_agent_availability_dashboard) if lp_feature_exist
    Account.current.revoke_feature(:omni_channel_routing) if feature_not_exist
  end

  def test_availability_count_without_privilege
    feature_not_exist = Account.current.add_feature(:omni_channel_routing)
    lp_feature_exist = Account.current.launched?(:omni_agent_availability_dashboard)
    Account.current.launch(:omni_agent_availability_dashboard)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
    get :availability_count, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:omni_agent_availability_dashboard) if !lp_feature_exist
    Account.current.revoke_feature(:omni_channel_routing) if feature_not_exist
  end

  def test_only_availability_ocr_feature
    @account.stubs(:omni_channel_routing_enabled?).returns(false)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    get :index, controller_params(only: 'availability')
    assert_response 400
    match_json([bad_request_error_pattern('only', :require_feature_for_attribute, code: :inaccessible_field, attribute: 'only=availability', feature: :omni_channel_routing)])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_only_availability_dashboard_feature
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(false)
    get :index, controller_params(only: 'availability')
    assert_response 400
    match_json([bad_request_error_pattern('only', :require_feature_for_attribute, code: :inaccessible_field, attribute: 'only=availability', feature: :omni_agent_availability_dashboard)])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_channel_param_with_only_availability
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    get :index, controller_params(channel: 'freshdesk')
    assert_response 400
    match_json([bad_request_error_pattern('channel', :require_availability, code: :inaccessible_field, param: :channel)])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_channel_param_with_group_id
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    get :index, controller_params(only: 'availability', channel: 'freshdesk')
    assert_response 400
    match_json([bad_request_error_pattern('channel', :require_group_id, code: :invalid_value, param: :channel)])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_group_id_param_with_channel
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    get :index, controller_params(only: 'availability', group_id: '222')
    assert_response 400
    match_json([bad_request_error_pattern('group_id', :require_channel, code: :invalid_value, param: :group_id)])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_search_term_with_only_availability
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    get :index, controller_params(search_term: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('search_term', :require_availability, code: :inaccessible_field, param: :search_term)])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_supervisor_access_only_availability
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    ApiAgentsController.any_instance.stubs(:request_ocr).returns(ocr_agents_response(channel: {}))
    get :index, controller_params(only: 'availability')
    assert_response 200
    match_json([])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
    User.any_instance.unstub(:privilege?)
  end

  def test_supervisor_access_denied_for_only_param
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    get :index, controller_params(only: 'available')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
    User.any_instance.unstub(:privilege?)
  end

  def test_ata_enabled_agents_across_channels
    freshdesk_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id)
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    channels_data = {
      freshdesk: { available: false, assignment_limit: 10, availability_updated_at: Faker::Time.between(10.days.ago, 2.days.ago), round_robin_enabled: false },
      freshcaller: { available: false, assignment_limit: 1, logged_in: false, on_call: false, availability_updated_at: Faker::Time.between(10.days.ago, 2.days.ago), round_robin_enabled: false },
      freshchat: { available: false, assignment_limit: 3, logged_in: false, availability_updated_at: Faker::Time.between(10.days.ago, 2.days.ago), round_robin_enabled: false }
    }
    fd_name = Faker::Lorem.characters(5)
    status_id = Faker::Number.number(3)
    ApiAgentsController.any_instance.stubs(:request_ocr).returns(ocr_agents_response(channel: { freshdesk_user.id.to_s => channels_data }, name: fd_name, status_id: status_id))
    group = create_group_with_agents(@account, agent_list: [freshdesk_user.id])
    get :index, controller_params(only: 'availability', channel: 'freshdesk', group_id: group.id, search_term: 'First')
    assert_response 200
    pattern = ocr_agents_availability_pattern(id: freshdesk_user.id.to_s, name: fd_name, status_id: status_id, availability: ocr_agent_availability_reformat(channels_data))
    match_json(pattern)
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_no_ata_enabled_agents_across_channels
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    ApiAgentsController.any_instance.stubs(:request_ocr).returns(ocr_agents_response(channel: {}))
    get :index, controller_params(only: 'availability')
    assert_response 200
    match_json([])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  private

    def enable_advanced_ticket_scopes
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      yield
    ensure
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end

    def enable_fsm_feature
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      fsm_agent_type = Account.current.agent_types.where(name: Agent::FIELD_AGENT.to_s).first
      AgentType.create_agent_type(@account, Agent::FIELD_AGENT) if fsm_agent_type.blank?
      yield
    ensure
      Account.current.agent_types.where(name: Agent::FIELD_AGENT).first.destroy if fsm_agent_type.blank?
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def create_fc_account
      @fchat_account = Freshchat::Account.where(account_id: Account.current.id).first
      @fchat_account ||= create_freshchat_account Account.current
    end

    def toggle_agent_status_feature(enable)
      enable ? Account.current.launch(:agent_statuses) : Account.current.rollback(:agent_statuses)
    end
end
