require_relative '../test_helper'
class ApiAgentsControllerTest < ActionController::TestCase
  include AgentsTestHelper
  def wrap_cname(params)
    { api_agent: params }
  end

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.features.gamification_enable.create
    @@before_all_run = true
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

  def test_me
    get :me, controller_params
    assert_response 200
    match_json(agent_pattern_with_additional_details(@agent))
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
    Account.any_instance.stubs(:features?).with(:multi_timezone).returns(false)
    Account.any_instance.stubs(:features?).with(:multi_language).returns(false)
    put :update, construct_params({ id: @agent.id }, params)
    match_json([bad_request_error_pattern(:language, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'language', feature: :multi_language),
                bad_request_error_pattern(:time_zone, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'time_zone', feature: :multi_timezone),
                bad_request_error_pattern(:ticket_scope, :agent_roles_and_scope_error, code: :inaccessible_field),
                bad_request_error_pattern(:role_ids, :agent_roles_and_scope_error, code: :inaccessible_field)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:features?)
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
    match_json([bad_request_error_pattern(:email, :'Email has already been taken')])
    assert_response 409
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
    Subscription.any_instance.stubs(:agent_limit).returns(@account.full_time_agents.count)
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
    Subscription.any_instance.stubs(:agent_limit).returns(@account.full_time_agents.count - 1)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name }
    put :update, construct_params({ id: agent.id }, params)
    match_json([bad_request_error_pattern(:occasional, :max_agents_reached, code: :incompatible_value, max_count: (@account.full_time_agents.count - 1))])
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
    @agent.stubs(:privilege?).with(:manage_account).returns(true)
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
end
