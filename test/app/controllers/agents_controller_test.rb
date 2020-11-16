require_relative '../../api/test_helper'
require_relative '../../core/helpers/users_test_helper'
require_relative '../../core/helpers/controller_test_helper'
require_relative '../../api/helpers/agents_test_helper'

class AgentsControllerTest < ActionController::TestCase
  include Redis::OthersRedis
  include CoreUsersTestHelper
  include ControllerTestHelper
  include AgentsTestHelper

  def setup
    super
  end

  def test_search_in_freshworks
    login_admin
    @user = Account.current.account_managers.first.make_current
    @account.launch(:freshid)

    new_email = Faker::Internet.email
    fid_user_params = { first_name: 'Existing', last_name: 'User', phone: '543210', mobile: '9876543210', email: new_email}
    existing_freshid_user = freshid_user(fid_user_params)
    user = add_new_user(@account)
    old_email = user.email

    Freshid::User.stubs(:find_by_email).returns(nil)
    
    # If old_email & new_email are different, but new_email does not present in freshid, returns Nil
    get :search_in_freshworks, new_email: Faker::Internet.email, old_email: old_email, format: 'json'
    assert_response 200
    user_info = JSON.parse(response.body)["user_info"]
    assert user_info.nil?

    Freshid::User.unstub(:find_by_email)

    Freshid::User.stubs(:find_by_email).returns(existing_freshid_user)

    # If old_email & new_email - both are same, return  old_email records
    get :search_in_freshworks, new_email: old_email, old_email: old_email, format: 'json'
    user_info = JSON.parse(response.body)["user_info"]
    assert_response 200
    assert user_info.present?
    assert_match user_info["name"], user.name

    # If old_email & new_email are different, new_email is present in freshid, returns new_email user info
    get :search_in_freshworks, new_email: new_email, old_email: old_email, format: 'json'
    user_info = JSON.parse(response.body)["user_info"]
    assert_response 200
    assert user_info.present?
    assert_match user_info["name"], "Existing User"

    Freshid::User.unstub(:find_by_email)
    @account.rollback(:freshid)
    user.destroy
    log_out
  end


  def test_index
    login_admin
    @user = Account.current.account_managers.first.make_current
    test_agent2 = add_agent(@account, name: "Tywin Lannister", agent_type: 1)

    get :index
    assert_response 200

    get :index, format: 'js'
    assert_response 200

    get :index, query: "state: \'support_agent\'", format: 'json'
    assert_response 200

    get :index, state: 'support_agent', format: 'json'
    assert_response 200
    assert JSON.parse(response.body).first["agent"]["user"].present?

    get :index, state: 'support_agent', letter: test_agent2.name, format: 'json'
    assert_response 200
    assert JSON.parse(response.body).first["agent"]["user"]["name"] == "Tywin Lannister"

    get :index, format: 'json'
    assert_response 200
    test_agent2.destroy
    log_out
  end

  def test_show
    login_admin
    @user = Account.current.account_managers.first.make_current
    user_agent = add_test_agent(@account)

    get :show, id: user_agent.id
    assert_response 200

    get :show, id: user_agent.id, format: 'json'
    assert_response 200
    assert JSON.parse(response.body)["agent"]["user"]["name"] == user_agent.name
    assert JSON.parse(response.body)["agent"]["user"]["email"] == user_agent.email
    
    get :show, id: user_agent.id, format: 'xml'
    assert_response 200
    assert response.body.include?(user_agent.name)
    assert response.body.include?(user_agent.email)

    get :show, id: user_agent.id, format: 'nmobile'
    assert_response 200
    user_agent.destroy
    log_out
  end

  def test_new
    login_admin
    @user = Account.current.account_managers.first.make_current
    get :new
    assert_response 200
    log_out
  end

  def test_edit
    login_admin
    @user = Account.current.account_managers.first.make_current
    user_agent = add_test_agent(@account)
    put :edit, id: user_agent.id
    assert_response 200
    user_agent.destroy
    log_out
  end

  def test_toggle_availability
    login_admin
    @user = Account.current.account_managers.first.make_current
    # :admin => 0, Toggle Availability = false, print nothing.
    group = Account.current.groups.create(name: "test_toggle_availability")
    Account.current.agent_groups.create(agent_id: @user.agent.id, group_id: group.id )
    post :toggle_availability, admin: false, id: @user.id
    assert_response 200
    assert response.body == " "

    post :toggle_availability, admin: false, id: @user.id, format: 'json'
    assert_response 200
    assert JSON.parse(response.body).empty?

    # :admin => 1, Toggle Availability = false
    post :toggle_availability, admin: true, id: @user.id
    assert_response 200    

    group.ticket_assign_type = 1
    group.capping_limit = 5
    group.toggle_availability = 1
    group.save

    # :admin => 0, Toggle Availability = true
    post :toggle_availability, admin: false, id: @user.id
    assert_response 200

    # :admin => 1, Toggle Availability = true
    post :toggle_availability, admin: true, id: @user.id
    assert_response 200    
    # :admin => 1
    group.destroy
    log_out
  end

  def test_toggle_shortcuts
    login_admin
    @user = Account.current.account_managers.first.make_current
    user_agent = add_test_agent(@account)

    # With shortcuts already enabled
    put :toggle_shortcuts, id: user_agent.id, format: 'json'
    assert_response 200
    assert JSON.parse(response.body)["shortcuts_enabled"] == false
    user_agent.destroy

    # With shortcuts disabled
    user_agent = add_test_agent(@account)
    agent = Account.current.all_agents.find_by_user_id(user_agent.id)
    agent.update_attribute(:shortcuts_enabled, false)
    put :toggle_shortcuts, id: user_agent.id, format: 'json'
    assert_response 200
    assert JSON.parse(response.body)["shortcuts_enabled"] == true
    user_agent.destroy
    log_out
  end

  def test_create
    login_admin
    @user = Account.current.account_managers.first.make_current
    field_agent_type = AgentType.create_agent_type(@account, 'field_agent')
    collaborator_agent_type = AgentType.create_agent_type(@account, 'collaborator')
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Account.any_instance.stubs(:collaborators_enabled?).returns(true)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)

    role_id = Account.current.roles.find_by_name("Agent").id
    user_email = Faker::Internet.email
    flash_string = "The Agent has been created and activation instructions sent to #{Faker::Internet.email}"
    post :create, :user => {:name => Faker::Name.name,
                        :email => user_email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :language => "en",
                        :role_ids => ["#{role_id}"],
                        :agent_type => 0 }
    assert_response 302
    assert flash[:notice], flash_string
    user = add_test_agent(@account)
    subscription = Account.current.subscription
    subscription.agent_limit = Account.current.all_agents.count
    subscription.state = "active"
    subscription.save

    Agent.any_instance.stubs(:save).returns(false)
    role_id = Account.current.roles.find_by_name("Agent").id
    post :create, :user => {:name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :language => "en",
                        :role_ids => ["#{role_id}"],
                        :agent_type => 0 }
    assert_response 200
    Agent.any_instance.unstub(:save)

    post :create, :user => {:name => user.name,
                        :email => user.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :language => "en",
                        :role_ids => ["#{role_id}"],
                        :agent_type => 1 }
    assert_response 200
    
    User.any_instance.stubs(:signup!).returns(false)
    role_id = Account.current.roles.find_by_name("Agent").id
    post :create, :user => {:name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :language => "en",
                        :role_ids => ["#{role_id}"],
                        :agent_type => 1 }
    assert_response 200

    User.any_instance.stubs(:signup!).returns(false)
    role_id = Account.current.roles.find_by_name('Agent').id
    post :create, user: { name: Faker::Name.name,
                          email: Faker::Internet.email,
                          active: 1,
                          role: 1,
                          agent: 1,
                          ticket_permission: 1,
                          language: 'en',
                          role_ids: [role_id.to_s],
                          agent_type: 3 }
    assert_response 200
    subscription = Account.current.subscription
    subscription.agent_limit = nil
    subscription.state = "trial"
    subscription.save
    User.any_instance.unstub(:signup!)
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.any_instance.unstub(:collaborators_enabled?)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    field_agent_type.destroy
    collaborator_agent_type.destroy
    log_out
  end

  def test_create_with_race_condition_without_redis_key_limit_greater_than_agent_count
    login_admin
    key = agents_count_key
    remove_others_redis_key(key) if redis_key_exists?(key)
    @user = Account.current.account_managers.first.make_current
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:reached_agent_limit?).returns(false)

    role_id = Account.current.roles.find_by_name('Agent').id

    subscription = Account.current.subscription
    subscription.agent_limit = Account.current.full_time_support_agents.count + 1
    subscription.state = 'active'
    subscription.save
    post :create, :user => { name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1, agent: 1, ticket_permission: 1, language: 'en', role_ids: [role_id.to_s], agent_type: 1 }
    assert_response 302
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:reached_agent_limit?)
    log_out
  end

  def test_create_with_race_condition_without_redis_key
    login_admin
    key = agents_count_key
    remove_others_redis_key(key) if redis_key_exists?(key)
    @user = Account.current.account_managers.first.make_current
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:reached_agent_limit?).returns(false)

    role_id = Account.current.roles.find_by_name('Agent').id

    subscription = Account.current.subscription
    subscription.agent_limit = Account.current.full_time_support_agents.count
    subscription.state = 'active'
    subscription.save
    post :create, user: { name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1, agent: 1, ticket_permission: 1, language: 'en', role_ids: [role_id.to_s], agent_type: 1 }
    assert_response 200
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:reached_agent_limit?)
    log_out
  end

  def test_create_with_race_condition_with_redis_key
    login_admin
    key = agents_count_key
    remove_others_redis_key(key) if redis_key_exists?(key)
    @user = Account.current.account_managers.first.make_current
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    Account.any_instance.stubs(:reached_agent_limit?).returns(false)

    role_id = Account.current.roles.find_by_name('Agent').id
    current_agent_count = Account.current.full_time_support_agents.count
    set_others_redis_key(key, current_agent_count)

    subscription = Account.current.subscription
    subscription.agent_limit = current_agent_count
    subscription.state = 'active'
    subscription.save
    post :create, :user => { name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1, agent: 1, ticket_permission: 1, language: 'en', role_ids: [role_id.to_s], agent_type: 1 }
    assert_response 200
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count
    assert_equal subscription.agent_limit, Account.current.full_time_support_agents.count
  ensure
    subscription.agent_limit = nil
    subscription.state = 'trial'
    subscription.save
    Account.any_instance.unstub(:field_service_management_enabled?)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    Account.any_instance.unstub(:reached_agent_limit?)
    remove_others_redis_key(key) if redis_key_exists?(key)
    log_out
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

    put :convert_to_contact, id: agent.id
    assert_equal get_others_redis_key(key).to_i, Account.current.full_time_support_agents.count

    post :create, user: params_hash
    assert_response 302
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

  def test_create_multiple_items
    login_admin
    @user = Account.current.account_managers.first.make_current
    email_array = []

    # Success case: @agent_email length < 25
    5.times { email_array << Faker::Internet.email}
    put :create_multiple_items, agents_invite_email: email_array
    assert_response 200
    assert response.body.include?"Successfully sent"

    # Failure case: @agent_email length > 25
    email_array = []
    30.times { email_array << Faker::Internet.email}
    put :create_multiple_items, agents_invite_email: email_array
    assert_response 200

    # Failure case: @agent_email length > 25 & failure while creating 
    email_array = []
    5.times { email_array << Faker::Internet.email}
    Account.any_instance.stubs(:can_add_agents?).returns(false)
    put :create_multiple_items, agents_invite_email: email_array
    assert_response 200
    Account.any_instance.unstub(:can_add_agents?)

    log_out
  end

  def test_update
    login_admin
    @user = Account.current.account_managers.first.make_current
    user = add_test_agent(@account)
    role_id = Account.current.roles.find_by_name("Agent").id
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    post :update, id: user.id, user: { role_ids: role_id, group_ids: Account.current.groups.first.id }
    assert_response 200

    Agent.any_instance.stubs(:update_attributes).returns(false)
    post :update, id: user.id
    assert_response 200
    Agent.any_instance.unstub(:update_attributes)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    user.destroy
    log_out
  end

  def test_destroy
    login_admin
    @user = Account.current.account_managers.first.make_current

    # Success case
    user_agent = add_test_agent(@account)
    put :destroy, id: user_agent.id
    assert_response 302
    assert flash[:notice].include? "The agent has been deleted"
    user_agent.destroy

    # Failure case
    User.any_instance.stubs(:update_attributes).returns(false)
    user_agent = add_test_agent(@account)
    put :destroy, id: user_agent.id
    assert_response 302
    assert_equal flash[:notice], "The Agent could not be deleted"
    User.any_instance.unstub(:update_attributes)
    user_agent.destroy

    log_out
  end

  def test_convert_to_contact
    login_admin
    @user = Account.current.account_managers.first.make_current
    user_agent = add_test_agent(@account)

    put :convert_to_contact, id: user_agent.id
    assert_equal flash[:notice], I18n.t(:'flash.agents.to_contact'), "The agent has been successfully converted to a Contact"
    assert_response 302
    user_agent.destroy

    acc_subscription = Account.current.subscription
    acc_subscription.state = "active"
    acc_subscription.save!
    user_agent = add_test_agent(@account)
    put :convert_to_contact, id: user_agent.id
    assert_equal flash[:notice], I18n.t(:'flash.agents.to_contact_active', :subscription_link => "/subscription"), "Please <a href = '/subscription'>update</a> billing information to reflect this change."
    assert_response 302

    acc_subscription.state = "trial"
    acc_subscription.save!
    user_agent.destroy

    User.any_instance.stubs(:make_customer).returns(false)
    user_agent = add_test_agent(@account)
    put :convert_to_contact, id: user_agent.id
    assert_equal flash[:notice], I18n.t(:'flash.agents.to_contact_failed'), "The agent could not be converted to a Contact"
    assert_response 302
    User.any_instance.unstub
    user_agent.destroy

    user_agent = add_test_agent(@account)
    user_agent.deleted = 1
    user_agent.save

    put :convert_to_contact, id: user_agent.id
    assert_equal flash[:notice], I18n.t(:'flash.agents.edit.not_allowed'), "You cannot edit this agent"
    assert_response 302
    user_agent.destroy

    log_out
  end

  def test_restore
    login_admin
    @user = Account.current.account_managers.first.make_current

    subscription = Account.current.subscription
    subscription.agent_limit = Account.current.all_agents.count - 1 
    subscription.state = "active"
    subscription.save

    user_agent = add_test_agent(@account)
    user_agent.deleted = 1
    user_agent.save
    put :restore, id: user_agent.id
    assert_response 302

    subscription = Account.current.subscription
    subscription.agent_limit = nil
    subscription.state = "trial"
    subscription.save 

    user_agent = add_test_agent(@account)
    user_agent.deleted = 1
    user_agent.save
    put :restore, id: user_agent.id
    assert_equal flash[:notice], "The agent has been restored  \n"
    assert_response 302
    user_agent.destroy

    User.any_instance.stubs(:update_attributes).returns(false)
    user_agent = add_test_agent(@account)
    put :restore, id: user_agent.id
    assert_response 302
    assert_equal flash[:notice], "The Agent could not be restored"
    User.any_instance.unstub(:update_attributes)
    user_agent.destroy
    log_out
  end

  def test_reset_password
    login_admin
    @user = Account.current.account_managers.first.make_current
    user_agent = add_test_agent(@account)
    notify_string = "A reset mail with instructions has been sent to #{user_agent.email}."
    put :reset_password, id: user_agent.id
    assert_response 302
    assert_equal flash[:notice], notify_string
    user_agent.destroy

    User.any_instance.stubs(:can_edit_agent?).returns(false)
    user_agent = add_test_agent(@account)
    put :reset_password, id: user_agent.id
    assert_response 302
    assert flash[:notice], 'You cannot edit this agent'
    User.any_instance.unstub(:can_edit_agent?)
    user_agent.destroy

    put :reset_password, id: 1
    assert_response 302
    assert flash[:notice], 'You cannot edit this agent'

    user_agent = add_test_agent(@account)
    Account.current.stubs(:freshid_enabled?).returns(:true)
    put :reset_password, id: user_agent.id
    assert_response 302
    assert flash[:notice], 'You are not allowed to access this page!'
    Account.current.unstub(:freshid_enabled?)
    user_agent.destroy
    log_out
  end

  def test_reset_score
    login_admin
    @user = Account.current.account_managers.first.make_current
    user_agent = add_test_agent(@account)
    put :reset_score, id: user_agent.id
    assert_response 302
    assert_equal flash[:notice], "Please wait while we reset the arcade points. This might take a few minutes."
    user_agent.destroy

    User.any_instance.stubs(:can_edit_agent?).returns(false)
    user_agent = add_test_agent(@account)
    put :reset_score, id: user_agent.id
    assert_response 302
    assert flash[:notice], "You cannot edit this agent"
    User.any_instance.unstub(:can_edit_agent?)
    user_agent.destroy
    log_out
  end

  def test_info_for_node
    login_admin
    @user = Account.current.account_managers.first.make_current

    key = %{#{NodeConfig["rest_secret_key"]}#{Account.current.id}#{@user.id}}
    hash = Digest::MD5.hexdigest(key)

    get :info_for_node, user_id: @user.id, hash: hash
    assert_response 200
    assert JSON.parse(response.body)["ticket_permission"].present?

    get :info_for_node, user_id: @user.id
    assert_response 200
    assert_equal JSON.parse(response.body)["error"], "Access denied!"

    log_out
  end

  def test_api_key
    login_admin
    @user = Account.current.account_managers.first.make_current

    get :api_key, id: 1
    assert_response 404

    @request.stubs(:ssl?).returns(true)
    get :api_key, id: 1
    assert_response 404
    @request.unstub(:ssl?)
    log_out
  end

  def test_configure_export
    login_admin
    @user = Account.current.account_managers.first.make_current
    get :configure_export
    assert_response 200
    log_out
  end

  def test_export_skill_csv
    login_admin
    @user = Account.current.account_managers.first.make_current
    post :export_skill_csv
    assert_response 200
    log_out
  end

  def test_export_csv
    login_admin
    @user = Account.current.account_managers.first.make_current
    # success case
    post :export_csv, :export_fields => { name: "agent_name", email: "agent_email", type: "agent_type", role: "agent_roles", group: "groups", ph: "agent_phone", lang: "agent_language"}
    assert_equal flash[:notice], "Your Agents data will be sent to your email shortly!"

    # failure case
    post :export_csv, :export_fields => { name: "agent-name", email: "agent-email", type: "agent-type", role: "agent-roles", group: "groups", ph: "agent_phone", lang: "agent_language"}
    assert_equal flash[:notice], "An error occurred while exporting agent data. Please try again."

    log_out
  end

  def test_update_unpermitted_role_ids
    admin_role_id = Account.current.roles.admin.first.id
    agent_role_id = Account.current.roles.agent.first.id
    admin = add_test_agent(@account, {role: admin_role_id})
    agent = add_test_agent(@account, {role: agent_role_id})
    login_as(admin)
    acc_admin_role_id = Account.current.roles.account_admin.first.id
    put :update, id: agent.id, user: { 'name' => Faker::Name.name, 'role_ids' => [acc_admin_role_id] }
    assert flash[:notice], "You are not allowed to perform this action"
  ensure
    agent.destroy
    admin.destroy
    log_out
  end

  def test_update_unpermitted_fields
    login_admin
    @user = Account.current.account_managers.first.make_current
    user = add_test_agent(@account)
    role_id = Account.current.roles.find_by_name('Agent').id
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:allow_update_agent_enabled?).returns(false)
    put :update, id: user.id, user: { 'name' => Faker::Name.name }
    assert_response 403
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:allow_update_agent_enabled?)
    user.destroy
    log_out
  end

  def test_allow_profile_info_update
    login_admin
    @user = Account.current.account_managers.first.make_current
    user = add_test_agent(@account)
    role_id = Account.current.roles.find_by_name('Agent').id
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:allow_update_agent_enabled?).returns(true)
    put :update, id: user.id, user: { 'name' => Faker::Name.name }
    assert_response 200
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:allow_update_agent_enabled?)
    user.destroy
    log_out
  end

  def test_update_email_freshid_agent
    login_admin
    @user = Account.current.account_managers.first.make_current
    user = add_test_agent(@account)
    role_id = Account.current.roles.find_by_name('Agent').id
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    @controller.stubs(:freshid_user_details).returns(user)
    User.any_instance.stubs(:email_id_changed?).returns(false)
    put :update, id: user.id, user: { 'email' => Faker::Internet.email }
    assert_response 200
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    User.any_instance.unstub(:email_id_changed?)
    @controller.unstub(:freshid_user_details)
    user.destroy
    log_out
  end

  def test_update_unpermitted_fields_for_freshid_agent
    login_admin
    @user = Account.current.account_managers.first.make_current
    user = add_test_agent(@account)
    role_id = Account.current.roles.find_by_name('Agent').id
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    @controller.stubs(:freshid_user_details).returns(user)
    put :update, id: user.id, user: { 'email' => Faker::Internet.email, 'name' => Faker::Name.name }
    assert_response 403
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    @controller.unstub(:freshid_user_details)
    user.destroy
    log_out
  end

  def test_update_for_non_freshid_agent
    login_admin
    @user = Account.current.account_managers.first.make_current
    user = add_test_agent(@account)
    role_id = Account.current.roles.find_by_name('Agent').id
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    User.any_instance.stubs(:email_id_changed?).returns(false)
    @controller.stubs(:freshid_user_details).returns(nil)
    put :update, id: user.id, user: { 'email' => Faker::Internet.email, 'name' => Faker::Name.name }
    assert_response 200
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    User.any_instance.unstub(:email_id_changed?)
    @controller.unstub(:freshid_user_details)
    user.destroy
    log_out
  end
end
