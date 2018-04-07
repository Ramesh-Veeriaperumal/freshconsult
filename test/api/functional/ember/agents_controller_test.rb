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
    agents = @account.agents.order('users.name')
    pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_only_filter
    create_rr_agent
    agents = @account.agents.order('users.name')
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
end
