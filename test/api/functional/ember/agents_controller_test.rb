require_relative '../../test_helper'
['advanced_scope_test_helper.rb', 'agents_test_helper.rb', 'privileges_helper.rb', 'attachments_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
class Ember::AgentsControllerTest < ActionController::TestCase
  include AgentsTestHelper
  include PrivilegesHelper
  include AttachmentsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include AdvancedScopeTestHelper

  SEARCH_SETTINGS_PARAMS = {
    search_settings: {
      tickets: {
        include_subject: true,
        include_description: true,
        include_other_properties: false,
        include_notes: false,
        include_attachment_names: false
      }
    }
  }.freeze

  def tear_down
    cleanup_fsm
  end
    
  def wrap_cname(params)
    { agent: params }
  end

  def get_or_create_agent(agent_type = nil)
    last_active_agent = Account.current.users.joins(:agent).where(active: true).last
    if last_active_agent.nil?
      @account = Account.current
      agent_type_id = 1
      if agent_type.present?
        agent_type_id = AgentType.create_agent_type(@account, agent_type).agent_type_id
      end
      add_test_agent(@account, role: Role.find_by_name('Agent').id, agent_type: agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    else
      last_active_agent
    end
  end

  def get_a_group(group_name, account, toggle_availability)
    group = FactoryGirl.build(:group, name: group_name)
    group.group_type = GroupConstants::SUPPORT_GROUP_ID
    group.account_id = account.id
    group.ticket_assign_type = 1
    group.toggle_availability = toggle_availability
    group.save!
    group
  end

  def test_agent_index
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    agents = @account.agents.order('users.name').limit(30)
    pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_manage_users_privilege_only
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    get :index, controller_params(version: 'private')
    agents = @account.agents.order('users.name').limit(30)
    pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    assert_response 200
    match_json(pattern.ordered)
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_agent_index_without_manage_users_privilege
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    get :index, construct_params(version: 'private')
    assert_response 403
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_agent_index_with_only_filter
    create_rr_agent
    agents = @account.agents.order('users.name').limit(30)
    # livechat_pattern = agents.map { |agent| livechat_agent_availability(agent) }.to_h
    # Ember::AgentsController.any_instance.stubs(:get_livechat_agent_details).returns(livechat_pattern)
    round_robin_groups = Group.round_robin_groups.map(&:id)
    get :index, controller_params(version: 'private', only: 'available')
    assert_response 200
    pattern = agents.map { |agent| agent_availability_pattern(agent, round_robin_groups) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_only_filter_count
    create_rr_agent
    # Ember::AgentsController.any_instance.stubs(:available_chat_agents).returns(0)
    json = get :index, controller_params(version: 'private', only: 'available_count')
    assert_response 200
    pattern = agent_availability_count_pattern
    assert_equal json.api_meta, pattern[:meta]
  end

  def test_agent_index_with_privilege_filter
    get :index, controller_params(version: 'private', only: 'with_privilege', privilege: 'manage_solutions')
    assert_response 200
    pattern = @account.users.where(helpdesk_agent: true).order('name').select { |user| user.privilege?(:manage_solutions) }.map { |user| private_api_privilege_agent_pattern(user) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_invalid_privilege
    get :index, controller_params(version: 'private', only: 'with_privilege', privilege: 'dummy_bla_bla')
    assert_response 400
    match_json([bad_request_error_pattern('privilege', 'invalid_privilege', code: 'invalid_value')])
  end

  def test_privilege_not_allowed
    get :index, controller_params(version: 'private', only: 'available_count', privilege: 'dummy_bla_bla')
    assert_response 400
    match_json([bad_request_error_pattern('privilege', 'privilege_not_allowed', code: 'invalid_value')])
  end

  def test_agent_index_with_only_filter_wrong_params
    create_rr_agent
    round_robin_groups = Group.round_robin_groups.map(&:id)
    Ember::AgentsController.any_instance.stubs(:available_chat_agents).returns(0)
    json = get :index, controller_params(version: 'private', only: 'wrong_params')
    assert_response 400
    match_json([bad_request_error_pattern('only', :not_included, list: 'available,available_count,with_privilege,availability')])
  ensure
    Ember::AgentsController.any_instance.unstub(:available_chat_agents)
  end

  def test_agent_index_with_filter_field_agent_with_out_user_info
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
        field_agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id)
        field_agent2 = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id)
        role = Role.find_by_name(FIELD_SERVICE_MANAGER_ROLE_NAME)
        agent = add_test_agent(@account, role: role.id)
        currentuser = User.current
        login_as(agent)
        get :index, controller_params(version: 'private', type: 'field_agent')
        assert_response 200
        pattern = @account.agents.where(agent_type: @account.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id).map { |user| private_api_restriced_agent_hash(user) }
        match_json(pattern)
      ensure
        role.try(:destroy)
        agent.try(:destroy)
        field_agent.try(:destroy)
        field_agent2.try(:destroy)
        cleanup_fsm
        login_as(currentuser)
      end
    end
  end

  def test_agent_index_with_filter_field_agent_with_user_info
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
        field_agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id)
        field_agent2 = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id)
        role = Role.find_by_name(FIELD_SERVICE_MANAGER_ROLE_NAME)
        agent = add_test_agent(@account, role: role.id)
        currentuser = User.current
        login_as(agent)
        get :index, controller_params(version: 'private', type: 'field_agent', include: 'user_info')
        assert_response 200
        pattern = @account.agents.where(agent_type: Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id).map { |user| private_api_restriced_agent_hash(user).merge!(contact_pattern(user)) }
        match_json(pattern)
      ensure
        role.try(:destroy)
        agent.try(:destroy)
        field_agent.try(:destroy)
        field_agent2.try(:destroy)
        cleanup_fsm
        login_as(currentuser)
      end
    end
  end

  def test_agent_index_with_include_filter_wrong_params
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
        field_agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id)
        role = Role.find_by_name(FIELD_SERVICE_MANAGER_ROLE_NAME)
        agent = add_test_agent(@account, role: role.id)
        currentuser = User.current
        login_as(agent)
        get :index, controller_params(version: 'private', type: 'field_agent', include: 'dummy')
        assert_response 400
        match_json([bad_request_error_pattern('include', :not_included, list: 'roles, user_info')])
      ensure
        role.try(:destroy)
        agent.try(:destroy)
        field_agent.try(:destroy)
        cleanup_fsm
        login_as(currentuser)
      end
    end
  end

  def test_update_with_availability
    group = get_a_group("avail_rand#{rand(999_999)}", @account, 1)
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    add_privilege(user, :manage_availability)
    add_privilege(user, :manage_users)
    remove_privilege(user, :manage_account)
    Account.current.agent_groups.create(user_id: user.id, group_id: group.id)
    Account.current.groups.update_all(toggle_availability: true)
    user.reload
    User.stubs(:current).returns(user)
    @controller.stubs(:api_current_user).returns(user)
    params_hash = { ticket_assignment: { available: false } }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    match_json(private_api_agent_pattern(user.agent))
  ensure
    User.unstub(:current)
    @controller.unstub(:api_current_user)
  end

  def test_update_with_availability_invalid_datatype
    @account = Account.current
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    group = get_a_group("avail_rand#{rand(999_999)}", @account, 0)
    User.stubs(:current).returns(user)
    @controller.stubs(:api_current_user).returns(user)
    add_privilege(user, :manage_availability)
    add_privilege(user, :manage_users)
    remove_privilege(user, :manage_account)
    group.agent_groups.build(user_id: user.id)
    params_hash = { ticket_assignment: { available: [true, false].sample } }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 400
    assert response.body.include? "Current user doesn't belong to any of the groups"
  ensure
    user.destroy if user.present?
    group.destroy if group.present?
    @account = nil
    User.unstub(:current)
    @controller.unstub(:api_current_user)
  end

  def test_update_with_availability_by_supervisor_valid
    group = get_a_group("avail_rand#{rand(999_999)}", @account, 0)
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    Account.current.agent_groups.create(user_id: user.id, group_id: group.id)
    supervisor = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
    Account.current.agent_groups.create(user_id: supervisor.id, group_id: group.id)
    supervisor.reload
    user.reload
    add_privilege(supervisor, :manage_users)
    add_privilege(supervisor, :manage_availability)
    add_privilege(supervisor, :manage_account)
    params_hash = { ticket_assignment: { available: false } }
    User.stubs(:current).returns(supervisor)
    @controller.stubs(:api_current_user).returns(supervisor)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    user.agent.reload
    match_json(private_api_agent_pattern(user.agent))
  ensure
    User.unstub(:current)
    @controller.unstub(:api_current_user)
  end

  def test_update_with_availability_by_supervisor_not_in_group
    group = get_a_group("avail_rand#{rand(999_999)}", @account, 1)
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    supervisor = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
    Account.current.agent_groups.create(user_id: user.id, group_id: group.id)
    user.reload
    add_privilege(supervisor, :manage_users)
    add_privilege(supervisor, :manage_availability)
    User.stubs(:current).returns(supervisor)
    @controller.stubs(:api_current_user).returns(supervisor)
    params_hash = { ticket_assignment: { available: false } }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 400
    assert response.body.include? 'belong to any of the groups of the agent'
  ensure
    User.unstub(:current)
    @controller.unstub(:api_current_user)
  end

  def test_update_with_availability_by_current_user_with_valid_group
    group = get_a_group("avail_rand#{rand(999_999)}", @account, 1)
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    Account.current.agent_groups.create(user_id: user.id, group_id: group.id)
    user.reload
    params_hash = { ticket_assignment: { available: false } }
    User.stubs(:current).returns(user)
    @controller.stubs(:api_current_user).returns(user)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    user.reload
    match_json(private_api_restriced_agent_hash(user.agent))
  ensure
    User.unstub(:current)
    @controller.unstub(:api_current_user)
  end

  def test_update_with_availability_by_current_user_without_valid_group
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    user.reload
    params_hash = { ticket_assignment: { available: false } }
    User.stubs(:current).returns(user)
    @controller.stubs(:api_current_user).returns(user)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 400
    assert response.body.include? 'Toggle availability not allowed for this user'
  ensure
    User.unstub(:current)
    @controller.unstub(:api_current_user)
  end

  def test_update_with_toggle_shortcuts_for_agent
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params_hash = { shortcuts_enabled: true }
    login_as(user)
    currentuser = User.current
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    match_json(private_api_restriced_agent_hash(user.agent))
    login_as(currentuser)
  end

  def test_central_publish_payload_login
    CentralPublishWorker::UserWorker.jobs.clear
    user = add_test_agent(@account, role: Role.find_by_name('Administrator').id)
    login_as(user)
    job = CentralPublishWorker::UserWorker.jobs.last
    assert_equal 'agent_update', job['args'][0]
    assert_equal({ 'logged_in' => [false, true] }, job['args'][1]['misc_changes'])
    CentralPublishWorker::UserWorker.jobs.clear
  end

  def test_central_publish_payload_logout
    CentralPublishWorker::UserWorker.jobs.clear
    user = add_test_agent(@account, role: Role.find_by_name('Administrator').id)
    login_as(user)
    log_out
    job = CentralPublishWorker::UserWorker.jobs.last
    assert_equal 'agent_update', job['args'][0]
    assert_equal({ 'logged_in' => [true, false] }, job['args'][1]['misc_changes'])
    CentralPublishWorker::UserWorker.jobs.clear
  end

  def test_update_freshchat_token
    user = get_or_create_agent
    token = Faker::Number.number(10)
    params_hash = { freshchat_token: token }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    user.reload
    assert_equal user.text_uc01[:agent_preferences][:freshchat_token], token
    assert_response 200
    match_json(private_api_agent_pattern(user.agent))
  end

  def test_update_with_search_settings_for_agent
    user = get_or_create_agent
    currentuser = User.current
    login_as(user)
    params_hash = SEARCH_SETTINGS_PARAMS
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    user.reload
    assert_equal user.text_uc01[:agent_preferences][:search_settings], SEARCH_SETTINGS_PARAMS[:search_settings]
    assert_response 200
    login_as(currentuser)
  end

  def test_update_with_search_settings_params_without_archive_feature
    Account.any_instance.stubs(:archive_tickets_enabled?).returns(false)
    user = get_or_create_agent
    currentuser = User.current
    login_as(user)
    search_settings_params_with_archive = SEARCH_SETTINGS_PARAMS.deep_dup
    search_settings_params_with_archive[:search_settings][:tickets][:archive] = true
    put :update, construct_params({ version: 'private', id: user.id }, search_settings_params_with_archive)
    assert_response 400
    match_json([bad_request_error_pattern('archive', 'Unexpected/invalid field in request', code: 'invalid_field')])
    Account.any_instance.unstub(:archive_tickets_enabled?)
  end

  def test_update_with_search_settings_params_with_archive_feature
    Account.any_instance.stubs(:archive_tickets_enabled?).returns(true)
    user = get_or_create_agent
    currentuser = User.current
    login_as(user)
    search_settings_params_with_archive = SEARCH_SETTINGS_PARAMS.deep_dup
    search_settings_params_with_archive[:search_settings][:tickets][:archive] = true
    put :update, construct_params({ version: 'private', id: user.id }, search_settings_params_with_archive)
    user.reload
    assert_response 200
    assert_equal user.text_uc01[:agent_preferences][:search_settings][:tickets][:archive], search_settings_params_with_archive[:search_settings][:tickets][:archive]
    Account.any_instance.unstub(:archive_tickets_enabled?)
  end

  def test_update_with_invalid_search_settings_for_agent
    user = get_or_create_agent
    currentuser = User.current
    login_as(user)
    invalid_params_hash = SEARCH_SETTINGS_PARAMS.deep_dup
    invalid_params_hash[:search_settings][:invalid_param] = 1
    put :update, construct_params({ version: 'private', id: user.id }, invalid_params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('invalid_param', 'Unexpected/invalid field in request', code: 'invalid_field')])
    login_as(currentuser)
  end

  def test_update_with_invalid_ticket_search_settings
    currentuser = User.current
    user = get_or_create_agent
    login_as(user)
    invalid_params_hash = SEARCH_SETTINGS_PARAMS.deep_dup
    invalid_params_hash[:search_settings][:tickets][:invalid_param] = 1
    put :update, construct_params({ version: 'private', id: user.id }, invalid_params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('invalid_param', 'Unexpected/invalid field in request', code: 'invalid_field')])
    login_as(currentuser)
  end

  def test_update_with_non_boolean_ticket_search_settings
    currentuser = User.current
    user = get_or_create_agent
    login_as(user)
    invalid_params_hash = SEARCH_SETTINGS_PARAMS.deep_dup
    invalid_params_hash[:search_settings][:tickets][:include_subject] = 1
    put :update, construct_params({ version: 'private', id: user.id }, invalid_params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('search_settings', 'include_subject', 'It should be a/an Boolean', code: 'datatype_mismatch')])
    login_as(currentuser)
  end

  def test_update_with_blank_search_settings
    currentuser = User.current
    user = get_or_create_agent
    login_as(user)
    blank_search_settings = { search_settings: {} }
    put :update, construct_params({ version: 'private', id: user.id }, blank_search_settings)
    assert_response 400
    match_json([bad_request_error_pattern('search_settings', "can't be blank", code: 'invalid_value')])
    login_as(currentuser)
  end

  def test_update_with_blank_ticket_search_settings
    currentuser = User.current
    user = get_or_create_agent
    login_as(user)
    blank_ticket_search_settings = { search_settings: { tickets: {} } }
    put :update, construct_params({ version: 'private', id: user.id }, blank_ticket_search_settings)
    assert_response 400
    match_json([bad_request_error_pattern('tickets', 'ticket_search_settings_blank', code: 'invalid_value')])
    login_as(currentuser)
  end

  def test_accept_gdpr_with_admin_and_not_gdpr_pending
    user = add_test_agent(@account, role: Role.find_by_name('Administrator').id)
    login_as(user)
    post :complete_gdpr_acceptance, construct_params(version: 'private')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_accept_gdpr_with_admin_and_gdpr_pending
    user = add_test_agent(@account, role: Role.find_by_name('Administrator').id)
    User.stubs(:current).returns(user)
    user.set_gdpr_preference
    login_as(user)
    post :complete_gdpr_acceptance, construct_params(version: 'private')
    user.reload
    assert_equal user.gdpr_pending?,false
    assert_response 204
  ensure
    User.unstub(:current)
  end

  def test_accept_gdpr_with_agent_access
     user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
     login_as(user)
     post :complete_gdpr_acceptance, construct_params(version: 'private')
     assert_response 403
     match_json(request_error_pattern(:access_denied))
  end

  def test_custom_field_service_manager_role
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        role = Role.find_by_name(FIELD_SERVICE_MANAGER_ROLE_NAME)
        assert_not_nil role
        assert role.privilege_list.include?(:schedule_fsm_dashboard)
        agent = add_test_agent(@account, role: role.id)
        assert agent.privilege?(:schedule_fsm_dashboard)
      ensure
        role.try(:destroy)
        agent.try(:destroy)
      end
    end
  end

  def test_update_others_with_toggle_shortcuts_for_agent
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    remove_privilege(User.current, :manage_users)
    remove_privilege(User.current, :manage_availability)
    params_hash = { shortcuts_enabled: true }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 403
  ensure
    add_privilege(User.current, :manage_availability)
    add_privilege(User.current, :manage_users)
  end

  def test_update_field_agent_with_correct_scope_and_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Agent.any_instance.stubs(:ticket_permission).returns(::Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    field_agent_type = Account.current.agent_types_from_cache.find { |type| type.name == Agent::FIELD_AGENT.to_s }
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT) if field_agent_type.blank?
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    params = {email: Faker::Internet.email}
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    match_json(private_api_agent_pattern(agent.agent))
  ensure
    agent.destroy if agent.present?
    field_agent_type.destroy if field_agent_type.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    field_tech_role.destroy
    Account.unstub(:current)
  end

  def test_update_field_agent_with_incorrect_scope_and_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    user = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], role_ids: [Role.find_by_name('Administrator').id] }
    put :update, construct_params({ id: user.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('ticket_permission', :field_agent_scope, :code => :invalid_value), bad_request_error_pattern('user.role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'), :code => :invalid_value)])
  ensure
    user.destroy if user.present?
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_update_field_agent_with_multiple_role
    Agent.any_instance.stubs(:check_ticket_permission).returns(true)
    field_agent_type = Account.current.agent_types_from_cache.find { |type| type.name == Agent::FIELD_AGENT.to_s }
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT) if field_agent_type.blank?
    field_tech_role = @account.roles.create(name: 'Field technician', default_role: true)
    agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    Account.any_instance.stubs(:agent_types_from_cache).returns(agent)
    User.any_instance.stubs(:find).returns(field_agent_type)
    Agent.any_instance.stubs(:find).returns(Account.first.agent_types.first)
    Agent.any_instance.stubs(:length).returns(0)
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    params = {role_ids: [Role.find_by_name('Administrator').id,Role.find_by_name('Agent').id]}
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('user.role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'), :code => :invalid_value)])
  ensure
    agent.destroy if agent.present?
    field_agent_type.destroy if field_agent_type.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    field_tech_role.destroy
    Account.unstub(:current)
  end

  def test_update_field_agent_from_restricted_to_group_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    user = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets] }
    put :update, construct_params({ id: user.id }, params)
    assert_response 200
    assert JSON.parse(response.body)['ticket_scope'] == Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets]
  ensure
    user.destroy if user.present?
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_update_field_agent_from_group_scope_to_restricted_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Agent.any_instance.stubs(:ticket_permission).returns(::Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    perform_fsm_operations
    agent = add_test_agent(@account, role: Role.find_by_name('Field technician').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    params = { ticket_scope: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] }
    put :update, construct_params({ id: agent.id }, params)
    puts "response_body ::#{response.body.inspect}, agent_id :: #{agent.inspect}"
    assert_response 200
    assert JSON.parse(response.body)['ticket_scope'] == Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
  ensure
    agent.destroy if agent.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    cleanup_fsm
  end

  def test_update_with_toggle_shortcuts_for_admin
    user = add_test_agent(@account, role: Role.find_by_name('Administrator').id)
    params_hash = { shortcuts_enabled: true }
    currentuser = User.current
    login_as(user)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    match_json(private_api_agent_pattern(user.agent))
    login_as(currentuser)
  end

  def test_show_agent
    sample_agent = @account.agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    match_json(private_api_agent_pattern(sample_agent))
  end

  def test_show_agent_with_view_contact_privilege_only
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    sample_agent = @account.agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_show_agent_with_manage_users_privilege_only
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    sample_agent = @account.all_agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    match_json(private_api_agent_pattern(sample_agent))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_show_agent_without_manage_users_and_view_contacts_privileges
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    sample_agent = @account.all_agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_show_agent_achievements
    sample_agent = @account.agents.first
    get :achievements, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    match_json(agent_achievements_pattern(sample_agent))
  end

  def test_agent_assume_identity
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    add_privilege(User.current, :manage_users)
    put :assume_identity, construct_params({ version: 'private', id: user.id }, {})
    assert_response 204
  end

  def test_revert_identity
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    add_privilege(User.current, :manage_users)
    put :assume_identity, construct_params({ version: 'private', id: user.id }, {})
    get :revert_identity, construct_params(version: 'private')
    assert_response 204
  end

   def test_agent_availability_without_admin_task_privilege
    group = create_group_with_agents(@account, role: Role.find_by_name('Supervisor').id)
    current_user = User.current
    group.agent_groups.create(user_id: current_user.id)
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    get :index, controller_params(version: 'private', only: 'available')
    response_body = JSON.parse(response.body).first
    response_body.must_match_json_expression(private_api_agent_pattern(current_user.agent))
    assert_response 200
    ensure
      User.any_instance.unstub(:privilege?)
  end

  def test_agent_availability_with_admin_task_privilege
    group = create_group_with_agents(@account, role: Role.find_by_name('Supervisor').id)
    current_user = User.current
    group.agent_groups.create(user_id: User.current.id)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    get :index, controller_params(version: 'private', only: 'available')
    assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
  end

  def test_enable_undo_send
    agent = @account.all_agents.first
    @agent.stubs(:privilege?).returns(true)
    post :enable_undo_send, construct_params(id: @agent.id)
    assert_response 204
  end

  def test_disable_undo_send
    agent = @account.all_agents.first
    @agent.stubs(:privilege?).returns(true)
    post :disable_undo_send, construct_params(id: @agent.id)
    assert_response 204
  end

  def test_update_with_avatar_id
    AgentValidation.any_instance.stubs(:private_api?).returns(true)
    user = get_or_create_agent
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachment_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = { avatar_id: attachment_id }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    assert_equal user.avatar.content_file_name, 'image33kb.jpg'
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
    AgentValidation.any_instance.unstub(:private_api?)
  end

  def test_update_with_avatar_id_null_removes_avatar_correctly
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    user = get_or_create_agent
    params_hash = { avatar_id: nil }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_nil user.avatar
    assert_response 200
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_user_changes_update_with_avatar_id
    AgentValidation.any_instance.stubs(:private_api?).returns(true)
    user = get_or_create_agent
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachment_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = { avatar_id: attachment_id }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Agent.any_instance.stubs(:user_avatar_changes).returns(:upsert)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    assert_equal user.avatar.content_file_name, 'image33kb.jpg'
  ensure
    Agent.any_instance.unstub(:user_avatar_changes)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    AgentValidation.any_instance.unstub(:private_api?)
  end

  def test_user_changes_update_with_avatar_id_null_removes_avatar_correctly
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    user = get_or_create_agent
    params_hash = { avatar_id: nil }
    Agent.any_instance.stubs(:user_avatar_changes).returns(:destroy)
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_nil user.avatar
    assert_response 200
  ensure
    Agent.any_instance.unstub(:user_avatar_changes)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_update_with_invalid_avatar_id
    AgentValidation.any_instance.stubs(:private_api?).returns(true)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    user = get_or_create_agent
    invalid_id = Faker::Number.number(3)
    params_hash = { avatar_id: invalid_id.to_i }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_id.to_i.to_s)])
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
    AgentValidation.any_instance.unstub(:private_api?)
  end

  def test_update_with_invalid_avatar_extension
    AgentValidation.any_instance.stubs(:private_api?).returns(true)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    user = get_or_create_agent
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: user.id).id
    params_hash = { avatar_id: attachment_id }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:avatar_id, :upload_jpg_or_png_file, current_extension: '.txt')])
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
    AgentValidation.any_instance.unstub(:private_api?)
  end

  def test_search_in_freshworks
    add_privilege(User.current, :manage_users)
    @account.launch(:freshid)
    new_email = Faker::Internet.email
    fid_user_params = { first_name: 'FreshId', last_name: 'User', phone: '543210', mobile: '9876543210', email: new_email }
    existing_freshid_user = freshid_user(fid_user_params)
    user = add_new_user(@account)
    old_email = user.email

    Freshid::User.stubs(:find_by_email).returns(nil)

    # If email & old_email are different, but new_email does not present in freshid, returns Nil
    get :search_in_freshworks, controller_params(version: 'private', email: Faker::Internet.email, old_email: old_email)
    assert_response 200
    json_response = JSON.parse(response.body)
    assert json_response['freshid_user_info'].empty?

    Freshid::User.unstub(:find_by_email)

    Freshid::User.stubs(:find_by_email).returns(existing_freshid_user)
    expected_response = { name: 'FreshId User', phone: '543210', mobile: '9876543210', job_title: nil, user_info: nil }

    # If email is present & old_email is not present returns freshid info
    get :search_in_freshworks, controller_params(version: 'private', email: new_email)
    assert_response 200
    pattern = private_api_search_in_freshworks_pattern(user, expected_response)
    match_json(pattern)

    # If old_email & email - both are same, return old_email records
    get :search_in_freshworks, controller_params(version: 'private', email: old_email, old_email: old_email)
    assert_response 200
    pattern = private_api_search_in_freshworks_pattern(user, { user_info: { user_id: user.id, marked_for_hard_delete: false, deleted: false } })
    match_json(pattern)

    # If old_email & email are different, email is present in freshid, returns freshid user info
    get :search_in_freshworks, controller_params(version: 'private', email: new_email, old_email: old_email)
    assert_response 200
    pattern = private_api_search_in_freshworks_pattern(user, expected_response)
    match_json(pattern)
  ensure
    Freshid::User.unstub(:find_by_email)
    @account.rollback(:freshid)
  end

  def test_read_only_property_of_agent_with_privilege
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    sample_agent = @account.agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    json_response = JSON.parse(response.body)
    assert_equal json_response['read_only'], true
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_read_only_property_of_agent_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    sample_agent = @account.agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    json_response = JSON.parse(response.body)
    assert_equal json_response['read_only'], false
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_agent_index_with_cache
    Account.current.stubs(:advanced_ticket_scopes_enabled?).returns(true)
    3.times do
      add_test_agent(@account, role: @account.roles.where(name: 'Agent').first.id)
    end
    user_one = @account.agents.first.user
    user_two = @account.agents.second.user
    memcache_key = MemcacheKeys::AGENT_CONTRIBUTION_ACCESS_GROUPS
    create_agent_group_with_read_access(@account, @account.agents.first.user)
    create_agent_group_with_read_access(@account, @account.agents.second.user)
    assert_nothing_raised do
      MemcacheKeys.stubs(:get_from_cache).at_least_once
      MemcacheKeys.expects(:get_from_cache).with(format(memcache_key, account_id: @account.id, user_id: user_one.id)).at_least_once
      MemcacheKeys.expects(:get_from_cache).with(format(memcache_key, account_id: @account.id, user_id: user_two.id)).at_least_once
      get :index, controller_params(version: 'private')
    end
    assert_response 200
  ensure
    Account.current.unstub(:advanced_ticket_scopes_enabled?)
  end

  def test_private_ata_enabled_agents_across_channels
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
    Ember::AgentsController.any_instance.stubs(:request_service).returns(ocr_agents_response(channel: { freshdesk_user.id.to_s => channels_data }, name: fd_name, status_id: status_id))
    group = create_group_with_agents(@account, agent_list: [freshdesk_user.id])
    get :index, controller_params(version: 'private', only: 'availability', channel: 'freshdesk', group_id: group.id, search_term: 'First')
    assert_response 200
    pattern = ocr_agents_availability_pattern(id: freshdesk_user.id.to_s, name: fd_name, status_id: status_id, availability: ocr_agent_availability_reformat(channels_data))
    match_json(pattern)
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_private_no_ata_enabled_agents_across_channels
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    @account.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    Ember::AgentsController.any_instance.stubs(:request_service).returns(ocr_agents_response(channel: {}))
    get :index, controller_params(version: 'private', only: 'availability')
    assert_response 200
    match_json([])
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
    @account.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_occasional_agent_day_pass_used_count
    freshdesk_user = add_test_agent(@account, role: Role.where(name: 'Agent').first.id)
    agent = freshdesk_user.agent
    agent.occasional = true
    agent.save
    freshdesk_user.reload
    freshdesk_user.account.day_pass_usages.create(granted_on: Time.now.utc, user: freshdesk_user)
    get :index, controller_params(version: 'private', state: 'occasional')
    assert_response 200
    output = JSON.parse response.body
    assert output.select { |s| s['id'] == freshdesk_user.id }.first['day_pass_used'].equal?(1)
  ensure
    freshdesk_user.destroy
  end

  def test_agent_index_with_include_roles_filter
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    get :index, controller_params(version: 'private', include: 'roles')
    assert_response 200
    agents = @account.agents.order('users.name').limit(30)
    pattern = agents.map { |agent| private_api_with_roles_pattern(agent) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_include_roles_and_user_info_filter
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    get :index, controller_params(version: 'private', include: 'roles,user_info')
    assert_response 200
    agents = @account.agents.order('users.name').limit(30)
    pattern = agents.map { |agent| private_api_with_roles_pattern(agent) }
    match_json(pattern.ordered)
  end
end
