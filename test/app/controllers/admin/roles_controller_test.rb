# frozen_string_literal: true

require_relative '../../../api/test_helper'

class Admin::RolesControllerTest < ActionController::TestCase
  include AccountHelper

  def setup
    super
    @account = Account.first || create_test_account
    @account.make_current
  end

  def test_manage_account_on_create_without_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    abilities_without_manage_account = User.current.abilities - [:manage_account]
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    name = "Test Role Param - #{Time.now.utc}"
    post :create, construct_params(roles_params(name: name))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal false, role.privilege?(:manage_account)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_manage_account_on_update_without_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    name = "Test Role Param - #{Time.now.utc}"
    role_save_params = roles_params(name: name, list: ['admin_tasks'])
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    abilities_without_manage_account = User.current.abilities - [:manage_account]
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: name)))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal false, role.privilege?(:manage_account)
    assert_equal true, role.privilege?(:manage_users)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_manage_account_on_create_with_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    abilities_without_manage_account = User.current.abilities
    abilities_without_manage_account += [:manage_account] unless abilities_without_manage_account.include?(:manage_account)
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    name = "Test Role Param - #{Time.now.utc}"
    post :create, construct_params(roles_params(name: name))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal true, role.privilege?(:manage_account)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_manage_account_on_update_with_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    name = "Test Role Param - #{Time.now.utc}"
    role_save_params = roles_params(name: name, list: ['admin_tasks'])
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    abilities_without_manage_account = User.current.abilities
    abilities_without_manage_account += [:manage_account] unless abilities_without_manage_account.include?(:manage_account)
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: name)))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal true, role.privilege?(:manage_account)
    assert_equal true, role.privilege?(:manage_users)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_create_role_with_invalid_privilege_mapping_for_the_field_agent_type_with_collaboration_roles_lp_enabled
    # setup
    @account.launch(:collaboration_roles)
    Account.any_instance.stubs(:current).returns(@account)
    role_name = "Field Agent Role - #{Time.now.utc}"
    # when
    post :create, construct_params(roles_params(name: role_name, list: [(Helpdesk::AgentTypes::SUPPORT_AGENT_PRIVILEGES - Helpdesk::AgentTypes::FIELD_AGENT_PRIVILEGES).sample], agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID))
    # then
    assert_response 200
    assert_template :new
    assert_equal true, Account.current.roles.find_by_name(role_name).blank?
  ensure
    @account.rollback(:collaboration_roles)
    Account.any_instance.unstub(:current)
  end

  # can be removed after LP cleanup
  def test_create_role_without_agent_type_param_with_collaboration_roles_lp_disabled
    # setup
    Account.any_instance.stubs(:current).returns(@account)
    @account.rollback(:collaboration_roles)
    role_name = "Sample Agent Role - #{Time.now.utc}"
    # when
    role_params = roles_params(name: role_name)
    role_params.delete(:agent_type)
    post :create, construct_params(role_params)
    # then
    assert_response 302
    assert_equal I18n.t(:'flash.roles.create.success', name: role_name), flash[:notice]
    assert_redirected_to admin_roles_url
    role = Account.current.roles.find_by_name(role_name)
    assert_equal true, role.present?
  ensure
    role.try(:destroy)
    Account.any_instance.unstub(:current)
  end

  def test_create_support_agent_role_with_collaboration_roles_lp_enabled
    @account.launch(:collaboration_roles)
    Account.any_instance.stubs(:current).returns(@account)
    role_name = "Support Agent Role - #{Time.now.utc}"
    # when
    post :create, construct_params(roles_params(name: role_name, list: [+'manage_tickets', +'reply_ticket'], agent_type: Helpdesk::AgentTypes::SUPPORT_AGENT_ID))
    # then
    assert_response 302
    assert_equal I18n.t(:'flash.roles.create.success', name: role_name), flash[:notice]
    assert_redirected_to admin_roles_url
    role = Account.current.roles.find_by_name(role_name)
    assert_equal true, role.present?
    assert_equal Helpdesk::AgentTypes::SUPPORT_AGENT_ID, role.agent_type
    assert_equal true, role.privilege?(:manage_tickets)
    assert_equal true, role.privilege?(:reply_ticket)
    assert_equal false, role.privilege?(:delete_contact)
  ensure
    role.try(:destroy)
    @account.rollback(:collaboration_roles)
    Account.any_instance.unstub(:current)
  end

  def test_create_field_agent_role_with_collaboration_roles_lp_enabled
    @account.launch(:collaboration_roles)
    Account.any_instance.stubs(:current).returns(@account)
    role_name = "Field Agent Role - #{Time.now.utc}"
    # when
    post :create, construct_params(roles_params(name: role_name, list: [+'manage_tickets', +'edit_ticket_properties'], agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID))
    # then
    assert_response 302
    assert_equal I18n.t(:'flash.roles.create.success', name: role_name), flash[:notice]
    assert_redirected_to admin_roles_url
    role = Account.current.roles.find_by_name(role_name)
    assert_equal true, role.present?
    assert_equal Helpdesk::AgentTypes::FIELD_AGENT_ID, role.agent_type
    assert_equal true, role.privilege?(:manage_tickets)
    assert_equal true, role.privilege?(:edit_ticket_properties)
    assert_equal false, role.privilege?(:manage_solutions)
  ensure
    role.try(:destroy)
    @account.rollback(:collaboration_roles)
    Account.any_instance.unstub(:current)
  end

  def test_update_role_by_changing_agent_type_with_collaboration_roles_lp_enabled
    # setup
    @account.launch(:collaboration_roles)
    Account.any_instance.stubs(:current).returns(@account)
    role_name = "Test Role - #{Time.now.utc}"
    role_save_params = roles_params(name: role_name, list: ['manage_tickets'], agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID)
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    role_name_update = "Updated Role - #{Time.now.utc}"
    # when
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: role_name_update, agent_type: Helpdesk::AgentTypes::SUPPORT_AGENT_ID)))
    # then
    assert_response 200
    assert_template :edit
    role = Account.current.roles.find_by_name(role_name)
    assert_equal true, role.present?
    assert_equal true, Account.current.roles.find_by_name(role_name_update).blank?
  ensure
    role.try(:destroy)
    @account.rollback(:collaboration_roles)
    Account.any_instance.unstub(:current)
  end

  def test_update_role_with_invalid_privilege_mapping_for_the_field_agent_type_with_collaboration_roles_lp_enabled
    # setup
    @account.launch(:collaboration_roles)
    Account.any_instance.stubs(:current).returns(@account)
    role_name = "Field Agent Role - #{Time.now.utc}"
    role_privilege = [(Helpdesk::AgentTypes::FIELD_AGENT_PRIVILEGES - [:manage_tickets]).sample]
    role_save_params = roles_params(name: role_name, list: role_privilege, agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID)
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    # when
    new_privilege = [(Helpdesk::AgentTypes::SUPPORT_AGENT_PRIVILEGES - Helpdesk::AgentTypes::FIELD_AGENT_PRIVILEGES - role_privilege).sample]
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: role_name, list: new_privilege, agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID)))
    # then
    assert_response 200
    assert_template :edit
    role = Account.current.roles.find_by_name(role_name)
    assert_equal true, role.privilege_list.include?(role_privilege.first)
    assert_equal false, role.privilege_list.include?(new_privilege.first)
  ensure
    role.try(:destroy)
    @account.rollback(:collaboration_roles)
    Account.any_instance.unstub(:current)
  end

  def test_update_field_agent_role_with_collaboration_roles_lp_enabled
    # setup
    @account.launch(:collaboration_roles)
    Account.any_instance.stubs(:current).returns(@account)
    old_role_name = "Field Agent Role - #{Time.now.utc}"
    old_role_privilege = [Helpdesk::AgentTypes::FIELD_AGENT_PRIVILEGES.sample]
    role_save_params = roles_params(name: old_role_name, list: old_role_privilege, agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID)
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    # when
    new_privilege = [(Helpdesk::AgentTypes::FIELD_AGENT_PRIVILEGES - old_role_privilege).sample]
    new_role_name = "Updated Field Agent Role - #{Time.now.utc}"
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: new_role_name, list: new_privilege, agent_type: Helpdesk::AgentTypes::FIELD_AGENT_ID)))
    # then
    assert_response 302
    assert_equal I18n.t(:'flash.roles.update.success', name: new_role_name), flash[:notice]
    assert_redirected_to admin_roles_url
    assert_equal true, Account.current.roles.find_by_name(old_role_name).blank?
    role = Account.current.roles.find_by_name(new_role_name)
    assert_equal true, role.present?
    assert_equal true, role.privilege_list.include?(new_privilege.first)
    assert_equal false, role.privilege_list.include?(old_role_privilege.first)
  ensure
    role.try(:destroy)
    @account.rollback(:collaboration_roles)
    Account.any_instance.unstub(:current)
  end

  def test_update_role_with_already_used_name
    Account.any_instance.stubs(:current).returns(@account)
    role1_name = "Sample Role 1 - #{Time.now.utc}"
    role1 = @account.roles.build(roles_params(name: role1_name)[:role])
    role1.save
    role2 = @account.roles.build(roles_params(name: "Sample Role 2 - #{Time.now.utc}")[:role])
    role2.save
    put :update, construct_params({ id: role2.id }.merge!(roles_params({ name: role1_name })))
    assert_response 200
    assert_template :edit
    assert_equal 1, Account.current.roles.where(name: role1_name).count
  ensure
    role1.try(:destroy)
    role2.try(:destroy)
    Account.any_instance.unstub(:current)
  end

  def test_create_and_update_role_with_existing_name_case_insensitive
    Account.any_instance.stubs(:current).returns(@account)
    timestamp = Time.now.utc
    role1 = @account.roles.build(roles_params(name: "Role Name #{timestamp}")[:role])
    role1.save
    put :create, construct_params(roles_params(name: "role name #{timestamp}"))
    assert_response 200
    assert_template :new
    assert_equal 1, Account.current.roles.where(name: "Role Name #{timestamp}").count
    role2 = @account.roles.build(roles_params(name: "Role Name 2 #{timestamp}")[:role])
    role2.save
    put :update, construct_params({ id: role2.id }.merge!(roles_params(name: "role name #{timestamp}")))
    assert_response 200
    assert_template :edit
    assert_equal 1, Account.current.roles.where(name: "Role Name #{timestamp}").count
  ensure
    role1.try(:destroy)
    role2.try(:destroy)
    Account.any_instance.unstub(:current)
  end

  def test_new_role_when_max_limit_reached
    stub_const(RoleConstants, 'MAX_ROLES_LIMIT', 1) do
      get :new, format: 'html'
      assert_response 302
      assert_equal true, Account.current.roles.count.positive?
      assert_includes response.redirect_url, '/admin/roles'
    end
  end

  def test_new_role_when_max_limit_not_reached
    get :new, format: 'html'
    assert_response 200
    assert_equal true, Account.current.roles.count < RoleConstants::MAX_ROLES_LIMIT
  end

  def test_index_when_max_limit_reached
    stub_const(RoleConstants, 'MAX_ROLES_LIMIT', 1) do
      get :index, format: 'html'
      assert_response 200
      assert_equal true, Account.current.roles.count.positive?
      assert_equal true, @controller.safe_send(:max_limit_reached?)
    end
  end

  def test_index_when_max_limit_not_reached
    get :index, format: 'html'
    assert_response 200
    assert_equal true, Account.current.roles.count < RoleConstants::MAX_ROLES_LIMIT
    assert_equal false, @controller.safe_send(:max_limit_reached?)
  end

  def test_create_when_max_limit_reached
    stub_const(RoleConstants, 'MAX_ROLES_LIMIT', 1) do
      name = "Test Role Param - #{Time.now.utc}"
      post :create, construct_params(roles_params(name: name))
      assert_response 302
      role = Account.current.roles.find_by_name(name)
      assert_equal false, role.present?
      assert_includes response.redirect_url, '/admin/roles'
      assert_equal true, Account.current.roles.count.positive?
      assert_equal true, @controller.safe_send(:max_limit_reached?)
    end
  end

  private

    def roles_params(args = {})
      {
        format: 'html',
        role: {
          name: args[:name],
          description: 'A Sample Test Role',
          privilege_list: args[:list] || [+'admin_tasks', +'manage_account', +'manage_users'],
          agent_type: args[:agent_type] || Helpdesk::AgentTypes::SUPPORT_AGENT_ID
        },
        add_user_ids: '',
        delete_user_ids: ''
      }
    end
end
