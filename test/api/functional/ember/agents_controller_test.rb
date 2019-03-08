require_relative '../../test_helper'
class Ember::AgentsControllerTest < ActionController::TestCase
  include AgentsTestHelper
  include PrivilegesHelper

  def wrap_cname(params)
    { agent: params }
  end

  def create_multiple_emails emails, other_params = {}
    email_params = []
    1..2.times do |loop_number|
      email_params.push({ email: emails[loop_number] })
    end
    email_params
  end

  def get_or_create_agent
    if Account.first.agents.last.nil?
      @account = Account.first
      field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
      return add_test_agent(@account, role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]) if Account.first.agents.last.nil?
    else
      Account.first.agents.last
    end
  end

  def test_multiple_agent_creation_with_valid_emails_and_no_role
    valid_emails = [Faker::Internet.email, Faker::Internet.email]
    invalid_emails = []
    post :create_multiple, construct_params(version: 'private', agents: create_multiple_emails(valid_emails))
    assert_response 202
    @account.reload

    agents = []
    valid_emails.each do |email|
      agents << @account.users.find_by_email(email).agent
    end

    success_pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    failure_pattern = failure_pattern()

    pattern = {:succeeded => success_pattern.ordered, :failed => failure_pattern.ordered}
    match_json(pattern)
  end
  
  def test_multiple_agent_creation_with_freshid
    @account.launch(:freshid)
    valid_emails = [Faker::Internet.email, Faker::Internet.email]
    freshid_users = {}
    valid_emails.each { |email| freshid_users[email] = freshid_user }
    Freshid::User.stubs(:create).returns(freshid_users[valid_emails[0]], freshid_users[valid_emails[1]])
    User.any_instance.stubs(:deliver_agent_invitation!).returns(true)
    post :create_multiple, construct_params(version: 'private', agents: create_multiple_emails(valid_emails))
    assert_response 202
    @account.reload

    valid_emails.each do |email|
      user = @account.users.find_by_email(email)
      assert_present user.freshid_authorization
      assert_equal user.freshid_authorization.uid, freshid_users[user.email].uuid
    end

    User.any_instance.unstub(:deliver_agent_invitation!)
    Freshid::User.unstub(:create)
    @account.rollback(:freshid)
  end
  
  def test_multiple_agent_creation_with_existing_user_in_freshid
    @account.launch(:freshid)
    fid_user_params = { first_name: "Existing", last_name: "User", phone: "543210", mobile: "9876543210" }
    existing_freshid_user = freshid_user(fid_user_params)
    valid_email = Faker::Internet.email
    agent_params = [{ email: valid_email }]
    Freshid::User.stubs(:create).returns(existing_freshid_user)
    User.any_instance.stubs(:deliver_agent_invitation!).returns(true)
    post :create_multiple, construct_params(version: 'private', agents: agent_params)
    assert_response 202
    @account.reload
  
    user = @account.users.find_by_email(valid_email)
    assert_equal user.name, "#{fid_user_params[:first_name]} #{fid_user_params[:last_name]}"
    assert_equal user.phone, fid_user_params[:phone]
    assert_equal user.mobile, fid_user_params[:mobile]
  
    User.any_instance.unstub(:deliver_agent_invitation!)
    Freshid::User.unstub(:create)
    @account.rollback(:freshid)
  end

  def test_multiple_agent_creation_with_valid_email_and_role
    valid_email = Faker::Internet.email
    request_params = [ {:email => valid_email, :role_ids => [ @account.roles.admin.first.id ]} ]
    post :create_multiple, construct_params(version: 'private', agents: request_params)

    assert_response 202
    agent = @account.users.find_by_email(valid_email).agent
    success_pattern = [ private_api_agent_pattern(agent) ]
    pattern = {:succeeded => success_pattern.ordered, :failed => failure_pattern().ordered}
    match_json(pattern)
    success_pattern[0][:contact][:name] = success_pattern[0][:contact][:email].split('@')[0]
    pattern = {:succeeded => success_pattern.ordered, :failed => failure_pattern().ordered}
    match_json(pattern)
  end

  def test_multiple_agent_creation_with_invalid_emails
    invalid_emails = [Faker::Name.name, Faker::Name.name]
    post :create_multiple, construct_params(version: 'private', agents: create_multiple_emails(invalid_emails))
    assert_response 400
  end

  def test_multiple_agent_creation_with_duplicate_emails
    agents = []
    email = Faker::Internet.email
    duplicate_emails = [email, email]
    post :create_multiple, construct_params(version: 'private', agents: create_multiple_emails(duplicate_emails))
    assert_response 202
    @account.reload
    failures = {}
    failures[email] = { "primary_email.email": "Email has already been taken".to_sym,
                        "base": "Email has already been taken".to_sym }
    agents << @account.users.find_by_email(email).agent
    success_pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    failure_pattern = failure_pattern(failures)
    match_json({:succeeded => success_pattern.ordered, :failed => failure_pattern})
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

  def test_agent_index_with_only_filter_wrong_params
    create_rr_agent
    round_robin_groups = Group.round_robin_groups.map(&:id)
    Ember::AgentsController.any_instance.stubs(:available_chat_agents).returns(0)
    json = get :index, controller_params(version: 'private', only: 'wrong_params')
    assert_response 400
    match_json([bad_request_error_pattern('only', :not_included, list: 'available,available_count')])
  ensure
    Ember::AgentsController.any_instance.unstub(:available_chat_agents)
  end

  def test_update_with_availability
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    add_privilege(User.current,:manage_availability)
    params_hash = { ticket_assignment: { available: false } }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    match_json(private_api_agent_pattern(user.agent))
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

  def test_update_freshchat_token
    token = Faker::Number.number(10)
    params_hash = { freshchat_token: token }
    currentuser = User.current
    put :update, construct_params({ version: 'private', id: currentuser.id }, params_hash)
    currentuser.reload
    assert_equal currentuser.text_uc01[:agent_preferences][:freshchat_token],token
    assert_response 200
    match_json(private_api_agent_pattern(currentuser.agent))
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
    user.set_gdpr_preference
    login_as(user)
    post :complete_gdpr_acceptance, construct_params(version: 'private')
    user.reload
    assert_equal user.gdpr_pending?,false
    assert_response 204
  end

  def test_accept_gdpr_with_agent_access
    
     user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
     login_as(user)
     post :complete_gdpr_acceptance, construct_params(version: 'private')
     assert_response 403
     match_json(request_error_pattern(:access_denied))
  end

  def test_update_others_with_toggle_shortcuts_for_agent
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    remove_privilege(User.current, :manage_availability)
    params_hash = { shortcuts_enabled: true }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 403
  end

  def test_update_field_agent_with_correct_scope_and_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Agent.any_instance.stubs(:ticket_permission).returns(::Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    agent = add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = {email: Faker::Internet.email}
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    match_json(private_api_agent_pattern(agent.agent))
  ensure
    agent.destroy if agent.present?
    field_agent_type.destroy if field_agent_type.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_incorrect_scope_and_role
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    agent = add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = { ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], role_ids: [Role.find_by_name('Administrator').id] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('ticket_permission', :field_agent_scope, :code => :invalid_value), bad_request_error_pattern('user.role_ids', :field_agent_roles, :code => :invalid_value)])
  ensure
    agent.destroy
    field_agent_type.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_with_multiple_role
    Agent.any_instance.stubs(:check_ticket_permission).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    agent = add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    Account.any_instance.stubs(:agent_types_from_cache).returns(agent)
    User.any_instance.stubs(:find).returns(field_agent_type)
    Agent.any_instance.stubs(:find).returns(Account.first.agent_types.first)
    Agent.any_instance.stubs(:length).returns(0)
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    params = {role_ids: [Role.find_by_name('Administrator').id,Role.find_by_name('Agent').id]}
    put :update, construct_params({ id: agent.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('user.role_ids', :field_agent_roles, :code => :invalid_value)])
  ensure
    agent.destroy if agent.present?
    field_agent_type.destroy if field_agent_type.present?
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_from_restricted_to_group_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    agent = add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] })
    params = { ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets]}
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)['ticket_scope'] == Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets]
  ensure
    agent.destroy
    field_agent_type.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
  end

  def test_update_field_agent_from_group_scope_to_restricted_scope
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    agent = add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: field_agent_type.agent_type_id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets] })
    params = { ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] }
    Account.stubs(:current).returns(Account.first)
    put :update, construct_params({ id: agent.id }, params)
    assert_response 200
    assert JSON.parse(response.body)['ticket_scope'] == Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
  ensure
    agent.destroy
    field_agent_type.destroy
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.unstub(:current)
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

  def test_validate_item_with_invalid_role_ids
    valid_email = Faker::Internet.email
    request_params = [ {:email => valid_email, :role_ids => [ @account.roles.admin.first.id ]} ]
    Account.any_instance.stubs(:roles_from_cache).returns([])
    post :create_multiple, construct_params(version: 'private', agents: request_params)
    assert_response 202
    ensure
      Account.any_instance.unstub(:roles_from_cache)
    
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
end  
